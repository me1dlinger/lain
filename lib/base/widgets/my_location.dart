import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/asset_images.dart';
import 'package:lain/base/my_audio_metadata.dart';

class MyLocation extends StatelessWidget {
  final ScrollController scrollController;
  final ValueNotifier<bool> listIsScrollingNotifier;
  final ValueNotifier<List<MyAudioMetadata>> currentSongListNotifier;
  final double offset;

  /// Exact scroll offset of the song's row, or a negative number when the song
  /// is not on screen. Views whose rows are not a uniform list - the artist
  /// view inserts an album strip and a heading per album - supply this; the
  /// others fall back to [rowExtent] * index.
  final double Function(MyAudioMetadata song)? offsetOf;

  /// Height of one row, used when [offsetOf] is not given.
  final double rowExtent;

  const MyLocation({
    super.key,
    required this.scrollController,
    required this.listIsScrollingNotifier,
    required this.currentSongListNotifier,
    required this.offset,
    this.offsetOf,
    this.rowExtent = 60,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        currentSongNotifier,
        currentSongListNotifier,
        listIsScrollingNotifier,
      ]),
      builder: (_, _) {
        if (currentSongNotifier.value == null ||
            !listIsScrollingNotifier.value) {
          return SizedBox.shrink();
        }
        final song = currentSongNotifier.value!;
        final index = currentSongListNotifier.value.indexOf(song);
        if (index == -1) {
          return SizedBox.shrink();
        }

        return IconButton(
          onPressed: () {
            final rowOffset = offsetOf?.call(song) ?? rowExtent * index;
            if (rowOffset < 0) {
              return;
            }
            final position = scrollController.position;
            final maxScrollExtent = position.maxScrollExtent;
            final minScrollExtent = position.minScrollExtent;
            scrollController.animateTo(
              (rowOffset + offset).clamp(minScrollExtent, maxScrollExtent),
              duration: Duration(milliseconds: 300),
              curve: Curves.linear,
            );
          },
          icon: ImageIcon(locationImage),
        );
      },
    );
  }
}
