import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/config.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/data/music_server.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/base/widgets/custom_text_field.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';

/// Server management: which library the app plays from, with one entry per
/// configured server and a public / LAN address pair on each of them.
class ServerListPage extends StatefulWidget {
  const ServerListPage({super.key});

  @override
  State<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends State<ServerListPage> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    // The panel colour is translucent by design (it sits over the app's
    // cover-art background); on a pushed page that would show the dark
    // navigator underneath, so composite it into an opaque colour instead.
    return ValueListenableBuilder(
      valueListenable: Listenable.merge([
        layersManager.backgroundChangeNotifier,
        panelColor.valueNotifier,
        pageBackgroundColor.valueNotifier,
      ]),
      builder: (context, _, child) {
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
                          l10n.servers,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.addServer,
                        icon: Icon(Icons.add_rounded, color: textColor),
                        onPressed: busy ? null : () => _edit(null),
                      ),
                    ],
                  ),
                ),
                if (busy) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      // A local library is not a server, but it is the other
                      // kind of source the app can play from.
                      _localRow(l10n, textColor),
                      const Divider(height: 20),
                      for (final server in config.servers)
                        _serverRow(l10n, server, textColor),
                      if (config.servers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              l10n.noData,
                              style: TextStyle(color: textColor.withAlpha(150)),
                            ),
                          ),
                        ),
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

  Widget _localRow(AppLocalizations l10n, Color textColor) {
    final selected = sourceType == .local;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Image(
        image: getSourceTypeImage(.local),
        width: 30,
        height: 30,
      ),
      title: Text(l10n.localMusic, style: TextStyle(color: textColor)),
      trailing: selected ? Icon(Icons.check, color: textColor) : null,
      onTap: busy
          ? null
          : () async {
              if (selected) {
                return;
              }
              setState(() => busy = true);
              await config.activateLocal();
              await _reloadLibrary();
              if (mounted) {
                setState(() => busy = false);
              }
            },
    );
  }

  Widget _serverRow(
    AppLocalizations l10n,
    MusicServer server,
    Color textColor,
  ) {
    final active = server.id == config.activeServerId;
    final address = server.currentUrl;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Image(
        image: getSourceTypeImage(server.type),
        width: 30,
        height: 30,
      ),
      title: Text(server.name, style: TextStyle(color: textColor)),
      subtitle: Text(
        [
          getSourceTypeDisplayName(l10n, server.type),
          if (active && address.isNotEmpty)
            '${server.usingLan ? l10n.lanAddress : l10n.publicAddress}: $address'
          else if (address.isNotEmpty)
            address,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
      ),
      trailing: active
          ? Text(
              l10n.inUse,
              style: TextStyle(fontSize: 12, color: textColor.withAlpha(180)),
            )
          : null,
      onTap: busy ? null : () => _activate(server),
      onLongPress: busy ? null : () => _menu(server),
    );
  }

  Future<void> _menu(MusicServer server) async {
    final l10n = AppLocalizations.of(context);
    showAnimationDialog(
      context: context,
      child: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.recheck),
              onTap: () {
                Navigator.pop(context);
                _activate(server);
              },
            ),
            ListTile(
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _edit(server);
              },
            ),
            ListTile(
              title: Text(l10n.delete),
              onTap: () async {
                Navigator.pop(context);
                await _delete(server);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(MusicServer? server) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => ServerEditPage(server: server)),
    );
    if (saved == true && mounted) {
      setState(() {});
    }
  }

  /// Probes the addresses, switches when one answers, and rebuilds the library.
  Future<void> _activate(MusicServer server) async {
    final l10n = AppLocalizations.of(context);
    setState(() => busy = true);
    final ok = await config.activateServer(server);
    setState(() => busy = false);

    if (!ok) {
      if (mounted) {
        showCenterMessage('${server.name}: ${l10n.unreachable}');
        setState(() {});
      }
      return;
    }
    await _reloadLibrary();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _delete(MusicServer server) async {
    final l10n = AppLocalizations.of(context);
    if (!await showConfirmDialog(context, l10n.delete)) {
      return;
    }
    setState(() => busy = true);
    final wasActive = server.id == config.activeServerId;
    await config.deleteServer(server);
    if (wasActive) {
      await _reloadLibrary();
    }
    if (mounted) {
      setState(() => busy = false);
    }
  }

  Future<void> _reloadLibrary() async {
    layersManager.clearDataLayers();
    audioHandler.clear();
    await Loader.sync();
  }
}

/// Add or edit one server: kind, name, the public and LAN addresses, and the
/// credentials. Saving probes both addresses and only keeps the reachable one.
class ServerEditPage extends StatefulWidget {
  final MusicServer? server;

  const ServerEditPage({super.key, this.server});

  @override
  State<ServerEditPage> createState() => _ServerEditPageState();
}

class _ServerEditPageState extends State<ServerEditPage> {
  late SourceType type = widget.server?.type ?? .navidrome;
  late final nameTmp = TextEditingController(
    text: widget.server?.name ?? '',
  );
  late final usernameTmp = TextEditingController(
    text: widget.server?.username ?? '',
  );
  late final passwordTmp = TextEditingController(
    text: widget.server?.password ?? '',
  );

