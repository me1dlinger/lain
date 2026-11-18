import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/services/ab_loop.dart';

void main() {
  test('an A-B loop needs both points in order', () {
    final loop = AbLoopController();
    loop.setStart(const Duration(seconds: 10));
    loop.setEnd(const Duration(seconds: 30));
    loop.setEnabled(true);
    expect(loop.active, isTrue);
    loop.setEnd(const Duration(seconds: 8));
    expect(loop.active, isFalse);
    expect(loop.a, isNull);
    expect(loop.b, const Duration(seconds: 8));
  });

  test('clearing removes both points', () {
    final loop = AbLoopController();
    loop.setStart(const Duration(seconds: 1));
    loop.setEnd(const Duration(seconds: 3));
    loop.clear();
    expect(loop.a, isNull);
    expect(loop.b, isNull);
    expect(loop.active, isFalse);
  });
}
