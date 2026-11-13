import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/buttons.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/seekbar.dart';

/// Driving mode: a full screen page with nothing but what a glance needs -
/// the big cover, what is playing, and the three transport buttons. No
/// lyrics, no menus. The colours are fixed dark-on-light regardless of the
/// app theme, because in a car the page has to stay readable at night and
/// against sunlight at once.
class DrivingModePage extends StatelessWidget {
  const DrivingModePage({super.key});

  static const Color _background = Color(0xFF17171A);
  static const Color _foreground = Color(0xFFFFFFFF);
  static const Color _secondary = Color(0xB3FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ValueListenableBuilder<MyAudioMetadata?>(
          valueListenable: currentSongNotifier,
          builder: (context, currentSong, _) {
            final width = MediaQuery.widthOf(context);
            final height = MediaQuery.heightOf(context);
            // The cover owns most of the page, but never the whole height:
            // on short screens the controls would be pushed off otherwise.
            final coverSize =
                width * 0.72 > height * 0.42 ? height * 0.42 : width * 0.72;

            return Column(
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
                    style: const TextStyle(fontSize: 16, color: _secondary),
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
            );
          },
        ),
      ),
    );
  }
}
