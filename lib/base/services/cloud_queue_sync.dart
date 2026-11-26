import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/cloud_play_queue.dart';
import 'package:lain/base/data/cloud_queue_setting.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/stream_client.dart';

enum CloudQueueRestoreStatus {
  /// No capable source, or the server did not answer.
  unavailable,

  /// The server has no queue for this user.
  empty,

  /// The queue was installed and playback started.
  restored,
}

class CloudQueueRestoreOutcome {
  final CloudQueueRestoreStatus status;
  final int count;
  final int missing;

  const CloudQueueRestoreOutcome(
    this.status, {
    this.count = 0,
    this.missing = 0,
  });

  static const unavailable = CloudQueueRestoreOutcome(
    CloudQueueRestoreStatus.unavailable,
  );
  static const empty = CloudQueueRestoreOutcome(CloudQueueRestoreStatus.empty);
}

/// Mirrors the play queue to the server and brings it back on request.
///
/// Uploads are debounced and compared against the last snapshot sent, so
/// browsing a queue does not become a request per tap. Restoring is never
/// automatic: [fetchRemote]/[applyRemote] are only reached from a user action,
/// which is what keeps a queue that is already playing here from being
/// replaced by whatever another device left on the server.
class CloudQueueSync {
  /// Queue changes settle for this long before they are sent. A pause or a
  /// background/stop flushes straight away instead.
  static const debounce = Duration(seconds: 4);

  Timer? _timer;
  String? _lastSignature;
  StreamClient? _client;
  StreamClient? _scheduledClient;
  bool _saving = false;
  bool _dirty = false;

  Future<bool>? _probeFuture;
  StreamClient? _probeClient;

  /// Whether the active source confirmed it has a server-side play queue.
  final availableNotifier = ValueNotifier<bool>(false);

  bool get enabled => cloudQueueEnabledNotifier.value;

  /// The client to sync with, or null for a source that cannot. A new client
  /// (another server) starts with no remembered snapshot.
  StreamClient? _activeClient() {
    final client = streamClient;
    if (client == null || !client.supportsCloudPlayQueue) {
      return null;
    }
    if (!identical(client, _client)) {
      _client = client;
      _lastSignature = null;
    }
    return client;
  }

  /// Schedules an upload after [debounce]. Called on queue and track changes.
  void noteQueueChanged() {
    if (!enabled) {
      return;
    }
    _scheduledClient = streamClient;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      unawaited(save());
    });
  }

  /// Sends the current queue now. Used on pause, stop and app background,
  /// when waiting for the debounce could lose the last position.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    await save(force: true);
  }

  /// Asks the server once whether this source supports the queue endpoints.
  /// The result is shared with the settings tile so a rebuild does not probe
  /// again; [fetchRemote] starts a new probe because it follows a user action.
  Future<bool> probeAvailability() {
    final client = streamClient;
    if (client == null || !client.supportsCloudPlayQueue) {
      _probeClient = null;
      _probeFuture = null;
      availableNotifier.value = false;
      return Future.value(false);
    }

    if (!identical(client, _probeClient)) {
      _probeClient = client;
      _probeFuture = null;
    }

    return _probeFuture ??= client.probeCloudPlayQueue().then((available) {
      availableNotifier.value = available;
      return available;
    });
  }

  /// Uploads the queue if it differs from the last one sent.
  Future<bool> save({bool force = false}) async {
    if (!enabled) {
      return false;
    }
    final client = _activeClient();
    if (client == null) {
      return false;
    }
    final scheduled = _scheduledClient;
    if (!force && scheduled != null && !identical(scheduled, client)) {
      // The queue change belonged to another source; that server's queue is
      // not this server's business.
      return false;
    }

    final ids = [for (final song in playQueue) song.id];
    if (ids.isEmpty) {
      // There is no "clear the queue" call in OpenSubsonic; leaving the last
      // snapshot alone is better than a request that every server rejects.
      return false;
    }

    final snapshot = CloudQueueSnapshot.fromQueue(
      ids,
      index: audioHandler.currentIndex,
      position: audioHandler.getPosition(),
    );
    if (snapshot.isEmpty) {
      return false;
    }

    final signature = snapshot.signature;
    if (!force && signature == _lastSignature) {
      return false;
    }

    if (_saving) {
      _dirty = true;
      return false;
    }

    _saving = true;
    try {
      // The client itself refuses when the server has no queue endpoint (and
      // remembers that refusal), so a source that cannot is not asked again
      // for every queue change.
      final saved = await client.savePlayQueue(
        snapshot.songIds,
        currentId: snapshot.currentId,
        position: snapshot.position,
      );
      if (saved) {
        _lastSignature = signature;
      }
      return saved;
    } finally {
      _saving = false;
      if (_dirty) {
        _dirty = false;
        // A change arrived while this request was in flight: send the newer
        // snapshot now rather than waiting for the next debounce.
        unawaited(save(force: true));
      }
    }
  }

  /// Reads the server's queue. Null when the source cannot or the server did
  /// not answer; an empty queue is returned as such.
  Future<CloudPlayQueue?> fetchRemote() async {
    final client = streamClient;
    if (client == null || !client.supportsCloudPlayQueue) {
      return null;
    }

    // This follows an explicit tap, so a probe that failed earlier (a flaky
    // network) gets another chance.
    _probeFuture = null;
    if (!await probeAvailability()) {
      return null;
    }
    return client.getPlayQueue();
  }

  /// Installs [queue] as the local queue and starts playing it. Only call this
  /// after the user has confirmed the replacement.
  Future<CloudQueueRestoreOutcome> applyRemote(CloudPlayQueue queue) async {
    if (queue.isEmpty) {
      return CloudQueueRestoreOutcome.empty;
    }

    final resolved = resolveCloudQueue<MyAudioMetadata>(queue, (id) {
      final song = library.id2Song[id];
      if (song == null || (library.cachedOnly && !song.cacheExist)) {
        return null;
      }
      return song;
    });
    if (resolved.isEmpty) {
      return CloudQueueRestoreOutcome.unavailable;
    }

    await audioHandler.setPlayQueue(
      resolved.songs,
      0,
      targetIndex: resolved.index,
      startPosition: resolved.position,
      preserveOrder: true,
    );

    // The queue is already on the server; do not send it straight back.
    _lastSignature = CloudQueueSnapshot.fromQueue(
      [for (final song in playQueue) song.id],
      index: audioHandler.currentIndex,
      position: audioHandler.getPosition(),
    ).signature;

    return CloudQueueRestoreOutcome(
      CloudQueueRestoreStatus.restored,
      count: resolved.count,
      missing: resolved.missing,
    );
  }
}

final cloudQueueSync = CloudQueueSync();
