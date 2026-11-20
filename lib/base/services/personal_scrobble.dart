import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/personal_scrobble.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/utils/metadata_utils.dart';

const _lastFmEndpoint = 'https://ws.audioscrobbler.com/2.0/';
const _listenBrainzEndpoint = 'https://api.listenbrainz.org/1/submit-listens';

class PersonalScrobbleCredentials {
  String lastFmApiKey;
  String lastFmApiSecret;
  String lastFmSession;
  String lastFmUser;
  String listenBrainzToken;

  PersonalScrobbleCredentials({
    this.lastFmApiKey = '',
    this.lastFmApiSecret = '',
    this.lastFmSession = '',
    this.lastFmUser = '',
    this.listenBrainzToken = '',
  });

  bool get lastFmReady =>
      lastFmSession.isNotEmpty &&
      lastFmApiKey.isNotEmpty &&
      lastFmApiSecret.isNotEmpty;

  bool get listenBrainzReady => listenBrainzToken.isNotEmpty;
}

class PersonalScrobbleEvent {
  final String id;
  final String service;
  final String source;
  final String title;
  final String artist;
  final String album;
  final int finishedAtMs;
  final int times;
  int attempts;
  int nextAtMs;
  String state;

  PersonalScrobbleEvent({
    required this.id,
    required this.service,
    required this.source,
    required this.title,
    required this.artist,
    required this.album,
    required this.finishedAtMs,
    required this.times,
    this.attempts = 0,
    this.nextAtMs = 0,
    this.state = 'pending',
  });

  factory PersonalScrobbleEvent.fromJson(Map json) => PersonalScrobbleEvent(
    id: '${json['id'] ?? ''}',
    service: '${json['service'] ?? ''}',
    source: '${json['source'] ?? ''}',
    title: '${json['title'] ?? ''}',
    artist: '${json['artist'] ?? ''}',
    album: '${json['album'] ?? ''}',
    finishedAtMs: json['finished'] is int ? json['finished'] as int : 0,
    times: json['times'] is int ? json['times'] as int : 1,
    attempts: json['attempts'] is int ? json['attempts'] as int : 0,
    nextAtMs: json['next'] is int ? json['next'] as int : 0,
    state: '${json['state'] ?? 'pending'}',
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'service': service,
    'source': source,
    'title': title,
    'artist': artist,
    'album': album,
    'finished': finishedAtMs,
    'times': times,
    'attempts': attempts,
    'next': nextAtMs,
    'state': state,
  };
}

/// Last.fm and ListenBrainz scrobbling.
///
/// The chosen modes live in `setting.json`; credentials live in their own
/// file so a settings backup never contains an API secret or session token.
/// Failed reports stay in a small queue and are retried with backoff.
class PersonalScrobbleService {
  final credentials = ValueNotifier<PersonalScrobbleCredentials>(
    PersonalScrobbleCredentials(),
  );
  final events = ValueNotifier<List<PersonalScrobbleEvent>>([]);

  File? _credentialsFile;
  File? _queueFile;
  bool _loaded = false;
  bool _sending = false;
  String _lastNowPlayingSong = '';
  int _lastNowPlayingAt = 0;
  Timer? _timer;

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final dir = Directory(appSupportDir.path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _credentialsFile = File('${dir.path}/personal_scrobble.json');
    _queueFile = File('${dir.path}/personal_scrobble_queue.json');
    if (!_credentialsFile!.existsSync()) {
      _credentialsFile!.writeAsStringSync('{}');
    }
    if (!_queueFile!.existsSync()) {
      _queueFile!.writeAsStringSync('[]');
    }
    try {
      final raw = jsonDecode(await _credentialsFile!.readAsString());
      if (raw is Map) {
        credentials.value = PersonalScrobbleCredentials(
          lastFmApiKey: '${raw['lastfm_api_key'] ?? ''}',
          lastFmApiSecret: '${raw['lastfm_api_secret'] ?? ''}',
          lastFmSession: '${raw['lastfm_session'] ?? ''}',
          lastFmUser: '${raw['lastfm_user'] ?? ''}',
          listenBrainzToken: '${raw['listenbrainz_token'] ?? ''}',
        );
      }
    } catch (_) {}
    try {
      final raw = jsonDecode(await _queueFile!.readAsString());
      if (raw is List) {
        events.value = [
          for (final item in raw)
            if (item is Map)
              if (PersonalScrobbleEvent.fromJson(item).id.isNotEmpty)
                PersonalScrobbleEvent.fromJson(item),
        ];
      }
    } catch (_) {}
  }

