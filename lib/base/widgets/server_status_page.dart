import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/data/music_server.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/navidrome_client.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// Server status of a Navidrome source: whether it answers and how fast, what
/// it runs, and what its library holds.
///
/// The active server is asked through the live client - the one the app plays
/// from - so its failover state is the truth; another server gets a temporary
/// client built from its recorded addresses and credentials.
class ServerStatusPage extends StatefulWidget {
  final MusicServer server;

  const ServerStatusPage({super.key, required this.server});

  @override
  State<ServerStatusPage> createState() => _ServerStatusPageState();
}

class _ServerStatusPageState extends State<ServerStatusPage> {
  NavidromeClient? _ownClient;
  NavidromeLibraryStats? _stats;
  bool _loading = true;
  bool _reachable = false;

  NavidromeClient get _client {
    final active = widget.server.id == config.activeServerId;
    if (active && streamClient is NavidromeClient) {
      return streamClient as NavidromeClient;
    }
    if (_ownClient != null) {
      return _ownClient!;
    }
    final client = NavidromeClient(
      baseUrl: widget.server.currentUrl,
      username: widget.server.username,
      password: widget.server.password,
    );
    final other = widget.server.addresses
        .firstWhere((url) => url != client.baseUrl, orElse: () => '');
    if (other.isNotEmpty) {
      client.alternativeBaseUrl = other;
    }
    return _ownClient = client;
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final stats = await _client.libraryStats(forceRefresh: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _stats = stats;
      _reachable = stats != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    // The panel colour is translucent by design; on a pushed page composite
    // it into an opaque one, as the other pushed pages do.
    return ListenableBuilder(
      listenable: Listenable.merge([
        panelColor.valueNotifier,
        pageBackgroundColor.valueNotifier,
      ]),
      builder: (context, child) {
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
                          widget.server.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.refresh,
                        icon: Icon(Icons.refresh_rounded, color: textColor),
                        onPressed: _loading ? null : _fetch,
                      ),
                    ],
                  ),
                ),
                Expanded(child: _body(l10n, textColor)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(AppLocalizations l10n, Color textColor) {
    if (_stats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_loading)
              const CircularProgressIndicator()
            else ...[
              Text(
                l10n.unreachable,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor.withAlpha(160),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.server.addresses.join('\n'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withAlpha(120),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final stats = _stats!;
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 30),
      children: [
        AppleFormSection(
          title: l10n.serverStatus,
          children: [
            _row(
              l10n.status,
              _reachable ? l10n.normal : l10n.unreachable,
              color: _reachable ? Colors.green : Colors.red,
            ),
            _row(l10n.latencyMs(stats.latency.inMilliseconds), ''),
            _row(l10n.serverAddress, _client.baseUrl),
          ],
        ),
        AppleFormSection(
          title: l10n.serverInfo,
          children: [
            _row(l10n.serverType, stats.serverType ?? 'navidrome'),
            _row(l10n.serverVersion, stats.serverVersion ?? '—'),
            _row(l10n.subsonicApiVersion, stats.subsonicVersion ?? '—'),
            _row(
              l10n.openSubsonic,
              stats.openSubsonic ? l10n.supported : l10n.notSupported,
            ),
          ],
        ),
        AppleFormSection(
          title: l10n.mediaStats,
          children: [
            _row(l10n.statsSongs, _groupNumber(stats.songCount)),
            _row(l10n.artists, _groupNumber(stats.artistCount)),
            _row(l10n.albums, _groupNumber(stats.albumCount)),
            _row(l10n.folders, _groupNumber(stats.folderCount)),
            _row(
              l10n.totalSize,
              stats.totalSize == null
                  ? '—'
                  : formatLibrarySize(stats.totalSize!),
            ),
            _row(
              l10n.totalDuration,
              stats.totalDuration == null
                  ? '—'
                  : l10n.libraryDurationHours(
                      formatLibraryDuration(
                        stats.totalDuration!,
                        inDays: _inDays,
                      ),
                      _inDays ? l10n.daysUnit : l10n.hoursUnit,
                    ),
            ),
            _row(
              l10n.scanStatus,
              stats.scanning == true ? l10n.scanning : l10n.scanCompleted,
            ),
            _row(l10n.lastScanTime, _formatDateTime(stats.lastScan)),
          ],
        ),
      ],
    );
  }

  /// One label/value line; the value sits on the right, like the other form
  /// values of the app.
  Widget _row(String label, String value, {Color? color}) {
    final textColor = color ?? colorManager.getSpecificTextColor();
    return appleFormRow(
      label,
      Text(
        value,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 15,
          color: color ?? textColor.withAlpha(200),
        ),
      ),
    );
  }

  String _groupNumber(int? value) => value?.toString() ?? '—';

  /// Whole days once the library passes 100 hours, like the home card.
  bool get _inDays =>
      _stats?.totalDuration != null && _stats!.totalDuration! >= 100 * 3600;

  /// Local time of the server's last scan; an unknown one shows a dash.
  String _formatDateTime(DateTime? time) {
    if (time == null) {
      return '—';
    }
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
