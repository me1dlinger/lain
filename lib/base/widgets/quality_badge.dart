import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/quality_badge_setting.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

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
        final info = QualityBadge.classify(song);
        if (info == null) {
          return const SizedBox.shrink();
        }
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: colorManager.getSpecificTextColor().withAlpha(
                  mainPageThemeNotifier.value == .vivid ? 40 : 18,
                ),
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
        );
      },
    );
  }

  /// (label, background, foreground), or null when the file cannot be read.
  static (String, Color, Color)? classify(MyAudioMetadata song) {
    final vivid = mainPageThemeNotifier.value == .vivid;
    final hrColor = vivid
        ? const Color(0xFF7A5A00)
        : const Color(0xFFD9AE3C);
    final sqColor = vivid
        ? const Color(0xFF1E5C7A)
        : const Color(0xFF6FA8C6);
    final hqColor = vivid
        ? const Color(0xFF6B4A2F)
        : const Color(0xFF8E6745);
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
          ? ('HR', const Color(0xFFFFF3C4), const Color(0xFFD9AE3C))
          : ('SQ', const Color(0xFFE3F0FF), const Color(0xFF6FA8C6));
    }
    if (format.isNotEmpty || kbps != null) {
      return ('HQ', hqColor, hqColor);
    }
    return null;
  }
}

/// The row's meta badges as one unit: quality, cached, favourite, each shown
/// only when it applies and separated by exactly the same 4 px. The old row
/// put the star in a 20 px box for a 15 px icon, which reserved blank space on
/// both sides even before anything was drawn.
class SongBadges extends StatelessWidget {
  final MyAudioMetadata song;

  const SongBadges({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        songQualityBadgeNotifier,
        library.changeNotifier,
        song.isFavoriteNotifier,
      ]),
      builder: (context, child) {
        final items = <Widget>[];
        final quality = songQualityBadgeNotifier.value
            ? QualityBadge.classify(song)
            : null;
        if (quality != null) {
          items.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: colorManager.getSpecificTextColor().withAlpha(
                  mainPageThemeNotifier.value == .vivid ? 40 : 18,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                quality.$1,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                  color: quality.$3,
                ),
              ),
            ),
          );
        }
        if (isStreamSource && song.cacheExist) {
          items.add(
            Tooltip(
              message: AppLocalizations.of(context).cached,
              child: Icon(
                Icons.offline_pin_rounded,
                size: 12,
                color: colorManager.getSpecificTextColor().withAlpha(110),
              ),
            ),
          );
        }
        if (song.isFavoriteNotifier.value) {
          items.add(
            const Icon(Icons.star_rounded, color: Colors.red, size: 15),
          );
        }
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                items[i],
              ],
            ],
          ),
        );
      },
    );
  }
}
