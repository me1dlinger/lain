import 'dart:async';

/// The media-session publish machinery, kept free of Flutter and of
/// audio_service so it can be unit tested without a device.
///
/// What it solves, in the order a head unit sees the failures:
///
/// * **Stale results overwriting the current track.** Announcing a track kicks
///   off asynchronous work - fetching the artwork, downscaling it, resolving a
///   cover URI. When that work finishes the phone may already be on another
///   track, so every result has to be checked against a *generation*: the
///   number of the broadcast it was started for. A result from an older
///   generation is dropped, never applied. Without it, a song's slow cover
///   lands after the next song was published and the session keeps showing
///   the previous one.
/// * **A burst of switches broadcasting every track.** Each switch wants to
///   publish immediately, but a feed that publishes six items in 40ms makes the
///   head unit (AVRCP / Android Auto) queue the metadata and then walk through
///   it, one by one, long after the phone has moved on. Only the track that is
///   current when the dust settles is published; the pending earlier ones are
///   cancelled.
/// * **A cover that went missing staying missing.** A failed or dropped cover
///   resolution is forgotten once the broadcast that asked for it is over, so
///   the next broadcast tries again. The item *id* doubles as a version: the
///   session's artwork is rebuilt (with a new id) every time the artwork
///   actually changes, so a consumer that caches by id re-reads it.

/// One media-session item, in terms the module can reason about without
/// knowing the app's song model.
class MediaSnapshot {
  /// The item id published to the session. Doubles as the artwork version: see
  /// [MediaBroadcaster.publish].
  final String id;

  /// A cheap value that changes whenever the item's content changes - title,
  /// artist, lyric line and the artwork paths. Used to skip a publish that
  /// would carry exactly what the session already has.
  final Object key;

  /// Whether this snapshot carries artwork (a bitmap source or a fetchable
  /// URI). A publish without it is still made - a title and a lyric line beat
  /// nothing - but it is remembered so a later broadcast can retry.
  final bool hasArt;

  /// Pushes the item into the system session. Synchronous on purpose: the
  /// session stream must be fed in order, and an await here would let the next
  /// track's publish overtake this one.
  final void Function(MediaSnapshot) deliver;

  const MediaSnapshot({
    required this.id,
    required this.key,
    required this.hasArt,
    required this.deliver,
  });

  @override
  String toString() =>
      'MediaSnapshot(id=$id hasArt=$hasArt key=${key.hashCode})';
}

/// What a cover resolution produces, when it does so later than the publish
/// that wanted it.
class CoverOutcome {
  /// The generation the resolution was started for.
  final int generation;

  /// The relay generation at the time, so a failure caused by the LAN address
  /// changing can be told apart from one that is worth retrying on this
  /// network. Null when the caller has no such notion.
  final int? relayGeneration;

  /// A file path for the id, or null for a failure.
  final String? artPath;

  const CoverOutcome({
    required this.generation,
    required this.artPath,
    this.relayGeneration,
  });
}

/// Covers that could not be produced, remembered per artwork key.
class CoverFailure {
  /// The broadcast the failure belongs to. A failure only ever suppresses a
  /// retry *inside its own broadcast*: once the session has moved on, the cover
  /// is worth another attempt, which is what keeps a lost cover from staying
  /// lost for the rest of the queue.
  final int generation;

  final int relayGeneration;
  final int attempts;

  const CoverFailure({
    required this.generation,
    required this.relayGeneration,
    this.attempts = 1,
  });
}

/// The result of [MediaBroadcaster.handleCoverOutcome].
class CoverVerdict {
  /// Whether the outcome belongs to the broadcast that is current now.
  final bool current;

  /// Whether a failure is worth retrying after [_maxImmediateRetries]:
  /// it is not a permanent "this artwork will never work" answer.
  final bool retryable;

  /// Set when the failure must be forgotten now (a different network).
  final bool reset;

  const CoverVerdict({
    required this.current,
    this.retryable = false,
    this.reset = false,
  });
}

