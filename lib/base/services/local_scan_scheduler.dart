import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/folder_scan_settings.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/loader.dart';

/// Checks the local folders on a timer and when the app returns to the
/// foreground. A tick only runs when the local source is active, auto scan is
/// on, the interval has passed and the app is not loading anything.
class LocalScanScheduler with WidgetsBindingObserver {
  LocalScanScheduler._();

  static final LocalScanScheduler instance = LocalScanScheduler._();

  Timer? _heartbeat;
  Timer? _startupCheck;
  DateTime? _lastRun;
  bool _running = false;
  bool _paused = false;
  bool _started = false;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _heartbeat = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_tick()),
    );
    // A launch is the moment an external change is most likely to be noticed;
    // wait a little so the startup scan and the first paint have finished.
    _startupCheck = Timer(
      const Duration(seconds: 14),
      () => unawaited(_tick()),
    );
  }

  void dispose() {
    _heartbeat?.cancel();
    _startupCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  Future<void> _tick() async {
    if (_paused || _running) {
      return;
    }
    if (!isLocalLibrary || !autoScanNotifier.value) {
      return;
    }
    if (library.folderList.isEmpty || Loader.busy) {
      return;
    }
    final interval = Duration(minutes: autoScanIntervalMinutesNotifier.value);
    final last = _lastRun;
    if (last != null && DateTime.now().difference(last) < interval) {
      return;
    }
    await _run();
  }

  Future<void> _run() async {
    if (_running) {
      return;
    }
    _running = true;
    _lastRun = DateTime.now();
    try {
      await Loader.autoSync();
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached;
    if (state == AppLifecycleState.resumed) {
      unawaited(_tick());
    }
  }
}
