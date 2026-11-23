import 'dart:async';

import 'package:flutter/services.dart';

/// Android audio focus, owned by the app rather than by audio_session.
///
/// The focus code follows `AudioManager`: 1 gain, -1 loss, -2 loss transient,
/// -3 loss transient can duck.
class AudioFocusService {
  static const _channel = MethodChannel('com.meidlinger.lain.audio_focus');

  final _events = StreamController<int>.broadcast();
  final _noisyEvents = StreamController<void>.broadcast();

  Stream<int> get events => _events.stream;
  Stream<void> get noisyEvents => _noisyEvents.stream;

  AudioFocusService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAudioFocusChange') {
        final code = call.arguments;
        if (code is int) {
          _events.add(code);
        }
      } else if (call.method == 'onAudioBecomingNoisy') {
        _noisyEvents.add(null);
      }
    });
  }

  Future<bool> request(String mode) async {
    try {
      return await _channel.invokeMethod<bool>('request', {'mode': mode}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> abandon() async {
    try {
      await _channel.invokeMethod<void>('abandon');
    } catch (_) {}
  }
}

final audioFocusService = AudioFocusService();
