import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/layer/layers_manager.dart';

/// Leading action of the page app bars: on a root page it opens Settings (the
/// sidebar that used to hold the menu is gone), and on a detail page it goes
/// back to the list it was opened from.
Widget customAppBarLeading(BuildContext context, {String label = ''}) {
  return IconButton(
    icon: Icon(
      label.isEmpty ? Icons.settings_outlined : Icons.arrow_back_ios_new_rounded,
    ),
    onPressed: () => label.isEmpty
        ? layersManager.switchRootLayer('settings')
        : layersManager.popDetail(label),
  );
}
