import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lpinyin/lpinyin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/layer/layers_manager.dart';

final artistAlbumManager = ArtistAlbumManager();

/// Identity of a song's album: the server's album id when it has one, the album
/// name otherwise. Two artists can each have an album of the same name, and
/// only the id tells them apart - keying by name merged their songs.
String albumKeyOf(MyAudioMetadata song) {
  final id = song.albumId;
  return (id != null && id.isNotEmpty) ? 'id:$id' : 'name:${getAlbum(song)}';
}

/// Rank used by the "favourites" order: 0 when not a favourite, otherwise the
/// time it was starred (1 when the source reports none). A descending sort then
/// lists favourites first, the most recently starred on top.
int _starredRank(ArtistAlbumBase entity) {
  if (!entity.starredNotifier.value) {
    return 0;
  }
  return entity.starredAt?.millisecondsSinceEpoch ?? 1;
}

/// Artist biographies and image URLs, kept across pages, sources and launches.
/// Keyed by artist name, so a local library shows what Navidrome cached for the
/// same artist, and so recreating the artist list never loses it.
class CachedArtistInfo {
  String? biography;
  String? imageUrl;

  /// Whether the server actually has an artist image. Decided from the server's
  /// artist list, so the list and the detail page agree from the first frame -
  /// no album cover that changes once a biography arrives.
  bool hasImage;

  /// The server id, kept so a local library can still find the cached image.
  String? artistId;

  CachedArtistInfo({
    this.biography,
    this.imageUrl,
    this.hasImage = false,
    this.artistId,
  });
}

final Map<String, CachedArtistInfo> artistInfoCache = {};

/// Artist pictures, kept per name for the same reason: the list is rebuilt on
/// every load, and a rebuilt artist must not fall back to its album cover while
/// the already-cached image is on disk.
final Map<String, MyPicture> artistPictureCache = {};

String artistKey(String name) => name.trim().toLowerCase();

File? _artistInfoFile;
bool _artistInfoLoaded = false;

File _artistInfoFileOf() =>
    _artistInfoFile ??= File('${appSupportDir.path}/artist_info.json');

/// Reads the on-disk artist cache once per source.
Future<void> loadArtistInfoCache() async {
  if (_artistInfoLoaded) {
    return;
  }
  _artistInfoLoaded = true;
  try {
    final file = _artistInfoFileOf();
    if (!await file.exists()) {
      return;
    }
    final map = jsonDecode(await file.readAsString());
    if (map is! Map) {
      return;
    }
    map.forEach((key, value) {
      if (value is Map) {
        artistInfoCache['$key'] = CachedArtistInfo(
          biography: value['biography'] as String?,
          imageUrl: value['imageUrl'] as String?,
          hasImage: value['hasImage'] as bool? ?? false,
          artistId: value['artistId'] as String?,
        );
      }
    });
  } catch (e) {
    logger.output('artist info cache: $e');
  }
}

Future<void> saveArtistInfoCache() async {
  try {
    await _artistInfoFileOf().writeAsString(
      jsonEncode({
        for (final entry in artistInfoCache.entries)
          entry.key: {
            'biography': entry.value.biography,
            'imageUrl': entry.value.imageUrl,
            'hasImage': entry.value.hasImage,
            'artistId': entry.value.artistId,
          },
      }),
    );
  } catch (e) {
    logger.output('artist info cache: $e');
  }
}

