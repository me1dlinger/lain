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

/// CJK ideographs. A kanji-only line cannot be classified on its own, but
/// once another line in the same lyric contains kana, it is almost certainly a
/// Japanese line and should be romanised too.
bool hasCjkIdeographs(String text) => RegExp(r'[㐀-鿿]').hasMatch(text);

final _creditPattern = RegExp(
  r'^(作词|作詞|作曲|编曲|編曲|制作|製作|混音|母带|母帶|翻译|翻譯|演唱|和声|和聲|录音|錄音|lyrics?|composed|arranged|produced|mixed|mastered|translated)(\s+by)?\s*[:：]',
  caseSensitive: false,
);

final _placeholderPattern = RegExp(
  r'^(纯音乐|純音樂|暂无歌词|暫無歌詞|无歌词|無歌詞|instrumental|no lyrics|//|[\s\*＊・.。…\-—_=~]+)$',
  caseSensitive: false,
);

/// Credits and placeholder lines are metadata, not lyrics. Leaving them in
/// the Japanese signal makes a Chinese credit line with a Japanese name look
/// like a Japanese lyric and can make the whole song's decision unstable.
bool isLyricContentLine(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  return !_creditPattern.hasMatch(trimmed) &&
      !_placeholderPattern.hasMatch(trimmed);
}

final _japaneseScriptPattern = RegExp(r'[぀-ヿ㐀-鿿々]');

/// Normalises invisible padding that lyric providers sometimes inject around
/// a line. A zero-width or non-breaking space can make Kuroshiro reject an
/// otherwise ordinary line, which used to leave the original Japanese text
/// mixed into the romaji output.
String sanitizeRomajiText(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final invisible =
        rune < 0x20 ||
        rune == 0x7f ||
        (rune >= 0x200b && rune <= 0x200f) ||
        (rune >= 0x202a && rune <= 0x202e) ||
        rune == 0x2060 ||
        rune == 0xfeff ||
        rune == 0x00a0 ||
        rune == 0x3000;
    buffer.write(invisible ? ' ' : String.fromCharCode(rune));
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _containsJapaneseScript(String text) =>
    _japaneseScriptPattern.hasMatch(text);

/// Lyrics sometimes carry inline readings such as `運命(さだめ)`. Use the
/// reading for romaji instead of asking the tokeniser to guess an unusual
/// kanji compound; this also avoids parser failures on the parentheses.
String normalizeAnnotatedReading(String text) {
  final pattern = RegExp(r'([㐀-鿿々]+)[（(]([぀-ヿー]+)[）)]');
  return text.replaceAllMapped(pattern, (match) => match.group(2)!);
}

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

  Future<List<String?>> convertLines(
    List<String> lines, {
    bool preferJapanese = false,
  }) async {
    final empty = List<String?>.filled(lines.length, null);
    if (!preferJapanese &&
        !lines.where(isLyricContentLine).any(hasJapaneseKana)) {
      return empty;
    }

    final key = md5
        .convert(utf8.encode('${lines.join('\u0000')}|$preferJapanese'))
        .toString();
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }

    final running = _inFlight[key];
    if (running != null) {
      return await running ?? empty;
    }

    final request = _request(lines, preferJapanese);
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

  Future<List<String?>?> _request(
    List<String> lines,
    bool preferJapanese,
  ) async {
    try {
      await _ensureWorker();
      final id = _nextId++;
      final completer = Completer<List<String?>?>();
      _pending[id] = completer;
      _requests!.send([id, lines, preferJapanese]);
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

/// Converts one line with a per-token fallback. Kuroshiro occasionally
/// throws on one rare kanji; splitting the line keeps the rest readable
/// instead of losing the whole song to that one character.
Future<String?> _convertLine(Kuroshiro kuroshiro, String raw) async {
  final text = normalizeAnnotatedReading(sanitizeRomajiText(raw));

  Future<String?> convert(String value) async {
    try {
      final converted = await kuroshiro.convert(
        value,
        to: ConvertTo.romaji,
        mode: ConvertMode.spaced,
      );
      final normalized = normalizeRomajiSpacing(converted);
      // Never publish a half-converted line. Some tokenisers leave rare kanji
      // untouched; mixing Japanese and romaji in one line is worse than
      // showing no pronunciation for that line.
      if (normalized.isEmpty || _containsJapaneseScript(normalized)) {
        return null;
      }
      return normalized;
    } catch (_) {
      return null;
    }
  }

  final whole = await convert(text);
  if (whole != null) {
    return whole;
  }

  final parts = text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final converted = <String>[];
  for (final part in parts) {
    final value = await convert(part);
    if (value == null) {
      return null;
    }
    converted.add(value);
  }
  return converted.isEmpty ? null : normalizeRomajiSpacing(converted.join(' '));
}

/// Worker entry point. It receives `[id, lines]`, keeps its own Kuroshiro
/// instance alive between requests and answers on [reply] with
/// `[id, result, error]`.
Future<void> _romajiWorkerMain(SendPort reply) async {
  final inbound = ReceivePort();
  reply.send(inbound.sendPort);

  Kuroshiro? kuroshiro;
  await for (final message in inbound) {
    if (message is! List || (message.length != 2 && message.length != 3)) {
      continue;
    }
    final id = message[0];
    final rawLines = message[1];
    final preferJapanese = message.length == 3 && message[2] == true;
    if (id is! int || rawLines is! List) {
      continue;
    }

    try {
      kuroshiro ??= await Kuroshiro().init();
      final texts = rawLines.whereType<String>().toList();
      // Detect the song once, not each line: a Japanese lyric often has
      // kanji-only lines between kana lines. Per-line detection dropped those
      // lines and made romaji look intermittent.
      final songIsJapanese =
          preferJapanese ||
          texts.where(isLyricContentLine).any(hasJapaneseKana);
      final result = <String?>[];
      for (final raw in texts) {
        if (!isLyricContentLine(raw) ||
            (!hasJapaneseKana(raw) &&
                !(songIsJapanese && hasCjkIdeographs(raw)))) {
          result.add(null);
          continue;
        }
        result.add(await _convertLine(kuroshiro, raw));
      }
      reply.send([id, result, null]);
    } catch (error) {
      reply.send([id, null, error.toString()]);
    }
  }
}

final romajiService = RomajiService();
