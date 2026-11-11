import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/history.dart';
import 'package:lain/base/my_audio_metadata.dart';

import 'package:lain/big_picture_view/panels/big_song_list_base_panel.dart';

class BigRecentlyPanel extends StatelessWidget {
  const BigRecentlyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return _BigRecentlySongListPanel();
  }
}

class _BigRecentlySongListPanel extends BigSongListBasePanel {
  const _BigRecentlySongListPanel();

  @override
  State<StatefulWidget> createState() => _BigRecentlySongListPanelState();
}

class _BigRecentlySongListPanelState extends BigSongListBasePanelState {
  @override
  List<MyAudioMetadata> get songList => history.recentlySongList;
}
