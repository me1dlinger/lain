import 'package:material_ui/material_ui.dart';

/// How one track becomes the next.
enum TrackTransitionMode {
  /// No long fade at the join. Gapless playback may be used instead.
  off,

  /// A fixed number of seconds, split equally between the outgoing tail and
  /// the incoming head.
  fixed,

  /// The length is chosen per pair from the songs' structure and measured
  /// spectral shape.
  adaptive,
}

/// Gapless and long fades are mutually exclusive: a fade needs the outgoing
/// track to be heard while the next one is prepared, while gapless hands the
/// output over without a seam. The playback engine honours this even if both
/// switches are on.
final gaplessPlaybackNotifier = ValueNotifier<bool>(true);

final trackTransitionModeNotifier = ValueNotifier<TrackTransitionMode>(
  TrackTransitionMode.off,
);

/// Total length of a fixed transition. The outgoing and incoming halves each
/// get half of it.
final trackTransitionSecondsNotifier = ValueNotifier<int>(6);
