import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/comment_server.dart';
import 'package:lain/base/data/comment_setting.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/comment_server_page.dart';
import 'package:lain/base/widgets/my_switch.dart';
import 'package:lain/base/widgets/settings_page_route.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/layer/layers_manager.dart';

/// The comment tab of the settings: a master switch, and which server answers.
///
/// The server row stays visible but is disabled while the switch is off, so it
/// is clear what has to be set up before the feature can be used.
class CommentSettingsPage extends StatelessWidget {
  const CommentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    return ListenableBuilder(
      listenable: Listenable.merge([
        layersManager.backgroundChangeNotifier,
        panelColor.valueNotifier,
        pageBackgroundColor.valueNotifier,
        commentSwitchNotifier,
        commentActiveServerIdNotifier,
        switchColor.valueNotifier,
        buttonColor.valueNotifier,
      ]),
      builder: (context, child) {
        final enabled = commentSwitchNotifier.value;
        final server = activeCommentServer;

        return Scaffold(
          backgroundColor: colorManager.getSpecificOpaqueBgColor(),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: textColor,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(
                          l10n.commentSettings,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 30),
                    children: [
                      // Plain tile, matching the startup/background switches:
                      // a lone master switch does not need a section box.
                      ListTile(
                        title: Text(
                          l10n.commentSwitch,
                          style: TextStyle(fontSize: 15, color: textColor),
                        ),
                        trailing: SizedBox(
                          width: 50,
                          child: MySwitch(
                            valueNotifier: commentSwitchNotifier,
                            // The switch only changes a notifier, and a
                            // notifier does not write itself to disk.
                            onToggleCallBack: () => setting.save(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text(
                          l10n.commentSwitchDesc,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: textColor.withAlpha(150),
                          ),
                        ),
                      ),
                      _serverSection(context, l10n, textColor, enabled, server),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _serverSection(
    BuildContext context,
    AppLocalizations l10n,
    Color textColor,
    bool enabled,
    CommentServer? server,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        appleSectionTitle(l10n.commentServer),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: textColor.withAlpha(20),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Icon(
              Icons.forum_rounded,
              size: 24,
              color: textColor.withAlpha(enabled ? 200 : 90),
            ),
            title: Text(
              server == null
                  ? l10n.commentNoServer
                  : (server.name.isEmpty ? server.currentUrl : server.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: textColor.withAlpha(enabled ? 255 : 110),
              ),
            ),
            subtitle: server == null
                ? null
                : Text(
                    server.currentUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(enabled ? 150 : 90),
                    ),
                  ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: textColor.withAlpha(enabled ? 130 : 70),
            ),
            onTap: enabled
                ? () => pushSettingsPage<void>(
                    context,
                    settingsPageRoute<void>(() => const CommentServersPage()),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
