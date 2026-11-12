import 'package:material_ui/material_ui.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// First-level entries of the settings page. The order is user-configurable
/// and persisted in `setting.json`.
enum SettingsCategory {
  musicSource,
  userInterface,
  comments,
  playbackLyrics,
  notifications,
  startupBackground,
  cacheDownloads,
  listeningReport,
  helpFeedback,
}

/// The persisted first-level order. Missing categories are appended on load,
/// so a new one always appears instead of being lost.
final settingsCategoryOrderNotifier = ValueNotifier<List<SettingsCategory>>(
  List.of(SettingsCategory.values),
);

String settingsCategoryTitle(AppLocalizations l10n, SettingsCategory category) {
  switch (category) {
    case SettingsCategory.musicSource:
      return l10n.settingsMusicSource;
    case SettingsCategory.userInterface:
      return l10n.settingsUserInterface;
    case SettingsCategory.comments:
      return l10n.settingsComments;
    case SettingsCategory.playbackLyrics:
      return l10n.settingsPlaybackLyrics;
    case SettingsCategory.notifications:
      return l10n.settingsNotifications;
    case SettingsCategory.startupBackground:
      return l10n.settingsStartupBackground;
    case SettingsCategory.cacheDownloads:
      return l10n.settingsCacheDownloads;
    case SettingsCategory.listeningReport:
      return l10n.listeningReport;
    case SettingsCategory.helpFeedback:
      return l10n.settingsHelpFeedback;
  }
}

IconData settingsCategoryIcon(SettingsCategory category) {
  switch (category) {
    case SettingsCategory.musicSource:
      return Icons.dns_rounded;
    case SettingsCategory.userInterface:
      return Icons.palette_outlined;
    case SettingsCategory.comments:
      return Icons.forum_rounded;
    case SettingsCategory.playbackLyrics:
      return Icons.play_circle_outline_rounded;
    case SettingsCategory.notifications:
      return Icons.notifications_none_rounded;
    case SettingsCategory.startupBackground:
      return Icons.power_settings_new_rounded;
    case SettingsCategory.cacheDownloads:
      return Icons.download_rounded;
    case SettingsCategory.listeningReport:
      return Icons.insights_rounded;
    case SettingsCategory.helpFeedback:
      return Icons.help_outline_rounded;
  }
}
