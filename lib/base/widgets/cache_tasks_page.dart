import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/stream_quality.dart';
import 'package:lain/base/services/cache_download_manager.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The cache batch, song by song, with the audio quality it is fetched at.
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
                  IconButton(
                    icon: Icon(Icons.stop_rounded, color: textColor),
                    onPressed: cacheDownloadManager.isRunning
                        ? cacheDownloadManager.cancel
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: cacheDownloadManager.notifier,
                builder: (context, progress, child) {
                  final batch = cacheDownloadManager.batch;
                  if (batch.isEmpty) {
                    return Center(child: Text(l10n.noCacheTasks));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 30),
                    itemCount: batch.length,
                    itemBuilder: (context, index) {
                      final song = batch[index];
                      final active =
                          cacheDownloadManager.activeIds.contains(song.id);
                      final failed =
                          cacheDownloadManager.failedIds.contains(song.id);
                      final status = active
                          ? l10n.downloadStateDownloading
                          : failed
                          ? l10n.downloadStateFailed
                          : song.cacheExist
                          ? l10n.allCached
                          : l10n.downloadStateWaitingWifi;
                      final quality = streamQualityNotifier.value;
                      final qualityText = quality == StreamQuality.original
                          ? l10n.streamQualityOriginal
                          : '${quality.maxBitRate}kbps · '
                                '${streamFormatNotifier.value.display}';
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
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withAlpha(160),
                          ),
                        ),
                        trailing: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withAlpha(170),
                          ),
                        ),
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
}
