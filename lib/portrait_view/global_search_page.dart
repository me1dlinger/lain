import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/artist_album.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/data/search_history.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/lyric_index.dart';
import 'package:lain/base/utils/dynamic_lyrics_page_route.dart';
import 'package:lain/layer/lyrics_page_layer.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/song_list.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/layer/layers_manager.dart';

/// Search 2.0: one field for the whole library - songs, albums, artists and
/// playlists - with a best match, category filters, recent searches and a
/// search for pinyin or English letters as well as the displayed name.
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  Timer? _debounce;
  String _query = '';
  _SearchResults? _results;
  List<LyricHit> _lyricHits = const [];
  int _lyricGeneration = 0;
  int _filter = 0;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    searchHistory.ensureLoaded();
    focusNode.addListener(() {
      if (_focused != focusNode.hasFocus) {
        setState(() => _focused = focusNode.hasFocus);
      }
    });
    controller.addListener(() {
      if (controller.text.isEmpty && _query.isNotEmpty) {
        _setQuery('');
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.trim();
    if (query == _query) {
      return;
    }
    _debounce?.cancel();
    // A short pause keeps the list still while a word is being typed, but not
    // long enough to feel like the search is waiting.
    _debounce = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) {
        return;
      }
      _apply(query);
    });
    _lyricGeneration++;
    setState(() {
      _query = query;
      _filter = 0;
      _lyricHits = const [];
    });
  }

  void _setQuery(String query) {
    final value = query.trim();
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    _debounce?.cancel();
    searchHistory.add(value);
    _apply(value);
  }

  void _apply(String value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _query = value;
      _filter = 0;
      _results = value.isEmpty ? null : _search(value);
      _lyricHits = const [];
    });
    _loadLyrics(value);
  }

  Future<void> _loadLyrics(String value) async {
    final generation = ++_lyricGeneration;
    if (value.trim().length < 2) {
      return;
    }
    final hits = await lyricIndex.search(value);
    if (!mounted || generation != _lyricGeneration || value != _query) {
      return;
    }
    setState(() => _lyricHits = hits);
  }

  void _clear() {
    controller.clear();
    _debounce?.cancel();
    _lyricGeneration++;
    setState(() {
      _query = '';
      _results = null;
      _lyricHits = const [];
      _filter = 0;
    });
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasQuery = _query.isNotEmpty;
    final results = _results;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context, l10n),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, .025),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: !hasQuery
                    ? _IdleSearch(
                        key: const ValueKey('idle'),
                        onQuery: _setQuery,
                      )
                    : results == null
                    ? const Center(
                        key: ValueKey('loading'),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _ResultsView(
                        key: const ValueKey('results'),
                        query: _query,
                        results: results,
                        lyricHits: _lyricHits,
                        filter: _filter,
                        onFilter: (value) => setState(() => _filter = value),
                        onQuery: _setQuery,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 46,
              decoration: BoxDecoration(
                color: textColor.withAlpha(_focused ? 26 : 14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _focused ? accent.withAlpha(110) : Colors.transparent,
                ),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: accent.withAlpha(34),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: _focused ? accent : textColor.withAlpha(150),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(fontSize: 16, color: textColor),
                      cursorColor: accent,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: l10n.searchHome,
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: textColor.withAlpha(130),
                        ),
                      ),
                      onChanged: _onChanged,
                      onSubmitted: (value) {
                        _debounce?.cancel();
                        _setQuery(value);
                      },
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: controller.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            key: const ValueKey('clear'),
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 19,
                              color: textColor.withAlpha(170),
                            ),
                            onPressed: _clear,
                          ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _SearchResults _search(String raw) {
    final q = raw.trim().toLowerCase();
    final songs = <_SongHit>[];
    for (final song in library.songList) {
      final title = _score(getTitle(song), q);
      final artist = _score(getArtist(song), q);
      final album = _score(getAlbum(song), q);
      final pinyin = _score(song.compareTitle, q);
      final score = max(title * 3 + artist + album, pinyin * 2);
      if (score > 0) {
        songs.add(_SongHit(song, score));
      }
    }
    songs.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      final byPlay = b.song.playCount.compareTo(a.song.playCount);
      return byPlay != 0 ? byPlay : a.song.compareTitle.compareTo(b.song.compareTitle);
    });

    final albums = <_AlbumHit>[
      for (final album in artistAlbumManager.albumList)
        if (_score(album.name, q) * 3 + _score(album.compareName, q) * 2 > 0)
          _AlbumHit(album, _score(album.name, q) * 3 + _score(album.compareName, q) * 2),
    ]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.album.compareName.compareTo(b.album.compareName);
      });

    final artists = <_ArtistHit>[
      for (final artist in artistAlbumManager.artistList)
        if (_score(artist.name, q) * 3 + _score(artist.compareName, q) * 2 > 0)
          _ArtistHit(
            artist,
            _score(artist.name, q) * 3 + _score(artist.compareName, q) * 2,
          ),
    ]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.artist.compareName.compareTo(b.artist.compareName);
      });

    final playlists = <_PlaylistHit>[
      for (final playlist in playlistManager.playlists)
        if (playlist.name != '_lain_play_queue_' && _score(playlist.name, q) > 0)
          _PlaylistHit(playlist, _score(playlist.name, q)),
    ]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.playlist.name.compareTo(b.playlist.name);
      });

    return _SearchResults(
      songs: songs,
      albums: albums,
      artists: artists,
      playlists: playlists,
    );
  }

  /// Exact name first, then a name starting with the query, then a name that
  /// contains it, then a word inside it. Diacritics and case are ignored by
  /// the callers lowering both sides.
  static int _score(String? raw, String query) {
    if (raw == null) {
      return 0;
    }
    final value = raw.toLowerCase().trim();
    if (value.isEmpty) {
      return 0;
    }
    if (value == query) {
      return 1000;
    }
    if (value.startsWith(query)) {
      return 800 - min(value.length, 100);
    }
    if (value.contains(query)) {
      return 600 - min(value.length, 100);
    }
    for (final word in value.split(RegExp(r'[\s\-_/.,()\[\]]+'))) {
      if (word.startsWith(query)) {
        return 500;
      }
    }
    return 0;
  }
}

