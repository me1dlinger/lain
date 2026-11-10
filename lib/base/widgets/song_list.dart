import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:rive_animated_icon/rive_animated_icon.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/utils/common_utils.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/edit_metadata.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/my_location.dart';
import 'package:sylvakru/base/widgets/my_scaffold.dart';
import 'package:sylvakru/base/widgets/my_sheet.dart';
import 'package:sylvakru/base/widgets/play_next_button.dart';
import 'package:sylvakru/base/widgets/playlist_widgets.dart';
import 'package:sylvakru/base/widgets/selectable_song_list_page.dart';
import 'package:sylvakru/base/widgets/song_info.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/albums_layer.dart';
import 'package:sylvakru/layer/artists_layer.dart';
import 'package:sylvakru/layer/folders_layer.dart';
import 'package:sylvakru/layer/home_layer.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/playlists_layer.dart';
import 'package:sylvakru/portrait_view/my_search_field.dart';
import 'package:text_scroll/text_scroll.dart';

part '../../landscape_view/panels/song_list_panel.dart';
part '../../portrait_view/pages/song_list_page.dart';

class SongList extends StatefulWidget {
  final Playlist? playlist;
  final Artist? artist;
  final Album? album;
  final Folder? folder;
  final bool isFrequently;
  final bool isRecently;
  final bool isRecentlyAdded;

  final bool isRoot;

  final bool isHomeDetail;

  /// Label of the page this detail is mounted on, when it is not its own list
  /// (e.g. viewing an album from a song list). The back button then returns to
  /// that page.
  final String? mountedOnLabel;

  const SongList({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.folder,
    this.isFrequently = false,
    this.isRecently = false,
    this.isRecentlyAdded = false,
    this.isRoot = true,
    this.isHomeDetail = false,
    this.mountedOnLabel,
  });

  @override
  State<StatefulWidget> createState() => _SongListState();
}

class _SongListState extends State<SongList> {
  String title = '';
  List<MyAudioMetadata> songList = [];
  List<MyAudioMetadata> tmpSongList = [];

  Playlist? playlist;
  Artist? artist;
  Album? album;
  Folder? folder;

  bool isLibrary = false;
  bool isFrequently = false;
  bool isRecently = false;
  bool isRecentlyAdded = false;

  bool canModify = false;

  Timer? timer;

  bool waitForSecondClick = false;
  Timer? doubleClicktimer;

  Timer? searchTimer;

  final currentSongListNotifier = ValueNotifier<List<MyAudioMetadata>>([]);

  final listIsScrollingNotifier = ValueNotifier(false);
  final scrollController = ScrollController();
  final textController = TextEditingController();

  String get searchValue => textController.text;

  bool isSearching = false;

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  /// First song of the list as it is ordered, which is the list's cover. Kept
  /// apart from the shown list so that a search does not change the cover.
  final coverSongNotifier = ValueNotifier<MyAudioMetadata?>(null);
  ValueNotifier<int> changeNotifier = ValueNotifier(0);

  Map<MyAudioMetadata, ValueNotifier<bool>> isSelectedNotifierMap = {};

  int continuousSelectBeginIndex = 0;

  final showPlayButtonNotifierMap = <MyAudioMetadata, ValueNotifier<bool>>{};

  final padding = const EdgeInsets.symmetric(horizontal: 30);

  ValueNotifier<bool>? rootVisibleNotifier;
  Function()? backToRoot;

  bool hideOthers = false;

  String rootLabel = '';

  bool prepareing = true;

  /// Server description of the album being viewed, fetched once when the page
  /// opens (only Navidrome has one).
  String? albumDescription;

  /// Whether the album/artist page can be marked as a favourite.
  bool get canFavorite {
    if (album == null && artist == null) {
      return false;
    }
    if (isNotStreamSource) {
      return true;
    }
    return streamClient?.supportsEntityFavorites == true;
  }

  ArtistAlbumBase? get favoriteEntity => album ?? artist;

  bool get reorderable {
    return canModify &&
        searchValue.isEmpty &&
        sortTypeNotifier.value == 0 &&
        (playlist != null ||
            folder != null ||
            (isLibrary && isNotStreamSource));
  }

