import 'package:flutter/foundation.dart';

/// How replay gain tags are applied to the player. Off keeps the file's own
/// level; track and album equalise loudness using the tags written by the
/// encoder, which is what stops a mixed library from jumping in volume.
enum ReplayGainMode { off, track, album }

final replayGainModeNotifier = ValueNotifier<ReplayGainMode>(
  ReplayGainMode.off,
);

/// Playback rate. 1.0 is the file's own speed.
final playbackSpeedNotifier = ValueNotifier<double>(1.0);

/// Fade the volume in when playback starts and out when it pauses or a track
/// is switched. Short enough to hide a seek or a switch, long enough to be
/// audible as a slope rather than a click.
final audioFadeNotifier = ValueNotifier<bool>(true);

/// Whether the phone keeps the server's now-playing entry up to date. Turning
/// it off stops the periodic position reports but leaves the play count that
/// is recorded when a song finishes.
final reportPlaybackProgressNotifier = ValueNotifier<bool>(true);

const playbackSpeedChoices = <double>[0.5, 0.75, 1.0, 1.15, 1.25, 1.5, 2.0];

String playbackSpeedLabel(double speed) {
  if ((speed - 1.0).abs() < 0.001) {
    return '1.0x';
  }
  final text = speed.toStringAsFixed(2);
  return '${text.endsWith('0') ? text.substring(0, text.length - 1) : text}x';
}
