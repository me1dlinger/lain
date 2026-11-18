import 'package:material_ui/material_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/asset_images.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/play_queue_sheet.dart';
import 'package:lain/base/widgets/vinyl_disc.dart';
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
                      ) {
                        final source = fromHeroContext.widget;
                        final sourceChild = source is Hero ? source.child : source;
                        final target = toHeroContext.widget;
                        final targetChild = target is Hero ? target.child : target;
                        // Closing a vinyl player: keep the disc during the
                        // flight and crossfade into the square mini cover near
                        // the end, instead of popping from a disc to a square
                        // cover for the whole transition.
                        if (flightDirection == HeroFlightDirection.pop &&
                            sourceChild is VinylDisc) {
                          return _VinylToMiniFlight(
                            vinyl: sourceChild,
                            cover: targetChild,
                            animation: animation,
                          );
                        }
                        return FittedBox(child: targetChild);
                      },
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


/// The closing flight of a vinyl player: the disc shrinks towards the play
/// bar, and the 35 px square cover fades in over the last part of the move.
class _VinylToMiniFlight extends StatelessWidget {
  final VinylDisc vinyl;
  final Widget cover;
  final Animation<double> animation;

  const _VinylToMiniFlight({
    required this.vinyl,
    required this.cover,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // On pop the route's animation runs from 1 back to 0. The flight
        // starts at the player and ends at the play bar, so turn it back into
        // 0..1; otherwise the square mini cover appears for the first frames
        // and then fades away before the disc has moved.
        final t = Curves.easeInOutCubic.transform(1 - animation.value);
        final square = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(child: vinyl),
            Opacity(
              opacity: square,
              child: FittedBox(child: cover),
            ),
          ],
        );
      },
    );
  }
}
