import 'package:material_ui/material_ui.dart';
import 'package:lain/base/widgets/song_list.dart';

/// The home shelf's "long time no see" list, as a page of its own.
class RediscoveryLayer extends StatelessWidget {
  const RediscoveryLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return const SongList(isRediscovery: true);
  }
}
