import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/config.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/feiniu_client.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/base/widgets/custom_text_field.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

class ConnectClientWidget extends StatefulWidget {
  final SourceType sourceType;

  const ConnectClientWidget({super.key, required this.sourceType});

  @override
  State<StatefulWidget> createState() => _ConnectClientWidgetState();
}

class _ConnectClientWidgetState extends State<ConnectClientWidget> {
  // The address is edited as scheme + host + port (+ path for WebDAV) instead
  // of one opaque URL string.
  final hostTmp = TextEditingController();
  final portTmp = TextEditingController();
  final pathTmp = TextEditingController();
  final usernameTmp = TextEditingController();
  final passwordTmp = TextEditingController();

  static const _schemes = ['https', 'http'];

  String scheme = 'https';

  bool get editsHost => widget.sourceType != .feiniu;

  /// Feiniu accepts a bare device id, so it keeps a single field.
  bool get editsPath => widget.sourceType == .webdav;

  @override
  void initState() {
    super.initState();
    if (widget.sourceType == .webdav) {
      loadUrl(webdavClient?.baseUrl ?? '');
      usernameTmp.text = webdavClient?.username ?? '';
      passwordTmp.text = webdavClient?.password ?? '';
    } else if (widget.sourceType == .navidrome) {
      loadUrl(config.navidromeBaseUrl ?? '');
      usernameTmp.text = config.navidromeUsername ?? '';
      passwordTmp.text = config.navidromePassword ?? '';
    } else if (widget.sourceType == .emby) {
      loadUrl(config.embyBaseUrl ?? '');
      usernameTmp.text = config.embyUsername ?? '';
      passwordTmp.text = config.embyPassword ?? '';
    } else if (widget.sourceType == .feiniu) {
      loadUrl(config.feiniuBaseUrl ?? '');
      usernameTmp.text = config.feiniuUsername ?? '';
      passwordTmp.text = config.feiniuPassword ?? '';
    }
  }

  /// The URL that is handed to the client constructors.
  String composeUrl() {
    if (widget.sourceType == .feiniu) {
      return hostTmp.text.trim();
    }
    final host = hostTmp.text.trim();
    if (host.isEmpty) {
      return '';
    }
    final buffer = StringBuffer('$scheme://$host');
    final port = portTmp.text.trim();
    if (port.isNotEmpty) {
      buffer.write(':$port');
    }
    if (editsPath) {
      final path = pathTmp.text.trim().replaceFirst(RegExp(r'^/+'), '');
      if (path.isNotEmpty) {
        buffer.write('/$path');
      }
    }
    return buffer.toString();
  }

