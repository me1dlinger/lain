import 'package:flutter/foundation.dart';

/// One field a head unit line can be built from.
enum CarDisplayToken {
  lyricOriginal,
  lyricTranslation,
  title,
  artist,
  album;

  static CarDisplayToken? fromName(String? name) =>
      CarDisplayToken.values.asNameMap()[name ?? ''];
}

/// One text line on the head unit: fields in their display order and the
/// separator between them.
class CarDisplayLine {
  List<CarDisplayToken> tokens;
  String separator;

  CarDisplayLine({List<CarDisplayToken>? tokens, this.separator = ''})
    : tokens = tokens ?? [];

  Map<String, Object?> toJson() => {
    'tokens': [for (final token in tokens) token.name],
    'separator': separator,
  };

  factory CarDisplayLine.fromJson(Object? raw) {
    if (raw is! Map) {
      return CarDisplayLine();
    }
    final tokens = <CarDisplayToken>[];
    final rawTokens = raw['tokens'];
    if (rawTokens is List) {
      for (final name in rawTokens) {
        final token = CarDisplayToken.fromName('$name');
        if (token != null && !tokens.contains(token)) {
          tokens.add(token);
        }
      }
    }
    return CarDisplayLine(
      tokens: tokens,
      separator: '${raw['separator'] ?? ''}',
    );
  }

  CarDisplayLine copy() =>
      CarDisplayLine(tokens: List.of(tokens), separator: separator);
}

class CarDisplayConfig {
  int lineCount;
  List<CarDisplayLine> lines;

  CarDisplayConfig({required this.lineCount, required this.lines});

  Map<String, Object?> toJson() => {
    'lineCount': lineCount,
    'lines': [for (final line in lines) line.toJson()],
  };

  factory CarDisplayConfig.fromJson(Object? raw) {
    if (raw is! Map) {
      return defaultCarDisplayConfig();
    }
    final count = switch (raw['lineCount']) {
      3 => 3,
      2 => 2,
      _ => 2,
    };
    final lines = <CarDisplayLine>[];
    final rawLines = raw['lines'];
    if (rawLines is List) {
      for (final line in rawLines) {
        lines.add(CarDisplayLine.fromJson(line));
      }
    }
    while (lines.length < 3) {
      lines.add(CarDisplayLine());
    }
    if (lines.every((line) => line.tokens.isEmpty)) {
      return defaultCarDisplayConfig()..lineCount = count;
    }
    return CarDisplayConfig(lineCount: count, lines: lines.take(3).toList());
  }

  CarDisplayConfig copy() => CarDisplayConfig(
    lineCount: lineCount,
    lines: [for (final line in lines) line.copy()],
  );

  /// Whether the listener has never changed the layout.
  ///
  /// The default layout keeps the old "broadcast lyrics" switch semantics; a
  /// layout the listener actually configured is treated as an explicit choice.
  bool get isDefault {
    final base = defaultCarDisplayConfig();
    if (lineCount != base.lineCount) {
      return false;
    }
    for (var i = 0; i < base.lines.length; i++) {
      final line = i < lines.length ? lines[i] : CarDisplayLine();
      final expected = base.lines[i];
      if (line.separator != expected.separator ||
          line.tokens.length != expected.tokens.length) {
        return false;
      }
      for (var j = 0; j < expected.tokens.length; j++) {
        if (line.tokens[j] != expected.tokens[j]) {
          return false;
        }
      }
    }
    return true;
  }
}

CarDisplayConfig defaultCarDisplayConfig() => CarDisplayConfig(
  lineCount: 2,
  lines: [
    CarDisplayLine(tokens: [CarDisplayToken.lyricOriginal]),
    CarDisplayLine(
      tokens: [CarDisplayToken.artist, CarDisplayToken.title],
      separator: '-',
    ),
    CarDisplayLine(tokens: [CarDisplayToken.album]),
  ],
);

final carDisplayConfigNotifier = ValueNotifier<CarDisplayConfig>(
  defaultCarDisplayConfig(),
);

bool _hasCjk(String text) =>
    RegExp(r'[㐀-鿿぀-ヿ가-힯]').hasMatch(text);

bool _hasLatin(String text) => RegExp(r'[A-Za-z]').hasMatch(text);

/// Picks the pair shown by the original/translation fields.
///
/// In a Chinese app the original field prefers the English line and the
/// translation field the Chinese one; in an English app the two swap. This is
/// what makes a bilingual lyric read the way the user asked regardless of the
/// order the provider returned.
({String original, String translation}) carLyricPair({
  required String text,
  required List<String> translations,
  required bool englishLocale,
}) {
  final candidates = [
    text.trim(),
    for (final translation in translations) translation.trim(),
  ].where((item) => item.isNotEmpty).toList();
  if (candidates.isEmpty) {
    return (original: '', translation: '');
  }

  final cjk = candidates.where(_hasCjk).toList();
  final latin = candidates.where((item) => _hasLatin(item) && !_hasCjk(item)).toList();

  if (englishLocale) {
    final original = cjk.isNotEmpty ? cjk.first : candidates.first;
    final translation = latin.isNotEmpty
        ? latin.first
        : candidates.firstWhere(
            (item) => item != original,
            orElse: () => '',
          );
    return (original: original, translation: translation == original ? '' : translation);
  }

  final original = latin.isNotEmpty ? latin.first : candidates.first;
  final translation = cjk.isNotEmpty
      ? cjk.firstWhere(
          (item) => item != original,
          orElse: () => '',
        )
      : candidates.firstWhere(
          (item) => item != original,
          orElse: () => '',
        );
  return (original: original, translation: translation == original ? '' : translation);
}

