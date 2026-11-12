import 'package:material_ui/material_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/comment_setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/asset_images.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/comment_page.dart';
import 'package:lain/base/widgets/play_queue_sheet.dart';
import 'package:lain/base/utils/dynamic_lyrics_page_route.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:lain/layer/lyrics_page_layer.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:text_scroll/text_scroll.dart';

class PlayBar extends StatelessWidget {
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        if (currentSong == null) return const SizedBox.shrink();

        return ListenableBuilder(
          listenable: Listenable.merge([
            layersManager.backgroundChangeNotifier,
            glassColor.valueNotifier,
          ]),
          builder: (context, child) {
            return GlassContainer(
              height: 50,
              settings: LiquidGlassSettings(glassColor: glassColor.value),
              shape: LiquidRoundedSuperellipse(borderRadius: 25),
              clipBehavior: .antiAlias,
              child: child,
            );
          },
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                DynamicLyricsPageRoute(
                  pageBuilder: (_, _, _) => LyricsPageLayer(),
                ),
              );
            },

            child: Row(
              children: [
                const SizedBox(width: 15),
                Hero(
                  tag: 'cover',
                  flightShuttleBuilder:
                      (
                        flightContext,
                        animation,
                        flightDirection,
                        fromHeroContext,
                        toHeroContext,
                      ) => FittedBox(child: toHeroContext.widget),
                  child: CoverArtWidget(
                    size: 35,
                    borderRadius: 3,
                    picture: currentSong.picture,
                    useResize: false,
                  ),
                ),

                const SizedBox(width: 10),
                Expanded(
                  child: TextScroll(
                    "${getTitle(currentSong)} - ${getArtist(currentSong)}",
                    key: ValueKey(
                      currentSong.hashCode + MediaQuery.widthOf(context),
                    ),
                    velocity: const Velocity(pixelsPerSecond: Offset(40, 0)),
                    style: TextStyle(fontSize: 16),
                    intervalSpaces: 10,
                    pauseBetween: Duration(seconds: 2),
                  ),
                ),

                // Play/Pause Button
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: ValueListenableBuilder(
                      valueListenable: isPlayingNotifier,
                      builder: (_, isPlaying, _) {
                        return ImageIcon(
                          isPlaying ? pauseCircleImage : playCircleFillImage,
                          size: 25,
                        );
                      },
                    ),

                    onPressed: () {
                      tryVibrate();
                      audioHandler.togglePlay();
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: Icon(Icons.playlist_play_rounded, size: 30),
                    onPressed: () {
                      tryVibrate();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) {
                          return PlayQueueSheet();
                        },
                      );
                    },
                  ),
                ),

                // Only when the feature is switched on and a server can
                // answer: an entry that opens a page that can only fail is
                // worse than no entry.
                ValueListenableBuilder(
                  valueListenable: commentSwitchNotifier,
                  builder: (_, commentEnabled, _) {
                    if (!commentEnabled || activeCommentServer == null) {
                      return const SizedBox.shrink();
                    }
                    return SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: const Icon(Icons.forum_rounded, size: 28),
                        onPressed: () {
                          tryVibrate();
                          Navigator.push(
                            context,
                            CommentPageView.route(currentSong),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 15),
              ],
            ),
          ),
        );
      },
    );
  }
}