class _SongHit {
  final MyAudioMetadata song;
  final int score;
  const _SongHit(this.song, this.score);
}

class _AlbumHit {
  final Album album;
  final int score;
  const _AlbumHit(this.album, this.score);
}

class _ArtistHit {
  final Artist artist;
  final int score;
  const _ArtistHit(this.artist, this.score);
}

class _PlaylistHit {
  final Playlist playlist;
  final int score;
  const _PlaylistHit(this.playlist, this.score);
}

class _SearchResults {
  final List<_SongHit> songs;
  final List<_AlbumHit> albums;
  final List<_ArtistHit> artists;
  final List<_PlaylistHit> playlists;

  const _SearchResults({
    required this.songs,
    required this.albums,
    required this.artists,
    required this.playlists,
  });

  int get total => songs.length + albums.length + artists.length + playlists.length;
}

/// A single result that is the most likely thing the user meant.
class _TopHit {
  final MyAudioMetadata? song;
  final Album? album;
  final Artist? artist;
  final int score;
  final int typeRank;

  const _TopHit({
    this.song,
    this.album,
    this.artist,
    required this.score,
    required this.typeRank,
  });
}

class _IdleSearch extends StatelessWidget {
  final ValueChanged<String> onQuery;
  const _IdleSearch({super.key, required this.onQuery});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final accent = Theme.of(context).colorScheme.primary;

