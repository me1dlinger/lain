import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:material_ui/material_ui.dart';

import 'package:lain/base/data/playback_mode.dart';
import 'package:lain/base/services/audio_focus_service.dart';

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
AudioSessionConfiguration configurationForPlaybackMode(AudioPlaybackMode mode) {
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
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      );
    case AudioPlaybackMode.mix:
      return const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        // A plain GAIN pauses every other player. A transient, duckable
        // focus is the closest Android equivalent of "mix": the other app
        // keeps running, and mix ignores the matching duck event.
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
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
  _configuredMode = mode;
  if (Platform.isAndroid) {
    if (_sessionActive) {
      await audioFocusService.request(mode.name);
    }
    return;
  }
  final session = _sharedSession;
  if (session == null) {
    return;
  }
  try {
    // configure() only changes the configuration used by the next focus
    // request; while the session is active Android keeps the old focus type.
    // Release and re-request it so exclusive/duck/mix actually takes effect.
    if (_sessionActive) {
      await session.setActive(false);
    }
    await session.configure(configurationForPlaybackMode(mode));
    if (_sessionActive) {
      await session.setActive(true);
    }
  } catch (error) {
    debugPrint('applyPlaybackMode($mode) failed: $error');
  }
}

bool _sessionActive = false;

/// `setActive` is called here rather than directly in `initAudioService`, so a
/// later playback-mode change knows whether the app currently owns focus and
/// can release/re-request it.
Future<void> activateAudioSession(bool active) async {
  if (!_audioFocusSupported) {
    _sessionActive = active;
    return;
  }
  if (Platform.isAndroid) {
    _sessionActive = active;
    if (active) {
      await audioFocusService.request(
        (_configuredMode ?? AudioPlaybackMode.exclusive).name,
      );
    } else {
      await audioFocusService.abandon();
    }
    return;
  }
  final session = _sharedSession;
  if (session == null) {
    return;
  }
  try {
    if (active) {
      await session.configure(
        configurationForPlaybackMode(
          _configuredMode ?? AudioPlaybackMode.exclusive,
        ),
      );
    }
    await session.setActive(active);
    _sessionActive = active;
  } catch (error) {
    debugPrint('activateAudioSession($active) failed: $error');
  }
}

/// Remembers the session [initAudioService] created, so [applyPlaybackMode]
/// can reconfigure it.
AudioSession? _sharedSession;

/// The mode the session was last configured for.
AudioPlaybackMode? _configuredMode;

/// The mode currently configured, or null before [adopt] has done its work.
AudioPlaybackMode? get configuredPlaybackMode => _configuredMode;

/// Hands the app-wide session and the initial mode to this library. The mode
/// is applied when the session is activated or when the user changes it.
void adopt(AudioSession session, AudioPlaybackMode mode) {
  _sharedSession = session;
  _configuredMode = mode;
}

/// Whether [mode] keeps playing while another app ducks this one instead of
/// pausing.
bool pausesOnInterruption(AudioPlaybackMode mode) =>
    mode != AudioPlaybackMode.duck && mode != AudioPlaybackMode.mix;

/// Plays the "another app took over the speakers" handling for [mode]:
///
/// - exclusive: pause on begin, and resume on end if this app was playing
///   when the other app took focus. When the other app pauses or closes,
///   Lain continues by itself.
/// - duck: [duck] (lower the volume, no pause) on begin, [unduck] on end. A
///   [duckFallbackDuration] timer calls [unduck] if no end event arrives.
/// - mix: nothing at all.
class InterruptionController {
  InterruptionController({
    required this.modeOf,
    required this.isPlaying,
    required this.pause,
    required this.resume,
    required this.duck,
    required this.unduck,
  });

  final AudioPlaybackMode Function() modeOf;
  final bool Function() isPlaying;
  final void Function() pause;
  final void Function() resume;
  final void Function() duck;
  final void Function() unduck;

  Timer? _restoreTimer;
  bool _pausedByInterruption = false;

  void handle(bool begin) {
    final mode = modeOf();
    if (begin) {
      switch (mode) {
        case AudioPlaybackMode.exclusive:
          if (isPlaying()) {
            _pausedByInterruption = true;
            pause();
          }
        case AudioPlaybackMode.duck:
          // Keep the deadline of the first duck: some platforms report the
          // interrupting app again and again while it holds focus, and
          // restarting the timer each time is how the volume stayed ducked
          // forever after the other app went quiet.
          _restoreTimer ??= Timer(duckFallbackDuration, _onDuckTimeout);
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
        if (_pausedByInterruption) {
          _pausedByInterruption = false;
          resume();
        }
      case AudioPlaybackMode.duck:
        unduck();
      case AudioPlaybackMode.mix:
        _pausedByInterruption = false;
        break;
    }
  }

  void _onDuckTimeout() {
    _restoreTimer = null;
    unduck();
  }

  /// A manual pause after an interruption must not be undone by a late
  /// focus-gain event.
  void clearPendingResume() {
    _pausedByInterruption = false;
  }

  /// Forgets a pending fallback, e.g. when the controller is replaced.
  void dispose() {
    _restoreTimer?.cancel();
    _restoreTimer = null;
    _pausedByInterruption = false;
  }
}
