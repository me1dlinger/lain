import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/cache_download_settings.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/download_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/utils/source_type.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The download queue and what has already been downloaded, with the queue's
/// global controls at the top.
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  void initState() {
    super.initState();
    downloadManager.ensureLoaded();
    // Coming back over Wi-Fi: the tasks that waited for it start here.
    downloadManager.resumeWaitingForWifi();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    return Scaffold(
      backgroundColor: colorManager.getSpecificOpaqueBgColor(),
      body: SafeArea(
        child: Column(
          children: [
            _header(l10n, textColor),
            _queueControls(textColor),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: downloadTasksNotifier,
                builder: (context, tasks, child) {
                  return ValueListenableBuilder(
                    valueListenable: downloadsNotifier,
                    builder: (context, items, child) {
                      if (tasks.isEmpty && items.isEmpty) {
                        return Center(child: Text(l10n.noDownloads));
                      }
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 30),
                        children: [
                          _folderLine(l10n, textColor),
                          if (tasks.isNotEmpty) ...[
                            _sectionTitle(l10n.downloadTasks, textColor),
                            for (final task in tasks)
                              _taskRow(task, textColor, l10n),
                          ],
                          if (items.isNotEmpty) ...[
                            _sectionTitle(l10n.downloads, textColor),
                            for (final item in items)
                              _row(item, l10n, textColor),
                          ],
                        ],
                      );
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

  Widget _header(AppLocalizations l10n, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              l10n.downloads,
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
    );
  }

  /// Continue all / pause all / delete all, icons only.
  Widget _queueControls(Color textColor) {
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
            onPressed: () => downloadManager.resumeAll(),
          ),
          IconButton(
            tooltip: l10n.pauseDownload,
            color: textColor,
            icon: const Icon(Icons.pause_rounded),
            onPressed: () => downloadManager.pauseAll(),
          ),
          IconButton(
            tooltip: l10n.deleteAllDownloads,
            color: textColor,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              if (downloadTasksNotifier.value.isEmpty) {
                return;
              }
              if (!await showConfirmDialog(context, l10n.deleteAllDownloads)) {
                return;
              }
              await downloadManager.deleteAllTasks();
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textColor.withAlpha(170),
        ),
      ),
    );
  }

  Widget _folderLine(AppLocalizations l10n, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Text(
        downloadDirNotifier.value.trim().isNotEmpty
            ? downloadDirNotifier.value.trim()
            : Platform.isAndroid
            ? '/storage/emulated/0/Download/$downloadFolderName'
            : '${appDocsDir.path}/$downloadFolderName',
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(160)),
      ),
    );
  }

  String _stateLabel(AppLocalizations l10n, DownloadTaskState state) {
    return switch (state) {
      DownloadTaskState.waitingForWifi => l10n.downloadStateWaitingWifi,
      DownloadTaskState.downloading => l10n.downloadStateDownloading,
      DownloadTaskState.paused => l10n.downloadStatePaused,
      DownloadTaskState.failed => l10n.downloadStateFailed,
    };
  }

  Widget _taskRow(DownloadTask task, Color textColor, AppLocalizations l10n) {
    final downloading = task.state == DownloadTaskState.downloading;
    final progress = task.progress;
    final stateText = progress == null
        ? _stateLabel(l10n, task.state)
        : '${_stateLabel(l10n, task.state)} ${(progress * 100).round()}%';
    final subtitle = task.artist.isEmpty
        ? stateText
        : '${task.artist} · $stateText';
    return ListTile(
      leading: Icon(Icons.download_rounded, size: 22, color: textColor),
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: textColor),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: textColor.withAlpha(160)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              downloading ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: textColor,
            ),
            onPressed: () {
              if (downloading) {
                downloadManager.pauseTask(task);
              } else {
                downloadManager.resumeTask(task);
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: textColor,
            ),
            onPressed: () => downloadManager.deleteTask(task),
          ),
        ],
      ),
    );
  }

  Widget _row(DownloadedSong item, AppLocalizations l10n, Color textColor) {
    final sourceType = item.sourceType;
    final size = '${(item.bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    final time =
        '${item.time.year}-'
        '${item.time.month.toString().padLeft(2, '0')}-'
        '${item.time.day.toString().padLeft(2, '0')}';

    return ListTile(
      leading: SizedBox(
        width: 48,
        child: Center(
          child: library.id2Song[item.songId]?.picture == null
              ? (sourceType == null
                    ? Icon(Icons.cloud_outlined, size: 22, color: textColor)
                    : ImageIcon(getSourceTypeImage(sourceType), size: 26))
              : CoverArtWidget(
                  size: 46,
                  borderRadius: 6,
                  picture: library.id2Song[item.songId]!.picture,
                ),
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: textColor),
      ),
      subtitle: Text(
        [
          if (item.artist.isNotEmpty) item.artist,
          if (sourceType != null) getSourceTypeDisplayName(l10n, sourceType),
          time,
          size,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: textColor.withAlpha(160)),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, size: 20, color: textColor),
        onPressed: () async {
          if (!await showConfirmDialog(context, item.fileName)) {
            return;
          }
          await downloadManager.delete(item);
        },
      ),
    );
  }
}
