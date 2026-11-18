import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/data/music_server.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/scrobble_queue.dart';
import 'package:lain/base/services/source_health.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/server_status_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

class SourceHealthPage extends StatefulWidget {
  const SourceHealthPage({super.key});

  @override
  State<SourceHealthPage> createState() => _SourceHealthPageState();
}

class _SourceHealthPageState extends State<SourceHealthPage> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    sourceHealth.ensureLoaded().then((_) {
      if (mounted && sourceHealth.entries.value.isEmpty) {
        _testAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return opaqueSettingsPage(
      context: context,
      title: l10n.sourceHealth,
      actions: [
        IconButton(
          tooltip: l10n.sourceTestAll,
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loading ? null : _testAll,
        ),
      ],
      body: ListenableBuilder(
        listenable: Listenable.merge([
          sourceHealth.entries,
          scrobbleQueue.events,
        ]),
        builder: (context, child) {
          final health = sourceHealth.entries.value;
          final servers = config.servers;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              if (servers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50),
                  child: Center(
                    child: Text(
                      l10n.sourceNoServers,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorManager
                            .getSpecificTextColor()
                            .withAlpha(140),
                      ),
                    ),
                  ),
                )
              else
                for (final server in servers)
                  _serverCard(context, l10n, server, health),
            ],
          );
        },
      ),
    );
  }

  Widget _serverCard(
    BuildContext context,
    AppLocalizations l10n,
    MusicServer server,
    List<SourceHealth> healths,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final info = healths.where((item) => item.serverId == server.id);
    final health = info.isEmpty ? null : info.first;
    final pending = scrobbleQueue.events.value
        .where((event) => event.serverId == server.id)
        .length;
    final ok = health?.ok ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ServerStatusPage(server: server)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: textColor.withAlpha(12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (ok ? Colors.green : textColor).withAlpha(28),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ok ? Icons.check_rounded : Icons.cloud_off_rounded,
                  size: 20,
                  color: ok ? Colors.green.shade600 : textColor.withAlpha(150),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        server.type.name,
                        ok ? l10n.sourceHealthy : l10n.sourceUnreachable,
                        if (health?.latencyMs != null) '${health!.latencyMs} ms',
                        if (pending > 0)
                          '${l10n.sourcePendingReports}: $pending',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withAlpha(140),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _testAll() async {
    setState(() => _loading = true);
    await sourceHealth.sampleAll();
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}
