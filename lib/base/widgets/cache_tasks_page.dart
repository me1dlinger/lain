import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/stream_quality.dart';
import 'package:lain/base/services/cache_download_manager.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The cache tasks, song by song, with the audio quality each is fetched at
/// and the same continue/pause/delete controls the download queue has.
class CacheTasksPage extends StatelessWidget {
  const CacheTasksPage({super.key});

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
                      l10n.cacheTasks,
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
            _controls(context, textColor),
            Expanded(
              child: AnimatedBuilder(
                // The task states, the songs' cache flags and the fetch
                // quality all change the rows.
                animation: Listenable.merge([
                  cacheDownloadManager.tasksNotifier,
                  library.changeNotifier,
                  streamQualityNotifier,
                  streamFormatNotifier,
                ]),
                builder: (context, child) {
                  final tasks = cacheDownloadManager.tasksNotifier.value;
                  if (tasks.isEmpty) {
                    return Center(child: Text(l10n.noCacheTasks));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 30),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return _taskRow(tasks[index], l10n, textColor);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Continue all / pause all / delete all, icons only.
  Widget _controls(BuildContext context, Color textColor) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            tooltip: l10n.continueDownload,
            color: textColor,
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: cacheDownloadManager.resumeAll,
          ),
          IconButton(
            tooltip: l10n.pauseDownload,
            color: textColor,
            icon: const Icon(Icons.pause_rounded),
            onPressed: cacheDownloadManager.pauseAll,
          ),
          IconButton(
            tooltip: l10n.deleteAllDownloads,
            color: textColor,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              if (cacheDownloadManager.tasksNotifier.value.isEmpty) {
                return;
              }
              if (!await showConfirmDialog(context, l10n.deleteAllDownloads)) {
                return;
              }
              cacheDownloadManager.deleteAllTasks();
            },
          ),
        ],
      ),
    );
  }

  String _stateLabel(AppLocalizations l10n, CacheTaskState state) {
    return switch (state) {
      CacheTaskState.waiting => l10n.cacheWaiting,
      CacheTaskState.downloading => l10n.downloadStateDownloading,
      CacheTaskState.paused => l10n.downloadStatePaused,
      CacheTaskState.completed => l10n.cached,
      CacheTaskState.failed => l10n.downloadStateFailed,
    };
  }

  Widget _taskRow(CacheTask task, AppLocalizations l10n, Color textColor) {
    final song = task.song;
    final downloading = task.state == CacheTaskState.downloading;
    final quality = streamQualityNotifier.value;
    final qualityText = quality == StreamQuality.original
        ? l10n.streamQualityOriginal
        : '${quality.maxBitRate}kbps · ${streamFormatNotifier.value.display}';

    return ListTile(
      leading: CoverArtWidget(
        size: 44,
        borderRadius: 5,
        picture: song.picture,
      ),
      title: Text(
        getTitle(song),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: textColor),
      ),
      subtitle: Text(
        '${getArtist(song)} · $qualityText',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: textColor.withAlpha(160)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _stateLabel(l10n, task.state),
            style: TextStyle(
              fontSize: 12,
              color: textColor.withAlpha(170),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              downloading ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: textColor,
            ),
            onPressed: () {
              if (downloading) {
                cacheDownloadManager.pauseTask(task);
              } else {
                cacheDownloadManager.resumeTask(task);
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: textColor),
            onPressed: () => cacheDownloadManager.deleteTask(task),
          ),
        ],
      ),
    );
  }
}
