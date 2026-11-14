import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/artist_album.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cache_download_dialog.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// Playlist and artist cache, as one page with a tab switch: how much of each
/// list is cached, and a download action for the ones that are not.
class CacheGroupPage extends StatefulWidget {
  const CacheGroupPage({super.key});

  @override
  State<CacheGroupPage> createState() => _CacheGroupPageState();
}

class _CacheGroupPageState extends State<CacheGroupPage> {
  int _tab = 0;

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
                      l10n.cacheGroup,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: appleSegmented<int>(
                const [0, 1],
                (value) => value == 0 ? l10n.playlists : l10n.artists,
                _tab,
                (value) => setState(() => _tab = value),
              ),
            ),
            Expanded(
              child: _tab == 0 ? _playlists(l10n, textColor) : _artists(l10n, textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playlists(AppLocalizations l10n, Color textColor) {
    final playlists = [
      for (final playlist in playlistManager.playlists)
        if (playlist.name != '_lain_play_queue_') playlist,
    ];
    if (playlists.isEmpty) {
      return Center(child: Text(l10n.cacheEmpty));
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 30),
      children: [
        for (final playlist in playlists)
          _row(
            textColor,
            title: playlist.name,
            subtitle: _countLabel(
              l10n,
              playlist.songList.where((song) => song.cacheExist).length,
              playlist.songList.length,
            ),
            leading: Icon(
              Icons.queue_music_rounded,
              color: textColor.withAlpha(170),
            ),
            onDownload: () =>
                showCacheDownloadDialog(context, playlist.songList),
          ),
      ],
    );
  }

  Widget _artists(AppLocalizations l10n, Color textColor) {
    final artists = [
      for (final artist in artistAlbumManager.artistList)
        if (artist.songList.any((song) => song.cacheExist) ||
            MyPicture.artistExists(artist.name))
          artist,
    ];
    if (artists.isEmpty) {
      return Center(child: Text(l10n.cacheEmpty));
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 30),
      children: [
        for (final artist in artists)
          _row(
            textColor,
            title: artist.name,
            subtitle: _countLabel(
              l10n,
              artist.songList.where((song) => song.cacheExist).length,
              artist.songList.length,
            ),
            leading: CoverArtWidget(
              size: 40,
              borderRadius: 20,
              picture: artist.picture,
            ),
            onDownload: () => showCacheDownloadDialog(context, artist.songList),
          ),
      ],
    );
  }

  String _countLabel(AppLocalizations l10n, int cached, int total) =>
      '$cached / $total';

  Widget _row(
    Color textColor, {
    required String title,
    required String subtitle,
    required Widget leading,
    required VoidCallback onDownload,
  }) {
    return ListTile(
      leading: SizedBox(
        width: 44,
        child: Center(child: leading),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: textColor),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11, color: textColor.withAlpha(160)),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.download_for_offline_outlined,
          size: 22,
          color: textColor,
        ),
        onPressed: onDownload,
      ),
    );
  }
}