  bool get isFixed => isMobile || !reorderable;

  void updateHideOthers() {
    setState(() {
      hideOthers = rootVisibleNotifier!.value;
    });
  }

  String getTitleText(AppLocalizations l10n) {
    return isLibrary
        ? l10n.songs
        : playlist?.isFavorite == true
        ? l10n.favorites
        : isFrequently
        ? l10n.frequently
        : isRecently
        ? l10n.recently
        : isRecentlyAdded
        ? l10n.recentlyAdded
        : title;
  }

  MyPicture? get mainPicture {
    // A server-side playlist cover wins over any song's artwork.
    final playlistCover = playlist?.serverCover;
    if (playlistCover != null) {
      return playlistCover;
    }
    if (isStreamSource) {
      if (artist != null) {
        return artist!.picture;
      }
      if (album != null) {
        return album!.picture;
      }
    }
    final song = coverSongNotifier.value ?? getFirstSong(songList);
    return song?.picture;
  }

  /// Albums of the artist being viewed, in the order their songs appear.
  List<Album> artistAlbums(List<MyAudioMetadata> songs) {
    final albums = <Album>[];
    for (final song in songs) {
      final album = artistAlbumManager.albumOf(song);
      if (album != null && !albums.contains(album)) {
        albums.add(album);
      }
    }
    return albums;
  }

  /// The songs grouped by album, each group ordered by track number.
  List<(String, List<MyAudioMetadata>)> artistSongGroups(
    List<MyAudioMetadata> songs,
  ) {
    final groups = <String, List<MyAudioMetadata>>{};
    for (final song in songs) {
      groups.putIfAbsent(getAlbum(song), () => []).add(song);
    }
    for (final group in groups.values) {
      group.sort((a, b) => (a.track ?? 9999).compareTo(b.track ?? 9999));
    }
    return [for (final entry in groups.entries) (entry.key, entry.value)];
  }

  /// Top of [song]'s row in the artist view, or -1 when it is not shown: the
  /// album strip and one heading per album come before the songs, and each
  /// group is ordered by track number.
  double artistRowOffsetOf(MyAudioMetadata song, List<MyAudioMetadata> songs) {
    const stripHeight = 148.0;
    const headerHeight = 62.0;
    const rowHeight = 60.0;

    var offset = stripHeight;
    for (final group in artistSongGroups(songs)) {
      offset += headerHeight;
      for (final item in group.$2) {
        if (item == song) {
          return offset;
        }
        offset += rowHeight;
      }
    }
    return -1;
  }

  /// Opens an album of the artist: the albums layer owns album detail pages.
  Future<void> openArtistAlbum(Album album) async {
    layersManager.switchRootLayer('albums');
    showCenterLoading();
    await layersManager.pushDetailIfNeed(album);
    removeCenterLoading();
  }

