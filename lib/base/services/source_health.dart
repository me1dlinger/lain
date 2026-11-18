import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/data/music_server.dart';
import 'package:lain/base/services/emby_client.dart';
import 'package:lain/base/services/feiniu_client.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/navidrome_client.dart';
import 'package:lain/base/services/scrobble_queue.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/services/webdav_client.dart';

class SourceHealth {
  final String serverId;
  final String name;
  final SourceType type;
  bool ok;
  int? latencyMs;
  DateTime? lastCheckedAt;
  DateTime? lastOkAt;
  DateTime? lastFailAt;
  String error;
  int pendingReports;

  SourceHealth({
    required this.serverId,
    required this.name,
    required this.type,
    this.ok = false,
    this.latencyMs,
    this.lastCheckedAt,
    this.lastOkAt,
    this.lastFailAt,
    this.error = '',
    this.pendingReports = 0,
  });

  Map<String, Object?> toJson() => {
    'id': serverId,
    'name': name,
    'type': type.name,
    'ok': ok,
    'latency': latencyMs,
    'checked': lastCheckedAt?.millisecondsSinceEpoch,
    'okAt': lastOkAt?.millisecondsSinceEpoch,
    'failAt': lastFailAt?.millisecondsSinceEpoch,
    'error': error,
  };

  factory SourceHealth.fromJson(Map json) => SourceHealth(
    serverId: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    type: SourceType.values.asNameMap()['${json['type']}'] ?? SourceType.local,
    ok: json['ok'] == true,
    latencyMs: json['latency'] is int ? json['latency'] as int : null,
    lastCheckedAt: json['checked'] is int
        ? DateTime.fromMillisecondsSinceEpoch(json['checked'] as int)
        : null,
    lastOkAt: json['okAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(json['okAt'] as int)
        : null,
    lastFailAt: json['failAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(json['failAt'] as int)
        : null,
    error: '${json['error'] ?? ''}',
  );
}

/// Cached reachability of every configured source. The actual probing is
/// intentionally manual or low-frequency: a NAS that is asleep must not be
/// woken by a dashboard the user is not looking at.
class SourceHealthService {
  final entries = ValueNotifier<List<SourceHealth>>([]);
  File? _file;
  bool _loaded = false;
  bool _sampling = false;
  Timer? _timer;

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _file = File('${appSupportDir.path}/source_health.json');
    if (!_file!.existsSync()) {
      _file!.writeAsStringSync('{"sources":{}}');
    }
    try {
      final raw = jsonDecode(await _file!.readAsString());
      if (raw is Map && raw['sources'] is Map) {
        final list = <SourceHealth>[];
        (raw['sources'] as Map).forEach((key, value) {
          if (value is Map) {
            final health = SourceHealth.fromJson(value);
            if (health.serverId.isNotEmpty) {
              list.add(health);
            }
          }
        });
        entries.value = list;
      }
    } catch (_) {}
  }

  Future<void> start() async {
    await ensureLoaded();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      unawaited(sampleAll());
    });
  }

  Future<void> sampleAll() async {
    if (_sampling) {
      return;
    }
    _sampling = true;
    await ensureLoaded();
    try {
      final results = <SourceHealth>[];
      for (final server in config.servers) {
        final previous = entries.value.where(
          (item) => item.serverId == server.id,
        );
        final health = previous.isEmpty
            ? SourceHealth(
                serverId: server.id,
                name: server.name,
                type: server.type,
              )
            : previous.first;
        final watch = Stopwatch()..start();
        var ok = false;
        String error = '';
        try {
          ok = await _probe(server).timeout(const Duration(seconds: 6));
        } catch (e) {
          error = '$e';
        }
        watch.stop();
        health
          ..ok = ok
          ..latencyMs = ok ? watch.elapsedMilliseconds : null
          ..lastCheckedAt = DateTime.now()
          ..error = error;
        if (ok) {
          health.lastOkAt = DateTime.now();
        } else {
          health.lastFailAt = DateTime.now();
        }
        health.pendingReports = scrobbleQueue.events.value
            .where((event) => event.serverId == server.id)
            .length;
        results.add(health);
      }
      entries.value = results;
      await _save();
    } finally {
      _sampling = false;
    }
  }

  Future<bool> _probe(MusicServer server) async {
    final address = server.currentUrl;
    if (address.isEmpty) {
      return false;
    }
    if (server.type == .webdav) {
      return WebDavClient(
        baseUrl: address,
        username: server.username,
        password: server.password,
      ).ping();
    }
    final StreamClient client = switch (server.type) {
      .emby => EmbyClient(
        baseUrl: address,
        username: server.username,
        password: server.password,
      ),
      .feiniu => FeiniuClient(
        baseUrl: address,
        username: server.username,
        password: server.password,
      ),
      _ => NavidromeClient(
        baseUrl: address,
        username: server.username,
        password: server.password,
      ),
    };
    try {
      return await client.ping();
    } catch (e) {
      logger.output('[health] ${server.name}: $e');
      return false;
    }
  }

  Future<void> _save() async {
    try {
      await _file?.writeAsString(
        jsonEncode({
          'sources': {
            for (final item in entries.value) item.serverId: item.toJson(),
          },
        }),
      );
    } catch (_) {}
  }
}

final sourceHealth = SourceHealthService();
