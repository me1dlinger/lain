import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/interaction.dart';

/// Quick action on a song row: the "+" queues the song right after the one
/// playing.
///
/// It borrows the icon of the menu's "add to playlist" entry, which is what it
/// sits next to, but it does not touch a playlist.
Widget playNextButton(MyAudioMetadata song, {double size = 20}) {
  return IconButton(
    icon: Icon(Icons.add_rounded, size: size),
    onPressed: () {
      tryVibrate();
      playSongNext(song);
    },
  );
}
