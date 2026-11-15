import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/lrc_document.dart';

void main() {
  group('parsing', () {
    test('keeps the header and reads timed lines', () {
      final document = LrcDocument.parse(
        '[ti:Title]\n'
        '[ar:Artist]\n'
        '[00:01.00]first\n'
        '[00:02.50]second\n',
      );

      expect(document.headerLines, ['[ti:Title]', '[ar:Artist]']);
      expect(document.groups.length, 2);
      expect(document.groups.first.start, const Duration(seconds: 1));
      expect(document.groups.first.primary, 'first');
      expect(document.groups.last.start, const Duration(milliseconds: 2500));
    });

    test('merges two lines sharing a timestamp into one group', () {
      final document = LrcDocument.parse(
        '[00:10.00]original\n[00:10.00]translation\n[00:11.00]next',
      );

      expect(document.groups.length, 2);
      expect(document.groups.first.primary, 'original');
      expect(document.groups.first.secondary, 'translation');
      expect(document.groups.last.secondary, isNull);
    });

    test('reads a one/two/three digit fraction as milliseconds', () {
      final document = LrcDocument.parse(
        '[00:01.5]a\n'
        '[00:02.05]b\n'
        '[00:03.050]c',
      );

      expect(document.groups[0].start, const Duration(milliseconds: 1500));
      expect(document.groups[1].start, const Duration(milliseconds: 2050));
      expect(document.groups[2].start, const Duration(milliseconds: 3050));
    });

    test('keeps untimed text editable when nothing is timed', () {
      final document = LrcDocument.parse('hello\nworld');
      expect(document.headerLines, isEmpty);
      expect(document.groups.length, 2);
      expect(document.groups.first.start, isNull);
      expect(document.groups.first.primary, 'hello');
    });

    test('keeps untimed text as header when the document is timed', () {
      final document = LrcDocument.parse(
        'preamble\n[00:01.00]first',
      );
      expect(document.headerLines, ['preamble']);
      expect(document.groups.length, 1);
    });

    test('detects per-word timestamps', () {
      final document = LrcDocument.parse(
        '[00:01.00]<00:01.00>He<00:01.50>llo',
      );
      expect(document.hasWordTimestamps, isTrue);
      expect(
        LrcDocument.parse('[00:01.00]plain').hasWordTimestamps,
        isFalse,
      );
    });
  });

  group('serialization', () {
    test('round-trips header, groups and shared timestamps', () {
      const source =
          '[ti:Title]\n[ar:Artist]\n[00:01.00]first\n[00:02.50]a\n[00:03.00]b';
      final serialized = LrcDocument.parse(source).serialize();
      final reparsed = LrcDocument.parse(serialized);
      expect(reparsed.headerLines, ['[ti:Title]', '[ar:Artist]']);
      expect(reparsed.groups.length, 3);
      expect(reparsed.groups[1].primary, 'a');
      expect(reparsed.groups[1].start, const Duration(milliseconds: 2500));
    });

    test('writes the same timestamp for a secondary line', () {
      final document = LrcDocument.parse(
        '[00:10.95]original\n[00:10.95]translation',
      );
      final serialized = document.serialize();
      expect(serialized, '[00:10.95]original\n[00:10.95]translation');
    });

    test('keeps an untimed line without a timestamp', () {
      final document = LrcDocument.parse('hello\nworld');
      expect(document.serialize(), 'hello\nworld');
    });
  });

  group('timestamp input', () {
    test('accepts mm:ss and its fractions', () {
      expect(parseLrcTimestampInput('00:00'), Duration.zero);
      expect(
        parseLrcTimestampInput('01:02'),
        const Duration(minutes: 1, seconds: 2),
      );
      expect(
        parseLrcTimestampInput('01:02.3'),
        const Duration(minutes: 1, seconds: 2, milliseconds: 300),
      );
    });

    test('rejects malformed input', () {
      expect(parseLrcTimestampInput('1:02.3'), isNull);
      expect(parseLrcTimestampInput('01:2.3'), isNull);
      expect(parseLrcTimestampInput('01:99.00'), isNull);
      expect(parseLrcTimestampInput('abc'), isNull);
      expect(parseLrcTimestampInput(''), isNull);
    });
  });

  group('editing helpers', () {
    test('baking a positive offset moves lines back and clamps at zero', () {
      final document = LrcDocument.parse(
        '[00:10.00]ten\n[00:00.20]early',
      );
      document.bakeOffset(500);
      expect(document.groups[0].start, const Duration(milliseconds: 9500));
      expect(document.groups[1].start, Duration.zero);
    });

    test('stripping word timestamps leaves the line text', () {
      final document = LrcDocument.parse(
        '[00:01.00]<00:01.00>He<00:01.50>llo',
      );
      document.stripWordTimestamps();
      expect(document.groups.first.primary, 'Hello');
    });
  });
}
