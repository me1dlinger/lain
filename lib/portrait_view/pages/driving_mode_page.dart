import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/buttons.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/seekbar.dart';

/// Driving mode: a full screen page with nothing but what a glance needs -
/// the big cover, what is playing, and the three transport buttons. No
/// lyrics, no menus. Like the vivid lyrics page, the background adapts to
/// the album cover (blurred cover + tinted overlay) so the page stays in
/// tune with the theme, while the text stays white for readability in a car
/// at night and against sunlight at once.
class DrivingModePage extends StatelessWidget {
  const DrivingModePage({super.key});

  static const Color _foreground = Color(0xFFFFFFFF);
  static const Color _secondary = Color(0xB3FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<MyAudioMetadata?>(
        valueListenable: currentSongNotifier,
        builder: (context, currentSong, _) {
          final width = MediaQuery.widthOf(context);
          final height = MediaQuery.heightOf(context);
          // Same adaptive background recipe as the vivid lyrics page: the
          // cover fills the page, gets blurred, and is tinted with the cover
          // color; the tint always keeps a dark floor so white text remains
          // readable even with a bright cover.
          final coverArtColor = currentCoverArtColor;
          final overlayColor = coverArtColor.withAlpha(180);
          // The cover owns most of the page, but never the whole height:
          // on short screens the controls would be pushed off otherwise.
          final coverSize =
              width * 0.72 > height * 0.42 ? height * 0.42 : width * 0.72;

          return Stack(
            fit: StackFit.expand,
            children: [
              CoverArtWidget(
                picture: currentSong?.picture,
                color: coverArtColor,
              ),
              RepaintBoundary(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: width * 0.03,
                    sigmaY: height * 0.03,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    color: overlayColor,
                  ),
                ),
              ),
              const ColoredBox(color: Color(0x42000000)),
              SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        color: _secondary,
                        icon: const Icon(Icons.close_rounded, size: 28),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const Spacer(),
                    CoverArtWidget(
                      size: coverSize,
                      borderRadius: 16,
                      picture: currentSong?.picture,
                      useResize: false,
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        getTitle(currentSong),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _foreground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        getArtist(currentSong),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          color: _secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: SeekBar(
                        color: Colors.white,
                        widgetHeight: 50,
                        seekBarHeight: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          skip2PreviousButton(48, iconColor: _foreground),
                          const SizedBox(width: 48),
                          playOrPauseButton(72, iconColor: _foreground),
                          const SizedBox(width: 48),
                          skip2NextButton(48, iconColor: _foreground),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
