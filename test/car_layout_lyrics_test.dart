import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/car_display.dart';

void main() {
  CarDisplayConfig customWithLyric() => CarDisplayConfig(
    lineCount: 2,
    lines: [
      CarDisplayLine(tokens: [CarDisplayToken.title]),
      CarDisplayLine(tokens: [CarDisplayToken.lyricOriginal]),
      CarDisplayLine(tokens: [CarDisplayToken.album]),
    ],
  );

  CarDisplayConfig customWithoutLyric() => CarDisplayConfig(
    lineCount: 2,
    lines: [
      CarDisplayLine(tokens: [CarDisplayToken.title]),
      CarDisplayLine(tokens: [CarDisplayToken.artist]),
      CarDisplayLine(tokens: [CarDisplayToken.album]),
    ],
  );

  group('layout lyrics detection', () {
    test('the default layout contains a lyric field', () {
      expect(carLayoutUsesLyrics(defaultCarDisplayConfig()), isTrue);
    });

    test('a custom layout with a lyric field is detected', () {
      expect(carLayoutUsesLyrics(customWithLyric()), isTrue);
    });

    test('a custom layout without a lyric field is not', () {
      expect(carLayoutUsesLyrics(customWithoutLyric()), isFalse);
    });

    test('a lyric field beyond the configured line count does not count', () {
      final config = CarDisplayConfig(
        lineCount: 2,
        lines: [
          CarDisplayLine(tokens: [CarDisplayToken.title]),
          CarDisplayLine(tokens: [CarDisplayToken.artist]),
          CarDisplayLine(tokens: [CarDisplayToken.lyricOriginal]),
        ],
      );
      expect(carLayoutUsesLyrics(config), isFalse);
    });
  });

  group('effective lyric switch', () {
    test('the default layout still follows the legacy switch', () {
      final config = defaultCarDisplayConfig();
      expect(carLyricsEnabled(config: config, legacySwitch: false), isFalse);
      expect(carLyricsEnabled(config: config, legacySwitch: true), isTrue);
    });

    test('the classic Bluetooth route honours any layout with a lyric field', () {
      final config = defaultCarDisplayConfig();
      expect(
        carLyricsEnabled(
          config: config,
          legacySwitch: false,
          classicRoute: true,
        ),
        isTrue,
      );
    });

    test('a custom layout with lyrics is self-sufficient', () {
      expect(
        carLyricsEnabled(config: customWithLyric(), legacySwitch: false),
        isTrue,
      );
    });

    test('a custom layout without a lyric field never asks for lyrics', () {
      expect(
        carLyricsEnabled(config: customWithoutLyric(), legacySwitch: false),
        isFalse,
      );
      expect(
        carLyricsEnabled(config: customWithoutLyric(), legacySwitch: true),
        isFalse,
      );
      expect(
        carLyricsEnabled(
          config: customWithoutLyric(),
          legacySwitch: true,
          classicRoute: true,
        ),
        isFalse,
      );
    });
  });

  group('default layout detection', () {
    test('the untouched config is the default', () {
      expect(defaultCarDisplayConfig().isDefault, isTrue);
    });

    test('changing a line makes it a custom layout', () {
      final config = defaultCarDisplayConfig()
        ..lines[0] = CarDisplayLine(tokens: [CarDisplayToken.title]);
      expect(config.isDefault, isFalse);
    });

    test('changing the line count makes it a custom layout', () {
      expect((defaultCarDisplayConfig()..lineCount = 3).isDefault, isFalse);
    });
  });

  test('a custom layout is composed exactly as configured', () {
    final lines = composeCarDisplayLines(
      customWithLyric(),
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      lyric: 'a lyric line',
      lyricsEnabled: true,
    );

    expect(lines, ['Song', 'a lyric line']);
  });

  group('classic broadcast mapping', () {
    test('default layout on the classic route uses three lines', () {
      final lines = composeCarLinesForRoute(
        config: defaultCarDisplayConfig(),
        classic: true,
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        lyric: 'a lyric line',
        lyricsEnabled: true,
        lyricOnPrimaryLine: true,
      );

      expect(lines, ['a lyric line', 'Artist - Song', 'Album']);
    });

    test('with the lyric off the primary line it moves to the secondary one', () {
      final lines = composeCarLinesForRoute(
        config: defaultCarDisplayConfig(),
        classic: true,
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        lyric: 'a lyric line',
        lyricsEnabled: true,
        lyricOnPrimaryLine: false,
      );

      expect(lines, ['Song', 'a lyric line', 'Album']);
    });

    test('without a lyric and with it off the secondary line is the artist', () {
      final lines = composeCarLinesForRoute(
        config: defaultCarDisplayConfig(),
        classic: true,
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        lyricsEnabled: true,
        lyricOnPrimaryLine: false,
      );

      expect(lines, ['Song', 'Artist', 'Album']);
    });

    test('a custom layout is never replaced by the classic mapping', () {
      final lines = composeCarLinesForRoute(
        config: customWithLyric(),
        classic: true,
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        lyric: 'a lyric line',
        lyricsEnabled: true,
        lyricOnPrimaryLine: false,
      );

      expect(lines, ['Song', 'a lyric line']);
    });

    test('the smart-link default layout keeps two lines', () {
      final lines = composeCarLinesForRoute(
        config: defaultCarDisplayConfig(),
        classic: false,
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        lyric: 'a lyric line',
        lyricsEnabled: true,
        lyricOnPrimaryLine: true,
      );

      expect(lines, ['a lyric line', 'Artist - Song']);
    });
  });
}
