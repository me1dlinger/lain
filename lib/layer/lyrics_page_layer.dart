import 'package:material_ui/material_ui.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/utils/media_query.dart';
import 'package:lain/landscape_view/pages/landscape_lyrics_page.dart';
import 'package:lain/portrait_view/pages/portrait_lyrics_page.dart';
import 'package:lain/layer/layers_manager.dart';

/// Whether the playing page is on screen. Anything that colours itself from
/// the palette by hand has to listen to this: the colour it reads depends on
/// this flag, and nothing is rebuilt while a page is merely revealed underneath.
final displayLyricsPageNotifier = ValueNotifier(false);

bool get displayLyricsPage => displayLyricsPageNotifier.value;

class LyricsPageLayer extends StatefulWidget {
  const LyricsPageLayer({super.key});

  @override
  State<StatefulWidget> createState() => _LyricsPageLayerState();
}

class _LyricsPageLayerState extends State<LyricsPageLayer> {
  @override
  void initState() {
    super.initState();
    displayLyricsPageNotifier.value = true;
    // The text/icon getters switch to the lyrics palette while this layer is
    // on screen. Rebuild the pages underneath as soon as it opens or closes,
    // otherwise a page built while the player was open keeps the wrong palette
    // after a swipe-down dismisses the player.
    layersManager.backgroundChangeNotifier.value++;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: 600));
      layersManager.backgroundChangeNotifier.value++;
      updateHoverFocusColor();
    });
  }

  @override
  void dispose() {
    displayLyricsPageNotifier.value = false;
    layersManager.backgroundChangeNotifier.value++;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: 600));
      layersManager.backgroundChangeNotifier.value++;
      updateHoverFocusColor();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isTooNarrow(context)) {
      return PortraitLyricsPage();
    }
    return LandscapeLyricsPage();
  }
}
