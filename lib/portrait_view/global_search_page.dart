import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/song_list.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';

/// Search across the whole library - songs, albums, artists and playlists - in
/// one place, split into tabs, instead of only filtering whatever the home page
/// happens to show.
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage>
    with SingleTickerProviderStateMixin {
  final controller = TextEditingController();
  late final TabController tab;
  String query = '';

  @override
  void initState() {
    super.initState();
    tab = TabController(length: 4, vsync: this);
    controller.addListener(() {
      final value = controller.text.trim().toLowerCase();
      if (value != query) {
        setState(() => query = value);
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    tab.dispose();
    super.dispose();
  }

  bool _matches(String value) => value.toLowerCase().contains(query);

  List<MyAudioMetadata> get songs => query.isEmpty
      ? const []
      : library.songList
            .where(
              (song) =>
                  _matches(getTitle(song)) ||
                  _matches(getArtist(song)) ||
                  _matches(getAlbum(song)),
            )
            .toList();

  List<Album> get albums => query.isEmpty
      ? const []
      : artistAlbumManager.albumList
            .where((album) => _matches(album.name))
            .toList();

  List<Artist> get artists => query.isEmpty
      ? const []
      : artistAlbumManager.artistList
            .where((artist) => _matches(artist.name))
            .toList();

  List<Playlist> get playlists => query.isEmpty
      ? const []
      : playlistManager.playlists
            .where(
              (playlist) =>
                  playlist.name != '_sylvakru_play_queue_' &&
                  _matches(playlist.name),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: l10n.searchHome,
          ),
        ),
      ),
      body: Column(
        children: [
          TabBar(
            controller: tab,
            tabs: [
              Tab(text: l10n.songs),
              Tab(text: l10n.albums),
              Tab(text: l10n.artists),
              Tab(text: l10n.playlists),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: tab,
              children: [
                _songResults(l10n),
                _albumResults(),
                _artistResults(),
                _playlistResults(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(AppLocalizations l10n) =>
      Center(child: Text(query.isEmpty ? l10n.searchHome : l10n.noResults));

  Widget _songResults(AppLocalizations l10n) {
    final list = songs;
    if (list.isEmpty) {
      return _empty(l10n);
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final song = list[index];
        return ListTile(
          leading: CoverArtWidget(size: 42, borderRadius: 4, picture: song.picture),
          title: Text(getTitle(song), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${getArtist(song)} - ${getAlbum(song)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => audioHandler.setPlayQueue(list, 0, targetIndex: index),
        );
      },
    );
  }

  Widget _albumResults() {
    final list = albums;
    final l10n = AppLocalizations.of(context);
    if (list.isEmpty) {
      return _empty(l10n);
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final album = list[index];
        return ListTile(
          leading: CoverArtWidget(size: 42, borderRadius: 4, picture: album.picture),
          title: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            l10n.songCount(album.songList.length),
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => pushAlbumDetail(album),
        );
      },
    );
  }

  Widget _artistResults() {
    final list = artists;
    final l10n = AppLocalizations.of(context);
    if (list.isEmpty) {
      return _empty(l10n);
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final artist = list[index];
        return ListTile(
          leading: CoverArtWidget(
            size: 42,
            borderRadius: 21,
            picture: artist.picture,
          ),
          title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${l10n.albumCount(artist.albumCount)} · '
            '${l10n.songCount(artist.songList.length)}',
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => pushArtistDetail(artist),
        );
      },
    );
  }

  Widget _playlistResults() {
    final list = playlists;
    final l10n = AppLocalizations.of(context);
    if (list.isEmpty) {
      return _empty(l10n);
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final playlist = list[index];
        return ListTile(
          leading: CoverArtWidget(
            size: 42,
            borderRadius: 4,
            picture: playlist.serverCover ?? playlist.picture,
          ),
          title: Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            l10n.songCount(playlist.songList.length),
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => pushPlaylistDetail(playlist),
        );
      },
    );
  }
}