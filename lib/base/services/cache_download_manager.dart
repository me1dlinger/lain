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

/// Downloads songs into the offline cache a few at a time.
///
/// The old batch path fetched one song after another, so a whole library on a
/// LAN link was limited by the server's per-request latency rather than the
/// link itself. Four workers hide that latency. There is no resume support:
/// an interrupted song is deleted, and the next run starts it over.
class CacheDownloadManager {
  static const _concurrency = 4;

  final ValueNotifier<CacheTaskProgress> notifier = ValueNotifier(
    CacheTaskProgress.idle,
  );

  final List<MyAudioMetadata> _pending = [];
  final List<CancelToken> _cancellations = [];
  Completer<void>? _done;
  bool _running = false;
  bool _cancelRequested = false;
  int _doneCount = 0;
  int _failedCount = 0;
  int _totalCount = 0;

  bool get isRunning => _running;

  /// Starts [songs]; the returned future completes when the whole queue has
  /// drained or the task is canceled. A start while the queue is running
  /// appends its songs behind the ones still waiting, so several playlists
  /// can be queued back to back instead of the second request being
  /// rejected.
  Future<void> start(Iterable<MyAudioMetadata> songs) {
    final fresh = <MyAudioMetadata>[];
    for (final song in songs) {
      if (!song.cacheExist &&
          !_pending.any((queued) => queued.id == song.id) &&
          !fresh.any((queued) => queued.id == song.id)) {
        fresh.add(song);
      }
    }
    if (fresh.isEmpty) {
      return _running ? (_done?.future ?? Future.value()) : Future.value();
    }

    _pending.addAll(fresh);

    if (_running) {
      _totalCount += fresh.length;
      _report();
      return _done!.future;
    }

    _running = true;
    _cancelRequested = false;
    _doneCount = 0;
    _failedCount = 0;
    _totalCount = fresh.length;
    _cancellations.clear();
    final completer = Completer<void>();
    _done = completer;
    _report();

    // Four workers each pull the next song off the queue, so appended songs
    // are picked up by whichever worker frees up first.
    Future<void> worker() async {
      while (true) {
        if (_cancelRequested) {
          return;
        }
        if (_pending.isEmpty) {
          return;
        }
        final song = _pending.removeAt(0);
        final token = CancelToken();
        _cancellations.add(token);
        try {
          final cached = await library.tryAddCache(song, cancelToken: token);
          if (!cached && !_cancelRequested) {
            _failedCount++;
          }
        } catch (e) {
          if (!_cancelRequested) {
            _failedCount++;
            logger.output('[cache] download failed for ${song.id}: $e');
          }
        } finally {
          _cancellations.remove(token);
          if (!_cancelRequested) {
            _doneCount++;
            _report();
          }
        }
      }
    }

    Future.wait([
      for (var i = 0; i < _concurrency; i++) worker(),
    ]).whenComplete(() async {
      _running = false;
      final canceled = _cancelRequested;
      _pending.clear();
      _cancellations.clear();
      notifier.value = CacheTaskProgress(
        phase: canceled ? CacheTaskPhase.canceled : CacheTaskPhase.completed,
        done: _doneCount,
        total: _totalCount,
        failed: _failedCount,
      );
      _done = null;
      try {
        await library.refreshCache();
        if (!canceled) {
          library.changeNotifier.value++;
        }
      } catch (e) {
        logger.output('[cache] refreshing the cache listing failed: $e');
      }
      completer.complete();
    });

    return completer.future;
  }

  void _report() {
    notifier.value = CacheTaskProgress(
      phase: CacheTaskPhase.running,
      done: _doneCount,
      total: _totalCount,
      failed: _failedCount,
    );
  }

  /// Stops scheduling new songs and aborts the requests already in flight.
  /// Their partial files are removed by [library.tryAddCache].
  void cancel() {
    if (!_running || _cancelRequested) {
      return;
    }
    _cancelRequested = true;
    for (final token in List<CancelToken>.of(_cancellations)) {
      token.cancel('cache download canceled');
    }
  }
}

final cacheDownloadManager = CacheDownloadManager();
