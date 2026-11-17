import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/services/broadcast_inspector.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/stream_relay.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// Diagnostics that are useful when testing a car or a new cover scheme, kept
/// out of the normal settings pages.
class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final host = Uri.tryParse(streamRelay.lanBaseUrl ?? '')?.host ?? '';
    final inspectorUrl = host.isEmpty
        ? ''
        : 'http://$host:${BroadcastInspector.httpPort}';

    return opaqueSettingsPage(
      context: context,
      title: l10n.debug,
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 130),
        children: [
          appleSectionTitle(l10n.carDisplay),
          AppleFormSection(
            children: [
              ListTile(
                leading: Icon(
                  Icons.monitor_heart_outlined,
                  color: colorManager.getSpecificIconColor(),
                ),
                title: Text(l10n.pcInspector),
                subtitle: Text(
                  inspectorUrl.isEmpty ? l10n.unreachable : inspectorUrl,
                ),
                trailing: inspectorUrl.isEmpty
                    ? null
                    : const Icon(Icons.copy_all_outlined, size: 18),
                onTap: inspectorUrl.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: inspectorUrl),
                        );
                        showCenterMessage(l10n.copied);
                      },
              ),
              ListTile(
                leading: Icon(
                  Icons.podcasts_rounded,
                  color: colorManager.getSpecificIconColor(),
                ),
                title: Text(l10n.currentBroadcast),
                onTap: () {
                  final state = broadcastInspector.state;
                  showAnimationDialog<void>(
                    context: context,
                    child: SizedBox(
                      width: 340,
                      height: 430,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ').convert(
                              state.isEmpty ? {'ok': false} : state,
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          appleSectionTitle(l10n.viewLog),
          AppleFormSection(
            children: [
              ListTile(
                leading: Icon(
                  Icons.article_outlined,
                  color: colorManager.getSpecificIconColor(),
                ),
                title: Text(l10n.viewLog),
                onTap: () {
                  showAnimationDialog<void>(
                    context: context,
                    child: SizedBox(
                      width: 360,
                      height: 500,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            logger.logContent,
                            style: TextStyle(
                              fontSize: 11,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'Lain ${versionNumber}',
              style: TextStyle(
                fontSize: 11,
                color: textColor.withAlpha(120),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
