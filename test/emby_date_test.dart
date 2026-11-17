import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/my_audio_metadata.dart';

void main() {
  group('Emby timestamps', () {
    test('seven fractional digits are parsed (Dart alone refuses them)', () {
      final date = MyAudioMetadata.parseEmbyDate(
        '2026-11-16T15:24:39.9437622Z',
      );
      expect(date, DateTime.utc(2026, 11, 16, 15, 24, 39, 943, 762));
      expect(date!.isUtc, isTrue);
    });

    test('fewer fractional digits are parsed as they arrive', () {
      expect(
        MyAudioMetadata.parseEmbyDate('2026-11-16T15:24:39.943Z'),
        DateTime.utc(2026, 11, 16, 15, 24, 39, 943),
      );
      expect(
        MyAudioMetadata.parseEmbyDate('2026-11-16T15:24:39Z'),
        DateTime.utc(2026, 11, 16, 15, 24, 39),
      );
    });

    test('an offset is honoured', () {
      expect(
        MyAudioMetadata.parseEmbyDate('2026-11-16T23:24:39.0000000+08:00'),
        DateTime.utc(2026, 11, 16, 15, 24, 39),
      );
    });

    test('the placeholder date and empty values mean "never"', () {
      expect(MyAudioMetadata.parseEmbyDate('0001-01-01T00:00:00.0000000Z'), null);
      expect(MyAudioMetadata.parseEmbyDate(''), null);
      expect(MyAudioMetadata.parseEmbyDate(null), null);
      expect(MyAudioMetadata.parseEmbyDate('not a date'), null);
    });
  });
}
