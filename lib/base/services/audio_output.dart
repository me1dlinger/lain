import 'package:flutter/services.dart';

/// One output device Android currently reports, with the raw platform type.
class AudioOutputDevice {
  final int type;
  final String name;

  const AudioOutputDevice({required this.type, required this.name});
}

/// What Android says about the audio output. The sample rate and buffer are
/// the system's own values; the connected devices let the UI show which kind
/// of route is in use (speaker, wired, USB, Bluetooth).
class AudioOutputInfo {
  final int? sampleRate;
  final int? framesPerBuffer;
  final List<AudioOutputDevice> devices;

  const AudioOutputInfo({
    this.sampleRate,
    this.framesPerBuffer,
    this.devices = const [],
  });

  /// Android reports every connected output, not which one is routed. The
  /// route the system picks follows its own priority, which is the same order
  /// used here: Bluetooth and USB beat the built-in speaker.
  AudioOutputDevice? get route {
    AudioOutputDevice? best;
    var bestRank = -1;
    for (final device in devices) {
      final rank = _rank(device.type);
      if (rank > bestRank) {
        best = device;
        bestRank = rank;
      }
    }
    return best;
  }

  static int _rank(int type) {
    switch (type) {
      case 26: // BLE headset
      case 27: // BLE speaker
      case 30: // BLE broadcast (kept numeric for old platforms)
        return 100;
      case 8: // Bluetooth A2DP
      case 7: // Bluetooth SCO
        return 90;
      case 11: // USB device
      case 12: // USB accessory
      case 22: // USB headset
        return 80;
      case 3: // wired headset
      case 4: // wired headphones
        return 70;
      case 29: // HDMI eARC
      case 9:
      case 10:
        return 60;
      case 13: // dock
        return 50;
      case 23: // hearing aid
        return 40;
      case 2:
        return 10;
      default:
        return 5;
    }
  }
}

class AudioOutputService {
  static const _channel = MethodChannel('com.meidlinger.lain.media');

  Future<AudioOutputInfo?> query() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getAudioOutputInfo',
      );
      if (raw == null) {
        return null;
      }
      final devices = <AudioOutputDevice>[];
      final rawDevices = raw['devices'];
      if (rawDevices is List) {
        for (final item in rawDevices) {
          if (item is Map) {
            devices.add(
              AudioOutputDevice(
                type: (item['type'] as num?)?.toInt() ?? 0,
                name: '${item['name'] ?? ''}',
              ),
            );
          }
        }
      }
      return AudioOutputInfo(
        sampleRate: (raw['sampleRate'] as num?)?.toInt(),
        framesPerBuffer: (raw['framesPerBuffer'] as num?)?.toInt(),
        devices: devices,
      );
    } catch (_) {
      return null;
    }
  }
}

final audioOutputService = AudioOutputService();
