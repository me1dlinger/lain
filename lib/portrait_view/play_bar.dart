import 'package:material_ui/material_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/asset_images.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/play_queue_sheet.dart';
import 'package:lain/base/utils/dynamic_lyrics_page_route.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:lain/layer/lyrics_page_layer.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:text_scroll/text_scroll.dart';

class PlayBar extends StatelessWidget {
  const PlayBar({super.key});

  void _openQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return PlayQueueSheet();
      },
    );
  }

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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              // A quick upward flick is the queue gesture; a slow drag is
              // left to the page behind, so scrolling near the bar still
              // works.
              if ((details.primaryVelocity ?? 0) < -250) {
                tryVibrateLight();
                _openQueue(context);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                InkWell(
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
                      _openQueue(context);
                    },
                  ),
                ),

                const SizedBox(width: 15),
              ],
            ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 2,
                  child: StreamBuilder<Duration>(
                    stream: audioHandler.getPositionStream(),
                    builder: (context, snapshot) {
                      final duration = audioHandler.getCurrentDuration();
                      final position = snapshot.data ?? Duration.zero;
                      if (duration <= Duration.zero) {
                        return const SizedBox.shrink();
                      }
                      final value =
                          (position.inMilliseconds / duration.inMilliseconds)
                              .clamp(0.0, 1.0);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 2,
                          backgroundColor: colorManager
                              .getSpecificTextColor()
                              .withAlpha(28),
                          valueColor: AlwaysStoppedAnimation(
                            colorManager.getSpecificHighlightTextColor(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
