import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/car_display.dart';

void main() {
  test('default two lines put the lyric above artist - title', () {
    final lines = composeCarDisplayLines(
      defaultCarDisplayConfig(),
      title: 'Title',
      artist: 'Artist',
      album: 'Album',
      lyric: 'line one',
      translation: '第一行',
    );

    expect(lines, ['line one', 'Artist - Title']);
  });

  test('a track without a lyric falls back to the title on the first line', () {
    final lines = composeCarDisplayLines(
      defaultCarDisplayConfig(),
      title: 'Title',
      artist: 'Artist',
      album: 'Album',
    );

    expect(lines[0], 'Title');
    expect(lines[1], 'Artist - Title');
  });

  test('a translation-only line uses the original when no translation exists', () {
    final config = CarDisplayConfig(
      lineCount: 2,
      lines: [
        CarDisplayLine(tokens: [CarDisplayToken.lyricTranslation]),
        CarDisplayLine(tokens: [CarDisplayToken.title]),
      ],
    );
    final lines = composeCarDisplayLines(
      config,
      title: 'Title',
      artist: 'Artist',
      album: 'Album',
      lyric: 'line one',
    );

    expect(lines[0], 'line one');
  });

  test('an empty separator joins fields with one space', () {
    final config = CarDisplayConfig(
      lineCount: 2,
      lines: [
        CarDisplayLine(
          tokens: [
            CarDisplayToken.title,
            CarDisplayToken.artist,
            CarDisplayToken.album,
          ],
        ),
        CarDisplayLine(tokens: [CarDisplayToken.lyricOriginal]),
      ],
    );
    final lines = composeCarDisplayLines(
      config,
      title: 'Title',
      artist: 'Artist',
      album: 'Album',
      lyric: 'line one',
    );

    expect(lines[0], 'Title Artist Album');
    expect(lines[1], 'line one');
  });

  test('bilingual lyrics choose English original and Chinese translation', () {
    final pair = carLyricPair(
      text: 'English line',
      translations: ['中文翻译'],
      englishLocale: false,
    );
    expect(pair.original, 'English line');
    expect(pair.translation, '中文翻译');

    final swapped = carLyricPair(
      text: 'English line',
      translations: ['中文翻译'],
      englishLocale: true,
    );
    expect(swapped.original, '中文翻译');
    expect(swapped.translation, 'English line');
  });

  test('a custom separator gets spaces on both sides', () {
    final config = CarDisplayConfig(
      lineCount: 3,
      lines: [
        CarDisplayLine(tokens: [CarDisplayToken.lyricOriginal]),
        CarDisplayLine(
          tokens: [CarDisplayToken.title, CarDisplayToken.album],
          separator: '/',
        ),
        CarDisplayLine(
          tokens: [CarDisplayToken.artist, CarDisplayToken.lyricTranslation],
          separator: '·',
        ),
      ],
    );
    final lines = composeCarDisplayLines(
      config,
      title: 'Title',
      artist: 'Artist',
      album: 'Album',
      lyric: 'line one',
      translation: '翻译',
    );

    expect(lines, ['line one', 'Title / Album', 'Artist · 翻译']);
  });
}