  late final publicEditor = _AddressEditor(
    initial: widget.server?.publicUrl ?? '',
  );
  late final lanEditor = _AddressEditor(initial: widget.server?.lanUrl ?? '');

  bool saving = false;

  @override
  void dispose() {
    nameTmp.dispose();
    usernameTmp.dispose();
    passwordTmp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    // The panel colour is translucent by design (it sits over the app's
    // cover-art background); on a pushed page that would show the dark
    // navigator underneath, so composite it into an opaque colour instead.
    return ValueListenableBuilder(
      valueListenable: Listenable.merge([
        layersManager.backgroundChangeNotifier,
        panelColor.valueNotifier,
        pageBackgroundColor.valueNotifier,
      ]),
      builder: (context, _, child) {
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
                          widget.server == null ? l10n.addServer : l10n.edit,
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
                if (saving) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    children: [
                      CustomDropdownField<SourceType>(
                        l10n.serverType,
                        type,
                        [
                          for (final value in SourceType.values)
                            if (value != .local) value,
                        ],
                        (value) => getSourceTypeDisplayName(l10n, value),
                        (value) => setState(() {
                          type = value;
                          publicEditor.type = value;
                          lanEditor.type = value;
                        }),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(l10n.serverName, nameTmp, compact: false),
                      const SizedBox(height: 16),
                      _addressSection(l10n.publicAddress, publicEditor, textColor),
                      const SizedBox(height: 16),
                      _addressSection(l10n.lanAddress, lanEditor, textColor),
                      const SizedBox(height: 16),
                      CustomTextField(
                        l10n.username,
                        usernameTmp,
                        compact: false,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        l10n.password,
                        passwordTmp,
                        needObscure: true,
                        compact: false,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (widget.server != null)
                            TextButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (!await showConfirmDialog(
                                        context,
                                        l10n.delete,
                                      )) {
                                        return;
                                      }
                                      setState(() => saving = true);
                                      await config.deleteServer(widget.server!);
                                      if (context.mounted) {
                                        Navigator.pop(context, true);
                                      }
                                    },
                              child: Text(l10n.delete),
                            ),
                          const Spacer(),
                          FilledButton(
                            onPressed: saving ? null : _save,
                            child: Text(l10n.testAndSave),
                          ),
                        ],
                      ),
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

  Widget _addressSection(String title, _AddressEditor editor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 6),
        editor.build(context),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final server =
        widget.server ??
        MusicServer(
          id: MusicServer.newId(),
          type: type,
          name: '',
        );
    server.type = type;
    server.name = nameTmp.text.trim().isEmpty
        ? getSourceTypeDisplayName(l10n, type)
        : nameTmp.text.trim();
    server.publicUrl = publicEditor.url;
    server.lanUrl = lanEditor.url;
    server.username = usernameTmp.text.trim();
    server.password = passwordTmp.text;

    if (!server.isUsable) {
      showCenterMessage(l10n.unreachable);
      return;
    }

    setState(() => saving = true);
    // activateServer probes both addresses (LAN first) and remembers the one
    // that answered; it also persists the server.
    final reachable = await config.activateServer(server);
    setState(() => saving = false);

    if (!reachable) {
      showCenterMessage('${server.name}: ${l10n.unreachable}');
      return;
    }
    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}

/// Scheme + host + port (and a path for WebDAV) as one compact row.
class _AddressEditor {
  String scheme = 'https';
  final hostTmp = TextEditingController();
  final portTmp = TextEditingController();
  final pathTmp = TextEditingController();
  SourceType type = .navidrome;

  _AddressEditor({required String initial}) {
    if (initial.isNotEmpty) {
      load(initial);
    }
  }

  void load(String url) {
    var text = url.trim();
    if (!text.contains('://')) {
      text = 'https://$text';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      hostTmp.text = url.trim();
      return;
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      scheme = uri.scheme;
    }
    hostTmp.text = uri.host;
    if (uri.hasPort) {
      portTmp.text = '${uri.port}';
    }
    final path = uri.path.replaceFirst(RegExp(r'^/+'), '');
    if (path.isNotEmpty) {
      pathTmp.text = path;
    }
  }

  String get url {
    final host = hostTmp.text.trim();
    if (host.isEmpty) {
      return '';
    }
    final buffer = StringBuffer('$scheme://$host');
    final port = portTmp.text.trim();
    if (port.isNotEmpty) {
      buffer.write(':$port');
    }
    if (type == .webdav) {
      final path = pathTmp.text.trim().replaceFirst(RegExp(r'^/+'), '');
      if (path.isNotEmpty) {
        buffer.write('/$path');
      }
    }
    return buffer.toString();
  }

  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: CustomDropdownField<String>(
                null,
                scheme,
                const ['https', 'http'],
                (item) => item,
                (picked) => scheme = picked,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CustomTextField('Host', hostTmp, compact: false),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 76,
              child: CustomTextField(
                'Port',
                portTmp,
                compact: false,
                onlyNumber: true,
              ),
            ),
          ],
        ),
        if (type == .webdav) ...[
          const SizedBox(height: 8),
          CustomTextField('Path', pathTmp, compact: false),
        ],
      ],
    );
  }
}