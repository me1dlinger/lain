import 'package:material_ui/material_ui.dart';
import 'package:lain/base/widgets/song_list.dart';

/// The home shelf's random list, as a page of its own.
class RandomSongsLayer extends StatelessWidget {
  const RandomSongsLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return const SongList(isRandom: true);
  }
}
