import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/data/music_server.dart';
import 'package:lain/base/data/server_stats.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/emby_client.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/navidrome_client.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/my_divider.dart';
import 'package:lain/base/widgets/my_switch.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// Server status of a stream source (Navidrome or Emby): whether it answers
/// and how fast, what it runs, and what its library holds.
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
  StreamClient? _ownClient;
  ServerLibraryStats? _stats;
  bool _loading = true;
  bool _reachable = false;
  bool _scanRequested = false;

  /// The address is hidden by default: it can carry a private domain, and the
  /// page is often looked at over someone's shoulder.
  bool _maskAddress = true;

  static const _green = Color(0xFF34C759);
  static const _red = Color(0xFFFF3B30);
  static const _blue = Color(0xFF007AFF);

  StreamClient get _client {
    final active = widget.server.id == config.activeServerId;
    final live = streamClient;
    if (active &&
        ((widget.server.type == .emby && live is EmbyClient) ||
            (widget.server.type == .navidrome && live is NavidromeClient))) {
      return live!;
    }
    if (_ownClient != null) {
      return _ownClient!;
    }
    final StreamClient client = widget.server.type == .emby
        ? EmbyClient(
            baseUrl: widget.server.currentUrl,
            username: widget.server.username,
            password: widget.server.password,
          )
        : NavidromeClient(
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
                _header(l10n, textColor),
                Expanded(child: _body(l10n, textColor)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The navigation bar, drawn rather than an AppBar: a circular back button,
  /// the server's name with its type under it, and a circular refresh button.
  Widget _header(AppLocalizations l10n, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          _circleButton(
            textColor,
            Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.server.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _serverTypeLabel(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withAlpha(140),
                  ),
                ),
              ],
            ),
          ),
          _circleButton(
            textColor,
            Icons.refresh_rounded,
            tooltip: l10n.refresh,
            // A refresh while one is running would only race the answer that
            // is already on its way.
            onTap: _loading ? null : _fetch,
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
    Color textColor,
    IconData icon, {
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final button = SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: textColor.withAlpha(16),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? textColor.withAlpha(90) : textColor,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
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
          divided: false,
          children: [
            _statusHeader(l10n, textColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MyDivider(
                thickness: 0.5,
                height: 1,
                color: dividerColor,
              ),
            ),
            _linkRow(l10n, textColor, stats),
            _speedRow(l10n, textColor),
          ],
        ),
        appleSectionTitle(l10n.serverInfo),
        AppleFormSection(
          divided: false,
          children: [
            _infoRow(
              l10n.serverType,
              stats.serverType ?? widget.server.type.name,
              textColor,
            ),
            if (stats.serverName != null)
              _infoRow(l10n.serverName, stats.serverName!, textColor),
            _infoRow(
              l10n.serverVersion,
              stats.serverVersion ?? '—',
              textColor,
            ),
            if (stats.sourceType == 'emby') ...[
              if (stats.operatingSystem != null)
                _infoRow(l10n.serverOs, stats.operatingSystem!, textColor),
              if (stats.hasUpdate != null)
                _infoRow(
                  l10n.systemUpdate,
                  stats.hasUpdate! ? l10n.updateAvailable : l10n.upToDate,
                  textColor,
                ),
            ] else ...[
              _infoRow(
                l10n.subsonicApiVersion,
                stats.subsonicVersion ?? '—',
                textColor,
              ),
              _infoRow(
                l10n.openSubsonic,
                stats.openSubsonic ? l10n.supported : l10n.notSupported,
                textColor,
              ),
            ],
          ],
        ),
        appleSectionTitle(l10n.mediaStats),
        AppleFormSection(
          divided: false,
          children: [
            _infoRow(l10n.statsSongs, _groupNumber(stats.songCount), textColor),
            _infoRow(l10n.artists, _groupNumber(stats.artistCount), textColor),
            _infoRow(l10n.albums, _groupNumber(stats.albumCount), textColor),
            _infoRow(l10n.folders, _groupNumber(stats.folderCount), textColor),
            _infoRow(
              l10n.totalSize,
              stats.totalSize == null
                  ? '—'
                  : formatLibrarySize(stats.totalSize!),
              textColor,
            ),
            _infoRow(
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
              textColor,
            ),
            if (stats.activeStreams != null)
              _infoRow(
                l10n.activeStreams,
                '${stats.activeStreams}',
                textColor,
              ),
            if (stats.transcodeStreams != null)
              _infoRow(
                l10n.transcoding,
                '${stats.transcodeStreams}',
                textColor,
              ),
            _infoRow(
              l10n.scanStatus,
              stats.scanning == true ? l10n.scanning : l10n.scanCompleted,
              textColor,
            ),
            _infoRow(l10n.lastScanTime, _formatDateTime(stats.lastScan), textColor),
            if (stats.canScan) _scanNowRow(l10n, textColor, stats),
          ],
        ),
        if (stats.extensions.isNotEmpty) ...[
          appleSectionTitle(l10n.serverCapabilities),
          AppleFormSection(
            divided: false,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final capability in stats.extensions)
                      _capabilityChip(
                        _capabilityLabel(l10n, capability),
                        textColor,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _capabilityChip(String label, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withAlpha(14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withAlpha(28)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(200)),
      ),
    );
  }

  /// OpenSubsonic extension names are technical; the known ones get the same
  /// wording as the app's own features, unknown ones are split into words so
  /// a new server extension is still readable.
  String _capabilityLabel(AppLocalizations l10n, String name) {
    switch (name) {
      case 'songLyrics':
      case 'lyrics':
        return l10n.capLyrics;
      case 'sonicSimilarity':
        return l10n.capSimilarSongs;
      case 'transcodeOffset':
        return l10n.capTranscodeOffset;
      case 'formPost':
        return l10n.capFormPost;
      case 'apiKeyAuthentication':
        return l10n.capApiKey;
      case 'playbackReport':
        return l10n.capPlaybackReport;
      case 'similarArtists':
        return l10n.capSimilarArtists;
      case 'favorites':
        return l10n.capFavorites;
      case 'libraryScan':
        return l10n.capLibraryScan;
      case 'playlists':
        return l10n.capPlaylists;
      default:
        return name
            .replaceAllMapped(
              RegExp(r'(?<!^)([A-Z])'),
              (match) => ' ${match.group(1)}',
            )
            .toLowerCase();
    }
  }

  Widget _scanNowRow(
    AppLocalizations l10n,
    Color textColor,
    ServerLibraryStats stats,
  ) {
    final scanning = stats.scanning == true || _scanRequested;
    return InkWell(
      onTap: scanning ? null : _startScan,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.manage_search_rounded,
                size: 20,
                color: textColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.scanNow,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
              ),
              if (scanning)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor.withAlpha(160),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: textColor.withAlpha(120),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startScan() async {
    if (_scanRequested || _stats?.scanning == true) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (!await showConfirmDialog(context, l10n.scanNowConfirm)) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _scanRequested = true);
    final ok = await _client.startScan();
    if (!mounted) {
      return;
    }
    setState(() => _scanRequested = false);
    showCenterMessage(ok ? l10n.scanStarted : l10n.operationFailed);
    if (!ok) {
      return;
    }
    // The server reports the scan as running almost immediately; give it a
    // moment to enter that state before reading the status again.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      await _fetch();
    }
  }

  /// The card's first line: what the server is doing, a control for the address
  /// mask, and the state word on the right.
  Widget _statusHeader(AppLocalizations l10n, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Text(
            l10n.serverStatus,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: _maskAddress ? l10n.showAddress : l10n.hideAddress,
            child: GestureDetector(
              onTap: () => setState(() => _maskAddress = !_maskAddress),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _maskAddress
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: textColor.withAlpha(110),
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            _reachable ? l10n.normal : l10n.unreachable,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _reachable ? _green : _red,
            ),
          ),
        ],
      ),
    );
  }

  /// The route the app is using right now, how fast it answers, and - when the
  /// server has more than one - the handle that says the list can be reordered.
  Widget _linkRow(
    AppLocalizations l10n,
    Color textColor,
    ServerLibraryStats stats,
  ) {
    final url = _client.baseUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.serverAddress,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _maskAddress ? _maskUrl(url) : url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withAlpha(130),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.latencyValue(stats.latency.inMilliseconds),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _blue,
            ),
          ),
          if (widget.server.addresses.length > 1) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.drag_handle_rounded,
              size: 22,
              color: textColor.withAlpha(70),
            ),
          ],
        ],
      ),
    );
  }

  /// "Speed first": lets the app pick the reachable route with the lowest
  /// latency. Turning it on selects one now, so the switch has a visible
  /// effect instead of only mattering the next time a request fails.
  Widget _speedRow(AppLocalizations l10n, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.speedFirst,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.speedFirstDescription,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: textColor.withAlpha(130),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 51,
            child: MySwitch(
              valueNotifier: preferFastestAddressNotifier,
              onToggleCallBack: _onSpeedFirstToggled,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSpeedFirstToggled() async {
    setting.save();
    if (!preferFastestAddressNotifier.value) {
      return;
    }
    final moved = await config.selectFastestAddress();
    if (moved && mounted) {
      _fetch();
    }
  }

  /// One label/value line; the value sits on the right, like the other form
  /// values of the app.
  Widget _infoRow(String label, String value, Color textColor) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 15, color: textColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor.withAlpha(210),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _serverTypeLabel() {
    final name = widget.server.type.name;
    if (name.isEmpty) {
      return name;
    }
    return name[0].toUpperCase() + name.substring(1);
  }

  /// Hides the identifying part of an address while keeping enough of it to be
  /// recognisable: `https://***.102419.xyz:19327`.
  String _maskUrl(String url) {
    final schemeEnd = url.indexOf('://');
    if (schemeEnd < 0) {
      return url;
    }
    final scheme = url.substring(0, schemeEnd + 3);
    final rest = url.substring(schemeEnd + 3);
    final slash = rest.indexOf('/');
    final authority = slash < 0 ? rest : rest.substring(0, slash);
    final path = slash < 0 ? '' : rest.substring(slash);
    final at = authority.indexOf('@');
    final userinfo = at < 0 ? '' : authority.substring(0, at + 1);
    final hostPort = authority.substring(userinfo.length);
    final colon = hostPort.lastIndexOf(':');
    final host = colon < 0 ? hostPort : hostPort.substring(0, colon);
    final port = colon < 0 ? '' : hostPort.substring(colon);
    final parts = host.split('.');
    final masked = parts.length > 1
        ? '***.${parts.sublist(1).join('.')}'
        : '***';
    return '$scheme$userinfo$masked$port$path';
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
