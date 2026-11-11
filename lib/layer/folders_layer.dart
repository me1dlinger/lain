import 'package:material_ui/material_ui.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:lain/base/asset_images.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/my_divider.dart';
import 'package:lain/base/widgets/my_navigator.dart';
import 'package:lain/base/widgets/my_scaffold.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/landscape_view/title_bar.dart';
import 'package:lain/layer/layers_manager.dart';

part '../landscape_view/panels/folders_panel.dart';
part '../portrait_view/pages/folders_page.dart';

final GlobalKey<NavigatorState> foldersKey = GlobalKey();
final foldersVisibleNotifier = ValueNotifier(true);

class FoldersLayer extends StatelessWidget {
  const FoldersLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return myNavigator(
      key: foldersKey,
      visibleNotifier: foldersVisibleNotifier,
      pageViewBuilder: () => pageView(context),
      panelViewBuilder: () => panelView(context),
    );
  }
}
