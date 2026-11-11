import 'package:material_ui/material_ui.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// Quick action on a song row: the "+" queues the song right after the one
/// playing.
///
/// It borrows the icon of the menu's "add to playlist" entry, which is what it
/// sits next to, but it does not touch a playlist.
Widget playNextButton(
  BuildContext context,
  MyAudioMetadata song, {
  double size = 20,
}) {
  return IconButton(
    icon: Icon(Icons.add_rounded, size: size),
    onPressed: () {
      // The button changing the queue is worth feeling, so this is the direct
      // feedback rather than the incidental one behind the vibration setting.
      vibrateGestureFeedback();
      playSongNext(song, AppLocalizations.of(context).added2Next);
    },
  );
}
