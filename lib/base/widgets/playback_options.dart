import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/playback_effect_settings.dart';
import 'package:lain/base/data/player_cover_style.dart';
import 'package:lain/base/data/playback_mode.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/playback_mode_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

String replayGainLabel(AppLocalizations l10n, ReplayGainMode mode) {
  return switch (mode) {
    ReplayGainMode.off => l10n.replayGainOff,
    ReplayGainMode.track => l10n.replayGainTrack,
    ReplayGainMode.album => l10n.replayGainAlbum,
  };
}

Widget _choiceRow(
  BuildContext dialogContext,
  String label,
  bool selected,
  Object value, {
  String? description,
}) {
  final textColor = colorManager.getSpecificTextColor();
  return ListTile(
    title: Text(label, style: TextStyle(color: textColor)),
    subtitle: description == null
        ? null
        : Text(
            description,
            style: TextStyle(fontSize: 11, color: textColor.withAlpha(150)),
          ),
    trailing: selected
        ? Icon(Icons.check_rounded, color: colorManager.getSpecificIconColor())
        : null,
    onTap: () => Navigator.pop(dialogContext, value),
  );
}

Future<void> showReplayGainDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final current = replayGainModeNotifier.value;
  final choice = await showAnimationDialog<ReplayGainMode>(
    context: context,
    child: Builder(
      builder: (dialogContext) => SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Text(
                  l10n.replayGainDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorManager.getSpecificTextColor().withAlpha(160),
                  ),
                ),
              ),
              for (final option in ReplayGainMode.values)
                _choiceRow(
                  dialogContext,
                  replayGainLabel(l10n, option),
                  option == current,
                  option,
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (choice == null) {
    return;
  }
  replayGainModeNotifier.value = choice;
  setting.save();
}

Future<void> showPlaybackSpeedDialog(BuildContext context) async {
  final current = playbackSpeedNotifier.value;
  final choice = await showAnimationDialog<double>(
    context: context,
    child: Builder(
      builder: (dialogContext) => SizedBox(
        width: 250,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in playbackSpeedChoices)
                _choiceRow(
                  dialogContext,
                  playbackSpeedLabel(option),
                  (option - current).abs() < 0.001,
                  option,
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (choice == null) {
    return;
  }
  playbackSpeedNotifier.value = choice;
  setting.save();
}

Future<void> showAudioPlaybackModeDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final current = playbackModeNotifier.value;
  final choice = await showAnimationDialog<AudioPlaybackMode>(
    context: context,
    child: Builder(
      builder: (dialogContext) => SizedBox(
        width: 330,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in PlaybackModePage.modes)
                _choiceRow(
                  dialogContext,
                  PlaybackModePage.modeLabel(l10n, option),
                  option == current,
                  option,
                  description: PlaybackModePage.modeDescription(l10n, option),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (choice == null) {
    return;
  }
  playbackModeNotifier.value = choice;
  setting.save();
}


String playerCoverStyleLabel(AppLocalizations l10n, PlayerCoverStyle style) {
  return switch (style) {
    PlayerCoverStyle.square => l10n.coverStyleSquare,
    PlayerCoverStyle.vinyl => l10n.coverStyleVinyl,
  };
}

Future<void> showPlayerCoverStyleDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final current = playerCoverStyleNotifier.value;
  final choice = await showAnimationDialog<PlayerCoverStyle>(
    context: context,
    child: Builder(
      builder: (dialogContext) => SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in PlayerCoverStyle.values)
                _choiceRow(
                  dialogContext,
                  playerCoverStyleLabel(l10n, option),
                  option == current,
                  option,
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (choice == null) {
    return;
  }
  playerCoverStyleNotifier.value = choice;
  setting.save();
}
