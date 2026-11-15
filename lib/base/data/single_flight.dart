import 'dart:async';

/// Runs one asynchronous job at a time, coalescing concurrent calls.
///
/// A call while a job is running asks for one more run and returns the running
/// job's future: the caller still waits until the extra run is done, and no two
/// runs are ever in flight. This is what keeps a playlist from appending the
/// same server answer twice when a cold start and a page refresh ask for it at
/// the same moment.
class SingleFlight {
  Future<void>? _inFlight;
  bool _queued = false;

  bool get isRunning => _inFlight != null;

  /// The future of the run currently in flight, if any.
  Future<void>? get inFlight => _inFlight;

  Future<void> run(Future<void> Function() work) {
    final running = _inFlight;
    if (running != null) {
      _queued = true;
      return running;
    }
    final future = _drain(work);
    _inFlight = future;
    return future;
  }

  Future<void> _drain(Future<void> Function() work) async {
    try {
      do {
        _queued = false;
        await work();
      } while (_queued);
    } finally {
      _inFlight = null;
    }
  }
}
