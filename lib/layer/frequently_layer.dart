import 'package:material_ui/material_ui.dart';
import 'package:lain/base/widgets/song_list.dart';

class FrequentlyLayer extends StatelessWidget {
  const FrequentlyLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return SongList(isFrequently: true);
  }
}
