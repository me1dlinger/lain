import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/notice_setting.dart';
import 'package:lain/base/data/lan_direct_setting.dart';
import 'package:lain/base/data/offline_setting.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/data/music_server.dart';
import 'package:lain/base/data/settings_category.dart';
import 'package:lain/base/data/artist_album.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/data/random_songs.dart';
import 'package:lain/base/data/recommendation_weights.dart';
import 'package:lain/base/data/transition_settings.dart';
import 'package:lain/base/data/ui_motion_settings.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/stream_relay.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/asset_images.dart';
import 'package:lain/base/services/emby_client.dart';
import 'package:lain/base/services/feiniu_client.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/navidrome_client.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/services/system_ui_service.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/utils/media_query.dart';
import 'package:lain/base/widgets/server_manager.dart';
import 'package:lain/base/widgets/equalizer.dart';
import 'package:lain/base/widgets/playback_mode_page.dart';
import 'package:lain/base/widgets/personal_scrobble_page.dart';
import 'package:lain/base/widgets/playback_options.dart';
import 'package:lain/base/widgets/share_card_settings_page.dart';
import 'package:lain/base/widgets/audio_quality_dashboard.dart';
import 'package:lain/base/widgets/car_display_settings_page.dart';
import 'package:lain/base/widgets/debug_page.dart';
import 'package:lain/base/widgets/backup_page.dart';
import 'package:lain/base/services/scrobble_queue.dart';
import 'package:lain/base/widgets/scrobble_queue_page.dart';
import 'package:lain/base/widgets/source_health_page.dart';
import 'package:lain/base/widgets/sync_preview_page.dart';
import 'package:lain/base/widgets/audio_output_page.dart';
import 'package:lain/base/widgets/cache_storage_dashboard.dart';
import 'package:lain/base/widgets/daily_recommendation_page.dart';
import 'package:lain/base/data/playback_mode.dart';
import 'package:lain/base/data/playback_effect_settings.dart';
import 'package:lain/base/data/comment_setting.dart';
import 'package:lain/base/widgets/comment_settings_page.dart';
import 'package:lain/base/services/download_manager.dart';
import 'package:lain/base/services/cache_download_manager.dart';
import 'package:lain/base/widgets/cache_download_dialog.dart';
import 'package:lain/base/widgets/downloads_page.dart';
import 'package:lain/base/widgets/song_cache_page.dart';
import 'package:lain/base/widgets/cache_group_page.dart';
import 'package:lain/base/widgets/home_layout_settings.dart';
import 'package:lain/base/widgets/local_library_tools_page.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/my_scaffold.dart';
import 'package:lain/base/widgets/settings_page_route.dart';
import 'package:lain/base/widgets/stats_page.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/data/stream_quality.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:lain/base/widgets/manage_music_folders.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/quality_badge_setting.dart';
import 'package:lain/base/data/cover_broadcast_mode.dart';
import 'package:lain/base/data/cache_download_settings.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/data/loader.dart';
import 'package:lain/layer/premium_layer.dart';
import 'package:lain/portrait_view/sleep_timer.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/base/widgets/my_switch.dart';
import 'package:smooth_corner/smooth_corner.dart';

/// The top-right button that opens the first-level order window.
Widget settingsOrderButton(BuildContext context) {
  return IconButton(
    tooltip: AppLocalizations.of(context).customizeSettingsOrder,
    icon: const Icon(Icons.tune_rounded),
    onPressed: () => showSettingsOrderDialog(context),
  );
}

Future<void> showSettingsOrderDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final order = List<SettingsCategory>.of(settingsCategoryOrderNotifier.value);
  await showAnimationDialog<void>(
    context: context,
    child: StatefulBuilder(
      builder: (context, setState) {
        return SizedBox(
          width: 340,
          height: 480,
          child: Material(
            shape: SmoothRectangleBorder(
              smoothness: 1,
              borderRadius: BorderRadius.circular(10),
            ),
            color: Color.alphaBlend(
              colorManager.getSpecificBgColor(),
              colorManager.getSpecificBgBaseColor(),
            ),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Text(
                    l10n.customizeSettingsOrder,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ReorderableListView.builder(
                      onReorderStart: (_) => vibrateGestureFeedback(),
                      itemCount: order.length,
                      // The default proxy is an opaque Material, which shows
                      // up as a white box against this themed window.
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          type: MaterialType.transparency,
                          child: child,
                        );
                      },
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = order.removeAt(oldIndex);
                          order.insert(newIndex, item);
                        });
                        settingsCategoryOrderNotifier.value = List.of(order);
                        setting.save();
                      },
                      itemBuilder: (context, index) {
                        final category = order[index];
                        return ListTile(
                          key: ValueKey(category),
                          tileColor: Colors.transparent,
                          selectedTileColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          leading: Icon(settingsCategoryIcon(category)),
                          title: Text(settingsCategoryTitle(l10n, category)),
                          trailing: ReorderableDelayedDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle_rounded),
                          ),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.confirm),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class SettingsCategoryPage extends StatelessWidget {
  final SettingsCategory category;

  const SettingsCategoryPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The page slides in over the settings menu, so it has to paint an opaque
    // background: with a transparent one the menu's text showed through the
    // moving page.
    return ListenableBuilder(
      listenable: Listenable.merge([
        layersManager.backgroundChangeNotifier,
        panelColor.valueNotifier,
        pageBackgroundColor.valueNotifier,
      ]),
      builder: (context, child) {
        return Container(
          color: colorManager.getSpecificOpaqueBgColor(),
          child: myScaffold(
            context: context,
            body: SettingsList(category: category, iconSize: 30),
            label: '__pushed__',
            title: settingsCategoryTitle(l10n, category),
          ),
        );
      },
    );
  }
}

class SettingsList extends StatefulWidget {
  final double? iconSize;

  /// Null shows the first-level category menu. A category shows only that
  /// category's tiles, on a page pushed from the menu.
  final SettingsCategory? category;

  const SettingsList({super.key, this.iconSize, this.category});

  @override
  State<StatefulWidget> createState() => _SettingsListState();
}