/// What a publish is about, which decides how long it must wait after the
/// previous one.
///
/// A head unit is not a screen that can be repainted at any rate: every
/// `MediaItem` change crosses the Bluetooth link as an AVRCP metadata update,
/// and the unit reads the new item (and, when it wants one, a new cover) before
/// it can process the next. Sending six of them in a second makes the unit walk
/// through a queue long after the phone has moved on - the "jumping titles" a
/// burst of next-presses produced. The kinds let the gate treat a track switch
/// (worth an immediate send) differently from a lyric line (worth at most one
/// send a second).
enum MediaUpdateKind {
  /// A different track is now playing.
  track,

  /// The same track, with artwork that was not available before.
  artwork,

  /// The same track, with a new lyric line.
  lyric,
}

/// The broadcast gate: one generation per announced track, one coalesced
/// publisher, and a failure memory that cannot outlive the broadcast.
class MediaBroadcaster {
  /// How long switches are coalesced before the current one is published.
  ///
  /// Short enough that pressing "next" shows the track at once on the phone,
  /// long enough that a burst of presses (holding the steering-wheel button,
  /// a queue load, an automatic advance right after a command) publishes once.
  final Duration debounce;

  /// The least time between two publishes of any kind. The Bluetooth link needs
  /// it: a second item that is sent while the first is still being read arrives
  /// when the unit is done with it, and looks like the unit is "one step behind"
  /// for the rest of the song.
  final Duration minGap;

  /// The least time between two publishes of lyric lines. A lyric line changes
  /// every few seconds, so this is never hit in normal playback; it is there for
  /// karaoke-style lyrics and for a seek that lands in the middle of a line.
  final Duration lyricGap;

  /// How long after a track switch a lyric line must wait. The unit is busy
  /// reading the new item (and its artwork); a lyric update landing on top of
  /// that is exactly what made the cover appear and disappear.
  final Duration trackSettle;

  /// How many times a cover that failed is retried for the same broadcast
  /// without waiting for the network to change. A cover that failed once on a
  /// slow link is worth another try; a format that cannot be decoded is not.
  static const int _maxImmediateRetries = 2;

  MediaBroadcaster({
    this.debounce = const Duration(milliseconds: 120),
    this.minGap = const Duration(milliseconds: 300),
    this.lyricGap = const Duration(seconds: 1),
    this.trackSettle = const Duration(milliseconds: 1500),
  });

  int _generation = 0;

  /// The current broadcast's generation. Async work started for a track
  /// remembers this and hands it back in [isCurrent].
  int get generation => _generation;

  /// Whether [generation] is still the broadcast that should be published.
  bool isCurrent(int generation) => generation == _generation;

  final _failures = <String, CoverFailure>{};

  Timer? _timer;
  MediaSnapshot? _pending;
  MediaUpdateKind _pendingKind = MediaUpdateKind.lyric;

  /// What the session currently has, to skip a publish that changes nothing.
  String? _deliveredId;
  int? _deliveredKey;

  /// When the last publish reached the session, and what kind it was.
  DateTime? _deliveredAt;
  MediaUpdateKind? _deliveredKind;

  int _publishes = 0;
  int _skipped = 0;

  /// Diagnostics for the `[media]` log line.
  int get publishCount => _publishes;
  int get skipCount => _skipped;
  bool get hasPending => _pending != null;

  /// Starts a new broadcast: every async result started before this call now
  /// belongs to an older generation and must be dropped.
  int nextGeneration() => ++_generation;

  /// Requests a publish of [snapshot].
  ///
  /// Every request replaces the pending one: only the state that is current
  /// when the gate opens is published, never the items a burst skipped through.
  /// [kind] sets how long the request waits after the previous publish, and
  /// [immediate] skips the plain debounce (a track switch must not wait for it)
  /// without ever skipping [minGap].
  void publish(
    MediaSnapshot snapshot, {
    MediaUpdateKind kind = MediaUpdateKind.lyric,
    bool immediate = false,
  }) {
    _pending = snapshot;
    _pendingKind = kind;

    var wait = immediate ? Duration.zero : debounce;

    final last = _deliveredAt;
    if (last != null) {
      final since = DateTime.now().difference(last);
      var gap = kind == MediaUpdateKind.lyric ? lyricGap : minGap;
      if (_deliveredKind == MediaUpdateKind.track &&
          kind == MediaUpdateKind.lyric) {
        gap = trackSettle;
      }
      if (since < gap) {
        final remaining = gap - since;
        if (remaining > wait) {
          wait = remaining;
        }
      }
    }

    _arm(wait);
  }

