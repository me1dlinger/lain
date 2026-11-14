import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/quality_badge_setting.dart';
import 'package:lain/base/my_audio_metadata.dart';

/// HR / SQ / HQ, in the row's metadata line. Hidden when the source does not
/// say enough about the file to classify it, or when the setting is off.
class QualityBadge extends StatelessWidget {
  final MyAudioMetadata song;

  const QualityBadge({super.key, required this.song});

  static const _lossless = {
    'flac', 'alac', 'wav', 'ape', 'dsf', 'dff', 'aiff', 'aif', 'wv', 'tta',
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: songQualityBadgeNotifier,
      builder: (context, enabled, child) {
        if (!enabled) {
          return const SizedBox.shrink();
        }
        final info = _classify();
        if (info == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: info.$2,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              info.$1,
              style: TextStyle(
                fontSize: 9,
                height: 1.1,
                fontWeight: FontWeight.bold,
                color: info.$3,
              ),
            ),
          ),
        );
      },
    );
  }

  /// (label, background, foreground), or null when the file cannot be read.
  (String, Color, Color)? _classify() {
    final format = (song.format ?? '').toLowerCase();
    final rawBitrate = song.bitrate;
    final kbps = rawBitrate == null
        ? null
        : rawBitrate > 10000
        ? rawBitrate ~/ 1000
        : rawBitrate;
    final lossless =
        _lossless.contains(format) || (kbps != null && kbps >= 900);

    if (lossless) {
      final hires =
          (song.samplerate ?? 0) > 48000 || (kbps != null && kbps > 1000);
      return hires
          ? ('HR', const Color(0xFFFFF3C4), const Color(0xFF8A6D1A))
          : ('SQ', const Color(0xFFE3F0FF), const Color(0xFF2F6FED));
    }
    if (format.isNotEmpty || kbps != null) {
      return ('HQ', const Color(0xFFF3E6DA), const Color(0xFF8B5E3C));
    }
    return null;
  }
}
