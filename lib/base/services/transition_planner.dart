import 'dart:math' as math;

import 'package:lain/base/my_audio_metadata.dart';

/// How long the two halves of one track transition should be.
class TrackTransitionPlan {
  /// Seconds the outgoing track takes to reach silence.
  final double outSeconds;

  /// Seconds the incoming track takes to reach its normal level.
  final double inSeconds;

  /// Why the planner chose this pair. Kept for the media log.
  final String reason;

  const TrackTransitionPlan({
    required this.outSeconds,
    required this.inSeconds,
    required this.reason,
  });

  double get totalSeconds => outSeconds + inSeconds;
}

/// How much room a song offers at one end.
///
/// `room` is seconds of instrumental material before the first sung line
/// (head) or after the last one (tail). `density` is lyric characters per
/// second in the nearby 20 seconds: a dense vocal is not a good place to run a
/// long fade across.
class _SongEnd {
  final double room;
  final double density;

  const _SongEnd(this.room, this.density);
}

_SongEnd _headOf(MyAudioMetadata song) {
  final duration = song.duration?.inMilliseconds ?? 0;
  final lines = song.parsedLyrics?.lines ?? const [];
  if (duration <= 0 || lines.isEmpty) {
    return const _SongEnd(0, 0);
  }
  final first = lines.first.start.inMilliseconds;
  var chars = 0;
  final until = math.min(duration, first + 20000);
  for (final line in lines) {
    if (line.start.inMilliseconds >= until) {
      break;
    }
    chars += line.text.trim().length;
  }
  final span = math.max(1, until - first);
  return _SongEnd(
    (first / 1000).clamp(0.0, 15.0),
    chars / (span / 1000),
  );
}

_SongEnd _tailOf(MyAudioMetadata song) {
  final duration = song.duration?.inMilliseconds ?? 0;
  final lines = song.parsedLyrics?.lines ?? const [];
  if (duration <= 0 || lines.isEmpty) {
    return const _SongEnd(0, 0);
  }
  final last = lines.last.start.inMilliseconds;
  var chars = 0;
  final from = math.max(0, last - 20000);
  for (final line in lines) {
    if (line.start.inMilliseconds < from) {
      continue;
    }
    chars += line.text.trim().length;
  }
  final span = math.max(1, duration - last);
  return _SongEnd(
    ((duration - last) / 1000).clamp(0.0, 15.0),
    chars / (span / 1000),
  );
}

/// Plans the fade around the join from [from] to [to].
///
/// This follows the useful part of folia's crossfade planner rather than a
/// fixed number: the outgoing half grows when the track has an instrumental
/// tail and shrinks when a dense vocal runs into the end; the incoming half
/// does the same with its intro. The total is also capped by a quarter of the
/// shorter track, so a two-minute interlude is not half transition. A true
/// spectral comparison can refine the length later; this plan is already
/// deterministic and does not depend on network timing.
TrackTransitionPlan planTrackTransition({
  required MyAudioMetadata from,
  required MyAudioMetadata to,
  required int fixedTotalSeconds,
}) {
  final fixed = (fixedTotalSeconds.clamp(2, 12) / 2).toDouble();
  final fromDuration = (from.duration?.inMilliseconds ?? 0) / 1000;
  final toDuration = (to.duration?.inMilliseconds ?? 0) / 1000;

  if (fromDuration <= 0 || toDuration <= 0) {
    return TrackTransitionPlan(
      outSeconds: fixed,
      inSeconds: fixed,
      reason: 'unknown duration, fixed split',
    );
  }

  final tail = _tailOf(from);
  final head = _headOf(to);
  double out = 2.0 + tail.room * 0.18 - tail.density * 0.12;
  double enter = 2.0 + head.room * 0.18 - head.density * 0.12;
  out = out.clamp(1.5, 6.0);
  enter = enter.clamp(1.5, 6.0);

  // Do not spend a large part of a short track on the fade.
  final cap = math.min(fromDuration, toDuration) / 6;
  out = math.min(out, math.max(1.5, cap));
  enter = math.min(enter, math.max(1.5, cap));
  // Keep the whole transition inside a short track even when both halves are
  // individually reasonable.
  final totalCap = math.min(fromDuration, toDuration) / 3;
  if (out + enter > totalCap) {
    final scale = totalCap / (out + enter);
    out *= scale;
    enter *= scale;
  }

  return TrackTransitionPlan(
    outSeconds: out,
    inSeconds: enter,
    reason:
        'tail=${tail.room.toStringAsFixed(1)}s/${tail.density.toStringAsFixed(1)}cps '
        'head=${head.room.toStringAsFixed(1)}s/${head.density.toStringAsFixed(1)}cps',
  );
}
