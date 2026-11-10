import 'dart:async';

import 'package:lpinyin/lpinyin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/layer/layers_manager.dart';

final artistAlbumManager = ArtistAlbumManager();

/// Artist biographies and images, kept across pages and visits. Only a
/// Navidrome server provides them, and only its information is cached here -
/// never a Feiniu cover, which its own page fetches.
final Map<String, ({String? biography, String? imageUrl})> artistInfoCache = {};

/// Fetches the artist's biography and image once, then remembers them on the
/// artist and in [artistInfoCache].
Future<void> loadArtistInfoIfNeed(Artist artist) async {
  if (sourceType != .navidrome) {
    return;
  }
  final id = artist.sourceId;
  if (id == null) {
    return;
  }
  final cached = artistInfoCache[id];
  if (cached != null) {
    artist.biography = cached.biography;
    artist.imageUrl = cached.imageUrl;
    return;
  }
  final info = await streamClient?.getArtistInfo(id);
  if (info == null) {
    return;
  }
  artistInfoCache[id] = info;
  artist.biography = info.biography;
  artist.imageUrl = info.imageUrl;
}

class ArtistAlbumManager {
  List<Artist> artistList = [];
  Map<String, Artist> artistMap = {};

  List<Album> albumList = [];
  // streamSoure will has duplicate name album
  Map<String, Album> albumMap = {};
  final updateNotifier = ValueNotifier(0);

  bool done = false;

  ArtistAlbumManager() {
    artistsIsAscendingNotifier.addListener(() {
      sortArtists();
      updateNotifier.value++;
    });
    albumsIsAscendingNotifier.addListener(() {
      sortAlbums();
      updateNotifier.value++;
    });
    artistsSortKeyNotifier.addListener(() {
      sortArtists();
      updateNotifier.value++;
    });
    albumsSortKeyNotifier.addListener(() {
      sortAlbums();
      updateNotifier.value++;
    });
  }

  List<ArtistAlbumBase> getArtistAlbumList(bool isArtist) {
    return isArtist ? artistList : albumList;
  }

  ValueNotifier<bool> getRandomizeNotifier(bool isArtist) {
    return isArtist ? artistsRandomizeNotifier : albumsRandomizeNotifier;
  }

  ValueNotifier<bool> getIsAscendingNotifier(bool isArtist) {
    return isArtist ? artistsIsAscendingNotifier : albumsIsAscendingNotifier;
  }

  ValueNotifier<bool> getUseLargePictureNotifier(bool isArtist) {
    return isArtist
        ? artistsUseLargePictureNotifier
        : albumsUseLargePictureNotifier;
  }

  void classify() async {
    for (final song in library.songList) {
      _processSong(song);
    }

    for (final album in albumList) {
      album.sort();
    }

    // combineAlbums fills each artist's song list, which a song-count or a
    // play-count order reads, so it has to run before the artists are sorted.
    for (final artist in artistList) {
      artist.combineAlbums();
    }

    sortArtists();
    sortAlbums();

    done = true;
    updateNotifier.value++;
    unawaited(applyFavorites());
  }

  /// Marks albums and artists as favourites, from the server's starred lists on
  /// a Navidrome server and from the local store on a local library. Feiniu and
  /// Emby have no album/artist favourite here, so nothing is marked.
  Future<void> applyFavorites() async {
    if (sourceType == .navidrome) {
      final albumIds =
          await streamClient?.getStarredIds(isArtist: false) ?? const {};
      for (final album in albumList) {
        album.starredNotifier.value =
            album.sourceId != null && albumIds.contains(album.sourceId);
      }
      final artistIds =
          await streamClient?.getStarredIds(isArtist: true) ?? const {};
      for (final artist in artistList) {
        artist.starredNotifier.value =
            artist.sourceId != null && artistIds.contains(artist.sourceId);
      }
    } else if (isNotStreamSource) {
      for (final album in albumList) {
        album.starredNotifier.value = localAlbumFavorites.contains(album.name);
      }
      for (final artist in artistList) {
        artist.starredNotifier.value = localArtistFavorites.contains(
          artist.name,
        );
      }
    }
  }

  void _processSong(MyAudioMetadata song) {
    final albumName = getAlbum(song);

    Album? album = albumMap[albumName];
    if (album == null) {
      album = Album(name: albumName);
      albumList.add(album);
      albumMap[albumName] = album;
    }

    if (song.year != null && album.year == null) {
      album.year = song.year;
    }

    album.songList.add(song);

    for (String artistName in getArtists(getArtist(song))) {
      Artist? artist = artistMap[artistName];
      if (artist == null) {
        artist = Artist(name: artistName);
        artistList.add(artist);
        artistMap[artistName] = artist;
      }
      artist.albumSet.add(album);
    }
  }

  void sortArtists() {
    final ascending = artistsIsAscendingNotifier.value;
    int compare(Artist a, Artist b) {
      switch (artistsSortKeyNotifier.value) {
        case 1: // album count
          return a.albumCount.compareTo(b.albumCount);
        case 2: // song count
          return a.songList.length.compareTo(b.songList.length);
        case 3: // size on disk
          return a.size.compareTo(b.size);
        case 4: // play count
          return a.playCount.compareTo(b.playCount);
        default: // name
          return a.compareName.compareTo(b.compareName);
      }
    }

    artistList.sort((a, b) {
      final result = compare(a, b);
      // Ties keep the name order, so the list is stable under the switches.
      return ascending
          ? (result != 0 ? result : a.compareName.compareTo(b.compareName))
          : (result != 0 ? -result : a.compareName.compareTo(b.compareName));
    });
  }

