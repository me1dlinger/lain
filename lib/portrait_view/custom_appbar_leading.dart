import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/layer/layers_manager.dart';

/// Leading action of the page app bars: with a detail page open it goes back,
/// otherwise it returns to the home page. (The sidebar it used to open is gone.)
Widget customAppBarLeading(BuildContext context, {String label = ''}) {
  return IconButton(
    icon: Icon(label.isEmpty ? Icons.home_rounded : Icons.arrow_back_ios_new_rounded),
    onPressed: () => label.isEmpty
        ? layersManager.switchRootLayer('home')
        : layersManager.popDetail(label),
  );
}
