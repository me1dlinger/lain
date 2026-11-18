import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lain/base/app.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/utils/metadata_utils.dart';

class JournalTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? coverId;
  final int durationMs;

  const JournalTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.coverId,
  });

  factory JournalTrack.fromSong(MyAudioMetadata song) => JournalTrack(
    id: song.id,
    title: getTitle(song),
    artist: getArtist(song),
    album: getAlbum(song),
    coverId: song.picture.id.isEmpty ? null : song.picture.id,
    durationMs: song.duration?.inMilliseconds ?? 0,
  );

  factory JournalTrack.fromJson(Map json) => JournalTrack(
    id: '${json['id'] ?? ''}',
    title: '${json['t'] ?? ''}',
    artist: '${json['a'] ?? ''}',
    album: '${json['b'] ?? ''}',
    coverId: json['c']?.toString(),
    durationMs: json['d'] is int ? json['d'] as int : 0,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    't': title,
    'a': artist,
    'b': album,
    if (coverId != null) 'c': coverId,
    'd': durationMs,
  };
}

class JournalEvent {
  final String songId;
  final String title;
  final String artist;
  final String album;
  final DateTime startedAt;
  final DateTime endedAt;
  final int playedMs;
  final int durationMs;
  final String endedBy;

  const JournalEvent({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    required this.startedAt,
    required this.endedAt,
    required this.playedMs,
    required this.durationMs,
    required this.endedBy,
  });

  double get completionRatio {
    if (durationMs <= 0) {
      return 0;
    }
    return (playedMs / durationMs).clamp(0.0, 1.0);
  }

  factory JournalEvent.fromJson(Map json) => JournalEvent(
    songId: '${json['id'] ?? ''}',
    title: '${json['t'] ?? ''}',
    artist: '${json['a'] ?? ''}',
    album: '${json['b'] ?? ''}',
    startedAt:
        DateTime.tryParse('${json['start'] ?? ''}') ?? DateTime.now(),
    endedAt: DateTime.tryParse('${json['end'] ?? ''}') ?? DateTime.now(),
    playedMs: json['p'] is int ? json['p'] as int : 0,
    durationMs: json['d'] is int ? json['d'] as int : 0,
    endedBy: '${json['by'] ?? 'switch'}',
  );

  Map<String, Object?> toJson() => {
    'id': songId,
    't': title,
    'a': artist,
    'b': album,
    'start': startedAt.toIso8601String(),
    'end': endedAt.toIso8601String(),
    'p': playedMs,
    'd': durationMs,
    'by': endedBy,
  };
}

class JournalSession {
  final String id;
  final DateTime startedAt;
  DateTime lastActivityAt;
  DateTime? endedAt;
  String? endReason;
  final String sourceType;
  final String? serverId;
  final String sourceKey;
  final List<JournalTrack> queue;
  int queueIndex;
  int playMode;
  final List<JournalEvent> events = [];
  int listenedMs = 0;

  JournalSession({
    required this.id,
    required this.startedAt,
    required this.sourceType,
    required this.serverId,
    required this.sourceKey,
    required this.queue,
    required this.queueIndex,
    required this.playMode,
  }) : lastActivityAt = startedAt;

  int get trackCount => events.length;
  int get completedCount => events.where((e) => e.completionRatio >= 0.9).length;
  int get skippedCount => events.where((e) => e.completionRatio < 0.5).length;

  factory JournalSession.fromJson(Map json) {
    final session = JournalSession(
      id: '${json['id'] ?? ''}',
      startedAt:
          DateTime.tryParse('${json['start'] ?? ''}') ?? DateTime.now(),
      sourceType: '${json['source'] ?? ''}',
      serverId: json['server']?.toString(),
      sourceKey: '${json['key'] ?? ''}',
      queue: [
        if (json['queue'] is List)
          for (final item in json['queue'] as List)
            if (item is Map) JournalTrack.fromJson(item),
      ],
      queueIndex: json['index'] is int ? json['index'] as int : 0,
      playMode: json['mode'] is int ? json['mode'] as int : 0,
    );
    session.lastActivityAt =
        DateTime.tryParse('${json['activity'] ?? ''}') ?? session.startedAt;
    session.endedAt = DateTime.tryParse('${json['ended'] ?? ''}');
    session.endReason = json['reason']?.toString();
    session.listenedMs = json['listened'] is int ? json['listened'] as int : 0;
    if (json['events'] is List) {
      for (final item in json['events'] as List) {
        if (item is Map) {
          session.events.add(JournalEvent.fromJson(item));
        }
      }
    }
    return session;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'start': startedAt.toIso8601String(),
    'activity': lastActivityAt.toIso8601String(),
    if (endedAt != null) 'ended': endedAt!.toIso8601String(),
    if (endReason != null) 'reason': endReason,
    'source': sourceType,
    if (serverId != null) 'server': serverId,
    'key': sourceKey,
    'queue': [for (final item in queue) item.toJson()],
    'index': queueIndex,
    'mode': playMode,
    'listened': listenedMs,
    'events': [for (final event in events) event.toJson()],
  };
}

/// A session is a continuous listening run, not one track. It is separate from
/// `listening_stats.json`: stats count what was played, this keeps when and in
/// what order, plus the queue to return to.
class PlaybackJournal {
  static const idleGap = Duration(minutes: 30);
  static const maxSessions = 2000;

