import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/lyrics_display_settings.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('lyrics alignment settings', () {
    test('reads persisted names and defaults to auto', () {
      expect(lyricsTextAlignFromName('start'), LyricsTextAlign.start);
      expect(lyricsTextAlignFromName('center'), LyricsTextAlign.center);
      expect(lyricsTextAlignFromName('auto'), LyricsTextAlign.auto);
      expect(lyricsTextAlignFromName('nonsense'), LyricsTextAlign.auto);
      expect(lyricsTextAlignFromName(null), LyricsTextAlign.auto);
    });

    test('auto keeps the existing layout of each lyric surface', () {
      expect(
        lyricsTextAlignFor(LyricsTextAlign.auto, expanded: true),
        TextAlign.left,
      );
      expect(
        lyricsTextAlignFor(LyricsTextAlign.auto, expanded: false),
        TextAlign.center,
      );
      expect(
        lyricsCrossAxisAlignmentFor(LyricsTextAlign.auto, expanded: true),
        CrossAxisAlignment.start,
      );
      expect(
        lyricsCrossAxisAlignmentFor(LyricsTextAlign.auto, expanded: false),
        CrossAxisAlignment.center,
      );
    });

    test('explicit alignment applies to both surfaces', () {
      for (final expanded in [true, false]) {
        expect(
          lyricsTextAlignFor(LyricsTextAlign.start, expanded: expanded),
          TextAlign.left,
        );
        expect(
          lyricsTextAlignFor(LyricsTextAlign.center, expanded: expanded),
          TextAlign.center,
        );
      }
    });
  });

  group('lyrics font weight persistence', () {
    test('reads Flutter font weight values', () {
      expect(lyricsFontWeightFromValue(300), FontWeight.w300);
      expect(lyricsFontWeightFromValue(900), FontWeight.w900);
    });

    test('falls back for missing or unknown values', () {
      expect(lyricsFontWeightFromValue(null), FontWeight.bold);
      expect(
        lyricsFontWeightFromValue(450, fallback: FontWeight.w400),
        FontWeight.w400,
      );
      expect(lyricsFontWeightFromValue('500'), FontWeight.bold);
    });
  });
}
