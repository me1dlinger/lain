import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// How a stream shares the output device with other apps.
///
/// Android arbitrates this through audio focus (exclusive / duck / mix); the
/// desktop backends have no such notion, so the setting exists everywhere and
/// is applied where the platform supports it.
enum AudioPlaybackMode {
  /// Takes the audio output for itself: other apps go silent.
  exclusive,

  /// Other apps keep playing, and this app lowers its own volume while they do.
  duck,

  /// Everything mixes, like a desktop player.
  mix,
}

/// The playback mode in effect. Mobile defaults to exclusive, which is what
/// those platforms themselves default to for a music player; desktop defaults
/// to mix, where exclusive has no meaning.
final playbackModeNotifier = ValueNotifier<AudioPlaybackMode>(
  defaultPlaybackMode(),
);

AudioPlaybackMode defaultPlaybackMode() {
  if (Platform.isAndroid || Platform.isIOS) {
    return AudioPlaybackMode.exclusive;
  }
  return AudioPlaybackMode.mix;
}
