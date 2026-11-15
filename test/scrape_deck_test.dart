import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/scrape_deck.dart';

void main() {
  test('turning forward wraps at the end', () {
    expect(rotateCardIndex(0, 1, 3), 1);
    expect(rotateCardIndex(2, 1, 3), 0);
  });

  test('turning back wraps to the last card', () {
    expect(rotateCardIndex(0, -1, 3), 2);
    expect(rotateCardIndex(1, -1, 3), 0);
  });

  test('an empty deck is index zero', () {
    expect(rotateCardIndex(4, 1, 0), 0);
    expect(rotateCardIndex(0, -1, 0), 0);
  });

  test('large jumps still land inside the deck', () {
    expect(rotateCardIndex(0, 4, 5), 4);
    expect(rotateCardIndex(1, -4, 5), 2);
  });
}
