import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:kuroshiro/kuroshiro.dart';

/// Kana ranges only: kanji is shared with Chinese, so a line without kana is
/// left alone instead of being romanised as Japanese.
final _kanaPattern = RegExp(r'[\u3040-\u30ff\u31f0-\u31ff]');

/// Whether [text] contains Japanese kana, i.e. is worth romanising.
bool hasJapaneseKana(String text) => _kanaPattern.hasMatch(text);

/// Kuroshiro's spaced mode separates tokens with several spaces around
/// non-Japanese words; a lyric line reads better with single spaces.
String normalizeRomajiSpacing(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Generates romaji for lyric lines on a background isolate.
///
/// The Japanese tokeniser needs its dictionary loaded once (hundreds of
/// milliseconds, tens of megabytes); keeping a worker alive across songs
/// means only the first request pays that cost. Results are cached by the
/// lyric text, so switching back to a song is immediate. Any failure yields
/// `null` entries - the lyrics page simply keeps showing the original lines.
class RomajiService {
  RomajiService();

  Isolate? _isolate;
  ReceivePort? _replies;
  SendPort? _requests;
  Future<void>? _starting;
  int _nextId = 1;
  final _pending = <int, Completer<List<String?>?>>{};
  final _cache = <String, List<String?>>{};
  final _inFlight = <String, Future<List<String?>?>>{};

  static const _cacheLimit = 8;
  static const _requestTimeout = Duration(seconds: 20);

  Future<List<String?>> convertLines(List<String> lines) async {
    final empty = List<String?>.filled(lines.length, null);
    if (!lines.any(hasJapaneseKana)) {
      return empty;
    }

    final key = md5.convert(utf8.encode(lines.join('\u0000'))).toString();
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }

    final running = _inFlight[key];
    if (running != null) {
      return await running ?? empty;
    }

    final request = _request(lines);
    _inFlight[key] = request;
    try {
      final result = await request;
      if (result == null) {
        return empty;
      }
      _cache[key] = result;
      if (_cache.length > _cacheLimit) {
        _cache.remove(_cache.keys.first);
      }
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<List<String?>?> _request(List<String> lines) async {
    try {
      await _ensureWorker();
      final id = _nextId++;
      final completer = Completer<List<String?>?>();
      _pending[id] = completer;
      _requests!.send([id, lines]);
      return await completer.future.timeout(_requestTimeout);
    } catch (_) {
      _shutdown();
      return null;
    }
  }

  Future<void> _ensureWorker() {
    if (_requests != null) {
      return Future.value();
    }
    return _starting ??= _startWorker();
  }

  Future<void> _startWorker() async {
    final replies = ReceivePort();
    final ready = Completer<SendPort>();
    replies.listen((message) {
      if (message is SendPort) {
        if (!ready.isCompleted) {
          ready.complete(message);
        }
        return;
      }
      _handleReply(message);
    });

    try {
      _isolate = await Isolate.spawn(
        _romajiWorkerMain,
        replies.sendPort,
        debugName: 'lyrics-romaji',
      );
      _replies = replies;
      _requests = await ready.future.timeout(_requestTimeout);
    } catch (_) {
      replies.close();
      _shutdown();
      rethrow;
    } finally {
      _starting = null;
    }
  }

  void _handleReply(Object? message) {
    if (message is! List || message.length != 3) {
      return;
    }
    final id = message[0];
    if (id is! int) {
      return;
    }
    final completer = _pending.remove(id);
    if (completer == null) {
      return;
    }
    final result = message[1];
    completer.complete(
      result is List
          ? [for (final value in result) value is String ? value : null]
          : null,
    );
  }

  void _shutdown() {
    _requests = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _replies?.close();
    _replies = null;
    _starting = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
    _pending.clear();
  }

  void dispose() => _shutdown();
}

/// Worker entry point. It receives `[id, lines]`, keeps its own Kuroshiro
/// instance alive between requests and answers on [reply] with
/// `[id, result, error]`.
Future<void> _romajiWorkerMain(SendPort reply) async {
  final inbound = ReceivePort();
  reply.send(inbound.sendPort);

  Kuroshiro? kuroshiro;
  await for (final message in inbound) {
    if (message is! List || message.length != 2) {
      continue;
    }
    final id = message[0];
    final rawLines = message[1];
    if (id is! int || rawLines is! List) {
      continue;
    }

    try {
      kuroshiro ??= await Kuroshiro().init();
      final result = <String?>[];
      for (final raw in rawLines.whereType<String>()) {
        if (!hasJapaneseKana(raw)) {
          result.add(null);
          continue;
        }
        final converted = await kuroshiro.convert(
          raw,
          to: ConvertTo.romaji,
          mode: ConvertMode.spaced,
        );
        final normalized = normalizeRomajiSpacing(converted);
        result.add(normalized.isEmpty ? null : normalized);
      }
      reply.send([id, result, null]);
    } catch (error) {
      reply.send([id, null, error.toString()]);
    }
  }
}

final romajiService = RomajiService();
