import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/widgets/my_navigator.dart';
import 'package:lain/base/widgets/my_scaffold.dart';
import 'package:lain/base/widgets/settings_list.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/landscape_view/title_bar.dart';

final GlobalKey<NavigatorState> settingsKey = GlobalKey();
final settingsVisibleNotifier = ValueNotifier(true);

class SettingsLayer extends StatelessWidget {
  const SettingsLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return myNavigator(
      key: settingsKey,
      visibleNotifier: settingsVisibleNotifier,
      pageViewBuilder: () => ValueListenableBuilder(
        valueListenable: mainPageThemeNotifier,
        builder: (context, value, child) {
          return myScaffold(
            context: context,
            body: SettingsList(iconSize: 30),
            title: AppLocalizations.of(context).settings,
          );
        },
      ),
      panelViewBuilder: () => Column(
        children: [
          TitleBar(),
          Expanded(child: SettingsList()),
        ],
      ),
    );
  }
}