  Future<void> start() async {
    await ensureLoaded();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(flush());
    });
    unawaited(flush());
  }

  Future<void> setLastFmKeys(String apiKey, String apiSecret) async {
    await ensureLoaded();
    final next = _copyCredentials(
      lastFmApiKey: apiKey.trim(),
      lastFmApiSecret: apiSecret.trim(),
    );
    credentials.value = next;
    await _saveCredentials();
  }

  Future<bool> connectLastFm({
    required String apiKey,
    required String apiSecret,
    required String username,
    required String password,
  }) async {
    await ensureLoaded();
    final key = apiKey.trim();
    final secret = apiSecret.trim();
    if (key.isEmpty ||
        secret.isEmpty ||
        username.trim().isEmpty ||
        password.isEmpty) {
      return false;
    }
    final params = <String, String>{
      'method': 'auth.getMobileSession',
      'api_key': key,
      'username': username.trim(),
      'password': password,
      'format': 'json',
    };
    params['api_sig'] = _sign(params, secret);
    try {
      final response = await http
          .post(
            Uri.parse(_lastFmEndpoint),
            body: params,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (body is! Map || body['session'] is! Map) {
        logger.output('[lastfm] login failed: ${response.body}');
        return false;
      }
      final session = body['session'] as Map;
      final sessionKey = '${session['key'] ?? ''}';
      if (sessionKey.isEmpty) {
        return false;
      }
      credentials.value = _copyCredentials(
        lastFmApiKey: key,
        lastFmApiSecret: secret,
        lastFmSession: sessionKey,
        lastFmUser: '${session['name'] ?? username.trim()}',
      );
      await _saveCredentials();
      unawaited(flush());
      return true;
    } catch (e) {
      logger.output('[lastfm] login failed: $e');
      return false;
    }
  }

  Future<void> disconnectLastFm() async {
    await ensureLoaded();
    credentials.value = _copyCredentials(lastFmSession: '', lastFmUser: '');
    await _saveCredentials();
  }

  Future<void> setListenBrainzToken(String token) async {
    await ensureLoaded();
    credentials.value = _copyCredentials(listenBrainzToken: token.trim());
    await _saveCredentials();
  }

  PersonalScrobbleCredentials _copyCredentials({
    String? lastFmApiKey,
    String? lastFmApiSecret,
    String? lastFmSession,
    String? lastFmUser,
    String? listenBrainzToken,
  }) {
    final current = credentials.value;
    return PersonalScrobbleCredentials(
      lastFmApiKey: lastFmApiKey ?? current.lastFmApiKey,
      lastFmApiSecret: lastFmApiSecret ?? current.lastFmApiSecret,
      lastFmSession: lastFmSession ?? current.lastFmSession,
      lastFmUser: lastFmUser ?? current.lastFmUser,
      listenBrainzToken: listenBrainzToken ?? current.listenBrainzToken,
    );
  }

  /// Publishes the "now playing" entry as soon as a track starts. This is a
  /// one-shot network call, not a queued scrobble: a stale now-playing entry
  /// delivered ten minutes later would be wrong.
  Future<void> updateNowPlaying(
    MyAudioMetadata song, {
    Duration? duration,
  }) async {
    await ensureLoaded();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (song.id == _lastNowPlayingSong && now - _lastNowPlayingAt < 20000) {
      return;
    }
    final title = getTitle(song).trim();
    final artist = getArtist(song).trim();
    if (title.isEmpty || artist.isEmpty) {
      return;
    }
    final album = getAlbum(song).trim();
    final work = <Future<void>>[];
    final c = credentials.value;
    if (personalScrobbleAllows(lastFmScrobbleModeNotifier.value) &&
        c.lastFmReady) {
      work.add(_lastFmNowPlaying(c, title, artist, album, duration));
    }
    if (personalScrobbleAllows(listenBrainzScrobbleModeNotifier.value) &&
        c.listenBrainzReady) {
      work.add(
        _listenBrainzNowPlaying(
          c.listenBrainzToken,
          title,
          artist,
          album,
          duration,
        ),
      );
    }
    if (work.isEmpty) {
      return;
    }
    _lastNowPlayingSong = song.id;
    _lastNowPlayingAt = now;
    await Future.wait(work);
  }

  Future<void> enqueue(
    MyAudioMetadata song,
    int times, {
    DateTime? startedAt,
  }) async {
    if (times <= 0) {
      return;
    }
    await ensureLoaded();
    final started = startedAt ?? DateTime.now();
    final now = started.millisecondsSinceEpoch;
    final source = sourceType.name;
    final title = getTitle(song).trim();
    final artist = getArtist(song).trim();
    if (title.isEmpty || artist.isEmpty) {
      return;
    }
    final album = getAlbum(song).trim();
    final additions = <PersonalScrobbleEvent>[];
    if (personalScrobbleAllows(lastFmScrobbleModeNotifier.value) &&
        credentials.value.lastFmReady) {
      additions.add(
        PersonalScrobbleEvent(
          id: 'lastfm:${song.id}:$now',
          service: 'lastfm',
          source: source,
          title: title,
          artist: artist,
          album: album,
          finishedAtMs: now,
          times: times,
        ),
      );
    }
    if (personalScrobbleAllows(listenBrainzScrobbleModeNotifier.value) &&
        credentials.value.listenBrainzReady) {
      additions.add(
        PersonalScrobbleEvent(
          id: 'listenbrainz:${song.id}:$now',
          service: 'listenbrainz',
          source: source,
          title: title,
          artist: artist,
          album: album,
          finishedAtMs: now,
          times: times,
        ),
      );
    }
    if (additions.isEmpty) {
      return;
    }
    final known = {for (final event in events.value) event.id};
    final fresh = [
      for (final event in additions)
        if (!known.contains(event.id)) event,
    ];
    if (fresh.isEmpty) {
      return;
    }
    events.value = [...fresh, ...events.value];
    if (events.value.length > 1000) {
      events.value = events.value.take(1000).toList();
    }
    await _saveQueue();
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
      final pending = events.value
          .where(
            (event) =>
                event.state == 'pending' &&
                event.nextAtMs <= now &&
                ((event.service == 'lastfm' && credentials.value.lastFmReady) ||
                    (event.service == 'listenbrainz' &&
                        credentials.value.listenBrainzReady)),
          )
          .toList();
      for (final event in pending) {
        var ok = false;
        try {
          ok = await _send(event);
        } catch (e) {
          logger.output('[scrobble] ${event.service}: $e');
        }
        if (ok) {
          events.value = [
            for (final item in events.value)
              if (item.id != event.id) item,
          ];
        } else {
          event.attempts++;
          if (event.attempts >= 12) {
            event.state = 'dead';
          } else {
            final minutes = (1 << (event.attempts - 1)).clamp(1, 360);
            event.nextAtMs = DateTime.now()
                .add(Duration(minutes: minutes.toInt()))
                .millisecondsSinceEpoch;
          }
        }
        await _saveQueue();
      }
    } finally {
      _sending = false;
    }
  }

  Future<bool> _send(PersonalScrobbleEvent event) async {
    switch (event.service) {
      case 'lastfm':
        return _scrobbleLastFm(event);
      case 'listenbrainz':
        return _submitListenBrainz(event);
      default:
        return true;
    }
  }

  Future<void> _lastFmNowPlaying(
    PersonalScrobbleCredentials c,
    String title,
    String artist,
    String album,
    Duration? duration,
  ) async {
    try {
      final params = <String, String>{
        'method': 'track.updateNowPlaying',
        'api_key': c.lastFmApiKey,
        'sk': c.lastFmSession,
        'artist': artist,
        'track': title,
        'format': 'json',
      };
      if (album.isNotEmpty) {
        params['album'] = album;
      }
      if (duration != null && duration > Duration.zero) {
        params['duration'] = '${duration.inSeconds}';
      }
      params['api_sig'] = _sign(params, c.lastFmApiSecret);
      final response = await http
          .post(
            Uri.parse(_lastFmEndpoint),
            body: params,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (body is! Map || body['error'] != null) {
        logger.output('[lastfm] now playing failed: ${response.body}');
      }
    } catch (e) {
      logger.output('[lastfm] now playing failed: $e');
    }
  }

  Future<void> _listenBrainzNowPlaying(
    String token,
    String title,
    String artist,
    String album,
    Duration? duration,
  ) async {
    if (token.isEmpty) {
      return;
    }
    try {
      final metadata = <String, Object?>{
        'artist_name': artist,
        'track_name': title,
        if (album.isNotEmpty) 'release_name': album,
      };
      if (duration != null && duration > Duration.zero) {
        metadata['additional_info'] = {'duration_ms': duration.inMilliseconds};
      }
      final body = jsonEncode({
        'listen_type': 'playing_now',
        'payload': [
          {'track_metadata': metadata},
        ],
      });
      final response = await http
          .post(
            Uri.parse(_listenBrainzEndpoint),
            headers: {
              'Authorization': 'Token $token',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        logger.output(
          '[listenbrainz] now playing failed ${response.statusCode}: '
          '${response.body}',
        );
      }
    } catch (e) {
      logger.output('[listenbrainz] now playing failed: $e');
    }
  }

  Future<bool> _scrobbleLastFm(PersonalScrobbleEvent event) async {
    final c = credentials.value;
    if (!c.lastFmReady) {
      return false;
    }
    for (var i = 0; i < event.times; i++) {
      final timestamp = (event.finishedAtMs ~/ 1000) + i;
      final params = <String, String>{
        'method': 'track.scrobble',
        'api_key': c.lastFmApiKey,
        'sk': c.lastFmSession,
        'artist': event.artist,
        'track': event.title,
        'timestamp': '$timestamp',
        'format': 'json',
      };
      if (event.album.isNotEmpty) {
        params['album'] = event.album;
      }
      params['api_sig'] = _sign(params, c.lastFmApiSecret);
      final response = await http
          .post(
            Uri.parse(_lastFmEndpoint),
            body: params,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (body is! Map || body['error'] != null) {
        logger.output('[lastfm] scrobble failed: ${response.body}');
        return false;
      }
      final scrobbles = body['scrobbles'];
      if (scrobbles is Map) {
        final accepted = scrobbles['@attr'];
        if (accepted is Map && accepted['accepted'] == 0) {
          return false;
        }
      }
    }
    return true;
  }

  Future<bool> _submitListenBrainz(PersonalScrobbleEvent event) async {
    final token = credentials.value.listenBrainzToken;
    if (token.isEmpty) {
      return false;
    }
    for (var i = 0; i < event.times; i++) {
      final timestamp = (event.finishedAtMs ~/ 1000) + i;
      final payload = <String, Object?>{
        'listen_type': 'single',
        'payload': [
          {
            'listened_at': timestamp,
            'track_metadata': {
              'artist_name': event.artist,
              'track_name': event.title,
              if (event.album.isNotEmpty) 'release_name': event.album,
            },
          },
        ],
      };
      final response = await http
          .post(
            Uri.parse(_listenBrainzEndpoint),
            headers: {
              'Authorization': 'Token $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        logger.output(
          '[listenbrainz] submit failed ${response.statusCode}: '
          '${response.body}',
        );
        return false;
      }
    }
    return true;
  }

  String _sign(Map<String, String> params, String secret) {
    final keys = [
      for (final key in params.keys)
        if (key != 'format' && key != 'api_sig') key,
    ]..sort();
    final source = [for (final key in keys) '$key${params[key]}'].join();
    return md5.convert(utf8.encode('$source$secret')).toString();
  }

  Future<void> _saveCredentials() async {
    await ensureLoaded();
    try {
      await _credentialsFile!.writeAsString(
        jsonEncode({
          'lastfm_api_key': credentials.value.lastFmApiKey,
          'lastfm_api_secret': credentials.value.lastFmApiSecret,
          'lastfm_session': credentials.value.lastFmSession,
          'lastfm_user': credentials.value.lastFmUser,
          'listenbrainz_token': credentials.value.listenBrainzToken,
        }),
      );
    } catch (e) {
      logger.output('[scrobble] save credentials failed: $e');
    }
  }

  Future<void> _saveQueue() async {
    await ensureLoaded();
    try {
      await _queueFile!.writeAsString(
        jsonEncode([for (final event in events.value) event.toJson()]),
      );
    } catch (e) {
      logger.output('[scrobble] save queue failed: $e');
    }
  }
}

final personalScrobble = PersonalScrobbleService();
