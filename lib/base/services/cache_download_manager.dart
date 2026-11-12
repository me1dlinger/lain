import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pool/pool.dart';

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

  final List<CancelToken> _cancellations = [];
  Completer<void>? _done;
  bool _running = false;
  bool _cancelRequested = false;

  bool get isRunning => _running;

  /// Starts [songs]; the returned future completes when every worker is done or
  /// the task is canceled. A start while one is already running joins it
  /// instead of interleaving two batches.
  Future<void> start(Iterable<MyAudioMetadata> songs) {
    if (_running) {
      return _done?.future ?? Future.value();
    }

    final pending = <MyAudioMetadata>[];
    final seen = <String>{};
    for (final song in songs) {
      if (!song.cacheExist && seen.add(song.id)) {
        pending.add(song);
      }
    }
    if (pending.isEmpty) {
      notifier.value = const CacheTaskProgress(
        phase: CacheTaskPhase.completed,
        done: 0,
        total: 0,
        failed: 0,
      );
      return Future.value();
    }

    _running = true;
    _cancelRequested = false;
    _cancellations.clear();
    final completer = Completer<void>();
    _done = completer;
    notifier.value = CacheTaskProgress(
      phase: CacheTaskPhase.running,
      done: 0,
      total: pending.length,
      failed: 0,
    );

    var done = 0;
    var failed = 0;
    final pool = Pool(_concurrency);

    Future<void> runOne(MyAudioMetadata song) async {
      if (_cancelRequested) {
        return;
      }
      final token = CancelToken();
      _cancellations.add(token);
      try {
        final cached = await library.tryAddCache(song, cancelToken: token);
        if (!cached && !_cancelRequested) {
          failed++;
        }
      } catch (e) {
        if (!_cancelRequested) {
          failed++;
          logger.output('[cache] download failed for ${song.id}: $e');
        }
      } finally {
        _cancellations.remove(token);
        if (!_cancelRequested) {
          done++;
          notifier.value = CacheTaskProgress(
            phase: CacheTaskPhase.running,
            done: done,
            total: pending.length,
            failed: failed,
          );
        }
      }
    }

    final futures = [
      for (final song in pending) pool.withResource(() => runOne(song)),
    ];

    Future.wait(futures).whenComplete(() async {
      await pool.close();
      _running = false;
      final canceled = _cancelRequested;
      _cancellations.clear();
      notifier.value = CacheTaskProgress(
        phase: canceled ? CacheTaskPhase.canceled : CacheTaskPhase.completed,
        done: done,
        total: pending.length,
        failed: failed,
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