/// Forgets every cached artist biography and image, on disk and in memory. The
/// image files are removed too, so the cache screen's number really drops.
Future<void> clearArtistInfoCache() async {
  artistInfoCache.clear();
  for (final picture in artistPictureCache.values) {
    try {
      final file = File(picture.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    picture.isExist = false;
    picture.isLoaded = false;
  }
  artistPictureCache.clear();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.clear();
  imageCache.clearLiveImages();
  try {
    final file = _artistInfoFileOf();
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e) {
    logger.output('artist info cache: $e');
  }
}

/// Reads every artist's biography and whether it has an image in one go, from
/// Navidrome's own artist list, and stores it. A local library reads the same
/// cache afterwards.
Future<void> prefetchArtistInfo() async {
  await loadArtistInfoCache();
  if (sourceType != .navidrome) {
    return;
  }
  final summaries = await streamClient?.getArtistSummaries();
  if (summaries == null || summaries.isEmpty) {
    return;
  }
  for (final summary in summaries) {
    final key = artistKey(summary.name);
    final existing = artistInfoCache[key];
    artistInfoCache[key] = CachedArtistInfo(
      biography: summary.biography ?? existing?.biography,
      imageUrl: summary.imageUrl ?? existing?.imageUrl,
      hasImage: summary.hasImage,
      artistId: summary.id,
    );
  }
  await saveArtistInfoCache();
}

/// Drops one artist's cached biography and image (missing ones are fine) and
/// fetches them again. Returns whether the server now reports an artist image;
/// when it does not, the album cover is used instead.
Future<bool> refreshArtistCache(Artist artist) async {
  final key = artistKey(artist.name);
  final info = artistInfoCache[key];
  final artistId = info?.artistId ?? artist.sourceId;

  final picture = artistPictureCache.remove(key);
  if (picture != null) {
    try {
      final file = File(picture.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      logger.output('artist cache: $e');
    }
  }
  // The widget reads the image with FileImage, whose cache entry is keyed by
  // the path and is not re-read when the file changes: without dropping it the
  // old picture stays on screen even though the bytes were fetched again.
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.clear();
  imageCache.clearLiveImages();
  artistInfoCache.remove(key);
  await saveArtistInfoCache();

  if (artistId == null || sourceType != .navidrome) {
    artist.changeNotifier.value++;
    artistAlbumManager.updateNotifier.value++;
    return false;
  }

  final fresh = await streamClient?.getArtistInfo(artistId);
  final hasImage = (fresh?.imageUrl ?? '').isNotEmpty;
  artistInfoCache[key] = CachedArtistInfo(
    biography: fresh?.biography,
    imageUrl: fresh?.imageUrl,
    hasImage: hasImage,
    artistId: artistId,
  );
  await saveArtistInfoCache();

  artist.changeNotifier.value++;
  artistAlbumManager.updateNotifier.value++;
  return hasImage;
}

/// Fetches one artist's biography if the cache does not have it yet.
Future<void> loadArtistInfoIfNeed(Artist artist) async {
  await loadArtistInfoCache();
  final key = artistKey(artist.name);
  final cached = artistInfoCache[key];
  if (cached != null && (cached.biography ?? '').isNotEmpty) {
    return;
  }
  if (sourceType != .navidrome) {
    return;
  }
  final id = artist.sourceId;
  if (id == null) {
    return;
  }
  final info = await streamClient?.getArtistInfo(id);
  if (info == null) {
    return;
  }
  artistInfoCache[key] = CachedArtistInfo(
    biography: info.biography,
    imageUrl: info.imageUrl,
    hasImage: cached?.hasImage ?? (info.imageUrl ?? '').isNotEmpty,
    artistId: id,
  );
  await saveArtistInfoCache();
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
        final id = album.sourceId;
        album.starredNotifier.value = id != null && albumIds.containsKey(id);
        album.starredAt = id == null ? null : albumIds[id];
      }
      final artistIds =
          await streamClient?.getStarredIds(isArtist: true) ?? const {};
      for (final artist in artistList) {
        final id = artist.sourceId;
        artist.starredNotifier.value = id != null && artistIds.containsKey(id);
        artist.starredAt = id == null ? null : artistIds[id];
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
    final key = albumKeyOf(song);

    Album? album = albumMap[key];
    if (album == null) {
      album = Album(name: albumName);
      albumList.add(album);
      albumMap[key] = album;
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

  /// The album a song belongs to, told apart by the server's album id so that
  /// two artists each having an album of the same name stay separate.
  Album? albumOf(MyAudioMetadata song) => albumMap[albumKeyOf(song)];

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
        case 5: // favourites: starred first, most recently starred first
          return _starredRank(a).compareTo(_starredRank(b));
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
        case 5: // favourites: starred first, most recently starred first
          return _starredRank(a).compareTo(_starredRank(b));
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

  /// When the album/artist was marked as a favourite, for the "favourites"
  /// order; null when the source does not report it.
  DateTime? starredAt;
}

class Artist extends ArtistAlbumBase {
  Artist({required super.name}) : super(isArtist: true);

  Set<Album> albumSet = {};

  List<Album> albumList = [];

  final changeNotifier = ValueNotifier(0);

  /// Number of non-empty albums by this artist.
  int get albumCount => albumSet.where((album) => !album.isEmpty).length;

  /// Biography and image URL, read from the shared cache so they survive the
  /// artist list being rebuilt and are shared with a local library.
  String? get biography => artistInfoCache[artistKey(name)]?.biography;
  String? get imageUrl => artistInfoCache[artistKey(name)]?.imageUrl;

  /// The artist's own image, decided from the cache for the list and the detail
/// page alike: the server's artist list says whether this artist has an image.
/// When it does, that image is fetched (once) into a cache keyed by name, which
/// a local library reads too. When it does not, the album cover is used - never
/// the server's blank placeholder. Nothing here depends on a biography arriving
/// asynchronously, so the picture cannot change under the user.
  @override
  MyPicture get picture {
    final key = artistKey(name);
    final existing = artistPictureCache[key];
    if (existing != null) {
      return existing;
    }

    final info = artistInfoCache[key];
    if (info == null || !info.hasImage) {
      return super.picture;
    }

    final picture = MyPicture.artist(
      name,
      artistId: info.artistId ?? sourceId,
    );
    // A local library cannot fetch the image; it can only use one that
    // Navidrome already cached. Without the file, the album cover is used - the
    // same picture the detail page shows, so the list never disagrees with it.
    if (!isStreamSource && !picture.isExist) {
      return super.picture;
    }
    artistPictureCache[key] = picture;
    return picture;
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