/// Builds the lines actually published to the head unit.
///
/// Empty fields are dropped; a line that contains a lyric field but has no
/// lyric at this moment falls back to the song title, so the top line never
/// goes blank before the first line or for a track without lyrics. A separator
/// gets one space on each side; leaving it empty joins the fields with a plain
/// space.
List<String> composeCarDisplayLines(
  CarDisplayConfig config, {
  required String title,
  required String artist,
  required String album,
  String? lyric,
  String? translation,
  bool lyricsEnabled = true,
}) {
  final original = lyricsEnabled ? (lyric ?? '').trim() : '';
  final translated = lyricsEnabled ? (translation ?? '').trim() : '';
  final fields = {
    CarDisplayToken.lyricOriginal: original,
    CarDisplayToken.lyricTranslation: translated,
    CarDisplayToken.title: title.trim(),
    CarDisplayToken.artist: artist.trim(),
    CarDisplayToken.album: album.trim(),
  };

  String resolved(CarDisplayLine line) {
    final separator = line.separator.trim();
    final join = separator.isEmpty ? ' ' : ' $separator ';
    final parts = [
      for (final token in line.tokens)
        if ((fields[token] ?? '').isNotEmpty) fields[token]!,
    ];
    var text = parts.join(join).trim();
    if (text.isNotEmpty) {
      return text;
    }
    final hasLyric = line.tokens.any(
      (token) =>
          token == CarDisplayToken.lyricOriginal ||
          token == CarDisplayToken.lyricTranslation,
    );
    if (hasLyric) {
      // Translation missing is normal; show the original instead of nothing.
      if (translated.isEmpty && original.isNotEmpty) {
        return original;
      }
      // No lyric at all: the first line falls back to the song name, a later
      // line may legitimately be empty.
      if (!line.tokens.contains(CarDisplayToken.title)) {
        return title.trim();
      }
    }
    return text;
  }

  final count = config.lineCount.clamp(2, 3);
  return [
    for (var i = 0; i < count; i++)
      resolved(
        i < config.lines.length ? config.lines[i] : CarDisplayLine(),
      ),
  ];
}

/// Whether [config] has a lyric field in one of the lines it actually shows.
///
/// A custom layout is an explicit choice about what the head unit displays: a
/// line built from "original" or "translation" is a request for lyric text,
/// so it must not depend on the legacy "broadcast lyrics" switch as well.
bool carLayoutUsesLyrics(CarDisplayConfig config) {
  final count = config.lineCount.clamp(2, 3);
  for (var i = 0; i < count && i < config.lines.length; i++) {
    for (final token in config.lines[i].tokens) {
      if (token == CarDisplayToken.lyricOriginal ||
          token == CarDisplayToken.lyricTranslation) {
        return true;
      }
    }
  }
  return false;
}

/// Whether the lyric values are filled for the current layout.
///
/// A layout with no lyric field never asks for lyric text, whatever the
/// legacy switch says. On the classic Bluetooth route any layout that has a
/// lyric field is honoured: that route exists to put the configured text on
/// the head unit, so it must not need a second, older switch. The smart-link
/// route keeps the historical behaviour: an untouched default layout still
/// follows the switch, while a customised layout is self-sufficient.
bool carLyricsEnabled({
  required CarDisplayConfig config,
  required bool legacySwitch,
  bool classicRoute = false,
}) {
  if (!carLayoutUsesLyrics(config)) {
    return false;
  }
  if (classicRoute) {
    return true;
  }
  return config.isDefault ? legacySwitch : true;
}

/// The fixed three-line mapping used on the classic Bluetooth route when the
/// layout is still the untouched default.
///
/// This is the shape that route has always been given: the current lyric on
/// the primary line, "artist - title" on the secondary one and the album on
/// the third. With [lyricOnPrimaryLine] false the primary line keeps the song
/// title and the secondary line carries the lyric, which is what a unit that
/// renders the metadata's artist field reads.
List<String> composeClassicBroadcastLines({
  required String title,
  required String artist,
  required String album,
  String? lyric,
  bool lyricOnPrimaryLine = true,
}) {
  final line = lyric != null && lyric.trim().isNotEmpty ? lyric.trim() : null;
  return [
    (lyricOnPrimaryLine && line != null) ? line : title,
    lyricOnPrimaryLine ? '$artist - $title' : (line ?? artist),
    album,
  ];
}

/// Builds the three published lines for [config] on [classic] or smart-link.
///
/// A layout the listener configured is always composed exactly as configured:
/// that is the feature the switch exists for. The untouched default layout has
/// no custom text to preserve, so on the classic Bluetooth route it uses the
/// fixed three-line mapping above; elsewhere it keeps the flexible two-line
/// composition.
List<String> composeCarLinesForRoute({
  required CarDisplayConfig config,
  required bool classic,
  required String title,
  required String artist,
  required String album,
  String? lyric,
  String? translation,
  required bool lyricsEnabled,
  required bool lyricOnPrimaryLine,
}) {
  if (classic && config.isDefault) {
    return composeClassicBroadcastLines(
      title: title,
      artist: artist,
      album: album,
      lyric: lyric,
      lyricOnPrimaryLine: lyricOnPrimaryLine,
    );
  }
  return composeCarDisplayLines(
    config,
    title: title,
    artist: artist,
    album: album,
    lyric: lyric,
    translation: translation,
    lyricsEnabled: lyricsEnabled,
  );
}
