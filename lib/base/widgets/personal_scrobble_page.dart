import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/personal_scrobble.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/personal_scrobble.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

class PersonalScrobblePage extends StatefulWidget {
  const PersonalScrobblePage({super.key});

  @override
  State<PersonalScrobblePage> createState() => _PersonalScrobblePageState();
}

class _PersonalScrobblePageState extends State<PersonalScrobblePage> {
  late final TextEditingController _lastFmKey;
  late final TextEditingController _lastFmSecret;
  late final TextEditingController _lastFmUser;
  late final TextEditingController _lastFmPassword;
  late final TextEditingController _listenBrainzToken;
  bool _ready = false;
  bool _connecting = false;
  Timer? _listenBrainzSave;

  @override
  void initState() {
    super.initState();
    _lastFmKey = TextEditingController();
    _lastFmSecret = TextEditingController();
    _lastFmUser = TextEditingController();
    _lastFmPassword = TextEditingController();
    _listenBrainzToken = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    await personalScrobble.ensureLoaded();
    if (!mounted) {
      return;
    }
    final credentials = personalScrobble.credentials.value;
    _lastFmKey.text = credentials.lastFmApiKey;
    _lastFmSecret.text = credentials.lastFmApiSecret;
    _lastFmUser.text = credentials.lastFmUser;
    _listenBrainzToken.text = credentials.listenBrainzToken;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    if (_listenBrainzSave?.isActive ?? false) {
      unawaited(personalScrobble.setListenBrainzToken(_listenBrainzToken.text));
    }
    _listenBrainzSave?.cancel();
    _lastFmKey.dispose();
    _lastFmSecret.dispose();
    _lastFmUser.dispose();
    _lastFmPassword.dispose();
    _listenBrainzToken.dispose();
    super.dispose();
  }

  String _modeLabel(AppLocalizations l10n, PersonalScrobbleMode mode) {
    return switch (mode) {
      PersonalScrobbleMode.off => l10n.scrobbleOff,
      PersonalScrobbleMode.localOnly => l10n.scrobbleLocalOnly,
      PersonalScrobbleMode.all => l10n.scrobbleAll,
    };
  }

  Widget _modeRow(
    AppLocalizations l10n,
    ValueNotifier<PersonalScrobbleMode> notifier,
  ) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, child) {
        return appleSegmented<PersonalScrobbleMode>(
          const [
            PersonalScrobbleMode.off,
            PersonalScrobbleMode.localOnly,
            PersonalScrobbleMode.all,
          ],
          (mode) => _modeLabel(l10n, mode),
          notifier.value,
          (mode) {
            notifier.value = mode;
            setting.save();
          },
        );
      },
    );
  }

  Future<void> _connectLastFm(AppLocalizations l10n) async {
    if (_connecting) {
      return;
    }
    setState(() => _connecting = true);
    await personalScrobble.setLastFmKeys(_lastFmKey.text, _lastFmSecret.text);
    final ok = await personalScrobble.connectLastFm(
      apiKey: _lastFmKey.text,
      apiSecret: _lastFmSecret.text,
      username: _lastFmUser.text,
      password: _lastFmPassword.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _connecting = false);
    if (ok) {
      _lastFmPassword.clear();
    }
    showCenterMessage(ok ? l10n.connectSuccess : l10n.connectionFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    return opaqueSettingsPage(
      context: context,
      title: l10n.personalScrobble,
      body: !_ready
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListenableBuilder(
              listenable: Listenable.merge([
                personalScrobble.credentials,
                lastFmScrobbleModeNotifier,
                listenBrainzScrobbleModeNotifier,
              ]),
              builder: (context, child) {
                final credentials = personalScrobble.credentials.value;
                return ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 110),
                  children: [
                    AppleFormSection(
                      title: l10n.lastFm,
                      children: [
                        _modeRow(l10n, lastFmScrobbleModeNotifier),
                        if (credentials.lastFmReady) ...[
                          appleFormRow(
                            l10n.username,
                            Text(
                              credentials.lastFmUser,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, color: textColor),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  personalScrobble.disconnectLastFm();
                                  _lastFmPassword.clear();
                                },
                                child: Text(l10n.disconnect),
                              ),
                            ),
                          ),
                        ] else ...[
                          appleTextFieldRow(
                            l10n.apiKey,
                            _lastFmKey,
                            obscure: true,
                          ),
                          appleTextFieldRow(
                            l10n.apiSecret,
                            _lastFmSecret,
                            obscure: true,
                          ),
                          appleTextFieldRow(l10n.username, _lastFmUser),
                          appleTextFieldRow(
                            l10n.password,
                            _lastFmPassword,
                            obscure: true,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                            child: appleFilledButton(
                              l10n.connect,
                              _connecting ? null : () => _connectLastFm(l10n),
                              busy: _connecting,
                            ),
                          ),
                        ],
                      ],
                    ),
                    AppleFormSection(
                      title: l10n.listenBrainz,
                      children: [
                        _modeRow(l10n, listenBrainzScrobbleModeNotifier),
                        appleTextFieldRow(
                          l10n.apiKey,
                          _listenBrainzToken,
                          obscure: true,
                          onChanged: (value) {
                            _listenBrainzSave?.cancel();
                            _listenBrainzSave = Timer(
                              const Duration(milliseconds: 400),
                              () =>
                                  personalScrobble.setListenBrainzToken(value),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}
