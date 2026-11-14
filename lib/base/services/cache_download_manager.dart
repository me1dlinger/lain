import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/logger.dart';

enum CacheTaskPhase { idle, running, completed, canceled }

@immutable
class CacheTaskProgress {
  final CacheTaskPhase phase;
  final int done;
  final int total;
  final int failed;

  const CacheTaskProgress({
    required this.phase,
    required this.done,
    required this.total,
    required this.failed,
  });

  static const idle = CacheTaskProgress(
    phase: CacheTaskPhase.idle,
    done: 0,
    total: 0,
    failed: 0,
  );

  bool get isRunning => phase == CacheTaskPhase.running;

  double? get fraction => total == 0 ? null : done / total;
}

/// What one cache task is doing. Mirrors [DownloadTaskState], minus the Wi-Fi
/// wait: caching is only ever started by the user, so nothing is queued behind
/// a connection setting.
enum CacheTaskState { waiting, downloading, paused, completed, failed }

/// One song the user asked to cache, kept in memory for the task list.
class CacheTask {
  final MyAudioMetadata song;
  CacheTaskState state;

  /// The request of a running task, so pause and delete can abort it.
  CancelToken? token;

  CacheTask(this.song, {this.state = CacheTaskState.waiting});
}

/// Downloads songs into the offline cache a few at a time.
///
/// The old batch path fetched one song after another, so a whole library on a
/// LAN link was limited by the server's per-request latency rather than the
/// link itself. Four workers hide that latency. There is no resume support:
/// an interrupted song is deleted, and a later retry starts it over.
///
/// Tasks are only kept in memory. A cache task is a snapshot of what this
/// session is fetching; what is on disk is already the source of truth, and a
/// half-finished download has no meaning across launches, so persisting the
/// list would only resurrect stale rows.
class CacheDownloadManager {
  static const _concurrency = 4;

  final ValueNotifier<CacheTaskProgress> notifier = ValueNotifier(
    CacheTaskProgress.idle,
  );

  /// The task list the cache page shows. A new unmodifiable copy is published
  /// on every state change so the page can listen to it.
  final ValueNotifier<List<CacheTask>> tasksNotifier = ValueNotifier(const []);

  final List<CacheTask> _tasks = [];

  Completer<void>? _done;
  bool _running = false;
  bool _cancelRequested = false;
  CacheTaskPhase _phase = CacheTaskPhase.idle;

  bool get isRunning => _running;

  List<CacheTask> get tasks => List<CacheTask>.unmodifiable(_tasks);

  /// Starts [songs]; the returned future completes when the whole batch has
  /// drained or the task is canceled. A start while the queue is running
  /// appends its songs behind the ones still waiting, so several playlists
  /// can be queued back to back instead of the second request being rejected.
  Future<void> start(Iterable<MyAudioMetadata> songs) {
    final fresh = <MyAudioMetadata>[];
    for (final song in songs) {
      if (song.cacheExist ||
          _tasks.any((task) => task.song.id == song.id) ||
          fresh.any((queued) => queued.id == song.id)) {
        continue;
      }
      fresh.add(song);
    }
    if (fresh.isEmpty) {
      return _running ? (_done?.future ?? Future.value()) : Future.value();
    }

    _tasks.addAll(fresh.map(CacheTask.new));
    // Songs appended to a running batch are picked up by whichever worker
    // frees up first. A finished batch starts a fresh run, so the future
    // returned here covers only the new songs.
    _publishTasks();
    _report(_running ? null : CacheTaskPhase.running);
    _ensureWorkers();
    return _done?.future ?? Future.value();
  }

  /// Starts the four workers when there is something waiting and they are not
  /// already running. Called after a start, a resume, and when a worker exits
  /// into a backlog that was appended while it was winding down.
  void _ensureWorkers() {
    if (_running ||
        !_tasks.any((task) => task.state == CacheTaskState.waiting)) {
      return;
    }

    _running = true;
    _cancelRequested = false;
    final completer = _done ??= Completer<void>();
    _report(CacheTaskPhase.running);

    Future<void> worker() async {
      while (true) {
        if (_cancelRequested) {
          return;
        }
        CacheTask? task;
        for (final candidate in _tasks) {
          if (candidate.state == CacheTaskState.waiting) {
            task = candidate;
            break;
          }
        }
        if (task == null) {
          return;
        }

        task.state = CacheTaskState.downloading;
        final token = CancelToken();
        task.token = token;
        _publishTasks();
        _report();

        try {
          final cached = await library.tryAddCache(
            task.song,
            cancelToken: token,
          );
          // A paused or deleted task was aborted above: its state was set on
          // purpose and must not be overwritten by this result.
          if (task.state == CacheTaskState.downloading) {
            task.state = cached || task.song.cacheExist
                ? CacheTaskState.completed
                : CacheTaskState.failed;
          }
        } catch (e) {
          if (task.state == CacheTaskState.downloading) {
            task.state = CacheTaskState.failed;
            if (!_cancelRequested) {
              logger.output('[cache] download failed for ${task.song.id}: $e');
            }
          }
        } finally {
          task.token = null;
          _publishTasks();
          _report();
        }
      }
    }

    Future.wait([
      for (var i = 0; i < _concurrency; i++) worker(),
    ]).whenComplete(() => _onWorkersStopped(completer));
  }