    final artists = artistAlbumManager.artistList;
    final albums = artistAlbumManager.albumList;
    final suggestions = <String>{};
    if (artists.isNotEmpty) {
      suggestions.add(artists[artists.length ~/ 3].name);
      suggestions.add(artists[artists.length ~/ 2].name);
    }
    if (albums.isNotEmpty) {
      suggestions.add(albums[albums.length ~/ 3].name);
      suggestions.add(albums[albums.length ~/ 2].name);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 50),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const SizedBox(height: 26),
        Icon(Icons.travel_explore_rounded, size: 42, color: accent.withAlpha(180)),
        const SizedBox(height: 12),
        Text(
          l10n.searchIdleHint,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: textColor.withAlpha(160)),
        ),
        const SizedBox(height: 26),
        _sectionTitle(context, l10n.searchBrowse, textColor),
        const SizedBox(height: 10),
        _browseGrid(context, l10n),
        ListenableBuilder(
          listenable: searchHistory.entries,
          builder: (context, child) {
            final items = searchHistory.entries.value;
            if (items.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(child: _sectionTitle(context, l10n.searchRecent, textColor)),
                    TextButton(
                      onPressed: searchHistory.clear,
                      child: Text(
                        l10n.searchClearRecent,
                        style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in items)
                      _recentChip(context, l10n, item, textColor, () => onQuery(item)),
                  ],
                ),
              ],
            );
          },
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 26),
          _sectionTitle(context, l10n.searchTrySearching, textColor),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in suggestions)
                _suggestionChip(context, item, textColor, () => onQuery(item)),
            ],
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _browseGrid(BuildContext context, AppLocalizations l10n) {
    final items = <(IconData, String, int, String)>[
      (Icons.music_note_rounded, l10n.songs, library.songList.length, 'songs'),
      (Icons.album_rounded, l10n.albums, artistAlbumManager.albumList.length, 'albums'),
      (Icons.person_rounded, l10n.artists, artistAlbumManager.artistList.length, 'artists'),
      (
        Icons.queue_music_rounded,
        l10n.playlists,
        playlistManager.playlists.where((p) => p.name != '_lain_play_queue_').length,
        'playlists',
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        for (final item in items) _browseTile(context, item.$1, item.$2, item.$3, item.$4),
      ],
    );
  }

  Widget _browseTile(
    BuildContext context,
    IconData icon,
    String label,
    int count,
    String layer,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final accent = Theme.of(context).colorScheme.primary;
    return _Pressable(
      onTap: () {
        Navigator.of(context).maybePop();
        layersManager.switchRootLayer(layer);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: textColor.withAlpha(14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withAlpha(30),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 11, color: textColor.withAlpha(130)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentChip(
    BuildContext context,
    AppLocalizations l10n,
    String query,
    Color textColor,
    VoidCallback onTap,
  ) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: textColor.withAlpha(14),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 15, color: textColor.withAlpha(140)),
            const SizedBox(width: 6),
            Text(
              query,
              style: TextStyle(fontSize: 13, color: textColor.withAlpha(210)),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () => searchHistory.remove(query),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 14, color: textColor.withAlpha(110)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(BuildContext context, String text, Color textColor, VoidCallback onTap) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: textColor.withAlpha(45)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 14, color: textColor.withAlpha(150)),
            const SizedBox(width: 5),
            Text(text, style: TextStyle(fontSize: 13, color: textColor.withAlpha(210))),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, Color textColor) {
    return Text(
      text,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final String query;
  final _SearchResults results;
  final List<LyricHit> lyricHits;
  final int filter;
  final ValueChanged<int> onFilter;
  final ValueChanged<String> onQuery;

  const _ResultsView({
    super.key,
    required this.query,
    required this.results,
    required this.lyricHits,
    required this.filter,
    required this.onFilter,
    required this.onQuery,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    if (results.total == 0 && lyricHits.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 40),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Icon(Icons.search_off_rounded, size: 46, color: textColor.withAlpha(70)),
          const SizedBox(height: 14),
          Text(
            '"$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor.withAlpha(200),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.noResults,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textColor.withAlpha(140)),
          ),
        ],
      );
    }

    final topHit = filter == 0 ? _topHit() : null;
    final songQueue = [for (final hit in results.songs) hit.song];
    final showSongs = filter == 0 || filter == 1;
    final showLyrics = filter == 0 || filter == 5;
    final showAlbums = filter == 0 || filter == 2;
    final showArtists = filter == 0 || filter == 3;
    final showPlaylists = filter == 0 || filter == 4;
    final all = filter == 0;
    final maxSongs = all ? 6 : results.songs.length;
    final maxCards = all ? 12 : 1000;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 50),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (topHit != null) _topResult(context, l10n, topHit),
        _filterChips(context, l10n),
        if (showSongs && results.songs.isNotEmpty) ...[
          _sectionHeader(
            context,
            l10n.songs,
            results.songs.length,
            all,
            () => onFilter(1),
          ),
          if (filter == 1)
            for (var i = 0; i < results.songs.length; i++)
              _Reveal(
                key: ValueKey('$query-song-$i'),
                index: i,
                child: _songRow(context, l10n, songQueue, i),
              )
          else
            for (var i = 0; i < min(maxSongs, results.songs.length); i++)
              _Reveal(
                key: ValueKey('$query-song-$i'),
                index: i,
                child: _songRow(context, l10n, songQueue, i),
              ),
          const SizedBox(height: 8),
        ],
        if (showLyrics && lyricHits.isNotEmpty) ...[
          _sectionHeader(
            context,
            l10n.lyrics,
            lyricHits.length,
            all,
            () => onFilter(5),
          ),
          for (var i = 0;
              i < (filter == 5 ? lyricHits.length : min(3, lyricHits.length));
              i++)
            _Reveal(
              key: ValueKey('$query-lyric-$i'),
              index: i,
              child: _lyricRow(context, l10n, lyricHits[i], i),
            ),
          const SizedBox(height: 8),
        ],
        if (showAlbums && results.albums.isNotEmpty) ...[
          _sectionHeader(
            context,
            l10n.albums,
            results.albums.length,
            all,
            () => onFilter(2),
          ),
          if (filter == 2)
            for (var i = 0; i < results.albums.length; i++)
              _Reveal(
                key: ValueKey('$query-album-$i'),
                index: i,
                child: _albumRow(context, l10n, results.albums[i].album),
              )
          else
            _horizontalCards(
              [
                for (var i = 0; i < min(maxCards, results.albums.length); i++)
                  _Reveal(
                    key: ValueKey('$query-album-card-$i'),
                    index: i,
                    child: _albumCard(context, l10n, results.albums[i].album),
                  ),
              ],
            ),
          const SizedBox(height: 10),
        ],
        if (showArtists && results.artists.isNotEmpty) ...[
          _sectionHeader(
            context,
            l10n.artists,
            results.artists.length,
            all,
            () => onFilter(3),
          ),
          if (filter == 3)
            for (var i = 0; i < results.artists.length; i++)
              _Reveal(
                key: ValueKey('$query-artist-$i'),
                index: i,
                child: _artistRow(context, l10n, results.artists[i].artist),
              )
          else
            _horizontalCards(
              [
                for (var i = 0; i < min(maxCards, results.artists.length); i++)
                  _Reveal(
                    key: ValueKey('$query-artist-card-$i'),
                    index: i,
                    child: _artistCard(context, l10n, results.artists[i].artist),
                  ),
              ],
            ),
          const SizedBox(height: 10),
        ],
        if (showPlaylists && results.playlists.isNotEmpty) ...[
          _sectionHeader(
            context,
            l10n.playlists,
            results.playlists.length,
            all,
            () => onFilter(4),
          ),
          if (filter == 4)
            for (var i = 0; i < results.playlists.length; i++)
              _Reveal(
                key: ValueKey('$query-playlist-$i'),
                index: i,
                child: _playlistRow(context, l10n, results.playlists[i].playlist),
              )
          else
            _horizontalCards(
              [
                for (var i = 0; i < min(maxCards, results.playlists.length); i++)
                  _Reveal(
                    key: ValueKey('$query-playlist-card-$i'),
                    index: i,
                    child: _playlistCard(context, l10n, results.playlists[i].playlist),
                  ),
              ],
            ),
        ],
      ],
    );
  }

  _TopHit? _topHit() {
    _TopHit? best;
    for (final hit in results.songs) {
      final value = _TopHit(
        song: hit.song,
        score: hit.score,
        typeRank: 0,
      );
      best = _better(best, value);
    }
    for (final hit in results.albums) {
      final value = _TopHit(album: hit.album, score: hit.score, typeRank: 1);
      best = _better(best, value);
    }
    for (final hit in results.artists) {
      final value = _TopHit(artist: hit.artist, score: hit.score, typeRank: 2);
      best = _better(best, value);
    }
    return best;
  }

  static _TopHit _better(_TopHit? current, _TopHit next) {
    if (current == null) {
      return next;
    }
    if (next.score != current.score) {
      return next.score > current.score ? next : current;
    }
    return next.typeRank < current.typeRank ? next : current;
  }

  Widget _topResult(BuildContext context, AppLocalizations l10n, _TopHit hit) {
    final textColor = colorManager.getSpecificTextColor();
    final accent = Theme.of(context).colorScheme.primary;
    final song = hit.song;
    final album = hit.album;
    final artist = hit.artist;

    final String title = song != null
        ? getTitle(song)
        : album?.name ?? artist?.name ?? '';
    final String subtitle = song != null
        ? '${getArtist(song)} · ${getAlbum(song)}'
        : album != null
        ? '${getArtist(album.songList.first)} · ${l10n.songCount(album.songList.length)}'
        : '${l10n.albumCount(artist!.albumCount)} · ${l10n.songCount(artist.songList.length)}';
    final MyPicture? picture = song?.picture ??
        (album != null ? album.picture : artist?.picture);
    final MyPicture? fallback = album == null && artist != null
        ? artist.albumCoverPicture
        : null;
    final String type = song != null
        ? l10n.title
        : album != null
        ? l10n.album
        : l10n.artist;

    void open() {
      if (song != null) {
        audioHandler.setPlayQueue([song], 0, targetIndex: 0);
      } else if (album != null) {
        pushAlbumDetail(album);
      } else if (artist != null) {
        pushArtistDetail(artist);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Pressable(
        onTap: open,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withAlpha(34), textColor.withAlpha(10)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: textColor.withAlpha(20)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CoverArtWidget(
                  size: 76,
                  borderRadius: 10,
                  picture: picture ?? song?.picture,
                  fallbackPicture: fallback,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.searchTopResult.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _HighlightedText(
                      text: title,
                      query: query,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      type,
                      style: TextStyle(fontSize: 10, color: textColor.withAlpha(120)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Icon(
                  song != null ? Icons.play_arrow_rounded : Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChips(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    final entries = <(String, int)>[
      (l10n.searchAll, results.total + lyricHits.length),
      (l10n.songs, results.songs.length),
      (l10n.albums, results.albums.length),
      (l10n.artists, results.artists.length),
      (l10n.playlists, results.playlists.length),
      (l10n.lyrics, lyricHits.length),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        padding: const EdgeInsets.symmetric(vertical: 7),
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = filter == index;
          final enabled = index == 0 || entries[index].$2 > 0;
          return _Pressable(
            onTap: enabled ? () => onFilter(index) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? textColor.withAlpha(48) : textColor.withAlpha(10),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? Colors.transparent : textColor.withAlpha(24),
                ),
              ),
              child: Text(
                '${entries[index].$1}  ${entries[index].$2}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: enabled
                      ? (selected ? textColor : textColor.withAlpha(170))
                      : textColor.withAlpha(60),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title,
    int count,
    bool showAll,
    VoidCallback onShowAll,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(width: 7),
          Text('$count', style: TextStyle(fontSize: 11, color: textColor.withAlpha(110))),
          const Spacer(),
          if (showAll)
            TextButton(
              onPressed: onShowAll,
              child: Text(
                AppLocalizations.of(context).searchShowAll,
                style: TextStyle(fontSize: 12, color: textColor.withAlpha(160)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _horizontalCards(List<Widget> children) {
    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  Widget _songRow(
    BuildContext context,
    AppLocalizations l10n,
    List<MyAudioMetadata> queue,
    int index,
  ) {
    final song = queue[index];
    final textColor = colorManager.getSpecificTextColor();
    final duration = getDuration(song);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => audioHandler.setPlayQueue(queue, 0, targetIndex: index),
      onLongPress: () => showSongOptions(
        context: context,
        song: song,
        includeGoToArtist: true,
        includeGoToAlbum: true,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CoverArtWidget(size: 46, borderRadius: 8, picture: song.picture),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HighlightedText(
                    text: getTitle(song),
                    query: query,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${getArtist(song)} · ${getAlbum(song)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textColor.withAlpha(140)),
                  ),
                ],
              ),
            ),
            if (duration > Duration.zero)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  formatDuration(duration),
                  style: TextStyle(fontSize: 11, color: textColor.withAlpha(110)),
                ),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.more_horiz_rounded, size: 20, color: textColor.withAlpha(130)),
              onPressed: () => showSongOptions(
                context: context,
                song: song,
                includeGoToArtist: true,
                includeGoToAlbum: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _albumCard(BuildContext context, AppLocalizations l10n, Album album) {
    final textColor = colorManager.getSpecificTextColor();
    return _Pressable(
      onTap: () => pushAlbumDetail(album),
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArtWidget(size: 112, borderRadius: 12, picture: album.picture),
            const SizedBox(height: 7),
            _HighlightedText(
              text: album.name,
              query: query,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              getArtist(album.songList.first),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: textColor.withAlpha(130)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artistCard(BuildContext context, AppLocalizations l10n, Artist artist) {
    final textColor = colorManager.getSpecificTextColor();
    return _Pressable(
      onTap: () => pushArtistDetail(artist),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            ClipOval(
              child: CoverArtWidget(
                size: 86,
                borderRadius: 43,
                picture: artist.picture,
                fallbackPicture: artist.albumCoverPicture,
              ),
            ),
            const SizedBox(height: 7),
            _HighlightedText(
              text: artist.name,
              query: query,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              l10n.albumCount(artist.albumCount),
              maxLines: 1,
              style: TextStyle(fontSize: 11, color: textColor.withAlpha(130)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playlistCard(BuildContext context, AppLocalizations l10n, Playlist playlist) {
    final textColor = colorManager.getSpecificTextColor();
    return _Pressable(
      onTap: () => pushPlaylistDetail(playlist),
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArtWidget(
              size: 112,
              borderRadius: 12,
              picture: playlist.serverCover ?? playlist.picture,
            ),
            const SizedBox(height: 7),
            _HighlightedText(
              text: playlist.name,
              query: query,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              l10n.songCount(playlist.songList.length),
              style: TextStyle(fontSize: 11, color: textColor.withAlpha(130)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lyricRow(
    BuildContext context,
    AppLocalizations l10n,
    LyricHit hit,
    int index,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final song = library.id2Song[hit.songId];
    if (song == null) {
      return const SizedBox.shrink();
    }
    final songs = [
      for (final item in lyricHits)
        if (library.id2Song[item.songId] != null)
          library.id2Song[item.songId]!,
    ];
    final target = songs.indexWhere((item) => item.id == song.id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await audioHandler.setPlayQueue(
          songs,
          0,
          targetIndex: target < 0 ? 0 : target,
        );
        final start = hit.start;
        if (start != null) {
          final wanted = start - Duration(milliseconds: song.lyricsTimeOffset);
          await audioHandler.seek(
            wanted.isNegative ? Duration.zero : wanted,
          );
        }
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).push(
            DynamicLyricsPageRoute(
              pageBuilder: (_, _, _) => LyricsPageLayer(),
            ),
          );
        }
      },
      onLongPress: () => showSongOptions(
        context: context,
        song: song,
        includeGoToArtist: true,
        includeGoToAlbum: true,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CoverArtWidget(
                size: 46,
                borderRadius: 8,
                picture: song.picture,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${getTitle(song)} · ${getArtist(song)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _HighlightedText(
                    text: hit.translationMatch && hit.translation != null
                        ? hit.translation!
                        : hit.text,
                    query: query,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: textColor.withAlpha(205),
                    ),
                    maxLines: 2,
                  ),
                  if (!hit.translationMatch &&
                      hit.translation != null &&
                      hit.translation!.trim().isNotEmpty)
                    Text(
                      hit.translation!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withAlpha(125),
                      ),
                    ),
                ],
              ),
            ),
            if (hit.start != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(
                  formatDuration(hit.start!),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withAlpha(110),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _albumRow(BuildContext context, AppLocalizations l10n, Album album) {
    final textColor = colorManager.getSpecificTextColor();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: CoverArtWidget(size: 46, borderRadius: 8, picture: album.picture),
      title: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${getArtist(album.songList.first)} · ${l10n.songCount(album.songList.length)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(140)),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: textColor.withAlpha(110)),
      onTap: () => pushAlbumDetail(album),
    );
  }

  Widget _artistRow(BuildContext context, AppLocalizations l10n, Artist artist) {
    final textColor = colorManager.getSpecificTextColor();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: ClipOval(
        child: CoverArtWidget(
          size: 46,
          borderRadius: 23,
          picture: artist.picture,
          fallbackPicture: artist.albumCoverPicture,
        ),
      ),
      title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${l10n.albumCount(artist.albumCount)} · ${l10n.songCount(artist.songList.length)}',
        maxLines: 1,
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(140)),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: textColor.withAlpha(110)),
      onTap: () => pushArtistDetail(artist),
    );
  }

  Widget _playlistRow(BuildContext context, AppLocalizations l10n, Playlist playlist) {
    final textColor = colorManager.getSpecificTextColor();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: CoverArtWidget(
        size: 46,
        borderRadius: 8,
        picture: playlist.serverCover ?? playlist.picture,
      ),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        l10n.songCount(playlist.songList.length),
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(140)),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: textColor.withAlpha(110)),
      onTap: () => pushPlaylistDetail(playlist),
    );
  }
}

/// A short fade-and-rise for the first few results, so a new search feels
/// assembled rather than swapped. Long lists skip it: the rows below the fold
/// are not seen arriving, and a controller per row would not be free.
class _Reveal extends StatefulWidget {
  final int index;
  final Widget child;

  const _Reveal({super.key, required this.index, required this.child});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (widget.index >= 14) {
      _controller.value = 1;
      return;
    }
    _delay = Timer(Duration(milliseconds: widget.index * 22), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.index >= 14) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .06),
          end: Offset.zero,
        ).animate(_fade),
        child: widget.child,
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;
  final TextAlign textAlign;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final index = query.isEmpty ? -1 : text.toLowerCase().indexOf(query.toLowerCase());
    if (index < 0) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      );
    }
    final accent = Theme.of(context).colorScheme.primary;
    return Text.rich(
      TextSpan(
        children: [
          if (index > 0) TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: style.copyWith(color: accent, fontWeight: FontWeight.w700),
          ),
          if (index + query.length < text.length)
            TextSpan(text: text.substring(index + query.length)),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
  }
}

/// A card that lifts slightly and dims while pressed, without a ripple that
/// would break the frosted surfaces.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Pressable({required this.child, this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? .975 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _down ? .78 : 1,
          duration: const Duration(milliseconds: 130),
          child: widget.child,
        ),
      ),
    );
  }
}
