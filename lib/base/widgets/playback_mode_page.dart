import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/playback_mode.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The "Playback and Lyrics" entry opens this page: which of the three audio
/// modes the app uses, one line explaining each of them, and what the modes
/// mean in practice.
///
/// The setting itself is saved through [setting] under its own key; applying it
/// to the audio session is the audio handler's job, not this page's.
class PlaybackModePage extends StatelessWidget {
  const PlaybackModePage({super.key});

  /// The three modes, in the order the normal choices read best: take the
  /// output, share it politely, then share it fully.
  static const List<AudioPlaybackMode> modes = [
    AudioPlaybackMode.exclusive,
    AudioPlaybackMode.duck,
    AudioPlaybackMode.mix,
  ];

  /// Desktop builds have no audio focus arbitration, so exclusive is not
  /// something they can honour; the choice is kept but applied as mix.
  static bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS;

  static String modeLabel(AppLocalizations l10n, AudioPlaybackMode mode) {
    switch (mode) {
      case AudioPlaybackMode.exclusive:
        return l10n.playbackModeExclusive;
      case AudioPlaybackMode.duck:
        return l10n.playbackModeDuck;
      case AudioPlaybackMode.mix:
        return l10n.playbackModeMix;
    }
  }

  static String modeDescription(
    AppLocalizations l10n,
    AudioPlaybackMode mode,
  ) {
    switch (mode) {
      case AudioPlaybackMode.exclusive:
        return l10n.playbackModeExclusiveDesc;
      case AudioPlaybackMode.duck:
        return l10n.playbackModeDuckDesc;
      case AudioPlaybackMode.mix:
        return l10n.playbackModeMixDesc;
    }
  }

  void _select(AudioPlaybackMode mode) {
    if (playbackModeNotifier.value == mode) {
      return;
    }
    playbackModeNotifier.value = mode;
    setting.save();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    // The page background is translucent by design (it sits over the app's
    // cover-art background); a pushed page would show the dark navigator
    // underneath it, so it paints the opaque variant instead.
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
                          l10n.playbackMode,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      // Same width as the back button, so the title stays
                      // centred.
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder<AudioPlaybackMode>(
                    valueListenable: playbackModeNotifier,
                    builder: (context, mode, child) {
                      return ListView(
                        padding: const EdgeInsets.only(top: 4, bottom: 30),
                        children: [
                          AppleFormSection(
                            title: l10n.playbackMode,
                            children: [
                              for (final value in modes)
                                _modeRow(l10n, value, mode),
                            ],
                          ),
                          if (!isMobilePlatform)
                            _desktopNote(l10n),
                          AppleFormSection(
                            title: l10n.playbackModeNotice,
                            children: [
                              _bulletRow(l10n, l10n.playbackModeNoticeInCar),
                              _bulletRow(
                                l10n,
                                l10n.playbackModeNoticeNavigation,
                              ),
                              _bulletRow(
                                l10n,
                                l10n.playbackModeNoticeDesktop,
                              ),
                            ],
                          ),
                          AppleFormSection(
                            title: l10n.playbackModeScenarios,
                            children: [
                              _scenarioRow(
                                l10n,
                                l10n.scenarioDailyListening,
                                l10n.scenarioDailyListeningMode,
                              ),
                              _scenarioRow(
                                l10n,
                                l10n.scenarioNavigation,
                                l10n.scenarioNavigationMode,
                              ),
                              _scenarioRow(
                                l10n,
                                l10n.scenarioGaming,
                                l10n.scenarioGamingMode,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// One selectable mode: its name, a check mark when it is in effect, and its
  /// description underneath in a smaller, quieter line.
  Widget _modeRow(
    AppLocalizations l10n,
    AudioPlaybackMode value,
    AudioPlaybackMode selected,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final isSelected = value == selected;

    return InkWell(
      onTap: () => _select(value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modeLabel(l10n, value),
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    modeDescription(l10n, value),
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withAlpha(160),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: textColor),
          ],
        ),
      ),
    );
  }

  Widget _bulletRow(AppLocalizations l10n, String text) {
    final textColor = colorManager.getSpecificTextColor();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 8),
            child: Text(
              '•',
              style: TextStyle(fontSize: 15, color: textColor.withAlpha(160)),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  /// One use case: what the situation is, then the mode that suits it.
  Widget _scenarioRow(AppLocalizations l10n, String scenario, String mode) {
    final textColor = colorManager.getSpecificTextColor();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              scenario,
              style: TextStyle(fontSize: 15, color: textColor),
            ),
          ),
          const SizedBox(width: 12),
          Text(l10n.scenarioArrow, style: TextStyle(color: textColor)),
          const SizedBox(width: 8),
          Text(
            mode,
            style: TextStyle(
              fontSize: 15,
              color: textColor.withAlpha(160),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopNote(AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: textColor.withAlpha(160)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.playbackModeDesktopNote,
              style: TextStyle(
                fontSize: 13,
                color: textColor.withAlpha(160),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
