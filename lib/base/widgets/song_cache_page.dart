import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/base/widgets/cache_tasks_page.dart';
import 'package:lain/base/widgets/settings_page_route.dart';

/// The songs whose audio is on disk, as a full page.
class SongCachePage extends StatelessWidget {
  const SongCachePage({super.key});

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
              // Both sides carry the same width (one 48px button vs two), so
              // the title is centred against the screen padding.
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
                  // Balances the second button on the right-hand group.
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      l10n.cacheSongs,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.list_alt_rounded, color: textColor),
                    onPressed: () {
                      pushSettingsPage<void>(
                        context,
                        settingsPageRoute<void>(() => const CacheTasksPage()),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: l10n.clearCache,
                    icon: Icon(Icons.delete_outline, color: textColor),
                    onPressed: () async {
                      // Two steps: clearing the audio cache is not reversible.
                      if (!await showConfirmDialog(
                        context,
                        l10n.clearCacheConfirm,
                      )) {
                        return;
                      }
                      if (!context.mounted) {
                        return;
                      }
                      if (!await showConfirmDialog(
                        context,
                        l10n.clearCacheConfirmAgain,
                      )) {
                        return;
                      }
                      await library.clearCache();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: cacheEntriesNotifier,
                builder: (context, entries, child) {
                  final songs = groupCacheBySong(entries);
                  if (songs.isEmpty) {
                    return Center(child: Text(l10n.cacheEmpty));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 30),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      return _row(context, songs[index], textColor);
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

  Widget _row(BuildContext context, CachedSong cached, Color textColor) {
    final song = cached.song;
    final size = '${(cached.size / (1024 * 1024)).toStringAsFixed(1)}MB';
    return ListTile(
      leading: CoverArtWidget(
        size: 44,
        borderRadius: 5,
        picture: song?.picture,
      ),
      title: Text(
        getTitle(song),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: textColor),
      ),
      subtitle: Text(
        '${getArtist(song)} - ${getAlbum(song)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: textColor.withAlpha(160)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            size,
            style: TextStyle(fontSize: 11, color: textColor.withAlpha(160)),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: textColor),
            onPressed: () async {
              await library.deleteCachedSong(cached);
            },
          ),
        ],
      ),
    );
  }
}