class _SettingsListState extends State<SettingsList> {
  double? iconSize;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    iconSize = widget.iconSize;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _categoryMatches(
    SettingsCategory category,
    AppLocalizations l10n,
    String query,
  ) {
    if (query.isEmpty) {
      return true;
    }
    final haystack = <String>[
      settingsCategoryTitle(l10n, category),
      settingsGroupTitle(l10n, settingsCategoryGroup(category)),
      category.name,
      ...settingsCategoryKeywords(category),
    ];
    for (final value in haystack) {
      if (value.toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }

  /// The order is persisted, so an old file or a bad merge could repeat an
  /// entry; the menu shows each category once.
  List<SettingsCategory> _uniqueOrder(List<SettingsCategory> order) {
    final seen = <SettingsCategory>{};
    return [
      for (final category in order)
        if (seen.add(category)) category,
    ];
  }

  Widget _settingsSearchField(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: textColor.withAlpha(14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search_rounded, size: 18, color: textColor.withAlpha(150)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l10n.settingsSearchHint,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: textColor.withAlpha(125),
                  ),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: textColor.withAlpha(150),
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _groupHeader(AppLocalizations l10n, SettingsGroup group) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 3),
      child: Text(
        settingsGroupTitle(l10n, group),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: .3,
          color: textColor.withAlpha(135),
        ),
      ),
    );
  }

  Widget _noSettingsResults(AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 38, color: textColor.withAlpha(70)),
          const SizedBox(height: 10),
          Text(
            l10n.settingsNoResults,
            style: TextStyle(fontSize: 13, color: textColor.withAlpha(140)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLandscape = !isTooNarrow(context);

    if (widget.category != null) {
      return ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 100),
        children: [
          for (final tile in _categoryTiles(widget.category!, context, l10n))
            paddingIfNeed(isLandscape, tile),
        ],
      );
    }

    return ValueListenableBuilder<List<SettingsCategory>>(
      valueListenable: settingsCategoryOrderNotifier,
      builder: (context, order, child) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = _uniqueOrder(order)
            .where((category) => _categoryMatches(category, l10n, query))
            .toList();
        final categorySlivers = <Widget>[];
        final grouped = <SettingsGroup, List<SettingsCategory>>{};
        for (final category in filtered) {
          // A local library has no downloads, and its covers/lyrics are
          // not something the cache page is needed for. WebDAV can cache
          // and download like a streamed source.
          if (!isStreamSource &&
              sourceType != .webdav &&
              category == SettingsCategory.cacheDownloads) {
            continue;
          }
          grouped
              .putIfAbsent(settingsCategoryGroup(category), () => [])
              .add(category);
        }
        // The headings keep a fixed order; the user's order is applied inside
        // each heading, so moving a category does not reshuffle the page.
        for (final group in SettingsGroup.values) {
          final categories = grouped[group];
          if (categories == null || categories.isEmpty) {
            continue;
          }
          categorySlivers.add(sliverBox(_groupHeader(l10n, group)));
          for (final category in categories) {
            categorySlivers.add(
              sliverBox(
                paddingIfNeed(
                  isLandscape,
                  _categoryListTile(context, l10n, category),
                ),
              ),
            );
          }
        }
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (isLandscape || viewModeNotifier.value == .bigPicture)
              sliverBox(_settingsHeader(context, l10n)),
            sliverBox(_settingsSearchField(context, l10n)),
            if (query.isNotEmpty && categorySlivers.isEmpty)
              sliverBox(_noSettingsResults(l10n)),
            ...categorySlivers,
            if (!isLandscape) sliverBox(const SizedBox(height: 100)),
            if (viewModeNotifier.value == .bigPicture)
              sliverBox(const SizedBox(height: 75)),
          ],
        );
      },
    );
  }

  /// Header of the landscape/desktop settings panel. The portrait app bar
  /// carries the same order button.
  Widget _settingsHeader(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ImageIcon(settingImage, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.settings,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          // Big-picture pages already have the app bar action; the panel view
          // has no app bar, so the header carries it here.
          if (viewModeNotifier.value != .bigPicture)
            settingsOrderButton(context),
        ],
      ),
    );
  }

  Widget _categoryListTile(
    BuildContext context,
    AppLocalizations l10n,
    SettingsCategory category,
  ) {
    return ListTile(
      leading: Icon(
        settingsCategoryIcon(category),
        size: iconSize ?? 30,
        color: iconColor.value,
      ),
      title: Text(settingsCategoryTitle(l10n, category)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        // The report is itself a page: opening the first-level entry goes
        // straight to it instead of showing a second menu with its own name.
        if (category == SettingsCategory.listeningReport) {
          pushSettingsPage<void>(
            context,
            settingsPageRoute<void>(() => const StatsPage()),
          );
          return;
        }
        if (category == SettingsCategory.dataBackup) {
          pushSettingsPage<void>(
            context,
            settingsPageRoute<void>(() => const BackupPage()),
          );
          return;
        }
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(
            () => SettingsCategoryPage(category: category),
          ),
        );
      },
    );
  }

  /// The tiles of one first-level category. Each existing setting belongs to
  /// exactly one of them, and the platform-specific ones stay conditional.
  List<Widget> _categoryTiles(
    SettingsCategory category,
    BuildContext context,
    AppLocalizations l10n,
  ) {
    switch (category) {
      case SettingsCategory.musicSource:
        return [
          serversListTile(context, l10n),
          ListTile(
            leading: Icon(
              Icons.monitor_heart_outlined,
              size: iconSize,
              color: colorManager.getSpecificIconColor(),
            ),
            title: Text(l10n.sourceHealth),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SourceHealthPage()),
              );
            },
          ),
          // The local library sits behind the servers so a stray tap does not
          // switch sources on the way to something else.
          localSourceListTile(context, l10n),
          if (isLocalLibrary) audioQualityStatsListTile(context, l10n),
          // The tools only exist for the on-device library: for a server or a
          // WebDAV source this tile is not built at all.
          if (isLocalLibrary) localLibraryToolsListTile(context, l10n),
          offlineModeListTile(l10n),
          offlineLibrarySourceListTile(context, l10n),
          // WebDAV still uses the generic folder manager; the local library
          // has its own second-level page.
          if (sourceType == .webdav) selectMusicFoldersListTile(context, l10n),
          syncListTile(context, l10n),
          if (isStreamSource) scrobbleQueueListTile(context, l10n),
          if (isStreamSource) ...[
            lanDirectListTile(l10n),
            streamQualityListTile(context, l10n),
            streamFormatListTile(context, l10n),
            useServerRandomListTile(l10n),
            if (sourceType == .navidrome) playbackReportListTile(l10n),
          ],
          // WebDAV caches to disk too, so the cache dashboard applies to it.
          if (isStreamSource || sourceType == .webdav)
            cacheStorageStatsListTile(context, l10n),
          if (Platform.isIOS && viewModeNotifier.value != .bigPicture)
            premiumFeaturesListTile(context, l10n),
        ];
      case SettingsCategory.userInterface:
        return [
          homeLayoutListTile(context, l10n),
          themeListTile(context, l10n),
          lyricsCoverMotionListTile(l10n),
          shareCardSettingsListTile(context, l10n),
          languageListTile(context, l10n),
          if (viewModeNotifier.value != .bigPicture)
            fontListTile(context, l10n),
          commentSettingsListTile(context, l10n),
          ListTile(
            leading: Icon(
              Icons.straighten_rounded,
              size: iconSize,
              color: iconColor.value,
            ),
            title: Text(l10n.songQualityBadge),
            trailing: SizedBox(
              width: 50,
              child: MySwitch(
                valueNotifier: songQualityBadgeNotifier,
                onToggleCallBack: () => setting.save(),
              ),
            ),
          ),
          if (Platform.isAndroid && !isTV) ...[
            immersiveWideLayoutListTile(l10n),
            wideSystemBarListTile(l10n, top: true),
            wideSystemBarListTile(l10n, top: false),
          ],
        ];
      case SettingsCategory.playbackLyrics:
        return [
          equalizerListTile(context, l10n),
          replayGainListTile(context, l10n),
          playbackSpeedListTile(context, l10n),
          audioFadeListTile(l10n),
          gaplessListTile(l10n),
          trackTransitionListTile(context, l10n),
          transitionSecondsListTile(context, l10n),
          playbackModeListTile(context, l10n),
          ListTile(
            leading: Icon(
              Icons.speaker_rounded,
              size: iconSize,
              color: iconColor.value,
            ),
            title: Text(l10n.audioOutput),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              pushSettingsPage<void>(
                context,
                settingsPageRoute<void>(() => const AudioOutputPage()),
              );
            },
          ),
          if (isMobile && !isTV) vibrationListTile(l10n),
          if (isMobile) sleepTimerListTile(context, l10n, iconSize: iconSize),
          commentSettingsListTile(context, l10n),
        ];
      case SettingsCategory.notifications:
        return [
          mobileDataWarningListTile(l10n),
          if (isMobile && viewModeNotifier.value != .bigPicture)
            carDisplayListTile(context, l10n),
          personalScrobbleListTile(context, l10n),
        ];
      case SettingsCategory.startupBackground:
        return [
          autoPlayOnStartupListTile(l10n),
          if (!isMobile) exitOnClose(l10n),
        ];
      case SettingsCategory.cacheDownloads:
        return [
          autoCacheListTile(
            l10n.autoCacheSongs,
            Icons.music_note_rounded,
            autoCacheSongsNotifier,
          ),
          autoCacheListTile(
            l10n.prefetchNextSong,
            Icons.skip_next_rounded,
            prefetchNextSongNotifier,
          ),
          // WebDAV has no server-side playlist covers/artist images to warm,
          // and no transcode quality to choose.
          if (isStreamSource) ...[
            autoCacheListTile(
              l10n.autoCachePlaylists,
              Icons.queue_music_rounded,
              autoCachePlaylistsNotifier,
            ),
            autoCacheListTile(
              l10n.autoCacheArtists,
              Icons.person_outline_rounded,
              autoCacheArtistsNotifier,
            ),
          ],
          songCacheListTile(context, l10n),
          cacheGroupListTile(context, l10n),
          downloadsListTile(context, l10n),
          if (isStreamSource) downloadQualityListTile(context, l10n),
          downloadMobileDataListTile(l10n),
          cacheDirListTile(context, l10n),
          downloadDirListTile(context, l10n),
          cacheLimitListTile(context, l10n),
        ];
      case SettingsCategory.listeningReport:
        return [listeningReportListTile(context, l10n)];
      case SettingsCategory.recommendations:
        return [
          skipAwareRecommendationsListTile(l10n),
          ListTile(
            leading: Icon(
              Icons.auto_awesome_motion_rounded,
              size: iconSize,
              color: iconColor.value,
            ),
            title: Text(l10n.dailyMix),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              pushSettingsPage<void>(
                context,
                settingsPageRoute<void>(() => const DailyRecommendationPage()),
              );
            },
          ),
        ];
      case SettingsCategory.dataBackup:
        return [
          ListTile(
            leading: Icon(
              Icons.backup_rounded,
              size: iconSize,
              color: iconColor.value,
            ),
            title: Text(l10n.backupData),
            onTap: () {
              pushSettingsPage<void>(
                context,
                settingsPageRoute<void>(() => const BackupPage()),
              );
            },
          ),
        ];
      case SettingsCategory.helpFeedback:
        return [
          ListTile(
            leading: Icon(
              Icons.feedback_outlined,
              size: iconSize,
              color: iconColor.value,
            ),
            title: Text(l10n.feedback),
            onTap: () {
              launchUrl(Uri.parse('https://github.com/me1dlinger/lain/issues'));
            },
          ),
          ListTile(
            leading: Icon(
              Icons.bug_report_outlined,
              size: iconSize,
              color: iconColor.value,
            ),
            title: Text(l10n.debug),
            onTap: () {
              pushSettingsPage<void>(
                context,
                settingsPageRoute<void>(() => const DebugPage()),
              );
            },
          ),
          viewLogListTile(context, l10n),
          if (viewModeNotifier.value != .bigPicture)
            ListTile(
              leading: ImageIcon(infoImage, size: iconSize),
              title: Text(l10n.about),
              onTap: () {
                layersManager.pushDetail('settings', 'about');
              },
            ),
        ];
    }
  }

  Widget paddingIfNeed(bool isLandscape, Widget child) {
    return isLandscape ? paddingForLandscape(child) : child;
  }

  Widget sliverBox(Widget child) => SliverToBoxAdapter(child: child);

  Widget paddingForLandscape(Widget child) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: viewModeNotifier.value == .bigPicture ? 50 : 30,
      ),
      child: SmoothClipRRect(
        smoothness: 1,
        borderRadius: BorderRadius.circular(10),
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }

  /// The song comment feature: whether it is on, and which comment server
  /// answers. One glance tells both, since the switch and the server are two
  /// separate settings that only work together.
  Widget commentSettingsListTile(BuildContext context, AppLocalizations l10n) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        commentSwitchNotifier,
        commentActiveServerIdNotifier,
      ]),
      builder: (context, child) {
        final server = activeCommentServer;
        String status;
        if (!commentSwitchNotifier.value) {
          status = l10n.commentOff;
        } else if (server == null) {
          status = l10n.commentNoServer;
        } else {
          status = l10n.commentOnWithServer(server.name);
        }

        return ListTile(
          leading: Icon(
            Icons.forum_rounded,
            size: iconSize,
            color: iconColor.value,
          ),
          title: Text(l10n.comment),
          subtitle: Text(status),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            pushSettingsPage<void>(
              context,
              settingsPageRoute<void>(() => const CommentSettingsPage()),
            );
          },
        );
      },
    );
  }

  Widget audioQualityStatsListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: Icon(
        Icons.equalizer_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.audioQualityStats),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const AudioQualityDashboardPage()),
        );
      },
    );
  }

  Widget cacheStorageStatsListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: Icon(
        Icons.donut_large_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.cacheStorageStats),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const CacheStorageDashboardPage()),
        );
      },
    );
  }

  Widget localLibraryToolsListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: Icon(
        Icons.handyman_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.localLibraryTools),
      subtitle: Text(
        l10n.localLibraryToolsHint,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const LocalLibraryToolsPage()),
        );
      },
    );
  }

  Widget localSourceListTile(BuildContext context, AppLocalizations l10n) {
    final selected = sourceType == .local;
    return ListTile(
      leading: Icon(
        Icons.folder_special_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.localMusic),
      subtitle: Text(
        l10n.longPressToConfigure,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: selected
          ? Text(
              l10n.inUse,
              style: TextStyle(
                fontSize: 12,
                color: colorManager.getSpecificTextColor().withAlpha(180),
              ),
            )
          : null,
      onTap: selected
          ? null
          : () {
              _switchToLocalSource();
            },
      onLongPress: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const LocalMusicSettingsPage()),
        );
      },
    );
  }

  Future<void> _switchToLocalSource() async {
    if (sourceType == .local) {
      return;
    }
    showCenterLoading();
    try {
      await Loader.switchToLocal();
      playlistManager.updateNotifier.value++;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      logger.output('[settings] could not switch to local: $e');
      showCenterMessage('$e');
    } finally {
      removeCenterLoading();
    }
  }

  Widget offlineModeListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.cloud_off_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.offlineMode),
      subtitle: Text(l10n.offlineModeDescription),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: offlineModeNotifier,
          onToggleCallBack: () {
            final enabling = offlineModeNotifier.value;
            setting.save();
            if (enabling) {
              unawaited(_enterOfflineMode(context, l10n));
            } else if (offlineUseCachedLibraryNotifier.value &&
                sourceType != .local) {
              unawaited(_reloadOnlineLibrary());
            }
          },
        ),
      ),
    );
  }

  /// Which library offline mode shows. Only meaningful while it is on: the
  /// local folders, or the songs of the current server that are already on
  /// disk.
  Widget offlineLibrarySourceListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: offlineModeNotifier,
      builder: (context, enabled, child) {
        if (!enabled) {
          return const SizedBox.shrink();
        }
        final cached =
            offlineUseCachedLibraryNotifier.value &&
            (isStreamSource || sourceType == .webdav);
        return ListTile(
          leading: Icon(
            cached ? Icons.offline_pin_rounded : Icons.folder_rounded,
            size: iconSize,
            color: iconColor.value,
          ),
          title: Text(l10n.offlineLibrarySource),
          subtitle: Text(
            cached ? l10n.offlineLibraryCached : l10n.offlineLibraryLocal,
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () => unawaited(_pickOfflineLibrary(context, l10n)),
        );
      },
    );
  }

  /// Asks which library offline mode should show. On a local source there is
  /// only one answer, so the switch simply stays on the local library.
  Future<void> _enterOfflineMode(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    if (sourceType == .local) {
      offlineUseCachedLibraryNotifier.value = false;
      setting.save();
      return;
    }
    final choice = await _askOfflineLibrary(context, l10n);
    if (choice == null) {
      offlineModeNotifier.value = false;
      setting.save();
      return;
    }
    offlineServerIdNotifier.value = config.activeServerId ?? '';
    if (choice) {
      offlineUseCachedLibraryNotifier.value = true;
      setting.save();
      await _reloadCachedLibrary();
    } else {
      offlineUseCachedLibraryNotifier.value = false;
      setting.save();
      showCenterLoading();
      try {
        await Loader.switchToLocal();
        playlistManager.updateNotifier.value++;
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        logger.output('[settings] could not enter offline mode: $e');
        showCenterMessage('$e');
      } finally {
        removeCenterLoading();
      }
    }
  }

  Future<void> _pickOfflineLibrary(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final cached =
        offlineUseCachedLibraryNotifier.value &&
        (isStreamSource || sourceType == .webdav);
    // Always ask, including while the local library is already showing. The
    // old branch treated "source is local" as "the user wants the cache" and
    // switched without a dialog, which is why tapping the menu once jumped to
    // the cached library and the second tap was the only one that asked.
    final choice = await _askOfflineLibrary(context, l10n);
    if (choice == null || choice == cached) {
      return;
    }
    if (choice) {
      // The server may have been cleared when the local library was entered.
      final wanted = _offlineServer();
      if (wanted == null) {
        showCenterMessage(l10n.noServerForOffline);
        return;
      }
      await config.activateServerOffline(wanted);
      offlineUseCachedLibraryNotifier.value = true;
      offlineServerIdNotifier.value = wanted.id;
      setting.save();
      await _reloadCachedLibrary();
    } else {
      offlineUseCachedLibraryNotifier.value = false;
      setting.save();
      await Loader.switchToLocal();
      playlistManager.updateNotifier.value++;
      if (mounted) {
        setState(() {});
      }
      layersManager.backgroundChangeNotifier.value++;
    }
  }

  /// True means the server's cached songs, false the local library, null that
  /// the dialog was dismissed.
  Future<bool?> _askOfflineLibrary(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final cachedCount = library.songList.where((song) => song.cacheExist).length;
    return showAnimationDialog<bool>(
      context: context,
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  l10n.offlineChooseLibrary,
                  style: TextStyle(fontSize: 15, color: iconColor.value),
                ),
              ),
              Builder(
                builder: (dialogContext) => ListTile(
                  leading: const Icon(Icons.folder_rounded),
                  title: Text(l10n.offlineLibraryLocal),
                  onTap: () => Navigator.pop(dialogContext, false),
                ),
              ),
              Builder(
                builder: (dialogContext) => ListTile(
                  leading: const Icon(Icons.offline_pin_rounded),
                  title: Text(l10n.offlineLibraryCached),
                  subtitle: Text(l10n.offlineLibraryCachedDetail(cachedCount)),
                  onTap: () => Navigator.pop(dialogContext, true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MusicServer? _offlineServer() {
    for (final server in config.servers) {
      if (server.id == offlineServerIdNotifier.value) {
        return server;
      }
    }
    return config.servers.isEmpty ? null : config.servers.first;
  }

  Future<void> _reloadCachedLibrary() async {
    showCenterLoading();
    try {
      await Loader.reload();
      playlistManager.updateNotifier.value++;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      logger.output('[settings] could not load the cached library: $e');
      showCenterMessage('$e');
    } finally {
      removeCenterLoading();
    }
  }

  /// Leaving offline mode on a server source brings the full library back; the
  /// metadata database was never pruned, only filtered.
  Future<void> _reloadOnlineLibrary() async {
    showCenterLoading();
    try {
      await Loader.reload();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      logger.output('[settings] could not leave offline mode: $e');
      showCenterMessage('$e');
    } finally {
      removeCenterLoading();
    }
  }

  Widget useServerRandomListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.shuffle_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.useServerRandom),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: useServerRandomNotifier,
          onToggleCallBack: () {
            setting.save();
            unawaited(refreshRandomSongs(force: true));
          },
        ),
      ),
    );
  }

  /// Songs that are skipped again and again are worth less in a recommendation
  /// than a song the listener actually hears out. The signal comes from the
  /// playback journal, so it works for every source without a server.
  Widget skipAwareRecommendationsListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.auto_awesome_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.skipAwareRecommendations),
      subtitle: Text(l10n.skipAwareRecommendationsDescription),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: skipAwareRecommendationsNotifier,
          onToggleCallBack: () {
            setting.save();
            unawaited(refreshRandomSongs(force: true));
          },
        ),
      ),
    );
  }

  /// Stream straight from the server while it is reachable on the LAN: the next
  /// track re-resolves its source, so the current one is never interrupted.
  Widget lanDirectListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.lan_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.lanDirect),
      subtitle: Text(l10n.lanDirectDescription),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: lanDirectNotifier,
          onToggleCallBack: () => setting.save(),
        ),
      ),
    );
  }

  Widget syncListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(reloadImage, size: iconSize),
      title: Text(l10n.syncLibrary),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SyncPreviewPage()),
        );
      },
    );
  }

  Widget scrobbleQueueListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ValueListenableBuilder(
      valueListenable: scrobbleQueue.events,
      builder: (context, events, child) {
        return ListTile(
          leading: Icon(
            Icons.cloud_upload_outlined,
            size: iconSize,
            color: colorManager.getSpecificIconColor(),
          ),
          title: Text(l10n.scrobbleQueue),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (events.isNotEmpty)
                Text(
                  '${events.length}  ',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorManager.getSpecificTextColor().withAlpha(170),
                  ),
                ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScrobbleQueuePage()),
            );
          },
        );
      },
    );
  }

  Widget selectMusicFoldersListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: ImageIcon(folderImage, size: iconSize),
      title: Text(l10n.manageMusicFolder),
      onTap: () {
        showAnimationDialog(context: context, child: ManageMusicFolders());
      },
    );
  }

  Widget premiumFeaturesListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(premiumImage, size: iconSize),
      title: Text(l10n.premiumFeatures),
      onTap: () {
        layersManager.pushDetail('settings', 'premium');
      },
      trailing: ValueListenableBuilder(
        valueListenable: trialRemainingMinNotifier,
        builder: (context, value, child) {
          if (value <= 0) {
            return SizedBox.shrink();
          }
          return Row(
            mainAxisSize: .min,
            children: [
              Text(
                "${l10n.trialRemaining}:${formatDuration(Duration(minutes: value), ms: false)}",
              ),
            ],
          );
        },
      ),
    );
  }

  Widget cleanCacheListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(cacheImage, size: iconSize),
      title: Text(l10n.viewCache),
      onTap: () => showCacheDetailDialog(context, l10n),
      trailing: ValueListenableBuilder(
        valueListenable: cacheSizeNotifier,
        builder: (context, value, child) {
          // While a caching task runs in the background, its progress is
          // visible here so the user is never left guessing after moving the
          // dialog to the background.
          return ValueListenableBuilder(
            valueListenable: cacheDownloadManager.notifier,
            builder: (context, progress, child) {
              if (!progress.isRunning) {
                // use blank as placeholders
                return Text("${value.toStringAsFixed(1)}MB  ");
              }
              final counts =
                  "${progress.done}/${progress.total}"
                  "${progress.failed > 0 ? '·${progress.failed}' : ''}";
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: progress.fraction,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(counts),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget streamQualityListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(equalizerImage, size: iconSize),
      title: Text(l10n.streamQuality),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Builder(
                builder: (context) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 35,
                        child: Text(
                          l10n.streamQuality,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final quality in StreamQuality.values)
                        ListTile(
                          title: Text(streamQualityLabel(l10n, quality)),
                          trailing: streamQualityNotifier.value == quality
                              ? Icon(Icons.check)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            streamQualityNotifier.value = quality;
                            setting.save();
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
      trailing: ValueListenableBuilder(
        valueListenable: streamQualityNotifier,
        builder: (context, value, child) {
          return Text('${streamQualityLabel(l10n, value)}  ');
        },
      ),
    );
  }

  Widget mobileDataWarningListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.signal_cellular_alt_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.mobileDataWarning),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: mobileDataWarningNotifier,
          onToggleCallBack: () {
            setting.save();
          },
        ),
      ),
    );
  }

  Widget streamFormatListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(optionImage, size: iconSize),
      title: Text(l10n.streamFormat),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Builder(
                builder: (context) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 35,
                        child: Text(
                          l10n.streamFormat,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final format in StreamFormat.values)
                        ListTile(
                          title: Text(format.display),
                          trailing: streamFormatNotifier.value == format
                              ? Icon(Icons.check)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            streamFormatNotifier.value = format;
                            setting.save();
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
      trailing: ValueListenableBuilder(
        valueListenable: streamFormatNotifier,
        builder: (context, value, child) {
          return Text('${value.display}  ');
        },
      ),
    );
  }

  Widget downloadsListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: Icon(Icons.download_rounded, size: iconSize),
      title: Text(l10n.downloads),
      trailing: ValueListenableBuilder(
        valueListenable: downloadsNotifier,
        builder: (context, items, child) => Text('${items.length}  '),
      ),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const DownloadsPage()),
        );
      },
    );
  }

  Widget songCacheListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(cacheImage, size: iconSize),
      title: Text(l10n.cacheSongs),
      trailing: ValueListenableBuilder(
        valueListenable: cacheSizeNotifier,
        builder: (context, size, child) => Text('${size.toStringAsFixed(1)}MB  '),
      ),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const SongCachePage()),
        );
      },
    );
  }

  Widget cacheGroupListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(cacheImage, size: iconSize),
      title: Text(l10n.cacheGroup),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const CacheGroupPage()),
        );
      },
    );
  }

  Widget downloadQualityListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: ImageIcon(equalizerImage, size: iconSize),
      title: Text(l10n.downloadQuality),
      trailing: ValueListenableBuilder(
        valueListenable: downloadQualityNotifier,
        builder: (context, value, child) {
          return Text('${streamQualityLabel(l10n, value)}  ');
        },
      ),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Builder(
                builder: (context) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final quality in StreamQuality.values)
                        ListTile(
                          title: Text(streamQualityLabel(l10n, quality)),
                          trailing: downloadQualityNotifier.value == quality
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            downloadQualityNotifier.value = quality;
                            setting.save();
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget downloadMobileDataListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.signal_cellular_alt_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.downloadOnMobileData),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: downloadOnMobileDataNotifier,
          onToggleCallBack: () => setting.save(),
        ),
      ),
    );
  }

  Widget autoCacheListTile(
    String title,
    IconData icon,
    ValueNotifier<bool> notifier,
  ) {
    return ListTile(
      leading: Icon(icon, size: iconSize, color: iconColor.value),
      title: Text(title),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: notifier,
          onToggleCallBack: () => setting.save(),
        ),
      ),
    );
  }

  String get _cacheDirLabel {
    final configured = cacheDirNotifier.value.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    return '${appSupportDir.path}/${sourceType.name}';
  }

  String get _downloadDirLabel {
    final configured = downloadDirNotifier.value.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    return Platform.isAndroid
        ? '/storage/emulated/0/Download/$downloadFolderName'
        : '${appDocsDir.path}/$downloadFolderName';
  }

  String _cacheLimitLabel(AppLocalizations l10n) {
    final gb = cacheLimitGbNotifier.value;
    return gb == 0 ? l10n.cacheLimitUnlimited : l10n.cacheLimitGb(gb);
  }

  Widget cacheDirListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.folder_outlined,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.cacheDirectory),
      subtitle: Text(
        _cacheDirLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _changeCacheDirectory(context, l10n),
    );
  }

  Widget downloadDirListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.folder_open_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.downloadDirectory),
      subtitle: Text(
        _downloadDirLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _changeDownloadDirectory(context, l10n),
    );
  }

  Widget cacheLimitListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.storage_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.cacheLimit),
      subtitle: ValueListenableBuilder(
        valueListenable: cacheLimitGbNotifier,
        builder: (context, value, child) {
          return Text(
            value == 0
                ? l10n.cacheLimitUnlimited
                : l10n.cacheLimitGb(value),
          );
        },
      ),
      onTap: () => _pickCacheLimit(context, l10n),
    );
  }

  Future<void> _changeCacheDirectory(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final picked = await FilePicker.getDirectoryPath();
    if (picked == null || !context.mounted) {
      return;
    }
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request() == .denied) {
        showCenterMessage(l10n.storagePermissionDenied, duration: 3000);
        return;
      }
    }
    final newRoot = _normalizePath(picked);
    final oldRoot = cacheDirNotifier.value.trim().isEmpty
        ? appSupportDir.path
        : _normalizePath(cacheDirNotifier.value.trim());
    if (newRoot == oldRoot) {
      return;
    }
    final move = await showConfirmDialog(context, l10n.moveCacheToNewDirectory);
    if (!context.mounted) {
      return;
    }
    showCenterLoading();
    try {
      if (move) {
        await _moveCacheTree(oldRoot, newRoot);
      }
      cacheDirNotifier.value = newRoot;
      setting.save();
      // Song objects capture their cache path when they are created, so the
      // library has to be rebuilt for the new root to be used everywhere.
      await Loader.reload();
      if (context.mounted) {
        showCenterMessage(l10n.cacheDirectoryChanged, duration: 3000);
      }
    } catch (e) {
      logger.output('[settings] cache directory change failed: $e');
      if (context.mounted) {
        showCenterMessage('$e');
      }
    } finally {
      removeCenterLoading();
    }
  }

  Future<void> _changeDownloadDirectory(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final picked = await FilePicker.getDirectoryPath();
    if (picked == null || !context.mounted) {
      return;
    }
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request() == .denied) {
        showCenterMessage(l10n.storagePermissionDenied, duration: 3000);
        return;
      }
    }
    final newRoot = _normalizePath(picked);
    final move = await showConfirmDialog(
      context,
      l10n.moveDownloadsToNewDirectory,
    );
    if (!context.mounted) {
      return;
    }
    try {
      if (move) {
        await downloadManager.moveToDirectory(newRoot);
      }
      downloadDirNotifier.value = newRoot;
      setting.save();
      if (context.mounted) {
        showCenterMessage(l10n.downloadDirectoryChanged, duration: 3000);
      }
    } catch (e) {
      logger.output('[settings] download directory change failed: $e');
      if (context.mounted) {
        showCenterMessage('$e');
      }
    }
  }

  Future<void> _pickCacheLimit(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final choice = await showAnimationDialog<int>(
      context: context,
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final gb in cacheLimitChoices)
                Builder(
                  builder: (dialogContext) => ListTile(
                    title: Text(
                      gb == 0
                          ? l10n.cacheLimitUnlimited
                          : l10n.cacheLimitGb(gb),
                    ),
                    trailing: cacheLimitGbNotifier.value == gb
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.pop(dialogContext, gb),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) {
      return;
    }
    cacheLimitGbNotifier.value = choice;
    setting.save();
    unawaited(library.enforceCacheLimit());
  }

  static final String _backslash = String.fromCharCode(92);

  String _normalizePath(String path) => path.replaceAll(_backslash, '/');

  /// Moves the cached audio/covers/lyrics of every source from [oldRoot] under
  /// [newRoot], keeping the per-source folder layout. A file that cannot be
  /// moved is left where it is; an existing destination file wins.
  Future<void> _moveCacheTree(String oldRoot, String newRoot) async {
    for (final type in SourceType.values) {
      for (final sub in const ['caches', 'pictures', 'lyrics']) {
        final fromDir = Directory('$oldRoot/${type.name}/$sub');
        if (!await fromDir.exists()) {
          continue;
        }
        final toDir = Directory('$newRoot/${type.name}/$sub');
        await toDir.create(recursive: true);
        await for (final entity in fromDir.list(recursive: true)) {
          if (entity is! File) {
            continue;
          }
          final relative = entity.path.substring(fromDir.path.length + 1);
          final dest = File('${toDir.path}/$relative');
          if (await dest.exists()) {
            continue;
          }
          await dest.parent.create(recursive: true);
          try {
            try {
              await entity.rename(dest.path);
            } catch (_) {
              await entity.copy(dest.path);
              await entity.delete();
            }
          } catch (e) {
            logger.output('[settings] cache move failed for ${entity.path}: $e');
          }
        }
      }
    }
  }

  Widget listeningReportListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(frequentlyImage, size: iconSize),
      title: Text(l10n.listeningReport),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const StatsPage()),
        );
      },
    );
  }

  Widget homeLayoutListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(optionImage, size: iconSize),
      title: Text(l10n.homeLayout),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const HomeLayoutSettings()),
        );
      },
    );
  }

  Widget serversListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(optionImage, size: iconSize),
      title: Text(l10n.servers),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const ServerListPage()),
        );
      },
    );
  }

  Widget languageListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(languageImage, size: iconSize),
      title: Text(l10n.language),
      onTap: () {
        showAnimationDialog(
          context: context,

          child: SizedBox(
            width: 300,
            height: isMobile ? 200 : 180,
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: ValueListenableBuilder(
                valueListenable: localeNotifier,
                builder: (context, value, child) {
                  final l10n = AppLocalizations.of(context);

                  return ListView(
                    children: [
                      ListTile(
                        title: Text(l10n.followSystem),
                        onTap: () {
                          localeNotifier.value = null;
                          setting.save();
                        },
                        trailing: value == null ? Icon(Icons.check) : null,
                      ),
                      ListTile(
                        title: Text('English'),
                        onTap: () {
                          localeNotifier.value = Locale('en');
                          setting.save();
                        },
                        trailing: value == Locale('en')
                            ? Icon(Icons.check)
                            : null,
                      ),
                      ListTile(
                        title: Text('中文'),
                        onTap: () {
                          localeNotifier.value = Locale('zh');
                          setting.save();
                        },
                        trailing: value == Locale('zh')
                            ? Icon(Icons.check)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget controlCenterLyricsListTile(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(desktopLyricsImage, size: iconSize),
      // The same stored flag as before (see `controlCenterLyricsNotifier`):
      // on, the head unit's primary line carries the lyric and the secondary
      // one carries "<< artist - title >>"; off, it gets plain track metadata
      // and no lyric updates at all.
      title: Text(l10n.broadcastLyrics),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: controlCenterLyricsNotifier,
          onToggleCallBack: () {
            setting.save();
            audioHandler.refreshServiceMediaItem();
          },
        ),
      ),
    );
  }

  Widget vibrationListTile(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(vibrationImage, size: iconSize),
      title: Text(l10n.vibration),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: vibrationOnNoitifier,
          onToggleCallBack: () {
            setting.save();
          },
        ),
      ),
    );
  }

  void _updateMainPageTheme() {
    setting.save();
    colorManager.updateMainPageColors();
  }

  void _updateLyricsPageTheme() {
    setting.save();
    colorManager.updateLyricsPageColors();
  }

  Widget fontListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(fontImage, size: iconSize),

      title: Text(l10n.fonts),
      onTap: () {
        if (!isPremiumNotifier.value) {
          showPremiumDialog(context);
          return;
        }
        layersManager.pushDetail('settings', 'font_picker');
      },
      trailing: ValueListenableBuilder(
        valueListenable: isPremiumNotifier,
        builder: (context, value, child) {
          if (value) {
            return SizedBox.shrink();
          }
          return Icon(Icons.lock);
        },
      ),
    );
  }

  Widget coverBroadcastListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.album_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.coverBroadcast),
      trailing: ValueListenableBuilder(
        valueListenable: coverBroadcastModeNotifier,
        builder: (context, mode, child) {
          return Text('${coverModeLabel(l10n, mode)}  ');
        },
      ),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Builder(
                builder: (context) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final mode in CoverBroadcastMode.values)
                        ListTile(
                          title: Text(coverModeLabel(l10n, mode)),
                          trailing: coverBroadcastModeNotifier.value == mode
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            coverBroadcastModeNotifier.value = mode;
                            setting.save();
                            audioHandler.refreshServiceMediaItem();
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Lets the user pick which of the phone's private addresses the head unit
  /// should fetch the relay from. A phone can have several (Wi-Fi, hotspot,
  /// VPN, cellular) and the car can only reach some of them.
  Widget relayAddressListTile(BuildContext context, AppLocalizations l10n) {
    return ValueListenableBuilder(
      valueListenable: relayAddressNotifier,
      builder: (context, address, child) {
        final resolved = streamRelay.lanBaseUrl;
        final label = address.isEmpty
            ? '${l10n.relayAddressAuto}${resolved == null ? '' : ' · ${Uri.tryParse(resolved)?.host ?? resolved}'}'
            : address;
        return ListTile(
          leading: Icon(
            Icons.lan_outlined,
            size: iconSize,
            color: iconColor.value,
          ),
          title: Text(l10n.relayAddress),
          trailing: Text('$label  '),
          onTap: () async {
            final candidates = await streamRelay.discoverLanAddresses();
            if (!context.mounted) {
              return;
            }
            final choice = await showAnimationDialog<String>(
              context: context,
              child: SizedBox(
                width: 320,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (dialogContext) => ListTile(
                          title: Text(l10n.relayAddressAuto),
                          trailing: relayAddressNotifier.value.isEmpty
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(dialogContext, ''),
                        ),
                      ),
                      for (final candidate in candidates)
                        Builder(
                          builder: (dialogContext) => ListTile(
                            title: Text(
                              '${candidate.interfaceName} · ${candidate.address}',
                            ),
                            trailing: relayAddressNotifier.value ==
                                    candidate.address
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () =>
                                Navigator.pop(dialogContext, candidate.address),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
            if (choice == null) {
              return;
            }
            relayAddressNotifier.value = choice;
            setting.save();
            streamRelay.invalidateLanAddress();
            unawaited(streamRelay.warmUp());
            audioHandler.refreshServiceMediaItem();
          },
        );
      },
    );
  }

  Widget themeListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(themeImage, size: iconSize),
      title: Text(l10n.theme),
      onTap: () async {
        mainPageThemeNotifier.addListener(_updateMainPageTheme);
        lyricsPageThemeNotifier.addListener(_updateLyricsPageTheme);
        await showAnimationDialog(
          context: context,

          child: OrientationBuilder(
            builder: (context, orientation) {
              final size = MediaQuery.of(context).size;
              final shortSide = size.shortestSide;

              bool isPhone = shortSide < 600;

              return SizedBox(
                width: 300,
                height: isPhone && orientation == .landscape
                    ? 350
                    : isMobile
                    ? 420
                    : 370,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: CustomScrollView(
                    scrollBehavior: ScrollBehavior().copyWith(
                      scrollbars: false,
                    ),
                    slivers: [
                      sliverBox(
                        ValueListenableBuilder(
                          valueListenable: mainPageThemeNotifier,
                          builder: (context, value, child) {
                            final l10n = AppLocalizations.of(context);
                            return Column(
                              children: [
                                Text(
                                  l10n.mainPageTheme,
                                  style: .new(fontSize: 18, fontWeight: .bold),
                                ),
                                ListTile(
                                  title: Text(l10n.vividMode),
                                  onTap: () {
                                    if (!isPremiumNotifier.value) {
                                      showPremiumDialog(context);
                                      return;
                                    }
                                    mainPageThemeNotifier.value = .vivid;
                                    updateHoverFocusColor();
                                  },
                                  trailing: ValueListenableBuilder(
                                    valueListenable: isPremiumNotifier,
                                    builder: (context, isPremium, child) {
                                      if (!isPremium) {
                                        return Icon(Icons.lock);
                                      }
                                      return value == .vivid
                                          ? Icon(Icons.check)
                                          : SizedBox.shrink();
                                    },
                                  ),
                                ),
                                ListTile(
                                  title: Text(l10n.lightMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = .light;
                                    updateHoverFocusColor();
                                  },
                                  trailing: value == .light
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  title: Text(l10n.darkMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = .dark;
                                    updateHoverFocusColor();
                                  },
                                  trailing: value == .dark
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      sliverBox(
                        ValueListenableBuilder(
                          valueListenable: lyricsPageThemeNotifier,
                          builder: (context, value, child) {
                            final l10n = AppLocalizations.of(context);
                            return Column(
                              children: [
                                Text(
                                  l10n.lyricsPageTheme,
                                  style: .new(fontSize: 18, fontWeight: .bold),
                                ),
                                ListTile(
                                  title: Text(l10n.vividMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = .vivid;
                                  },
                                  trailing: value == .vivid
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  title: Text(l10n.lightMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = .light;
                                  },
                                  trailing: value == .light
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  title: Text(l10n.darkMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = .dark;
                                  },
                                  trailing: value == .dark
                                      ? Icon(Icons.check)
                                      : null,
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
          ),
        );
        mainPageThemeNotifier.removeListener(_updateMainPageTheme);
        lyricsPageThemeNotifier.removeListener(_updateLyricsPageTheme);
      },
    );
  }

  Widget equalizerListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(equalizerImage, size: iconSize),
      title: Text(l10n.equalizer),
      onTap: () {
        if (!isPremiumNotifier.value) {
          showPremiumDialog(context);
          return;
        }
        showAnimationDialog(
          context: context,
          child: OrientationBuilder(
            builder: (context, orientation) {
              final size = MediaQuery.of(context).size;
              final shortSide = size.shortestSide;

              bool isPhone = shortSide < 600;
              if (isMobile && orientation == .portrait) {
                return SizedBox(
                  height: 500,
                  width: isPhone ? 300 : 400,
                  child: EqualizerWidget(),
                );
              } else {
                return SizedBox(
                  height: isPhone ? 350 : 400,
                  width: 540,
                  child: EqualizerWidget(),
                );
              }
            },
          ),
        );
      },
      trailing: ValueListenableBuilder(
        valueListenable: isPremiumNotifier,
        builder: (context, value, child) {
          if (value) {
            return SizedBox.shrink();
          }
          return Icon(Icons.lock);
        },
      ),
    );
  }

  String _replayGainLabel(AppLocalizations l10n, ReplayGainMode mode) {
    return replayGainLabel(l10n, mode);
  }

  /// Loudness tags in the files: off, per track, or per album.
  Widget replayGainListTile(BuildContext context, AppLocalizations l10n) {
    return ValueListenableBuilder<ReplayGainMode>(
      valueListenable: replayGainModeNotifier,
      builder: (context, mode, child) {
        return ListTile(
          leading: Icon(
            Icons.hearing_rounded,
            size: iconSize,
            color: iconColor.value,
          ),
          title: Text(l10n.replayGain),
          subtitle: Text(_replayGainLabel(l10n, mode)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () => showReplayGainDialog(context),
        );
      },
    );
  }

  /// Playback rate. The player applies a change immediately, so a track that
  /// is already playing is not restarted.
  Widget playbackSpeedListTile(BuildContext context, AppLocalizations l10n) {
    return ValueListenableBuilder<double>(
      valueListenable: playbackSpeedNotifier,
      builder: (context, speed, child) {
        return ListTile(
          leading: Icon(
            Icons.speed_rounded,
            size: iconSize,
            color: iconColor.value,
          ),
          title: Text(l10n.playbackSpeed),
          subtitle: Text(playbackSpeedLabel(speed)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () => showPlaybackSpeedDialog(context),
        );
      },
    );
  }

  Widget gaplessListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.link_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.gaplessPlayback),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: gaplessPlaybackNotifier,
          onToggleCallBack: () {
            if (gaplessPlaybackNotifier.value &&
                trackTransitionModeNotifier.value != TrackTransitionMode.off) {
              trackTransitionModeNotifier.value = TrackTransitionMode.off;
            }
            setting.save();
            setState(() {});
          },
        ),
      ),
    );
  }

  String _transitionLabel(
    AppLocalizations l10n,
    TrackTransitionMode mode,
  ) {
    return switch (mode) {
      TrackTransitionMode.off => l10n.transitionOff,
      TrackTransitionMode.fixed => l10n.transitionFixed,
      TrackTransitionMode.adaptive => l10n.transitionAdaptive,
    };
  }

  Widget trackTransitionListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        trackTransitionModeNotifier,
        trackTransitionSecondsNotifier,
      ]),
      builder: (context, child) {
        final mode = trackTransitionModeNotifier.value;
        final seconds = trackTransitionSecondsNotifier.value;
        return ListTile(
          leading: Icon(
            Icons.compare_arrows_rounded,
            size: iconSize,
            color: iconColor.value,
          ),
          title: Text(l10n.trackTransition),
          trailing: Text(
            mode == TrackTransitionMode.fixed
                ? '${_transitionLabel(l10n, mode)} · ${seconds}s  '
                : '${_transitionLabel(l10n, mode)}  ',
            style: TextStyle(
              fontSize: 13,
              color: colorManager.getSpecificTextColor().withAlpha(170),
            ),
          ),
          onTap: () async {
            final choice = await showAnimationDialog<TrackTransitionMode>(
              context: context,
              child: SizedBox(
                width: 300,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final value in TrackTransitionMode.values)
                        Builder(
                          builder: (dialogContext) => ListTile(
                            title: Text(_transitionLabel(l10n, value)),
                            trailing: mode == value
                                ? const Icon(Icons.check_rounded)
                                : null,
                            onTap: () => Navigator.pop(dialogContext, value),
                          ),
                        ),
                      if (mode == TrackTransitionMode.fixed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Row(
                            children: [
                              Text(
                                l10n.transitionSeconds,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const Spacer(),
                              DropdownButton<int>(
                                value: seconds,
                                underline: const SizedBox.shrink(),
                                items: [
                                  for (final value in const [2, 4, 6, 8, 10, 12])
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text('$value s'),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  trackTransitionSecondsNotifier.value = value;
                                  setting.save();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
            if (choice == null) {
              return;
            }
            trackTransitionModeNotifier.value = choice;
            if (choice != TrackTransitionMode.off) {
              // A long fade and gapless cannot run together.
              gaplessPlaybackNotifier.value = false;
            }
            setting.save();
            if (mounted) {
              setState(() {});
            }
          },
        );
      },
    );
  }

  Widget transitionSecondsListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        trackTransitionModeNotifier,
        trackTransitionSecondsNotifier,
      ]),
      builder: (context, child) {
        if (trackTransitionModeNotifier.value != TrackTransitionMode.fixed) {
          return const SizedBox.shrink();
        }
        return ListTile(
          leading: Icon(
            Icons.timer_outlined,
            size: iconSize,
            color: iconColor.value,
          ),
          title: Text(l10n.transitionSeconds),
          trailing: Text(
            '${trackTransitionSecondsNotifier.value}s  ',
            style: TextStyle(
              fontSize: 13,
              color: colorManager.getSpecificTextColor().withAlpha(170),
            ),
          ),
          onTap: () async {
            final choice = await showAnimationDialog<int>(
              context: context,
              child: SizedBox(
                width: 280,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final value in const [2, 4, 6, 8, 10, 12])
                        Builder(
                          builder: (dialogContext) => ListTile(
                            title: Text('$value s'),
                            subtitle: Text(
                              '${value ~/ 2}s + ${value ~/ 2}s',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing:
                                trackTransitionSecondsNotifier.value == value
                                ? const Icon(Icons.check_rounded)
                                : null,
                            onTap: () => Navigator.pop(dialogContext, value),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
            if (choice == null) {
              return;
            }
            trackTransitionSecondsNotifier.value = choice;
            setting.save();
            if (mounted) {
              setState(() {});
            }
          },
        );
      },
    );
  }

  Widget audioFadeListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.volume_up_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.audioFade),
      subtitle: Text(l10n.audioFadeDescription),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: audioFadeNotifier,
          onToggleCallBack: () => setting.save(),
        ),
      ),
    );
  }

  Widget carDisplayListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.directions_car_filled_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.carDisplay),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const CarDisplaySettingsPage()),
        );
      },
    );
  }

  Widget personalScrobbleListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: Icon(
        Icons.history_toggle_off_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.personalScrobble),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const PersonalScrobblePage()),
        );
      },
    );
  }

  Widget playbackReportListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.cloud_upload_outlined,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.playbackReport),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: reportPlaybackProgressNotifier,
          onToggleCallBack: () => setting.save(),
        ),
      ),
    );
  }

  /// How this app shares the output device with other apps. The subtitle shows
  /// the mode in effect, so leaving the page needs no second look.
  Widget playbackModeListTile(BuildContext context, AppLocalizations l10n) {
    return ValueListenableBuilder<AudioPlaybackMode>(
      valueListenable: playbackModeNotifier,
      builder: (context, mode, child) {
        return ListTile(
          leading: Icon(
            Icons.graphic_eq_rounded,
            size: iconSize,
            color: iconColor.value,
          ),
          title: Text(l10n.playbackMode),
          subtitle: Text(PlaybackModePage.modeLabel(l10n, mode)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () {
            pushSettingsPage<void>(
              context,
              settingsPageRoute<void>(() => const PlaybackModePage()),
            );
          },
        );
      },
    );
  }

  Widget shareCardSettingsListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: Icon(
        Icons.photo_size_select_large_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.shareCardSettings),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () {
        pushSettingsPage<void>(
          context,
          settingsPageRoute<void>(() => const ShareCardSettingsPage()),
        );
      },
    );
  }

  Widget lyricsCoverMotionListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Icon(
        Icons.animation_rounded,
        size: iconSize,
        color: iconColor.value,
      ),
      title: Text(l10n.lyricsCoverMotion),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: lyricsCoverMotionNotifier,
          onToggleCallBack: () => setting.save(),
        ),
      ),
    );
  }

  Widget immersiveWideLayoutListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Transform.scale(
        scale: 0.9,
        child: ImageIcon(fullscreenImage, size: iconSize),
      ),

      title: Text(l10n.immersiveWideLayout),
      trailing: SizedBox(
        width: 50,
        child: Builder(
          builder: (context) {
            return MySwitch(
              valueNotifier: immersiveWideLayoutNotifier,
              onToggleCallBack: () {
                if (!isTooNarrow(context)) {
                  applyWideLayoutSystemUiMode();
                }
                setting.save();
              },
            );
          },
        ),
      ),
    );
  }

  // 宽布局关闭沉浸模式时才显示，分别控制顶/底系统条
  Widget wideSystemBarListTile(AppLocalizations l10n, {required bool top}) {
    return ValueListenableBuilder(
      valueListenable: immersiveWideLayoutNotifier,
      builder: (context, immersive, child) {
        if (immersive) {
          return const SizedBox.shrink();
        }
        return child!;
      },
      child: ListTile(
        leading: Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Icon(
            top ? Icons.border_top : Icons.border_bottom,
            size: iconSize,
            color: iconColor.value,
          ),
        ),
        title: Text(
          top ? l10n.wideShowTopSystemBar : l10n.wideShowBottomSystemBar,
        ),
        trailing: SizedBox(
          width: 50,
          child: Builder(
            builder: (context) {
              return MySwitch(
                valueNotifier: top
                    ? wideShowTopSystemBarNotifier
                    : wideShowBottomSystemBarNotifier,
                onToggleCallBack: () {
                  if (!isTooNarrow(context)) {
                    applyWideLayoutSystemUiMode();
                  }
                  setting.save();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget autoPlayOnStartupListTile(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(playOutlinedImage, size: iconSize),

      title: Text(l10n.autoPlayOnStartup),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: autoPlayOnStartupNotifier,
          onToggleCallBack: () {
            setting.save();
          },
        ),
      ),
    );
  }

  Widget exitOnClose(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(powerOffImage),

      title: Text(l10n.closeAction),
      trailing: SizedBox(
        width: 150,
        child: Row(
          children: [
            Spacer(),
            MySwitch(
              trueText: l10n.exit,
              falseText: l10n.hide,
              valueNotifier: exitOnCloseNotifier,
              onToggleCallBack: () {
                setting.save();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget checkUpdate(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(checkUpdateImage, size: iconSize),
      title: Text(l10n.checkUpdate),
      onTap: () async {
        final url = Uri.parse(
          'https://api.github.com/repos/me1dlinger/lain/releases/latest',
        );

        try {
          final response = await http
              .get(url)
              .timeout(const Duration(seconds: 3));
          if (response.statusCode != 200) {
            if (context.mounted) {
              showCenterMessage(
                'Failed to fetch GitHub release:${response.statusCode}',
              );
            }
            return;
          }
          final data = jsonDecode(response.body);
          String latestVersion = (data['tag_name'] as String).replaceFirst(
            'v',
            '',
          );
          if (compareVersion(latestVersion, versionNumber) > 0) {
            if (context.mounted) {
              showAnimationDialog(
                context: context,

                child: SizedBox(
                  height: isMobile ? 350 : 400,
                  width: isMobile ? 320 : 400,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: ListView(
                              children: [
                                Center(
                                  child: Text(
                                    data['tag_name'] as String,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: .bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),

                                Text(data['body'] as String),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        ValueListenableBuilder(
                          valueListenable: buttonColor.valueNotifier,
                          builder: (context, value, child) {
                            return Row(
                              children: [
                                Spacer(),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: value,
                                  ),
                                  child: Text(l10n.cancel),
                                ),
                                SizedBox(width: 20),
                                ElevatedButton(
                                  onPressed: () => launchUrl(
                                    Uri.parse(
                                      "https://github.com/me1dlinger/lain/releases/latest",
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: value,
                                  ),
                                  child: Text(l10n.go2Download),
                                ),
                                Spacer(),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          } else {
            if (context.mounted) {
              showCenterMessage(l10n.alreadyLatest);
            }
          }
        } catch (e) {
          if (context.mounted) {
            showCenterMessage(
              'Failed to fetch GitHub release:$e',
              duration: 5000,
            );
          }
        }
      },
    );
  }

  Widget viewLogListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(exportLogImage, size: iconSize),

      title: Text(l10n.viewLog),
      onTap: () async {
        showAnimationDialog(
          context: context,
          child: Builder(
            builder: (context) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.heightOf(context) * 0.75,
                  maxWidth: isTooNarrow(context) ? 300 : 400,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(logger.logContent),
                        ),
                      ),
                      SizedBox(height: 20),
                      if (isMobile)
                        ValueListenableBuilder(
                          valueListenable: buttonColor.valueNotifier,
                          builder: (context, value, child) {
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor.value,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.all(10),
                              ),
                              onPressed: () async {
                                String? result;
                                if (Platform.isAndroid) {
                                  result = await FilePicker.getDirectoryPath();
                                  if (result == null) {
                                    return;
                                  }
                                  logger.export2Directory(result);
                                  if (context.mounted) {
                                    showCenterMessage('Export to $result');
                                  }
                                } else {
                                  result = '${appDocsDir.path}/logs';
                                  logger.export2Directory(result);
                                  showCenterMessage('Export to Lain/logs');
                                }
                              },
                              child: Text(l10n.exportLog),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String streamQualityLabel(AppLocalizations l10n, StreamQuality quality) {
  switch (quality) {
    case StreamQuality.standard:
      return l10n.streamQualityStandard;
    case StreamQuality.high:
      return l10n.streamQualityHigh;
    case StreamQuality.hq:
      return l10n.streamQualityHq;
    case StreamQuality.sq:
      return l10n.streamQualitySq;
    case StreamQuality.original:
      return l10n.streamQualityOriginal;
  }
}

String _cacheMb(Iterable<CacheEntry> entries) {
  var bytes = 0;
  for (final entry in entries) {
    bytes += entry.size;
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

String _cacheKindLabel(AppLocalizations l10n, CacheKind kind) {
  switch (kind) {
    case CacheKind.song:
      return l10n.cacheSongs;
    case CacheKind.cover:
      return l10n.cacheCovers;
    case CacheKind.lyric:
      return l10n.cacheLyrics;
    case CacheKind.list:
      return l10n.cacheLists;
  }
}

/// Cache contents of the current source, in tabs: the cached songs, how much of
/// each playlist is cached, and the artists (songs and cover). One place to see
/// what is on disk, and to precache or clear it.
Future<void> showCacheDetailDialog(
  BuildContext context,
  AppLocalizations l10n,
) async {
  if (Loader.busy) {
    showCenterMessage(l10n.syncLibrary);
    return;
  }
  await library.refreshCache();
  if (!context.mounted) {
    return;
  }

  showAnimationDialog(context: context, child: const _CacheDetailView());
}

class _CacheDetailView extends StatefulWidget {
  const _CacheDetailView();

  @override
  State<_CacheDetailView> createState() => _CacheDetailViewState();
}

class _CacheDetailViewState extends State<_CacheDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  Timer? _cacheRefreshDebounce;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    cacheSizeNotifier.addListener(_onCacheSizeChanged);
    // The listing used to be rebuilt only when a download or precache run
    // finished, so the MB total was whatever it had been when the view opened.
    unawaited(_refreshCache());
  }

  Future<void> _refreshCache() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      await library.refreshCache();
    } finally {
      _refreshing = false;
    }
  }

  void _onCacheSizeChanged() {
    // One scan per burst of downloads: songs finish one after another, and
    // rescanning the cache directory for each of them is pointless.
    _cacheRefreshDebounce?.cancel();
    _cacheRefreshDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_refreshCache());
    });
  }

  @override
  void dispose() {
    cacheSizeNotifier.removeListener(_onCacheSizeChanged);
    _cacheRefreshDebounce?.cancel();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 360,
      height: 520,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 30,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.cacheDetails,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: cacheEntriesNotifier,
                    builder: (context, entries, child) {
                      return Text(
                        '${entries.length} - ${_cacheMb(entries)}',
                        style: const TextStyle(fontSize: 12),
                      );
                    },
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: precacheProgressNotifier,
                  builder: (context, progress, child) {
                    if (progress == null) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      '${progress.$1}/${progress.$2}',
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ],
            ),
            ValueListenableBuilder(
              valueListenable: precacheProgressNotifier,
              builder: (context, progress, child) {
                if (progress == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LinearProgressIndicator(
                    value: progress.$2 == 0 ? null : progress.$1 / progress.$2,
                  ),
                );
              },
            ),
            TabBar(
              controller: _tab,
              tabs: [
                Tab(text: l10n.songUnit),
                Tab(text: l10n.playlists),
                Tab(text: l10n.artists),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _songsTab(l10n),
                  _playlistsTab(l10n),
                  _artistsTab(l10n),
                ],
              ),
            ),
            const Divider(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  if (!await showConfirmDialog(context, l10n.clear)) {
                    return;
                  }
                  showCenterLoading();
                  layersManager.clearDataLayers();
                  audioHandler.clear(notifyUndo: false);
                  await library.clearCache();
                  await library.clearPicture();
                  await library.clearLrcCache();
                  playlistManager.updateNotifier.value++;
                  removeCenterLoading();
                },
                child: Text(l10n.clear),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _songsTab(AppLocalizations l10n) {
    return ValueListenableBuilder(
      valueListenable: cacheEntriesNotifier,
      builder: (context, entries, child) {
        final songs = groupCacheBySong(entries);
        return Column(
          children: [
            Expanded(
              child: songs.isEmpty
                  ? Center(child: Text(l10n.cacheEmpty))
                  : ListView(
                      children: [
                        for (final cached in songs)
                          _cachedSongTile(context, l10n, cached),
                      ],
                    ),
            ),
            // Scoped to this tab: it caches the whole library's artwork and
            // lyrics, but it is a song action, not a page-wide one.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  if (!await showConfirmDialog(context, l10n.precacheAll)) {
                    return;
                  }
                  // The progress bar above the tabs reports this; the old
                  // blocking spinner is what made the button feel stuck.
                  unawaited(library.precacheSongs(library.songList));
                },
                child: Text(l10n.precacheAll),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _playlistsTab(AppLocalizations l10n) {
    return ValueListenableBuilder(
      valueListenable: cacheEntriesNotifier,
      builder: (context, entries, child) {
        final playlists = playlistManager.playlists
            .where((playlist) => playlist.name != '_lain_play_queue_')
            .toList();
        if (playlists.isEmpty) {
          return Center(child: Text(l10n.cacheEmpty));
        }
        return ListView(
          children: [
            for (final playlist in playlists)
              // Downloads the songs themselves: this button is the playlist's
              // "make it available offline", not a metadata warm-up.
              _cacheGroupTile(
                l10n: l10n,
                title: playlist.name,
                songs: playlist.songList,
              ),
          ],
        );
      },
    );
  }

  Widget _artistsTab(AppLocalizations l10n) {
    return ValueListenableBuilder(
      valueListenable: cacheEntriesNotifier,
      builder: (context, entries, child) {
        // Only artists that actually have something cached: a list of every
        // artist, mostly without a cover, is not a cache view.
        final artists = artistAlbumManager.artistList.where((artist) {
          final info = artistInfoCache[artistKey(artist.name)];
          return MyPicture.artistExists(artist.name) ||
              (info != null &&
                  ((info.biography ?? '').isNotEmpty ||
                      (info.imageUrl ?? '').isNotEmpty));
        }).toList();
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  if (!await showConfirmDialog(
                    context,
                    l10n.clearArtistsCache,
                  )) {
                    return;
                  }
                  await clearArtistInfoCache();
                  setState(() {});
                  showCenterMessage(l10n.clearSuccess);
                },
                child: Text(l10n.clearArtistsCache),
              ),
            ),
            Expanded(
              child: artists.isEmpty
                  ? Center(child: Text(l10n.cacheEmpty))
                  : ListView(
                      children: [
                        for (final artist in artists)
                          _cacheGroupTile(
                            l10n: l10n,
                            title: artist.name,
                            songs: artist.songList,
                            coverCached: MyPicture.artistExists(artist.name),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  /// A row for a playlist or an artist: how many of its songs (and, when it has
  /// one, its cover) are cached, and a button to cache them all.
  Widget _cacheGroupTile({
    required AppLocalizations l10n,
    required String title,
    required List<MyAudioMetadata> songs,
    bool? coverCached,
  }) {
    final cachedSongs = songs.where((song) => song.cacheExist).length;
    final parts = <String>[
      '${l10n.songCount(cachedSongs)} / ${l10n.songCount(songs.length)}',
      if (coverCached == true) l10n.cacheTagCover,
    ];
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(parts.join(' - ')),
      trailing: IconButton(
        tooltip: l10n.precacheAll,
        icon: const Icon(Icons.download_rounded),
        onPressed: () async {
          if (!await showConfirmDialog(context, l10n.precacheAll)) {
            return;
          }
          if (!mounted) {
            return;
          }
          await showCacheDownloadDialog(context, songs);
        },
      ),
    );
  }
}

/// One cached song: what is on disk (song / cover / lyrics), how big it is, a
/// detail view, and a delete that asks first.
Widget _cachedSongTile(
  BuildContext context,
  AppLocalizations l10n,
  CachedSong cached,
) {
  final cover = cached.cover;
  return ListTile(
    dense: true,
    visualDensity: VisualDensity.compact,
    leading: cover == null
        ? const Icon(Icons.music_note, size: 20)
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(cover.path),
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  const Icon(Icons.music_note, size: 20),
            ),
          ),
    title: Text(
      getTitle(cached.song),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      '${_cachedTags(l10n, cached)} · '
      '${(cached.size / (1024 * 1024)).toStringAsFixed(1)}MB',
    ),
    onTap: () => showCachedSongDialog(context, l10n, cached),
    trailing: IconButton(
      tooltip: l10n.removeCache,
      icon: const Icon(Icons.delete_outline),
      onPressed: () async {
        if (!await showConfirmDialog(context, l10n.removeCache)) {
          return;
        }
        await library.deleteCachedSong(cached);
      },
    ),
  );
}

/// Which parts of a song are cached, as short tags - only the ones present.
String _cachedTags(AppLocalizations l10n, CachedSong cached) {
  final tags = <String>[
    if (cached.hasCover) l10n.cacheTagCover,
    if (cached.hasLyric) l10n.cacheTagLyric,
    if (cached.hasAudio) l10n.cacheTagAudio,
  ];
  return tags.isEmpty ? l10n.cacheEmpty : tags.join(' · ');
}

/// What one cached song actually holds: the cover image and the lyrics.
Future<void> showCachedSongDialog(
  BuildContext context,
  AppLocalizations l10n,
  CachedSong cached,
) async {
  final cover = cached.cover;
  final lyric = cached.lyric;

  var lyrics = '';
  if (lyric != null) {
    final file = File(lyric.path);
    if (await file.exists()) {
      lyrics = await file.readAsString();
    }
  }
  if (!context.mounted) {
    return;
  }

  showAnimationDialog(
    context: context,
    child: SizedBox(
      width: 340,
      height: 460,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              getTitle(cached.song),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              getArtist(cached.song),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (cover != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(cover.path),
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const SizedBox(
                    height: 160,
                    child: Icon(Icons.broken_image),
                  ),
                ),
              )
            else
              Text('${l10n.cacheTagCover}: -'),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  lyrics.isEmpty ? l10n.noLyrics : lyrics,
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String coverModeLabel(AppLocalizations l10n, CoverBroadcastMode mode) {
  return switch (mode) {
    CoverBroadcastMode.bitmap => l10n.coverBroadcastBitmap,
    CoverBroadcastMode.server => l10n.coverBroadcastServer,
    CoverBroadcastMode.relay => l10n.coverBroadcastRelay,
    CoverBroadcastMode.content => l10n.coverBroadcastContent,
    CoverBroadcastMode.auto => l10n.coverBroadcastAuto,
    CoverBroadcastMode.relayOriginal => l10n.coverBroadcastRelayOriginal,
  };
}
