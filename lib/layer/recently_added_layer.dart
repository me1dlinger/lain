import 'package:material_ui/material_ui.dart';
import 'package:lain/base/widgets/song_list.dart';

/// The home shelf's "recently added" list, as a page of its own.
class RecentlyAddedLayer extends StatelessWidget {
  const RecentlyAddedLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return SongList(isRecentlyAdded: true);
  }
}
