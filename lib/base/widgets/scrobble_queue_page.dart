import 'package:material_ui/material_ui.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/scrobble_queue.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// Reports that are waiting for a network the app can actually reach.
class ScrobbleQueuePage extends StatelessWidget {
  const ScrobbleQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    return opaqueSettingsPage(
      context: context,
      title: l10n.scrobbleQueue,
      actions: [
        IconButton(
          tooltip: l10n.scrobbleRetry,
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => scrobbleQueue.flush(),
        ),
      ],
      body: ListenableBuilder(
        listenable: Listenable.merge([
          scrobbleQueue.events,
          scrobbleQueue.deadEvents,
        ]),
        builder: (context, child) {
          final pending = scrobbleQueue.events.value;
          final dead = scrobbleQueue.deadEvents.value;
          return ListView(
            padding: const EdgeInsets.only(top: 6, bottom: 110),
            children: [
              appleSectionTitle(l10n.scrobblePending),
              if (pending.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    l10n.scrobbleNoPending,
                    style: TextStyle(fontSize: 13, color: textColor.withAlpha(140)),
                  ),
                )
              else
                for (final event in pending)
                  ListTile(
                    title: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                    subtitle: Text(
                      '${event.artist} · ${event.serverId} · '
                      '${l10n.scrobbleAttempts(event.attempts)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: textColor.withAlpha(135)),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.refresh_rounded, color: colorManager.getSpecificIconColor()),
                      onPressed: () => scrobbleQueue.retry(event),
                    ),
                  ),
              if (dead.isNotEmpty) ...[
                appleSectionTitle(l10n.scrobbleDead),
                for (final event in dead)
                  ListTile(
                    title: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: textColor.withAlpha(170)),
                    ),
                    subtitle: Text(
                      '${event.artist} · ${event.serverId}',
                      style: TextStyle(fontSize: 11, color: textColor.withAlpha(120)),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.refresh_rounded, color: textColor.withAlpha(150)),
                      onPressed: () => scrobbleQueue.retry(event),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: TextButton(
                    onPressed: () => scrobbleQueue.clearDead(),
                    child: Text(
                      l10n.scrobbleClearDead,
                      style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
