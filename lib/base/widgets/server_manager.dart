import 'package:flutter/cupertino.dart';
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        layersManager.backgroundChangeNotifier,
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
      // Say which addresses were tried, so a failure is actionable.
      showCenterMessage(
        '${server.name}\n${l10n.connectionFailed}\n${server.addresses.join('\n')}',
        duration: 5000,
      );
      if (mounted) {
        setState(() {});
      }
      return;
    }
    await _reloadLibrary();
    showCenterMessage(
      '${server.name}\n${l10n.connectSuccess} · '
      '${server.usingLan ? l10n.lanAddress : l10n.publicAddress}',
      duration: 3000,
    );
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
/// Add or edit a server, as an iOS-style grouped form.
///
/// The field set follows the kind: Navidrome, Emby and WebDAV are addressed by
/// scheme + host + port (WebDAV also by a path), while Feiniu is addressed by its
/// device id - or a plain address - and therefore gets a single field.
class ServerEditPage extends StatefulWidget {
  final MusicServer? server;

  const ServerEditPage({super.key, this.server});

  @override
  State<ServerEditPage> createState() => _ServerEditPageState();
}

class _ServerEditPageState extends State<ServerEditPage> {
  late SourceType type = widget.server?.type ?? .navidrome;
  late final TextEditingController nameTmp = TextEditingController(
    text: widget.server?.name ?? '',
  );
  late final TextEditingController usernameTmp = TextEditingController(
    text: widget.server?.username ?? '',
  );
  late final TextEditingController passwordTmp = TextEditingController(
    text: widget.server?.password ?? '',
  );
  late final _AddressEditor publicEditor = _AddressEditor(
    initial: widget.server?.publicUrl ?? '',
    type: type,
  );
  late final _AddressEditor lanEditor = _AddressEditor(
    initial: widget.server?.lanUrl ?? '',
    type: type,
  );

  bool saving = false;
  bool obscure = true;

  @override
  void dispose() {
    nameTmp.dispose();
    usernameTmp.dispose();
    passwordTmp.dispose();
    publicEditor.dispose();
    lanEditor.dispose();
    super.dispose();
  }

