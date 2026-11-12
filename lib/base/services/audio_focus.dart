import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:material_ui/material_ui.dart';

import 'package:lain/base/data/playback_mode.dart';

/// Android and iOS expose "how do I share the speakers?" through their audio
/// session APIs; the desktop backends simply mix everything, so the modes only
/// mean something on a phone.
bool get _audioFocusSupported => Platform.isAndroid || Platform.isIOS;

/// Session configuration matching [mode].
///
/// - [AudioPlaybackMode.exclusive]: unchanged legacy behaviour - Android's full
///   (non-transient) audio focus, iOS `playback`. Other apps go silent.
/// - [AudioPlaybackMode.duck]: on iOS another app may interrupt and our own
///   audio is then paused by the interruption handler; on Android a transient
///   focus that lets the interrupting app duck (lower) us instead of stopping
///   us. `androidWillPauseWhenDucked: false` keeps this app playing while the
///   interrupting app is ducked in turn, and the handler lowers the volume.
/// - [AudioPlaybackMode.mix]: sides with the other apps: `mix` focus that never
///   pauses when ducked on Android, `playback` + `mixWithOthers` on iOS, so
///   everything stays at full volume together.
AudioSessionConfiguration configurationForPlaybackMode(
  AudioPlaybackMode mode,
) {
  switch (mode) {
    case AudioPlaybackMode.exclusive:
      return const AudioSessionConfiguration.music();
    case AudioPlaybackMode.duck:
      return const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      );
    case AudioPlaybackMode.mix:
      return const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      );
  }
}

/// Player volume while another app ducks this one, on this app's 0..1 scale
/// (the handler maps it on to mpv's 0..100).
const double duckedVolumeScaled = 0.15;

/// How long a duck lasts before the volume is brought back even though no
/// "interruption ended" event arrived. Android commonly reports a duck as a
/// bare focus loss with no matching end, so without this fallback the player
/// could stay quiet forever.
const Duration duckFallbackDuration = Duration(seconds: 3);

/// Applies [mode] to the app-wide audio session.
///
/// A no-op on the desktop and before [adopt] has supplied a session; the
/// platform call is awaited but its failure is swallowed so a backend that
/// rejects a configuration cannot take playback down with it.
Future<void> applyPlaybackMode(AudioPlaybackMode mode) async {
  if (!_audioFocusSupported) {
    return;
  }
  final session = _sharedSession;
  if (session == null) {
    return;
  }
  _configuredMode = mode;
  try {
    await session.configure(configurationForPlaybackMode(mode));
  } catch (error) {
    debugPrint('applyPlaybackMode($mode) failed: $error');
  }
}

/// Remembers the session [initAudioService] created, so [applyPlaybackMode]
/// can reconfigure it.
AudioSession? _sharedSession;

/// The mode the session was last configured for.
AudioPlaybackMode? _configuredMode;

/// The mode currently configured, or null before [adopt] has done its work.
AudioPlaybackMode? get configuredPlaybackMode => _configuredMode;

/// Hands the app-wide session to this library and applies [mode] to it.
///
/// Deliberately not async and not awaited by the caller: the actual platform
/// call goes through [applyPlaybackMode], which catches its own errors, so a
/// failing channel can never break `initAudioService`.
void adopt(AudioSession session, AudioPlaybackMode mode) {
  _sharedSession = session;
  unawaited(applyPlaybackMode(mode));
}

/// Whether [mode] keeps playing while another app ducks this one instead of
/// pausing.
bool pausesOnInterruption(AudioPlaybackMode mode) =>
    mode != AudioPlaybackMode.duck && mode != AudioPlaybackMode.mix;

/// Plays the "another app took over the speakers" handling for [mode]:
///
/// - exclusive: [pause] on begin, [resume] on end.
/// - duck: [duck] (lower the volume, no pause) on begin, [unduck] on end. A
///   [duckFallbackDuration] timer calls [unduck] if no end event arrives.
/// - mix: nothing at all.
///
/// [isPlaying] gates the exclusive resume, so an interruption that ends while
/// the user was already paused does not start playback behind their back.
class InterruptionController {
  InterruptionController({
    required this.modeOf,
    required this.pause,
    required this.resume,
    required this.duck,
    required this.unduck,
    required this.isPlaying,
  });

  final AudioPlaybackMode Function() modeOf;
  final void Function() pause;
  final void Function() resume;
  final void Function() duck;
  final void Function() unduck;
  final bool Function() isPlaying;

  Timer? _restoreTimer;
  bool _playingWhenInterrupted = false;

  void handle(bool begin) {
    final mode = modeOf();
    if (begin) {
      switch (mode) {
        case AudioPlaybackMode.exclusive:
          _playingWhenInterrupted = isPlaying();
          pause();
        case AudioPlaybackMode.duck:
          _playingWhenInterrupted = isPlaying();
          _restoreTimer?.cancel();
          _restoreTimer = Timer(duckFallbackDuration, _onDuckTimeout);
          duck();
        case AudioPlaybackMode.mix:
          break;
      }
      return;
    }

    // An end event always cancels a pending fallback: the owner is talking
    // again (or the interruption is over) either way.
    _restoreTimer?.cancel();
    _restoreTimer = null;

    switch (mode) {
      case AudioPlaybackMode.exclusive:
        if (_playingWhenInterrupted) {
          resume();
        }
      case AudioPlaybackMode.duck:
        unduck();
      case AudioPlaybackMode.mix:
        break;
    }
    _playingWhenInterrupted = false;
  }

  void _onDuckTimeout() {
    _restoreTimer = null;
    unduck();
  }

  /// Forgets a pending fallback, e.g. when the controller is replaced.
  void dispose() {
    _restoreTimer?.cancel();
    _restoreTimer = null;
  }
}