  void sortAlbums() {
    final ascending = albumsIsAscendingNotifier.value;
    int compare(Album a, Album b) {
      switch (albumsSortKeyNotifier.value) {
        case 1: // added time (oldest song of the album)
          final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return at.compareTo(bt);
        case 2: // play count
          return a.playCount.compareTo(b.playCount);
        case 3: // size on disk
          return a.size.compareTo(b.size);
        case 4: // latest year
          return (a.maxYear ?? 0).compareTo(b.maxYear ?? 0);
        default: // name
          return a.compareName.compareTo(b.compareName);
      }
    }

    albumList.sort((a, b) {
      final result = compare(a, b);
      return ascending
          ? (result != 0 ? result : a.compareName.compareTo(b.compareName))
          : (result != 0 ? -result : a.compareName.compareTo(b.compareName));
    });
  }

  void updateArtistAlbum() {
    layersManager.clearArtistAlbum();
    clear();
    classify();
  }

  void clear() {
    artistList.clear();
    albumList.clear();
    artistMap.clear();
    albumMap.clear();
    done = false;
  }
}

abstract class ArtistAlbumBase {
  final String name;
  late final String compareName;

  final List<MyAudioMetadata> songList = [];

  final bool isArtist;

  MyPicture get picture => songList.first.picture;

  ArtistAlbumBase({required this.name, required this.isArtist}) {
    compareName = PinyinHelper.getPinyinE(name);
  }

  bool get isEmpty => songList.isEmpty;

  int get totalCount => songList.length;

  /// Total plays across every song here, which is what the server would report
  /// for the album or the artist as a whole.
  int get playCount =>
      songList.fold(0, (sum, song) => sum + song.playCount);

  /// Space the songs take up, in bytes; 0 when the source does not report it.
  int get size => songList.fold(0, (sum, song) => sum + (song.size ?? 0));

  Duration get totalDuration => songList.fold(
    Duration.zero,
    (sum, song) => sum + (song.duration ?? Duration.zero),
  );

  /// When the album or the artist was added, i.e. the oldest of its songs.
  DateTime? get createdAt {
    DateTime? earliest;
    for (final song in songList) {
      final created = song.created;
      if (created != null &&
          (earliest == null || created.isBefore(earliest))) {
        earliest = created;
      }
    }
    return earliest;
  }

  /// The server id of the album/artist, used to star it as a whole.
  String? get sourceId {
    for (final song in songList) {
      final id = isArtist ? song.artistId : song.albumId;
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  /// Whether this album/artist is a favourite, driven by the server's starred
  /// list. Only meaningful for a source that can star a whole album or artist.
  final starredNotifier = ValueNotifier<bool>(false);
}

class Artist extends ArtistAlbumBase {
  Artist({required super.name}) : super(isArtist: true);

  Set<Album> albumSet = {};

  List<Album> albumList = [];

  final changeNotifier = ValueNotifier(0);

  /// Number of non-empty albums by this artist.
  int get albumCount => albumSet.where((album) => !album.isEmpty).length;

  /// Server biography and image URL, fetched lazily and cached; only a
  /// Navidrome server provides them.
  String? biography;
  String? imageUrl;

  MyPicture? _picture;

  /// The artist's own image when the source serves one (Navidrome does, via the
  /// same cover-art endpoint), and the first album's cover otherwise.
  @override
  MyPicture get picture {
    if (isStreamSource) {
      final id = sourceId;
      if (id != null) {
        return _picture ??= MyPicture.form(id);
      }
    }
    return super.picture;
  }

  void combineAlbums() {
    // classify() runs again on every load and sync, while this list used to be
    // appended to every time: a song ended up in the artist three times.
    songList.clear();
    albumSet.removeWhere((album) => album.isEmpty);
    albumList = albumSet.toList();
    albumList.sort((a, b) {
      int aYear = a.year ?? 9999;
      int bYear = b.year ?? 9999;
      final yearCompre = aYear.compareTo(bYear);
      if (yearCompre != 0) {
        return yearCompre;
      }
      return a.compareName.compareTo(b.compareName);
    });

    for (final album in albumList) {
      for (final song in album.songList) {
        if (getArtist(song).contains(name)) {
          songList.add(song);
        }
      }
    }
  }
}

class Album extends ArtistAlbumBase {
  Album({required super.name}) : super(isArtist: false);

  int? year;

  /// Server description/notes for the album; only Navidrome provides one, and
  /// it is fetched when the album page is opened.
  String? description;

  /// The most recent year among the album's songs, which is what a "year" sort
  /// key should use - [year] is just the first song's.
  int? get maxYear {
    int? latest;
    for (final song in songList) {
      final value = song.year;
      if (value != null && (latest == null || value > latest)) {
        latest = value;
      }
    }
    return latest ?? year;
  }

  int _sort(MyAudioMetadata a, MyAudioMetadata b) {
    final discA = a.disc ?? 9999;
    final discB = b.disc ?? 9999;

    final discCompare = discA.compareTo(discB);
    if (discCompare != 0) return discCompare;

    final trackA = a.track ?? 9999;
    final trackB = b.track ?? 9999;

    return trackA.compareTo(trackB);
  }

  void sort() {
    songList.sort((a, b) => _sort(a, b));
  }
}
