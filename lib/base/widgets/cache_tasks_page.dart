import 'package:material_ui/material_ui.dart';
import 'package:lain/base/services/cache_download_manager.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The cache task that is running, with its progress and a stop action.
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
              padding: const EdgeInsets.fromLTRB(12, 8, 48, 4),
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
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: cacheDownloadManager.notifier,
                builder: (context, progress, child) {
                  if (!progress.isRunning) {
                    return Center(child: Text(l10n.noCacheTasks));
                  }
                  return ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 30),
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.download_rounded,
                          color: textColor,
                        ),
                        title: Text(
                          '${progress.done} / ${progress.total}',
                          style: TextStyle(fontSize: 15, color: textColor),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.stop_rounded,
                            color: textColor,
                          ),
                          onPressed: cacheDownloadManager.cancel,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: LinearProgressIndicator(
                          value: progress.fraction,
                          minHeight: 3,
                        ),
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
  }
}