  File? _file;
  bool _loaded = false;
  final List<JournalSession> sessions = [];
  JournalSession? _current;
  DateTime? _currentSongStartedAt;
  Timer? _flushTimer;

  String get _key =>
      '${sourceType.name}:${config.activeServerId ?? ''}';

  String get sourceKey => _key;

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _file = File('${appSupportDir.path}/playback_sessions.json');
    final dir = _file!.parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    if (!_file!.existsSync()) {
      _file!.writeAsStringSync('{"version":1,"sessions":[]}');
    }
    try {
      final raw = jsonDecode(await _file!.readAsString());
      if (raw is Map && raw['sessions'] is List) {
        for (final item in raw['sessions'] as List) {
          if (item is Map) {
            final session = JournalSession.fromJson(item);
            if (session.id.isNotEmpty) {
              sessions.add(session);
            }
          }
        }
      }
    } catch (_) {
      // A corrupt file must never stop playback; it starts empty.
    }
  }

  List<JournalSession> get history {
    final list = List<JournalSession>.from(sessions)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  JournalSession? get current => _current;

  Future<void> noteSong(MyAudioMetadata song, {required int index}) async {
    await ensureLoaded();
    final now = DateTime.now();
    final current = _current;
    if (current != null &&
        now.difference(current.lastActivityAt) > idleGap) {
      await end(reason: 'idle');
    }
    if (_current == null) {
      _current = JournalSession(
        id: '${now.microsecondsSinceEpoch}',
        startedAt: now,
        sourceType: sourceType.name,
        serverId: config.activeServerId,
        sourceKey: _key,
        queue: const [],
        queueIndex: index,
        playMode: 0,
      );
      sessions.add(_current!);
    }
    _currentSongStartedAt = now;
    _current!.lastActivityAt = now;
  }

  Future<void> captureQueue(
    List<MyAudioMetadata> queue, {
    required int index,
    required int playMode,
  }) async {
    await ensureLoaded();
    final current = _current;
    if (current == null) {
      return;
    }
    current.queue
      ..clear()
      ..addAll(queue.take(500).map(JournalTrack.fromSong));
    current.queueIndex = index;
    current.playMode = playMode;
    current.lastActivityAt = DateTime.now();
    _scheduleFlush();
  }

  Future<void> notePlaying(bool playing) async {
    final current = _current;
    if (current == null) {
      return;
    }
    if (playing) {
      current.lastActivityAt = DateTime.now();
    }
    _scheduleFlush();
  }

  Future<void> recordTrack(
    MyAudioMetadata song, {
    required Duration played,
    required Duration duration,
    required String endedBy,
  }) async {
    await ensureLoaded();
    final current = _current;
    if (current == null) {
      return;
    }
    final started =
        _currentSongStartedAt ?? DateTime.now().subtract(played);
    current.events.add(
      JournalEvent(
        songId: song.id,
        title: getTitle(song),
        artist: getArtist(song),
        album: getAlbum(song),
        startedAt: started,
        endedAt: DateTime.now(),
        playedMs: played.inMilliseconds,
        durationMs: duration.inMilliseconds,
        endedBy: endedBy,
      ),
    );
    current.listenedMs += played.inMilliseconds;
    current.lastActivityAt = DateTime.now();
    _currentSongStartedAt = null;
    _scheduleFlush();
  }

  Future<void> end({required String reason}) async {
    final current = _current;
    if (current == null) {
      return;
    }
    current.endedAt = DateTime.now();
    current.endReason = reason;
    _current = null;
    _currentSongStartedAt = null;
    await _save();
  }

  Future<void> flush({bool idleOnly = false}) async {
    final current = _current;
    if (current == null) {
      return;
    }
    if (idleOnly &&
        DateTime.now().difference(current.lastActivityAt) < idleGap) {
      return;
    }
    if (idleOnly) {
      await end(reason: 'idle');
    } else {
      await _save();
    }
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(minutes: 5), () {
      unawaited(_save());
    });
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) {
      return;
    }
    // A session without events was only opened and abandoned; it is not a
    // listening memory.
    sessions.removeWhere(
      (session) =>
          session.events.isEmpty &&
          session.endedAt != null &&
          session != _current,
    );
    if (sessions.length > maxSessions) {
      sessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      sessions.removeRange(0, sessions.length - maxSessions);
    }
    try {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({
          'version': 1,
          'sessions': [for (final session in sessions) session.toJson()],
        }),
        flush: true,
      );
      try {
        await tmp.rename(file.path);
      } catch (_) {
        await file.writeAsString(await tmp.readAsString(), flush: true);
        await tmp.delete();
      }
    } catch (_) {
      // Journal loss must not interrupt playback.
    }
  }

  List<JournalSession> onThisDay(DateTime day) {
    final month = day.month;
    final date = day.day;
    return [
      for (final session in sessions)
        if (session.startedAt.month == month &&
            session.startedAt.day == date &&
            session.startedAt.year < day.year)
          session,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  List<JournalSession> forDate(DateTime day) {
    return [
      for (final session in sessions)
        if (session.startedAt.year == day.year &&
            session.startedAt.month == day.month &&
            session.startedAt.day == day.day)
          session,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }
}

final playbackJournal = PlaybackJournal();
