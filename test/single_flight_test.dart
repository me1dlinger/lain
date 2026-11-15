import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/single_flight.dart';

void main() {
  test('concurrent calls share one run and ask for a single rerun', () async {
    final flight = SingleFlight();
    final gates = [Completer<void>(), Completer<void>()];
    var runs = 0;

    Future<void> work() async {
      final index = runs++;
      await gates[index].future;
    }

    final first = flight.run(work);
    final concurrentA = flight.run(work);
    final concurrentB = flight.run(work);

    expect(identical(first, concurrentA), isTrue);
    expect(identical(first, concurrentB), isTrue);
    expect(flight.isRunning, isTrue);
    expect(runs, 1);

    gates[0].complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    // The two concurrent calls asked for one rerun, not two.
    expect(runs, 2);

    gates[1].complete();
    await first;
    expect(runs, 2);
    expect(flight.isRunning, isFalse);
  });

  test('a new call after completion starts a fresh run', () async {
    final flight = SingleFlight();
    var runs = 0;
    await flight.run(() async => runs++);
    await flight.run(() async => runs++);
    expect(runs, 2);
  });

  test('the running future rethrows to every caller and clears the flight', () async {
    final flight = SingleFlight();
    final gate = Completer<void>();

    Future<void> work() async {
      await gate.future;
      throw StateError('offline');
    }

    final first = flight.run(work);
    final second = flight.run(work);

    gate.complete();
    await expectLater(first, throwsStateError);
    await expectLater(second, throwsStateError);
    expect(flight.isRunning, isFalse);
  });
}
