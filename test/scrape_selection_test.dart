import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/scrape_selection.dart';

void main() {
  test('best candidate is the highest score, first one on a tie', () {
    expect(bestCandidateIndex([1, 9, 3]), 1);
    expect(bestCandidateIndex([4, 4, 1]), 0);
    expect(bestCandidateIndex([]), -1);
  });

  test('moving to the next song skips ones without results and wraps', () {
    final has = [true, false, true, false];
    expect(nextIndexWithValue(has, 0, 1), 2);
    expect(nextIndexWithValue(has, 2, 1), 0);
    expect(nextIndexWithValue(has, 3, 1), 0);
  });

  test('moving back skips too', () {
    final has = [true, false, true, false];
    expect(nextIndexWithValue(has, 2, -1), 0);
  });

  test('nothing with a result keeps the current index', () {
    expect(nextIndexWithValue([false, false], 1, 1), 1);
    expect(nextIndexWithValue([], 0, 1), -1);
  });
}
