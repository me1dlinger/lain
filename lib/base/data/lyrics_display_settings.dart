import 'package:material_ui/material_ui.dart';

/// How lyric lines are aligned. [auto] keeps the layout the pages have always
/// used: left in the full player, centred in the controls page and mini view.
enum LyricsTextAlign { auto, start, center }

LyricsTextAlign lyricsTextAlignFromName(Object? name) {
  for (final value in LyricsTextAlign.values) {
    if (value.name == name) {
      return value;
    }
  }
  return LyricsTextAlign.auto;
}

TextAlign lyricsTextAlignFor(LyricsTextAlign align, {required bool expanded}) {
  return switch (align) {
    LyricsTextAlign.auto => expanded ? TextAlign.left : TextAlign.center,
    LyricsTextAlign.start => TextAlign.left,
    LyricsTextAlign.center => TextAlign.center,
  };
}

CrossAxisAlignment lyricsCrossAxisAlignmentFor(
  LyricsTextAlign align, {
  required bool expanded,
}) {
  return switch (align) {
    LyricsTextAlign.auto =>
      expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
    LyricsTextAlign.start => CrossAxisAlignment.start,
    LyricsTextAlign.center => CrossAxisAlignment.center,
  };
}

/// Reads the persisted font weight (Flutter's 100..900 value) back into a
/// [FontWeight], falling back when the stored value is missing or unknown.
FontWeight lyricsFontWeightFromValue(
  Object? value, {
  FontWeight fallback = FontWeight.bold,
}) {
  if (value is int) {
    for (final weight in FontWeight.values) {
      if (weight.value == value) {
        return weight;
      }
    }
  }
  return fallback;
}

final lyricsFontSizeOffsetNotifier = ValueNotifier(0.0);
final lyricsFontWeightNotifier = ValueNotifier(FontWeight.bold);
final lyricsTextAlignNotifier = ValueNotifier(LyricsTextAlign.auto);

/// The full-screen lyrics page has its own visual scale. It follows the
/// cover-page offset, font family and romaji switch, but keeps its own size,
/// weight and alignment so tuning one page cannot shrink the other.
final lyricsFullscreenFontSizeOffsetNotifier = ValueNotifier(0.0);
final lyricsFullscreenFontWeightNotifier = ValueNotifier(FontWeight.bold);
final lyricsFullscreenTextAlignNotifier = ValueNotifier(LyricsTextAlign.auto);

/// Whether Japanese lyric lines get a romaji pronunciation line below them.
final lyricsRomajiNotifier = ValueNotifier(false);
