import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/playback_effect_settings.dart';
import 'package:lain/base/data/transition_settings.dart';
import 'package:lain/base/data/player_cover_style.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
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

Future<void> showTrackTransitionDialog(
  BuildContext context, {
  Color? textColor,
}) async {
  final l10n = AppLocalizations.of(context);
  final color = textColor ?? colorManager.getSpecificTextColor();
  final titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: color,
  );
  final optionStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: color,
  );
  final detailStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: color.withAlpha(165),
  );

  await showAnimationDialog<void>(
    context: context,
    child: SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            trackTransitionModeNotifier,
            trackTransitionSecondsNotifier,
          ]),
          builder: (context, child) {
            final mode = trackTransitionModeNotifier.value;
            final seconds = trackTransitionSecondsNotifier.value;
            return DefaultTextStyle.merge(
              style: TextStyle(color: color),
              child: IconTheme(
                data: IconThemeData(color: color),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                      child: Text(l10n.trackTransition, style: titleStyle),
                    ),
                    for (final value in TrackTransitionMode.values)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        titleTextStyle: optionStyle,
                        title: Text(switch (value) {
                          TrackTransitionMode.off => l10n.transitionOff,
                          TrackTransitionMode.fixed => l10n.transitionFixed,
                          TrackTransitionMode.adaptive =>
                            l10n.transitionAdaptive,
                        }),
                        trailing: mode == value
                            ? Icon(Icons.check_rounded, color: color)
                            : null,
                        onTap: () {
                          trackTransitionModeNotifier.value = value;
                          if (value != TrackTransitionMode.off) {
                            gaplessPlaybackNotifier.value = false;
                          }
                          setting.save();
                        },
                      ),
                    if (mode != TrackTransitionMode.off)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                        child: Row(
                          children: [
                            Text(l10n.transitionSeconds, style: detailStyle),
                            const Spacer(),
                            DropdownButton<int>(
                              value: seconds,
                              dropdownColor: colorManager
                                  .getSpecificOpaqueBgColor(),
                              style: optionStyle,
                              iconEnabledColor: color,
                              underline: const SizedBox.shrink(),
                              items: [
                                for (final value in const [2, 4, 6, 8, 10, 12])
                                  DropdownMenuItem(
                                    value: value,
                                    child: Text('$value s', style: optionStyle),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                trackTransitionSecondsNotifier.value = value;
                                setting.save();
                              },
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(foregroundColor: color),
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.confirm),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
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
