import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/services/romaji.dart';

void main() {
  group('hasJapaneseKana', () {
    test('accepts hiragana and katakana', () {
      expect(hasJapaneseKana('こんにちは'), isTrue);
      expect(hasJapaneseKana('カタカナ'), isTrue);
    });

    test('rejects kanji-only, latin and Chinese text', () {
      expect(hasJapaneseKana('君名前'), isFalse);
      expect(hasJapaneseKana('Hello world'), isFalse);
      expect(hasJapaneseKana('你好世界'), isFalse);
    });
  });

  group('normalizeRomajiSpacing', () {
    test('collapses runs of spaces and trims', () {
      expect(normalizeRomajiSpacing('  Hello   world  '), 'Hello world');
      expect(normalizeRomajiSpacing('a\tb\nc'), 'a b c');
    });
  });

  group('RomajiService', () {
    test('romanises Japanese lines and leaves other lines empty', () async {
      final service = RomajiService();
      addTearDown(service.dispose);

      final result = await service.convertLines([
        'こんにちは',
        '君名前',
        'Hello world',
        '',
      ]);

      expect(result, hasLength(4));
      expect(result[0], 'konnichiwa');
      expect(result[1], isNotNull);
      expect(result[2], isNull);
      expect(result[3], isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('uses kanji readings', () async {
      final service = RomajiService();
      addTearDown(service.dispose);

      final result = await service.convertLines(['君の名前']);

      expect(result.single, isNotNull);
      expect(result.single, contains('namae'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('short-circuits when there is nothing Japanese', () async {
      final service = RomajiService();
      addTearDown(service.dispose);

      final result = await service.convertLines(['Hello', 'world']);
      expect(result, [null, null]);
    });

    test('reuses cached results for the same lines', () async {
      final service = RomajiService();
      addTearDown(service.dispose);

      final first = await service.convertLines(['こんにちは']);
      final second = await service.convertLines(['こんにちは']);
      expect(second, first);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