  Future<void> _onWorkersStopped(Completer<void> completer) async {
    _running = false;

    // A start can land while the last workers are on their way out. Those
    // songs were never picked up, so give them a new set of workers under the
    // same batch instead of leaving them waiting forever.
    if (!_cancelRequested &&
        _tasks.any((task) => task.state == CacheTaskState.waiting)) {
      _ensureWorkers();
      return;
    }

    final canceled = _cancelRequested;
    _cancelRequested = false;
    if (canceled) {
      // A start can land while cancel is winding down; those songs were never
      // scheduled and must not stay waiting behind a canceled batch.
      for (final task in _tasks) {
        if (task.state == CacheTaskState.waiting) {
          task.state = CacheTaskState.paused;
        }
      }
      _publishTasks();
    }
    _report(canceled ? CacheTaskPhase.canceled : CacheTaskPhase.completed);

    try {
      await library.refreshCache();
      if (!canceled) {
        library.changeNotifier.value++;
      }
    } catch (e) {
      logger.output('[cache] refreshing the cache listing failed: $e');
    }

    if (!completer.isCompleted) {
      completer.complete();
    }
    if (identical(_done, completer)) {
      _done = null;
    }
  }

  void _report([CacheTaskPhase? phase]) {
    if (phase != null) {
      _phase = phase;
    }
    var done = 0;
    var failed = 0;
    for (final task in _tasks) {
      if (task.state == CacheTaskState.completed) {
        done++;
      } else if (task.state == CacheTaskState.failed) {
        failed++;
      }
    }
    notifier.value = CacheTaskProgress(
      phase: _phase,
      done: done,
      total: _tasks.length,
      failed: failed,
    );
  }

  void _publishTasks() {
    tasksNotifier.value = List<CacheTask>.unmodifiable(_tasks);
  }

  /// Stops [task]. A running request is aborted and its partial file removed
  /// by [library.tryAddCache], so continuing it starts from the beginning.
  void pauseTask(CacheTask task) {
    if (task.state == CacheTaskState.paused) {
      return;
    }
    task.token?.cancel('cache task paused');
    task.token = null;
    task.state = CacheTaskState.paused;
    _publishTasks();
    _report();
  }

  /// Queues [task] again so a worker picks it up.
  void resumeTask(CacheTask task) {
    if (task.state == CacheTaskState.downloading) {
      return;
    }
    task.state = task.song.cacheExist
        ? CacheTaskState.completed
        : CacheTaskState.waiting;
    _publishTasks();
    _ensureWorkers();
    _report();
  }

  /// Aborts and forgets [task].
  void deleteTask(CacheTask task) {
    task.token?.cancel('cache task deleted');
    task.token = null;
    _tasks.remove(task);
    _publishTasks();
    _report();
  }

  /// Pauses everything that is waiting or running; finished rows stay as they
  /// are.
  void pauseAll() {
    for (final task in _tasks) {
      if (task.state == CacheTaskState.waiting ||
          task.state == CacheTaskState.downloading) {
        task.token?.cancel('cache task paused');
        task.token = null;
        task.state = CacheTaskState.paused;
      }
    }
    _publishTasks();
    _report();
  }

  /// Queues every paused or failed task again.
  void resumeAll() {
    for (final task in _tasks) {
      if (task.state == CacheTaskState.paused ||
          task.state == CacheTaskState.failed) {
        task.state = task.song.cacheExist
            ? CacheTaskState.completed
            : CacheTaskState.waiting;
      }
    }
    _publishTasks();
    _ensureWorkers();
    _report();
  }

  /// Aborts and clears the whole list.
  void deleteAllTasks() {
    for (final task in _tasks) {
      task.token?.cancel('cache tasks deleted');
      task.token = null;
    }
    _tasks.clear();
    _publishTasks();
    _report();
  }

  /// Stops the whole batch: waiting and running tasks are paused, the requests
  /// in flight are aborted, and the future returned by [start] completes.
  void cancel() {
    if (!_running || _cancelRequested) {
      return;
    }
    _cancelRequested = true;
    for (final task in _tasks) {
      if (task.state == CacheTaskState.waiting ||
          task.state == CacheTaskState.downloading) {
        task.token?.cancel('cache download canceled');
        task.token = null;
        task.state = CacheTaskState.paused;
      }
    }
    _publishTasks();
  }
}

final cacheDownloadManager = CacheDownloadManager();
