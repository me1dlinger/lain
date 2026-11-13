import 'dart:async';

import 'package:lain/base/services/picture_service.dart';

PictureLoadScheduler pictureLoadScheduler = PictureLoadScheduler();

/// Runs cover loads a few at a time, and makes every widget asking for the same
/// cover await one load instead of starting another.
///
/// The state is a single map of id -> future: an id has at most one load in
/// flight or finished, and every caller - a list thumbnail, a page header, the
/// media session's artwork - shares that one result. A finished load that
/// produced no image is forgotten after [retryAfter] so a re-entered page can
/// try again without hammering the network on every rebuild.
///
/// Nothing here can leave a caller waiting forever: the completer is completed
/// in a `finally`, and a load that is already running is never re-queued.
class PictureLoadScheduler {
  final int maxConcurrent;

  PictureLoadScheduler({this.maxConcurrent = 6});

  int _running = 0;
  final _queue = <_Task>[];

  /// The load (running or finished) for each picture id. A successful load
  /// stays here for the process: the image is on disk, so no caller ever has
  /// to fetch it again.
  final Map<String, Future<void>> _futures = {};

  /// Ids whose last load produced no image, and when. A rebuild within
  /// [retryAfter] waits instead of starting another doomed download.
  final Map<String, DateTime> _failedAt = {};

  static const retryAfter = Duration(seconds: 2);

  /// Loads the picture [id] through [loader], which reports whether it ended up
  /// with an image. A call for an id that is already loading (or already
  /// loaded) returns that same future; [widgetId] only identifies the caller
  /// and [priority] puts the load before the thumbnails of a scrolling list.
  ///
  /// The signature keeps [widgetId] so existing call sites stay as they are:
  /// a load is shared, so a widget that goes away must not cancel the load a
  /// still-visible widget is waiting for.
  Future<void> load(
    String id,
    Future<bool> Function() loader,
    int? widgetId, {
    bool priority = false,
  }) {
    final existing = _futures[id];
    if (existing != null) {
      return existing;
    }

    final failedAt = _failedAt[id];
    if (failedAt != null && DateTime.now().difference(failedAt) < retryAfter) {
      return Future.value();
    }

    final completer = Completer<void>();
    final future = completer.future;
    _futures[id] = future;

    final task = _Task(() => _run(id, loader, completer));

    // The now-playing artwork must not queue behind the thumbnails of a list
    // the user is scrolling: it goes to the front.
    if (priority) {
      _queue.insert(0, task);
    } else {
      _queue.add(task);
    }

    _schedule();

    return future;
  }

  Future<void> _run(
    String id,
    Future<bool> Function() loader,
    Completer<void> completer,
  ) async {
    var producedImage = false;
    try {
      producedImage = await loader();
    } catch (_) {
      producedImage = false;
    } finally {
      if (producedImage) {
        _failedAt.remove(id);
      } else {
        // Not remembering a failure forever is what lets a cover that was
        // unreachable (a server that had not answered yet) load on the next
        // visit; the short window keeps a rebuild from retrying immediately.
        _failedAt[id] = DateTime.now();
        _futures.remove(id);
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
      _running--;
      _schedule();
    }
  }

  void _schedule() {
    while (_running < maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _running++;
      task.run();
    }
  }

  /// Kept for call sites that stop watching a picture. The load itself is
  /// shared, so it is not cancelled: another widget (or the media session) may
  /// still be waiting for that same id.
  void cancel(int widgetId) {}

  /// Forgets everything about [picture] so its next load starts from scratch -
  /// used when its bytes have changed (a resynced artist image).
  void resetPicture(MyPicture picture) {
    _futures.remove(picture.id);
    _failedAt.remove(picture.id);
  }

  void clear() {
    _queue.clear();
    _futures.clear();
    _failedAt.clear();
    _running = 0;
  }
}

class _Task {
  final void Function() run;

  _Task(this.run);
}