  /// Splits a stored URL back into its parts, keeping anything that cannot be
  /// parsed (a bare Feiniu id, a malformed value) in the host field.
  void loadUrl(String url) {
    if (url.isEmpty) {
      return;
    }
    if (widget.sourceType == .feiniu) {
      hostTmp.text = url;
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

  @override
  void dispose() {
    hostTmp.dispose();
    portTmp.dispose();
    pathTmp.dispose();
    usernameTmp.dispose();
    passwordTmp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: 300,
      child: Padding(
        padding: .fromLTRB(20, 15, 20, 15),
        child: Column(
          mainAxisAlignment: .center,
          mainAxisSize: .min,
          children: [
            if (!firstLaunch)
              SizedBox(
                child: Text(
                  getSourceTypeDisplayName(l10n, widget.sourceType),
                  style: .new(fontWeight: .bold, fontSize: 18),
                ),
              ),

            SizedBox(height: 10),
            if (editsHost) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: isTV
                        ? fakeTextField(l10n.serverScheme, null, scheme)
                        : CustomDropdownField<String>(
                            l10n.serverScheme,
                            scheme,
                            _schemes,
                            (item) => item,
                            (picked) => setState(() => scheme = picked),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: isTV
                        ? fakeTextField(l10n.serverHost, hostTmp)
                        : CustomTextField(
                            l10n.serverHost,
                            hostTmp,
                            compact: false,
                          ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 100),
                  Expanded(
                    child: isTV
                        ? fakeTextField(l10n.serverPort, portTmp)
                        : CustomTextField(
                            l10n.serverPort,
                            portTmp,
                            compact: false,
                            onlyNumber: true,
                          ),
                  ),
                ],
              ),
              if (editsPath) ...[
                SizedBox(height: 10),
                isTV
                    ? fakeTextField(l10n.serverPath, pathTmp)
                    : CustomTextField(
                        l10n.serverPath,
                        pathTmp,
                        compact: false,
                      ),
              ],
            ] else
              isTV
              ? fakeTextField('FN ID', hostTmp)
              : CustomTextField('FN ID', hostTmp, compact: false),

            SizedBox(height: 10),
            isTV
                ? fakeTextField(l10n.username, usernameTmp)
                : CustomTextField(l10n.username, usernameTmp, compact: false),

            SizedBox(height: 10),
            isTV
                ? fakeTextField(l10n.password, passwordTmp)
                : CustomTextField(
                    l10n.password,
                    passwordTmp,
                    needObscure: true,
                    compact: false,
                  ),

            SizedBox(height: isMobile ? 10 : 25),

            buttons(),
          ],
        ),
      ),
    );
  }

  Widget fakeTextField(
    String title,
    TextEditingController? textController, [
    String? fixedValue,
  ]) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('$title:', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        InkWell(
          onTap: textController == null
              ? null
              : () async {
                  textController.text = await getInputTextDialog(
                    context,
                    title,
                    needConfirm: false,
                  );
                  setState(() {});
                },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: textColor.value),
            ),
            child: Text(
              fixedValue ?? textController?.text ?? '',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget buttons() {
    return ValueListenableBuilder(
      valueListenable: buttonColor.valueNotifier,
      builder: (context, value, child) {
        final l10n = AppLocalizations.of(context);

        return Row(
          children: [
            Spacer(),

            if (!firstLaunch)
              ElevatedButton(
                onPressed: () => onDelete(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: firstLaunch ? null : value,
                ),
                child: Text(l10n.delete),
              ),

            if (!firstLaunch) SizedBox(width: 20),

            firstLaunch
                ? Card(
                    clipBehavior: .antiAlias,
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: onSave,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Text(l10n.connect),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => onSave(),
                    style: ElevatedButton.styleFrom(backgroundColor: value),
                    child: Text(l10n.save),
                  ),
            Spacer(),
          ],
        );
      },
    );
  }

  void onDelete() async {
    if (!await showConfirmDialog(
      context,
      AppLocalizations.of(context).delete,
    )) {
      return;
    }
    if (widget.sourceType == .webdav) {
      await library.updateFolders([]);
      webdavClient = null;
    } else if (widget.sourceType == .navidrome) {
      config.navidromeBaseUrl = null;
      config.navidromeUsername = null;
      config.navidromePassword = null;
      if (sourceType == widget.sourceType) {
        streamClient = null;
      }
    } else if (widget.sourceType == .emby) {
      config.embyBaseUrl = null;
      config.embyUsername = null;
      config.embyPassword = null;
      if (sourceType == widget.sourceType) {
        streamClient = null;
      }
    } else if (widget.sourceType == .feiniu) {
      config.feiniuBaseUrl = null;
      config.feiniuUsername = null;
      config.feiniuPassword = null;
      if (sourceType == widget.sourceType) {
        streamClient = null;
      }
    }
    if (mounted) {
      Navigator.pop(context);
    }

    await config.save();
    if (widget.sourceType == sourceType) {
      audioHandler.clear();
      await Loader.sync();
    } else {
      Directory dir = Directory(
        '${appSupportDir.path}/${widget.sourceType.name}',
      );
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }

  void onSave() async {
    final l10n = AppLocalizations.of(context);
    try {
      if (widget.sourceType == .webdav) {
        final tmp = webdavClient;
        webdavClient = WebDavClient(
          baseUrl: composeUrl(),
          username: usernameTmp.text,
          password: passwordTmp.text,
        );
        if (!await webdavClient!.ping()) {
          showCenterMessage('Can not connect to WebDAV');
          webdavClient = tmp;
          return;
        }
      } else if (widget.sourceType == .navidrome) {
        final tmp = streamClient;
        final navidromeClient = NavidromeClient(
          baseUrl: composeUrl(),
          username: usernameTmp.text,
          password: passwordTmp.text,
        );
        if (!await navidromeClient.ping()) {
          showCenterMessage('Can not connect to Navidrome');
          streamClient = tmp;
          return;
        }
        if (widget.sourceType == sourceType) {
          streamClient = navidromeClient;
        }
        config.navidromeBaseUrl = composeUrl();
        config.navidromeUsername = usernameTmp.text;
        config.navidromePassword = passwordTmp.text;
      } else if (widget.sourceType == .emby) {
        final tmp = streamClient;
        final embyClient = EmbyClient(
          baseUrl: composeUrl(),
          username: usernameTmp.text,
          password: passwordTmp.text,
        );

        if (!await embyClient.ping()) {
          showCenterMessage('Can not connect to Emby');
          streamClient = tmp;
          return;
        }
        if (widget.sourceType == sourceType) {
          streamClient = embyClient;
        }
        config.embyBaseUrl = composeUrl();
        config.embyUsername = usernameTmp.text;
        config.embyPassword = passwordTmp.text;
      } else if (widget.sourceType == .feiniu) {
        final feiniuClient = FeiniuClient(
          baseUrl: composeUrl(),
          username: usernameTmp.text,
          password: passwordTmp.text,
        );
        if (!await feiniuClient.ping()) {
          showCenterMessage(l10n.feiniuConnectionFailed);
          return;
        }
        if (widget.sourceType == sourceType) {
          streamClient = feiniuClient;
        }
        config.feiniuBaseUrl = composeUrl();
        config.feiniuUsername = usernameTmp.text;
        config.feiniuPassword = passwordTmp.text;
      }
    } catch (e) {
      if (context.mounted) {
        showCenterMessage(
          widget.sourceType == .feiniu
              ? l10n.feiniuConnectionFailed
              : e.toString(),
          duration: 5000,
        );
      }
      logger.output(e.toString());
      return;
    }

    if (!firstLaunch && mounted) {
      Navigator.pop(context);
    }
    showCenterMessage(l10n.savedSuccessfully);
    await config.save();

    if (!firstLaunch &&
        widget.sourceType != .webdav &&
        widget.sourceType == sourceType) {
      await Loader.sync();
    }
  }
}
