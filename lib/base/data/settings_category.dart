import 'package:material_ui/material_ui.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// First-level entries of the settings page. The order is user-configurable
/// and persisted in `setting.json`.
enum SettingsCategory {
  musicSource,
  userInterface,
  playbackLyrics,
  notifications,
  startupBackground,
  cacheDownloads,
  dataBackup,
  listeningReport,
  helpFeedback,
}

/// The headings the category menu is grouped under. The user's own category
/// order is kept; a heading is inserted whenever the group changes, so moving
/// a category inside the order moves it between headings as well.
enum SettingsGroup { general, playback, library, more }

SettingsGroup settingsCategoryGroup(SettingsCategory category) {
  switch (category) {
    case SettingsCategory.userInterface:
    case SettingsCategory.startupBackground:
      return SettingsGroup.general;
    case SettingsCategory.playbackLyrics:
    case SettingsCategory.notifications:
      return SettingsGroup.playback;
    case SettingsCategory.musicSource:
    case SettingsCategory.cacheDownloads:
    case SettingsCategory.dataBackup:
      return SettingsGroup.library;
    case SettingsCategory.listeningReport:
    case SettingsCategory.helpFeedback:
      return SettingsGroup.more;
  }
}

String settingsGroupTitle(AppLocalizations l10n, SettingsGroup group) {
  switch (group) {
    case SettingsGroup.general:
      return l10n.settingsGroupGeneral;
    case SettingsGroup.playback:
      return l10n.settingsGroupPlayback;
    case SettingsGroup.library:
      return l10n.settingsGroupLibrary;
    case SettingsGroup.more:
      return l10n.settingsGroupMore;
  }
}

/// Search terms that do not appear in a category's own title. The category
/// name itself is always searched as well, in every language.
List<String> settingsCategoryKeywords(SettingsCategory category) {
  switch (category) {
    case SettingsCategory.musicSource:
      return const [
        'server', 'source', 'navidrome', 'emby', 'webdav', 'local',
        'scan', 'folder', 'offline', 'random', 'quality', 'lan', 'login',
        '服务器', '音乐源', '扫描', '文件夹', '离线', '随机', '音质', '局域网',
      ];
    case SettingsCategory.userInterface:
      return const [
        'theme', 'color', 'font', 'home', 'layout', 'cover', 'animation',
        'language', 'ui', '主题', '颜色', '字体', '首页', '布局', '封面', '动画',
        '语言', '界面',
      ];
    case SettingsCategory.playbackLyrics:
      return const [
        'speed', 'fade', 'replaygain', 'gain', 'equalizer', 'eq', 'mode',
        'vibration', 'sleep', 'audio', 'pitch', 'output',
        '速度', '淡入', '淡出', '增益', '均衡', '播放模式', '振动', '定时',
        '音频', '音高', '输出',
      ];
    case SettingsCategory.notifications:
      return const [
        'notification', 'car', 'bluetooth', 'broadcast', 'lyrics', 'cover',
        'mobile', 'data', '通知', '车机', '蓝牙', '广播', '歌词', '封面', '流量',
      ];
    case SettingsCategory.startupBackground:
      return const [
        'startup', 'launch', 'background', 'exit', 'autoplay',
        '启动', '后台', '退出', '自动播放',
      ];
    case SettingsCategory.cacheDownloads:
      return const [
        'cache', 'download', 'storage', 'prefetch', 'path', 'limit',
        '缓存', '下载', '存储', '预缓存', '路径', '上限',
      ];
    case SettingsCategory.dataBackup:
      return const [
        'backup', 'restore', 'export', 'import', 'playlist', 'stats',
        '备份', '恢复', '导出', '导入', '歌单', '统计',
      ];
    case SettingsCategory.listeningReport:
      return const [
        'stats', 'report', 'history', 'year', 'plays',
        '统计', '报告', '历史', '年度', '播放次数',
      ];
    case SettingsCategory.helpFeedback:
      return const [
        'help', 'feedback', 'debug', 'log', 'about', 'version',
        '帮助', '反馈', '调试', '日志', '关于', '版本',
      ];
  }
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
    case SettingsCategory.playbackLyrics:
      return l10n.settingsPlaybackLyrics;
    case SettingsCategory.notifications:
      return l10n.settingsNotifications;
    case SettingsCategory.startupBackground:
      return l10n.settingsStartupBackground;
    case SettingsCategory.cacheDownloads:
      return l10n.settingsCacheDownloads;
    case SettingsCategory.dataBackup:
      return l10n.settingsDataBackup;
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
    case SettingsCategory.playbackLyrics:
      return Icons.play_circle_outline_rounded;
    case SettingsCategory.notifications:
      return Icons.notifications_none_rounded;
    case SettingsCategory.startupBackground:
      return Icons.power_settings_new_rounded;
    case SettingsCategory.cacheDownloads:
      return Icons.download_rounded;
    case SettingsCategory.dataBackup:
      return Icons.backup_rounded;
    case SettingsCategory.listeningReport:
      return Icons.insights_rounded;
    case SettingsCategory.helpFeedback:
      return Icons.help_outline_rounded;
  }
}
