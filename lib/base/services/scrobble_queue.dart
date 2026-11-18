import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/utils/metadata_utils.dart';

class ScrobbleEvent {
  final String id;
  final String serverId;
  final String sourceType;
  final String songId;
  final String title;
  final String artist;
  final String album;
  final int times;
  final int finishedAtMs;
  int attempts;
  int nextAtMs;
  String state; // pending / attempting / dead
  String lastErrorKind;

  ScrobbleEvent({
    required this.id,
    required this.serverId,
    required this.sourceType,
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    required this.times,
    required this.finishedAtMs,
    this.attempts = 0,
    this.nextAtMs = 0,
    this.state = 'pending',
    this.lastErrorKind = '',
  });

  factory ScrobbleEvent.fromJson(Map json) => ScrobbleEvent(
    id: '${json['id'] ?? ''}',
    serverId: '${json['server'] ?? ''}',
    sourceType: '${json['source'] ?? ''}',
    songId: '${json['song'] ?? ''}',
    title: '${json['title'] ?? ''}',
    artist: '${json['artist'] ?? ''}',
    album: '${json['album'] ?? ''}',
    times: json['times'] is int ? json['times'] as int : 1,
    finishedAtMs: json['finished'] is int ? json['finished'] as int : 0,
    attempts: json['attempts'] is int ? json['attempts'] as int : 0,
    nextAtMs: json['next'] is int ? json['next'] as int : 0,
    state: '${json['state'] ?? 'pending'}',
    lastErrorKind: '${json['error'] ?? ''}',
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'server': serverId,
    'source': sourceType,
    'song': songId,
    'title': title,
    'artist': artist,
    'album': album,
    'times': times,
    'finished': finishedAtMs,
    'attempts': attempts,
    'next': nextAtMs,
    'state': state,
    'error': lastErrorKind,
  };
}

/// Play reports that could not be delivered. They are kept until the server
/// answers, so listening offline still counts once the connection returns.
class ScrobbleQueue {
  final events = ValueNotifier<List<ScrobbleEvent>>([]);
  final deadEvents = ValueNotifier<List<ScrobbleEvent>>([]);

  File? _file;
  File? _deadFile;
  bool _loaded = false;
  Timer? _timer;
  bool _sending = false;

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final dir = Directory(appSupportDir.path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _file = File('${dir.path}/scrobble_queue.json');
    _deadFile = File('${dir.path}/scrobble_dead.json');
    if (!_file!.existsSync()) {
      _file!.writeAsStringSync('[]');
    }
    if (!_deadFile!.existsSync()) {
      _deadFile!.writeAsStringSync('[]');
    }
    try {
      final raw = jsonDecode(await _file!.readAsString());
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final event = ScrobbleEvent.fromJson(item);
            if (event.id.isNotEmpty) {
              if (event.state == 'attempting') {
                event.state = 'pending';
              }
              events.value = [...events.value, event];
            }
          }
        }
      }
    } catch (_) {}
    try {
      final raw = jsonDecode(await _deadFile!.readAsString());
      if (raw is List) {
        deadEvents.value = [
          for (final item in raw)
            if (item is Map) ScrobbleEvent.fromJson(item),
        ];
      }
    } catch (_) {}
    _publish();
  }

  Future<void> start() async {
    await ensureLoaded();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(flush());
    });
    unawaited(flush());
  }

  Future<void> enqueue(MyAudioMetadata song, int times) async {
    if (!isStreamSource || streamClient == null || times <= 0) {
      return;
    }
    final serverId = config.activeServerId;
    if (serverId == null || serverId.isEmpty) {
      return;
    }
    await ensureLoaded();
    final now = DateTime.now().millisecondsSinceEpoch;
    final key = '$serverId:${song.id}:$now';
    final existing = events.value.where(
      (event) =>
          event.serverId == serverId &&
          event.songId == song.id &&
          event.finishedAtMs == now,
    );
    if (existing.isNotEmpty) {
      return;
    }
    final event = ScrobbleEvent(
      id: key,
      serverId: serverId,
      sourceType: sourceType.name,
      songId: song.id,
      title: getTitle(song),
      artist: getArtist(song),
      album: getAlbum(song),
      times: times,
      finishedAtMs: now,
    );
    events.value = [event, ...events.value];
    _trim();
    await _save();
    _publish();
    unawaited(flush());
  }

  Future<void> flush() async {
    if (_sending) {
      return;
    }
    await ensureLoaded();
    _sending = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pending = events.value.where(
        (event) =>
            event.state == 'pending' &&
            event.nextAtMs <= now &&
            event.serverId == config.activeServerId,
      ).toList();
      for (final event in pending) {
        if (streamClient == null) {
          break;
        }
        var ok = true;
        try {
          for (var i = 0; i < event.times; i++) {
            final sent = await streamClient!.scrobble(event.songId);
            if (!sent) {
              ok = false;
              break;
            }
          }
        } catch (e) {
          ok = false;
          logger.output('[scrobble] ${event.songId}: $e');
        }
        if (ok) {
          events.value = [
            for (final item in events.value)
              if (item.id != event.id) item,
          ];
        } else {
          event.attempts++;
          event.lastErrorKind = 'network';
          if (event.attempts >= 12) {
            event.state = 'dead';
          } else {
            final delay =
                Duration(minutes: (1 << (event.attempts - 1)).clamp(1, 360).toInt());
            event.nextAtMs = DateTime.now().add(delay).millisecondsSinceEpoch;
          }
        }
        _publish();
        await _save();
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> retry(ScrobbleEvent event) async {
    event.state = 'pending';
    event.nextAtMs = 0;
    event.attempts = 0;
    _publish();
    await _save();
    unawaited(flush());
  }

  Future<void> remove(ScrobbleEvent event) async {
    events.value = [
      for (final item in events.value)
        if (item.id != event.id) item,
    ];
    _publish();
    await _save();
  }

  Future<void> clearDead() async {
    deadEvents.value = const [];
    await _deadFile?.writeAsString('[]');
    _publish();
  }

  void _trim() {
    final list = List<ScrobbleEvent>.from(events.value);
    if (list.length <= 5000) {
      return;
    }
    list.sort((a, b) => a.finishedAtMs.compareTo(b.finishedAtMs));
    final overflow = list.length - 5000;
    final moved = list.take(overflow).toList();
    final keep = list.skip(overflow).toList();
    events.value = keep;
    final dead = List<ScrobbleEvent>.from(deadEvents.value)..addAll(moved);
    if (dead.length > 200) {
      dead.removeRange(0, dead.length - 200);
    }
    deadEvents.value = dead;
  }

  void _publish() {
    // ValueNotifier compares lists by identity; replacing both lists is what
    // the settings page and the diagnostics listen to.
    events.value = List.of(events.value);
    deadEvents.value = List.of(deadEvents.value);
  }

  Future<void> _save() async {
    try {
      await _file?.writeAsString(jsonEncode([for (final e in events.value) e.toJson()]));
      await _deadFile?.writeAsString(
        jsonEncode([for (final e in deadEvents.value) e.toJson()]),
      );
    } catch (_) {}
  }
}

final scrobbleQueue = ScrobbleQueue();