  bool get isFeiniu => type == .feiniu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    return Scaffold(
      backgroundColor: colorManager.getSpecificOpaqueBgColor(),
      body: SafeArea(
        // Cupertino follows the platform brightness by default; this app has its
        // own light/dark setting, so hand it over, and use the app's text colour
        // as the tint so the filled button stays monochrome.
        child: CupertinoTheme(
          data: CupertinoThemeData(
            brightness: mainPageThemeNotifier.value == .dark
                ? Brightness.dark
                : Brightness.light,
            primaryColor: textColor,
          ),
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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 30),
                  children: [
                    CupertinoFormSection.insetGrouped(
                      header: Text(l10n.serverType),
                      children: [
                        CupertinoFormRow(
                          child: CupertinoSlidingSegmentedControl<SourceType>(
                            groupValue: type,
                            children: {
                              for (final value in SourceType.values)
                                if (value != .local)
                                  value: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      getSourceTypeDisplayName(l10n, value),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                            },
                            onValueChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                type = value;
                                publicEditor.type = value;
                                lanEditor.type = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    CupertinoFormSection.insetGrouped(
                      header: Text(l10n.servers),
                      children: [
                        _textRow(
                          l10n.serverName,
                          nameTmp,
                          placeholder: getSourceTypeDisplayName(l10n, type),
                        ),
                        _textRow(l10n.username, usernameTmp),
                        _passwordRow(l10n),
                      ],
                    ),
                    _addressSection(l10n.publicAddress, publicEditor),
                    _addressSection(l10n.lanAddress, lanEditor),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: CupertinoButton.filled(
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onPressed: saving ? null : _save,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (saving)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: CupertinoActivityIndicator(radius: 8),
                              ),
                            Text(l10n.testAndSave),
                          ],
                        ),
                      ),
                    ),
                    if (widget.server != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: CupertinoButton(
                          onPressed: saving ? null : _delete,
                          child: Text(
                            l10n.delete,
                            style: const TextStyle(
                              color: CupertinoColors.destructiveRed,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textRow(
    String label,
    TextEditingController controller, {
    String? placeholder,
    bool number = false,
  }) {
    return CupertinoFormRow(
      prefix: Text(label, style: const TextStyle(fontSize: 15)),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        keyboardType: number ? TextInputType.number : null,
        textAlign: TextAlign.right,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _passwordRow(AppLocalizations l10n) {
    return CupertinoFormRow(
      prefix: Text(l10n.password, style: const TextStyle(fontSize: 15)),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: passwordTmp,
              obscureText: obscure,
              textAlign: TextAlign.right,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(),
              style: const TextStyle(fontSize: 15),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
            ),
            onPressed: () => setState(() => obscure = !obscure),
          ),
        ],
      ),
    );
  }

  Widget _addressSection(String header, _AddressEditor editor) {
    final l10n = AppLocalizations.of(context);

    if (isFeiniu) {
      // Feiniu takes the device id (the client turns a bare id into
      // https://<id>.fnos.net) or a full address.
      return CupertinoFormSection.insetGrouped(
        header: Text(header),
        children: [
          CupertinoFormRow(
            prefix: const Text('FN ID', style: TextStyle(fontSize: 15)),
            child: CupertinoTextField(
              controller: editor.hostTmp,
              placeholder: 'xxxxxxxx',
              textAlign: TextAlign.right,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      );
    }

    return CupertinoFormSection.insetGrouped(
      header: Text(header),
      children: [
        CupertinoFormRow(
          prefix: Text(l10n.serverScheme, style: const TextStyle(fontSize: 15)),
          child: CupertinoSlidingSegmentedControl<String>(
            groupValue: editor.scheme,
            children: const {
              'https': Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('https', style: TextStyle(fontSize: 12)),
              ),
              'http': Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('http', style: TextStyle(fontSize: 12)),
              ),
            },
            onValueChanged: (value) {
              if (value != null) {
                setState(() => editor.scheme = value);
              }
            },
          ),
        ),
        _textRow(l10n.serverHost, editor.hostTmp),
        _textRow(l10n.serverPort, editor.portTmp, number: true),
        if (type == .webdav) _textRow(l10n.serverPath, editor.pathTmp),
      ],
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    if (!await showConfirmDialog(context, l10n.delete)) {
      return;
    }
    setState(() => saving = true);
    await config.deleteServer(widget.server!);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final server =
        widget.server ??
        MusicServer(id: MusicServer.newId(), type: type, name: '');
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
    // activateServer probes both addresses (LAN first) and only keeps the one
    // that answered; it persists the server as well.
    final reachable = await config.activateServer(server);
    setState(() => saving = false);

    if (!reachable) {
      showCenterMessage(
        '${server.name}\n${l10n.connectionFailed}\n${server.addresses.join('\n')}',
        duration: 5000,
      );
      return;
    }
    showCenterMessage(
      '${server.name}\n${l10n.connectSuccess} · '
      '${server.usingLan ? l10n.lanAddress : l10n.publicAddress}',
      duration: 3000,
    );
    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}

/// One address, edited as scheme + host + port (plus a path for WebDAV) or, for
/// Feiniu, as whatever the user typed - the client normalises a bare id itself.
class _AddressEditor {
  String scheme = 'https';
  final TextEditingController hostTmp = TextEditingController();
  final TextEditingController portTmp = TextEditingController();
  final TextEditingController pathTmp = TextEditingController();
  SourceType type;

  _AddressEditor({required String initial, required this.type}) {
    if (initial.isNotEmpty) {
      load(initial);
    }
  }

  void dispose() {
    hostTmp.dispose();
    portTmp.dispose();
    pathTmp.dispose();
  }

  void load(String url) {
    if (type == .feiniu) {
      hostTmp.text = url.trim();
      return;
    }

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
    if (type == .feiniu) {
      return host;
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
}
