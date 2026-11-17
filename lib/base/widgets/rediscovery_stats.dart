import 'package:material_ui/material_ui.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';

/// The two facts that make a "long time no see" song worth meeting again:
/// how often it was played, and when that last happened. Icons and numbers
/// only - no labels, so the row stays quiet next to the song text.
class RediscoveryStats extends StatelessWidget {
  final MyAudioMetadata song;
  final double fontSize;
  final Color? color;

  const RediscoveryStats({
    super.key,
    required this.song,
    this.fontSize = 11,
    this.color,
  });

  static String dateText(DateTime? date) {
    if (date == null) {
      return '—';
    }
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final tint =
        color ?? colorManager.getSpecificTextColor().withAlpha(155);
    final style = TextStyle(
      fontSize: fontSize,
      height: 1.2,
      fontWeight: FontWeight.w500,
      color: tint,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_arrow_rounded, size: fontSize + 2, color: tint),
        const SizedBox(width: 1),
        Text('${song.playCount}', style: style),
        const SizedBox(width: 9),
        Icon(Icons.schedule_rounded, size: fontSize, color: tint),
        const SizedBox(width: 3),
        Text(dateText(song.lastPlayed), style: style),
      ],
    );
  }
}
