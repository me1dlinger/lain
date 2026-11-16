import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/cache_download_settings.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/download_manager.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/utils/path.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/dashboard_widgets.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// What the current streamed source has on disk: cached audio, covers and
/// lyrics, downloads, and how much of the cache limit is used.
class CacheStorageDashboardPage extends StatefulWidget {
  const CacheStorageDashboardPage({super.key});

  @override
  State<CacheStorageDashboardPage> createState() =>
      _CacheStorageDashboardPageState();
}

class _CacheStorageDashboardPageState extends State<CacheStorageDashboardPage> {
  @override
  void initState() {
    super.initState();
    unawaited(library.refreshCache());
    downloadManager.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return opaqueSettingsPage(
      context: context,
      title: l10n.cacheStorageStats,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          cacheEntriesNotifier,
          downloadsNotifier,
          downloadTasksNotifier,
          cacheLimitGbNotifier,
          downloadDirNotifier,
        ]),
        builder: (context, child) {
          final entries = cacheEntriesNotifier.value;
          final songs = groupCacheBySong(entries);
          final textColor = colorManager.getSpecificTextColor();

          int sizeOf(CacheKind kind) => entries
              .where((entry) => entry.kind == kind)
              .fold<int>(0, (sum, entry) => sum + entry.size);
          final audioBytes = sizeOf(CacheKind.song);
          final coverBytes = sizeOf(CacheKind.cover);
          final lyricBytes = sizeOf(CacheKind.lyric);
          final listBytes = sizeOf(CacheKind.list);
          final total = audioBytes + coverBytes + lyricBytes + listBytes;

          final downloads = downloadsNotifier.value;
          final downloadBytes = downloads.fold<int>(
            0,
            (sum, item) => sum + item.bytes,
          );
          final tasks = downloadTasksNotifier.value;
          final downloading = tasks
              .where((task) => task.state == DownloadTaskState.downloading)
              .length;
          final waiting = tasks
              .where((task) => task.state == DownloadTaskState.waitingForWifi)
              .length;
          final paused = tasks
              .where((task) => task.state == DownloadTaskState.paused)
              .length;
          final failed = tasks
              .where((task) => task.state == DownloadTaskState.failed)
              .length;

          final limitGb = cacheLimitGbNotifier.value;
          final limitBytes = limitGb * 1024 * 1024 * 1024;
          final usage = limitBytes <= 0
              ? 0.0
              : (total / limitBytes).clamp(0.0, 1.0);
          final accent = colorManager.getSpecificIconColor();

          return ListView(
            padding: const EdgeInsets.only(top: 6, bottom: 130),
            children: [
              DashboardCard(
                child: Row(
                  children: [
                    AnimatedRing(
                      size: 132,
                      strokeWidth: 14,
                      segments: [
                        RingSegment(
                          label: 'audio',
                          value: audioBytes.toDouble(),
                          color: accent,
                        ),
                        RingSegment(
                          label: 'cover',
                          value: coverBytes.toDouble(),
                          color: const Color(0xFF6FA8C6),
                        ),
                        RingSegment(
                          label: 'lyric',
                          value: lyricBytes.toDouble(),
                          color: const Color(0xFFD9AE3C),
                        ),
                        RingSegment(
                          label: 'other',
                          value: listBytes.toDouble(),
                          color: textColor.withAlpha(55),
                        ),
                      ],
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dashboardSize(total),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            l10n.cacheStorageStats,
                            style: TextStyle(
                              fontSize: 10,
                              color: textColor.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _heroStat(
                            l10n.cacheSongs,
                            '${songs.length}',
                            textColor,
                          ),
                          _heroStat(
                            l10n.downloadedFiles,
                            '${downloads.length} · ${dashboardSize(downloadBytes)}',
                            textColor,
                          ),
                          _heroStat(
                            l10n.cacheLimit,
                            limitGb == 0
                                ? l10n.cacheLimitUnlimited
                                : l10n.cacheLimitGb(limitGb),
                            textColor,
                          ),
                          _heroStat(
                            l10n.cacheUsage,
                            '${(usage * 100).round()}%',
                            textColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              appleSectionTitle(l10n.storageBreakdown),
              DashboardCard(
                child: Column(
                  children: [
                    AnimatedMetricBar(
                      label: l10n.cacheAudio,
                      value: dashboardSize(audioBytes),
                      fraction: total == 0 ? 0 : audioBytes / total,
                      color: accent,
                    ),
                    AnimatedMetricBar(
                      label: l10n.cacheCovers,
                      value: dashboardSize(coverBytes),
                      fraction: total == 0 ? 0 : coverBytes / total,
                      color: const Color(0xFF6FA8C6),
                    ),
                    AnimatedMetricBar(
                      label: l10n.cacheLyrics,
                      value: dashboardSize(lyricBytes),
                      fraction: total == 0 ? 0 : lyricBytes / total,
                      color: const Color(0xFFD9AE3C),
                    ),
                    AnimatedMetricBar(
                      label: l10n.cacheOther,
         
                      value: dashboardSize(listBytes),
                      fraction: total == 0 ? 0 : listBytes / total,
                      color: textColor.withAlpha(70),
                    ),
                  ],
                ),
              ),
              appleSectionTitle(l10n.activeTasks),
              DashboardCard(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _taskPill(
                      l10n.downloadStateDownloading,
                      downloading,
                      textColor,
                    ),
                    _taskPill(
                      l10n.downloadStateWaitingWifi,
                      waiting,
                      textColor,
                    ),
                    _taskPill(l10n.downloadStatePaused, paused, textColor),
                    _taskPill(l10n.downloadStateFailed, failed, textColor),
                  ],
                ),
              ),
              appleSectionTitle(l10n.largestCached),
              DashboardCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: songs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          l10n.cacheEmpty,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withAlpha(150),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final cached in songs.take(6))
                            ListTile(
                              leading: CoverArtWidget(
                                size: 42,
                                borderRadius: 6,
                                picture: cached.song.picture,
                              ),
                              title: Text(
                                getTitle(cached.song),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                              subtitle: Text(
                                '${getArtist(cached.song)} · '
                                '${getAlbum(cached.song)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textColor.withAlpha(150),
                                ),
                              ),
                              trailing: Text(
                                dashboardSize(cached.size),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor.withAlpha(160),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              appleSectionTitle(l10n.storageLocation),
              DashboardCard(
                child: Column(
                  children: [
                    _pathRow(
                      l10n.cacheStorageStats,
                      getCacheRootPath(sourceType),
                      textColor,
                    ),
                    const SizedBox(height: 8),
                    _pathRow(
                      l10n.downloads,
                      downloadDirNotifier.value.trim().isEmpty
                          ? '${appDocsDir.path}/$downloadFolderName'
                          : downloadDirNotifier.value.trim(),
                      textColor,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _heroStat(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: textColor.withAlpha(150)),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskPill(String label, int count, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: textColor.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(190)),
      ),
    );
  }

  Widget _pathRow(String label, String path, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
          ),
        ),
        Expanded(
          child: Text(
            path,
            style: TextStyle(fontSize: 11, color: textColor.withAlpha(180)),
          ),
        ),
      ],
    );
  }
}