  /// Horizontal strip of the artist's albums; tapping one opens that album.
  Widget artistAlbumStrip(BuildContext context, List<MyAudioMetadata> songs) {
    final albums = artistAlbums(songs);
    if (albums.isEmpty) {
      return const SizedBox.shrink();
    }
    final textColor = colorManager.getSpecificTextColor();
    return SizedBox(
      height: 148,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => openArtistAlbum(album),
              child: SizedBox(
                width: 108,
                child: Column(
                  children: [
                    CoverArtWidget(
                      size: 92,
                      borderRadius: 10,
                      picture: album.picture,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: textColor),
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

  /// Heading of one album group: the album name and a button that puts just that
  /// album in the play queue (long press shuffles it).
  Widget artistGroupHeader(
    BuildContext context,
    String albumName,
    List<MyAudioMetadata> groupSongs,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 6, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              albumName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          Text(
            '${groupSongs.length}',
            style: TextStyle(fontSize: 12, color: textColor.withAlpha(140)),
          ),
          IconButton(
            icon: Icon(Icons.play_arrow_rounded, color: textColor),
            onPressed: () => audioHandler.setPlayQueue(groupSongs, 0),
            onLongPress: () => audioHandler.setPlayQueue(groupSongs, 1),
          ),
        ],
      ),
    );
  }

  /// The backdrop of this page is generated from its cover, which follows the
  /// sort order, so it is recomputed when the order changes.
  void refreshBackdrop() {
    layersManager.updateBackground();
  }

  void resetSelectedAndUpdateSongList() {
    continuousSelectBeginIndex = 0;
    for (final tmp in isSelectedNotifierMap.values) {
      tmp.value = false;
    }
    updateSongList();
  }

  void updateSongList() {
    prepareing = false;

    final currentSongList = List<MyAudioMetadata>.from(
      searchValue.isEmpty ? songList : tmpSongList,
    );

    for (var e in currentSongList) {
      showPlayButtonNotifierMap.putIfAbsent(e, () => ValueNotifier(false));
      isSelectedNotifierMap.putIfAbsent(e, () => ValueNotifier(false));
    }

    if (playlist != null) {
      canModify = playlist!.canModify;
    } else if (folder != null) {
      canModify = folder!.canModify;
    } else if (isLibrary) {
      canModify = library.canModify;
    }
    sortSongList(
      sortTypeNotifier.value,
      currentSongList,
      addedOrder: playlistAddedOrder,
    );
    currentSongListNotifier.value = currentSongList;

    if (searchValue.isEmpty) {
      // The cover is the first song of the chosen order, so changing the sort
      // changes it.
      coverSongNotifier.value = currentSongList.isEmpty
          ? null
          : currentSongList.first;
    }
  }

  /// The order the songs of a locally-built playlist were added in, oldest
  /// first: the playlist keeps them newest first, and the servers report a
  /// per-entry `created` instead.
  List<MyAudioMetadata>? get playlistAddedOrder {
    final target = playlist;
    if (target == null || isStreamSource) {
      return null;
    }
    return target.songList.reversed.toList();
  }

  void startNewSearchIfNeed() {
    if (prepareing) {
      return;
    }
    searchTimer?.cancel();
    searchTimer = Timer(Duration(milliseconds: 300), () async {
      if (searchValue.isNotEmpty) {
        tmpSongList = filterSongList(songList, searchValue);
      }
      resetSelectedAndUpdateSongList();
    });
  }

  @override
  void initState() {
    super.initState();

    playlist = widget.playlist;
    artist = widget.artist;
    album = widget.album;
    folder = widget.folder;
    isFrequently = widget.isFrequently;
    isRecently = widget.isRecently;
    isRecentlyAdded = widget.isRecentlyAdded;

    if (playlist != null) {
      title = playlist!.name;
      songList = playlist!.songList;
      sortTypeNotifier = songSortTypeNotifier(playlist!.sortKey);
      changeNotifier = playlist!.changeNotifier;
      if (!widget.isRoot) {
        rootVisibleNotifier = playlistsVisibleNotifier;
        backToRoot = () {
          layersManager.popDetail('playlists');
        };
        rootLabel = 'playlists';
      }
    } else if (artist != null) {
      title = artist!.name;
      songList = artist!.songList;
      sortTypeNotifier = songSortTypeNotifier('artist');
      rootVisibleNotifier = artistsVisibleNotifier;
      backToRoot = () {
        layersManager.popDetail('artists');
      };
      rootLabel = 'artists';
      changeNotifier = artist!.changeNotifier;
    } else if (album != null) {
      title = album!.name;
      songList = album!.songList;
      sortTypeNotifier = songSortTypeNotifier('album');
      rootLabel = 'albums';
      rootVisibleNotifier = albumsVisibleNotifier;
      backToRoot = () {
        layersManager.popDetail('albums');
      };
    } else if (folder != null) {
      title = folder!.id;
      songList = folder!.songList;
      sortTypeNotifier = songSortTypeNotifier(folder!.sortKey);
      changeNotifier = folder!.changeNotifier;
      rootVisibleNotifier = foldersVisibleNotifier;
      backToRoot = () {
        layersManager.popDetail('folders');
      };
      rootLabel = 'folders';
    } else if (isFrequently) {
      songList = history.frequentlySongList;
      history.frequentlyChangeNotifier.addListener(updateSongList);
    } else if (isRecently) {
      songList = history.recentlySongList;
      history.recentlyChangeNotifier.addListener(updateSongList);
    } else if (isRecentlyAdded) {
      songList = library.recentlyAddedSongList;
      library.changeNotifier.addListener(updateSongList);
    } else {
      isLibrary = true;
      songList = library.songList;
      sortTypeNotifier = songSortTypeNotifier(librarySortKey);
      library.changeNotifier.addListener(updateSongList);
    }

    if (widget.isHomeDetail) {
      rootVisibleNotifier = homeVisibleNotifier;
      rootLabel = 'home';
      backToRoot = () {
        layersManager.popDetail('home');
      };
    }

    // Opened from another page (a song list): that page owns this detail, so
    // the back button returns to it instead of the album/artist list, which is
    // not even shown underneath.
    final mountLabel = widget.mountedOnLabel;
    if (mountLabel != null && mountLabel.isNotEmpty) {
      rootLabel = mountLabel;
      rootVisibleNotifier =
          layersManager.rootVisibleNotifierOf(mountLabel) ??
          rootVisibleNotifier;
      backToRoot = () {
        layersManager.popDetail(mountLabel);
      };
    }
    rootVisibleNotifier?.addListener(updateHideOthers);

    // An album's description and an artist's biography are extra information
    // shown on the page; both are fetched once, in the background, so the page
    // opens at once.
    if (album != null && sourceType == .navidrome) {
      final albumId = album!.sourceId;
      if (albumId != null) {
        streamClient?.getAlbumNotes(albumId).then((notes) {
          if (notes != null && mounted) {
            setState(() => albumDescription = notes);
          }
        });
      }
    }
    if (artist != null) {
      loadArtistInfoIfNeed(artist!).then((_) {
        if (mounted) setState(() {});
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      updateSongList();
    });

    sortTypeNotifier.addListener(resetSelectedAndUpdateSongList);
    sortTypeNotifier.addListener(refreshBackdrop);
    changeNotifier.addListener(updateSongList);
    textController.addListener(startNewSearchIfNeed);
  }

  @override
  void dispose() {
    rootVisibleNotifier?.removeListener(updateHideOthers);

    sortTypeNotifier.removeListener(resetSelectedAndUpdateSongList);
    sortTypeNotifier.removeListener(refreshBackdrop);
    changeNotifier.removeListener(updateSongList);
    textController.removeListener(startNewSearchIfNeed);
    scrollController.dispose();
    timer?.cancel();
    doubleClicktimer?.cancel();
    searchTimer?.cancel();
    super.dispose();
  }

  Widget mainCover(double size) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        currentSongListNotifier,
        coverSongNotifier,
      ]),
      builder: (_, _) {
        MyPicture? picture = mainPicture;
        return ListenableBuilder(
          listenable: Listenable.merge([
            picture?.changeNotifier,
            mainPageThemeNotifier,
            layersManager.backgroundChangeNotifier,
          ]),
          builder: (_, _) {
            final coverArt = CoverArtWidget(
              size: size,
              borderRadius: size / 10,
              picture: picture,
              elevation: 5,
              color: colorManager.getSpecificMainPageCoverArtBaseColorForm(
                picture,
              ), // keep stable color
            );

            return widget.isRoot
                ? coverArt
                : Hero(
                    tag:
                        (picture?.id ?? '') +
                        rootLabel +
                        getTitleText(AppLocalizations.of(context)),
                    transitionOnUserGestures: true,
                    flightShuttleBuilder:
                        (
                          flightContext,
                          animation,
                          flightDirection,
                          fromHeroContext,
                          toHeroContext,
                        ) => FittedBox(child: toHeroContext.widget),
                    child: coverArt,
                  );
          },
        );
      },
    );
  }

  void moveToTop(int index) {
    final item = songList.removeAt(index);
    songList.insert(0, item);

    if (isLibrary) {
      library.update();
    } else if (folder != null) {
      folder!.update();
    } else {
      playlist!.update();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isTooNarrow(context)) {
      return pageView(context);
    }
    return panelView(context);
  }
}
