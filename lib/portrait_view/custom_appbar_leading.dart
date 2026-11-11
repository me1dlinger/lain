import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/layer/layers_manager.dart';

/// Leading action of the page app bars:
/// - a detail page (a level below a list) goes back to the list it came from,
/// - the home page opens Settings,
/// - every other page goes back home.
Widget customAppBarLeading(BuildContext context, {String label = ''}) {
  return ValueListenableBuilder(
    valueListenable: currentRootLabel,
    builder: (context, root, child) {
      // A detail opened as its own route simply pops it, returning to exactly
      // the page it was opened from.
      if (label == '__pushed__') {
        return IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        );
      }
      if (label.isNotEmpty) {
        return IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => layersManager.popDetail(label),
        );
      }
      if (root == 'home') {
        return IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => layersManager.switchRootLayer('settings'),
        );
      }
      return IconButton(
        icon: const Icon(Icons.home_rounded),
        onPressed: () => layersManager.switchRootLayer('home'),
      );
    },
  );
}
