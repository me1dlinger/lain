import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/comment_server.dart';
import 'package:lain/base/data/comment_setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/comment_client.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/settings_page_route.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/layer/layers_manager.dart';

/// The configured comment servers, one row each.
///
/// Same shape as the music source list: a back arrow, a centred title and an
/// add button, then a list whose rows switch the server on tap and open a menu
/// of retest / edit / delete on a long press.
class CommentServersPage extends StatefulWidget {
  const CommentServersPage({super.key});

  @override
  State<CommentServersPage> createState() => _CommentServersPageState();
}

class _CommentServersPageState extends State<CommentServersPage> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    // The panel colour is translucent by design; on a pushed page that would
    // show the navigator underneath, so an opaque colour is used here.
    return ListenableBuilder(
      listenable: Listenable.merge([
        layersManager.backgroundChangeNotifier,
        panelColor.valueNotifier,
        pageBackgroundColor.valueNotifier,
        commentActiveServerIdNotifier,
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
                          l10n.commentServers,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.addCommentServer,
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
                      for (final server in commentServers)
                        _serverRow(l10n, server, textColor),
                      if (commentServers.isEmpty)
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

  Widget _serverRow(
    AppLocalizations l10n,
    CommentServer server,
    Color textColor,
  ) {
    final active = server.id == activeCommentServer?.id;
    final address = server.currentUrl;
    final usingLan = server.hasLan && server.isLan(address);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.forum_rounded, size: 28, color: textColor),
      title: Text(
        server.name.isEmpty ? server.currentUrl : server.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: textColor),
      ),
      subtitle: Text(
        [
          server.scheme.toUpperCase(),
          if (address.isNotEmpty)
            '${usingLan ? l10n.lanAddress : l10n.publicAddress}: $address'
          else
            l10n.unreachable,
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

  Future<void> _menu(CommentServer server) async {
    final l10n = AppLocalizations.of(context);
    // Wait for the menu to close before navigating; pushing while its route is
    // still popping left the menu on top of the edit page.
    // The dialog lives on the root navigator while this page sits on the
    // settings navigator: pop it through its own context, or the pop lands on
    // the settings navigator underneath and closes this page instead.
    final action = await showAnimationDialog<String>(
      context: context,
      child: Builder(
        builder: (dialogContext) => SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.recheck),
                onTap: () => Navigator.pop(dialogContext, 'recheck'),
              ),
              ListTile(
                title: Text(l10n.edit),
                onTap: () => Navigator.pop(dialogContext, 'edit'),
              ),
              ListTile(
                title: Text(l10n.delete),
                onTap: () => Navigator.pop(dialogContext, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    switch (action) {
      case 'recheck':
        await _activate(server);
      case 'edit':
        await _edit(server);
      case 'delete':
        await _delete(server);
      default:
        break;
    }
  }

  Future<void> _edit(CommentServer? server) async {
    final saved = await pushSettingsPage<bool>(
      context,
      settingsPageRoute<bool>(() => CommentServerEditPage(server: server)),
    );
    if (saved == true && mounted) {
      setState(() {});
    }
  }

  /// Probes the addresses and keeps the server as the active one when either
  /// answers. A server that does not answer is not selected: the comment page
  /// would only fail on every song.
  Future<void> _activate(CommentServer server) async {
    final l10n = AppLocalizations.of(context);
    setState(() => busy = true);
    final url = await CommentClient(server).probe();
    if (!mounted) {
      return;
    }
    setState(() => busy = false);

    if (url == null) {
      showCenterMessage(
        '${server.name}\n${l10n.connectionFailed}\n'
        '${server.addresses.join('\n')}',
        duration: 5000,
      );
      return;
    }
    await upsertCommentServer(server);
    if (!mounted) {
      return;
    }
    setState(() {});
    showCenterMessage(
      '${server.name}\n${l10n.connectSuccess} · '
      '${server.isLan(url) ? l10n.lanAddress : l10n.publicAddress}',
      duration: 3000,
    );
  }

  Future<void> _delete(CommentServer server) async {
    final l10n = AppLocalizations.of(context);
    if (!await showConfirmDialog(context, l10n.delete)) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => busy = true);
    await deleteCommentServer(server.id);
    if (mounted) {
      setState(() => busy = false);
    }
  }
}

/// Add or edit one comment server.
///
/// The layout follows the music server form: a name, the protocol, the LAN and
/// public address each in its own card, then the optional credentials. Saving
/// probes the addresses first and only stores a server that answered.
class CommentServerEditPage extends StatefulWidget {
  final CommentServer? server;

  const CommentServerEditPage({super.key, this.server});

  @override
  State<CommentServerEditPage> createState() => _CommentServerEditPageState();
}

class _CommentServerEditPageState extends State<CommentServerEditPage> {
  late final TextEditingController nameTmp = TextEditingController(
    text: widget.server?.name ?? '',
  );
  late final TextEditingController lanHostTmp = TextEditingController(
    text: widget.server?.lanHost ?? '',
  );
  late final TextEditingController lanPortTmp = TextEditingController(
    text: widget.server?.lanPort ?? '',
  );
  late final TextEditingController publicHostTmp = TextEditingController(
    text: widget.server?.publicHost ?? '',
  );
  late final TextEditingController publicPortTmp = TextEditingController(
    text: widget.server?.publicPort ?? '',
  );
  late final TextEditingController usernameTmp = TextEditingController(
    text: widget.server?.username ?? '',
  );
  late final TextEditingController passwordTmp = TextEditingController(
    text: widget.server?.password ?? '',
  );

  late String scheme = widget.server?.scheme ?? 'http';

  final lanIgnoreCert = ValueNotifier<bool>(false);
  final publicIgnoreCert = ValueNotifier<bool>(false);

  bool saving = false;
  bool obscure = true;

  @override
  void initState() {
    super.initState();
    lanIgnoreCert.value = widget.server?.ignoreLanCert ?? false;
    publicIgnoreCert.value = widget.server?.ignorePublicCert ?? false;
  }

  @override
  void dispose() {
    nameTmp.dispose();
    lanHostTmp.dispose();
    lanPortTmp.dispose();
    publicHostTmp.dispose();
    publicPortTmp.dispose();
    usernameTmp.dispose();
    passwordTmp.dispose();
    lanIgnoreCert.dispose();
    publicIgnoreCert.dispose();
    super.dispose();
  }

  // A plain http address has no certificate to skip.
  bool get isSecure => scheme == 'https';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

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
                      widget.server == null ? l10n.addCommentServer : l10n.edit,
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
                  AppleFormSection(
                    title: l10n.commentServer,
                    children: [
                      appleTextFieldRow(
                        l10n.commentServerName,
                        nameTmp,
                        placeholder: 'Comment API',
                      ),
                      appleSegmented<String>(
                        const ['http', 'https'],
                        (value) => value,
                        scheme,
                        (value) => setState(() => scheme = value),
                      ),
                    ],
                  ),
                  _addressSection(
                    l10n.lanAddress,
                    lanHostTmp,
                    lanPortTmp,
                    lanIgnoreCert,
                  ),
                  _addressSection(
                    l10n.publicAddress,
                    publicHostTmp,
                    publicPortTmp,
                    publicIgnoreCert,
                  ),
                  AppleFormSection(
                    title: l10n.commentTokenHint,
                    children: [
                      appleTextFieldRow(l10n.username, usernameTmp),
                      appleFormRow(
                        l10n.password,
                        Row(
                          children: [
                            Expanded(
                              child: appleTextField(
                                passwordTmp,
                                obscure: obscure,
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: textColor,
                              ),
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: appleFilledButton(
                      l10n.testAndSave,
                      saving ? null : _save,
                      busy: saving,
                    ),
                  ),
                  if (widget.server != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: appleTextButton(
                        l10n.delete,
                        saving ? null : _delete,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One address: host and port, plus the certificate switch when the address
  /// is reached over https. Both addresses may be left empty, but not both.
  Widget _addressSection(
    String title,
    TextEditingController hostTmp,
    TextEditingController portTmp,
    ValueNotifier<bool> ignoreCert,
  ) {
    final l10n = AppLocalizations.of(context);

    return AppleFormSection(
      title: title,
      children: [
        appleTextFieldRow(l10n.serverHost, hostTmp, placeholder: '192.168.1.2'),
        appleTextFieldRow(l10n.serverPort, portTmp, number: true),
        if (isSecure) appleSwitchRow(l10n.ignoreCert, ignoreCert),
      ],
    );
  }

  /// The server as the fields describe it, without its id.
  CommentServer _serverFromFields() {
    final l10n = AppLocalizations.of(context);
    final server =
        widget.server ?? CommentServer(id: CommentServer.newId(), name: '');
    server.name = nameTmp.text.trim().isEmpty
        ? l10n.commentServer
        : nameTmp.text.trim();
    server.scheme = scheme;
    server.lanHost = lanHostTmp.text.trim();
    server.lanPort = lanPortTmp.text.trim();
    server.publicHost = publicHostTmp.text.trim();
    server.publicPort = publicPortTmp.text.trim();
    server.username = usernameTmp.text.trim();
    server.password = passwordTmp.text;
    server.ignoreLanCert = lanIgnoreCert.value;
    server.ignorePublicCert = publicIgnoreCert.value;
    return server;
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    if (!await showConfirmDialog(context, l10n.delete)) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => saving = true);
    await deleteCommentServer(widget.server!.id);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final server = _serverFromFields();

    if (!server.isUsable) {
      showCenterMessage(l10n.commentAtLeastOneAddress);
      return;
    }

    setState(() => saving = true);
    final url = await CommentClient(server).probe();
    if (!mounted) {
      return;
    }
    setState(() => saving = false);

    if (url == null) {
      showCenterMessage(
        '${server.name}\n${l10n.connectionFailed}\n'
        '${server.addresses.join('\n')}',
        duration: 5000,
      );
      return;
    }
    await upsertCommentServer(server);
    if (!mounted) {
      return;
    }
    showCenterMessage(
      '${server.name}\n${l10n.connectSuccess} · '
      '${server.isLan(url) ? l10n.lanAddress : l10n.publicAddress}',
      duration: 3000,
    );
    Navigator.pop(context, true);
  }
}