  void _arm(Duration wait) {
    _timer?.cancel();
    if (wait <= Duration.zero) {
      _timer = null;
      scheduleMicrotask(_flush);
      return;
    }
    _timer = Timer(wait, () {
      _timer = null;
      _flush();
    });
  }

  /// Delivers the pending snapshot unless it is exactly what the session
  /// already has. A no-op publish still serves a purpose: it is how a lyric
  /// line that did not change is kept from re-writing the session.
  void _flush() {
    final snapshot = _pending;
    _pending = null;
    if (snapshot == null) {
      return;
    }
    final key = snapshot.key.hashCode;
    if (snapshot.id == _deliveredId && key == _deliveredKey) {
      _skipped++;
      return;
    }
    _deliveredId = snapshot.id;
    _deliveredKey = key;
    _deliveredAt = DateTime.now();
    _deliveredKind = _pendingKind;
    _publishes++;
    snapshot.deliver(snapshot);
  }

  /// Whether a cover resolution for [artKey] should be attempted again, or
  /// whether it failed too recently for that to be anything but wasted work.
  /// Failures are keyed by artwork and forgotten when [relayGeneration]
  /// changes: a cover that was unreachable on the previous network is very
  /// likely reachable on this one.
  bool shouldAttemptCover(
    String artKey, {
    int? relayGeneration,
    int? generation,
  }) {
    final failure = _failures[artKey];
    if (failure == null) {
      return true;
    }
    if (!isCurrent(failure.generation)) {
      // The broadcast that failed is over; its memory is not this one's.
      _failures.remove(artKey);
      return true;
    }
    if (generation != null && failure.generation != generation) {
      // Explicitly asked for by a broadcast other than the failing one.
      return true;
    }
    if (relayGeneration != null && failure.relayGeneration != relayGeneration) {
      _failures.remove(artKey);
      return true;
    }
    return failure.attempts < _maxImmediateRetries;
  }

  /// Records the outcome of resolving the cover for [artKey].
  ///
  /// A successful outcome that is still current makes the caller re-publish
  /// (so the session gets the artwork); an outcome from an older broadcast is
  /// dropped. A failed outcome is remembered only while it belongs to the
  /// current broadcast and the same network, which is what keeps a lost cover
  /// recoverable: the next song, or the next network, starts from a clean
  /// slate.
  CoverVerdict handleCoverOutcome(
    String artKey,
    CoverOutcome outcome, {
    int? relayGeneration,
  }) {
    if (!isCurrent(outcome.generation)) {
      return const CoverVerdict(current: false);
    }
    if (outcome.artPath != null) {
      _failures.remove(artKey);
      return const CoverVerdict(current: true);
    }

    final network = outcome.relayGeneration ?? relayGeneration;
    final existing = _failures[artKey];
    final foreign = existing != null && !isCurrent(existing.generation);
    if (existing != null &&
        network != null &&
        (foreign || existing.relayGeneration != network)) {
      // The LAN address changed since the failure (or the failure belongs to a
      // session that is over): whatever was unreachable then may answer now,
      // so it is a fresh start, not a new failure.
      _failures.remove(artKey);
      return const CoverVerdict(current: true, reset: true, retryable: true);
    }
    if (foreign) {
      // The broadcast that failed is over: this is its first failure, not a
      // repeat of one belonging to a session that has moved on.
      _failures.remove(artKey);
    }

    final previous = existing != null && existing.generation == outcome.generation;
    final updated = CoverFailure(
      generation: outcome.generation,
      relayGeneration: network ?? existing?.relayGeneration ?? -1,
      attempts: previous ? existing.attempts + 1 : 1,
    );
    _failures[artKey] = updated;
    return CoverVerdict(
      current: true,
      retryable: updated.attempts < _maxImmediateRetries,
    );
  }

  /// The recorded failure for [artKey], for diagnostics and tests.
  CoverFailure? failureFor(String artKey) => _failures[artKey];

  /// Forgets everything that belongs to a broadcast that is over. Called when
  /// the phone starts over (a new queue) rather than for every track.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _failures.clear();
    _deliveredId = null;
    _deliveredKey = null;
    _deliveredAt = null;
    _deliveredKind = null;
    _generation = 0;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
