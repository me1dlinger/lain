import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/utils/metadata_utils.dart';

void main() {
  group('getArtists', () {
    test('splits on the separators the servers join artists with', () {
      expect(getArtists('A/B/C'), ['A', 'B', 'C']);
      expect(getArtists('A, B'), ['A', 'B']);
    });

    test('splits on the ideographic and full-width commas', () {
      expect(getArtists('A、B'), ['A', 'B']);
      expect(getArtists('A、B、C'), ['A', 'B', 'C']);
      expect(getArtists('甲、乙'), ['甲', '乙']);
      expect(getArtists('A，B'), ['A', 'B']);
      expect(getArtists('A／B'), ['A', 'B']);
    });

    test('keeps a single name, and an ampersand inside one', () {
      expect(getArtists('A'), ['A']);
      expect(getArtists('MYTH & ROID'), ['MYTH & ROID']);
    });

    test('keeps the tag whole when a part is empty', () {
      expect(getArtists('A,'), ['A,']);
      expect(getArtists('A,,B'), ['A,,B']);
      expect(getArtists('A、'), ['A、']);
    });

    test('trims each part', () {
      expect(getArtists(' A , B '), ['A', 'B']);
    });
  });
}
