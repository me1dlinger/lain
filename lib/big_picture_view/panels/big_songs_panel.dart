import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/loader.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/big_picture_view/panels/big_song_list_base_panel.dart';

class BigSongsPanel extends BigSongListBasePanel {
  const BigSongsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigSongsPanelState();
}

class _BigSongsPanelState extends BigSongListBasePanelState {
  @override
  List<MyAudioMetadata> get songList => library.songList;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Loader.stateNotifier,
      builder: (context, value, child) => super.build(context),
    );
  }
}
