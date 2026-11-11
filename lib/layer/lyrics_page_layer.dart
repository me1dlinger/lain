import 'package:material_ui/material_ui.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/utils/media_query.dart';
import 'package:lain/landscape_view/pages/landscape_lyrics_page.dart';
import 'package:lain/portrait_view/pages/portrait_lyrics_page.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: 600));
      updateHoverFocusColor();
    });
  }

  @override
  void dispose() {
    displayLyricsPageNotifier.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: 600));
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
