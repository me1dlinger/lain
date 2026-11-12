import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/database.dart';
import 'package:lain/base/data/folder_scan_settings.dart';
import 'package:lain/base/extensions/metadata_extension.dart';
import 'package:lain/base/services/background_task_service.dart';
import 'package:lain/base/services/file_time.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/lyric.dart';
import 'package:lain/base/services/media_art.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/services/picture_load_scheduler.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/services/webdav_client.dart';
import 'package:lain/base/utils/path.dart';
import 'package:lain/base/data/folder.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:pool/pool.dart';

Library library = Library();

final ValueNotifier<double> cacheSizeNotifier = ValueNotifier(0);

enum CacheKind { song, cover, lyric, list }

/// One file inside the source's cache directories, with the song it belongs to
/// when that can be resolved (cache files are named after the md5 of a song or
/// cover id).
class CacheEntry {
  final CacheKind kind;
  final String path;
  final int size;
  final DateTime modified;
  final MyAudioMetadata? song;

  const CacheEntry({
    required this.kind,
    required this.path,
    required this.size,
    required this.modified,
    this.song,
  });

  String get fileName {
    final index = path.lastIndexOf(Platform.pathSeparator);
    return index == -1 ? path : path.substring(index + 1);
  }
}

/// Everything currently on disk, largest first.
final ValueNotifier<List<CacheEntry>> cacheEntriesNotifier = ValueNotifier([]);

/// How far a precache run has got, or null when none is running: (done, total).
final precacheProgressNotifier = ValueNotifier<(int, int)?>(null);

/// The cached files of one song, as a single row: its audio, its cover and its
/// lyrics are three files on disk, but one entry to the user.
class CachedSong {
  final MyAudioMetadata song;
  final CacheEntry? audio;
  final CacheEntry? cover;
  final CacheEntry? lyric;

  const CachedSong({required this.song, this.audio, this.cover, this.lyric});

  bool get hasAudio => audio != null;
  bool get hasCover => cover != null;
  bool get hasLyric => lyric != null;

  int get size => (audio?.size ?? 0) + (cover?.size ?? 0) + (lyric?.size ?? 0);

  List<CacheEntry> get files =>
      [audio, cover, lyric].whereType<CacheEntry>().toList();

  DateTime get modified {
    var newest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final entry in files) {
      if (entry.modified.isAfter(newest)) {
        newest = entry.modified;
      }
    }
    return newest;
  }

  CachedSong withPart(CacheKind kind, CacheEntry entry) {
    return CachedSong(
      song: song,
      audio: kind == CacheKind.song ? entry : audio,
      cover: kind == CacheKind.cover ? entry : cover,
      lyric: kind == CacheKind.lyric ? entry : lyric,
    );
  }
}

/// Groups the raw cache files per song, largest first, so the cache view shows
/// one row per song with the parts that are actually on disk.
List<CachedSong> groupCacheBySong(List<CacheEntry> entries) {
  final bySong = <String, CachedSong>{};
  final order = <String>[];

  for (final entry in entries) {
    final song = entry.song;
    if (song == null) {
      continue;
    }
    final existing = bySong[song.id];
    if (existing == null) {
      bySong[song.id] = CachedSong(song: song).withPart(entry.kind, entry);
      order.add(song.id);
    } else {
      bySong[song.id] = existing.withPart(entry.kind, entry);
    }
  }

  final songs = [for (final id in order) bySong[id]!];
  songs.sort((a, b) => b.size.compareTo(a.size));
  return songs;
}

class Library {
  MetadataDB? _metadataDB;

  Map<String, MyAudioMetadata> id2Song = {};
  List<MyAudioMetadata> songList = [];

  final changeNotifier = ValueNotifier(0);

  File? _folderIdListFile;
  List<Folder> folderList = [];
  final folderListChangeNotifier = ValueNotifier(0);

  bool canModify = false;

  /// Newest songs first, by the creation time of a local file or the `created`
  /// value a server reported: the home page's shelf, and the page it opens.
  List<MyAudioMetadata> get recentlyAddedSongList {
    final songs = List<MyAudioMetadata>.from(songList);
    songs.sort((a, b) {
      final aTime = a.created ?? a.modified ?? DateTime(1970);
      final bTime = b.created ?? b.modified ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return songs.take(30).toList();
  }

  Library() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _metadataDB = MetadataDB(openMetadataDB('${sourceType.name}/metadata.db'));
    if (isNotStreamSource) {
      _folderIdListFile = File(
        "${getFolderConfigPath(sourceType)}/folder_id_list.json",
      );
      initFile(_folderIdListFile!, true);
    }
  }

  Future<bool> updateFolders(List<String> idList) async {
    bool needUpdate = false;
    if (idList.length == folderList.length) {
      for (int i = 0; i < idList.length; i++) {
        if (idList[i] != folderList[i].id) {
          needUpdate = true;
          break;
        }
      }
    } else {
      needUpdate = true;
    }

    if (!needUpdate) {
      return false;
    }

    List<Folder> newFolderList = [];
    for (int i = 0; i < idList.length; i++) {
      String id = idList[i];
      bool exist = false;
      for (final folder in folderList) {
        if (id == folder.id) {
          newFolderList.add(folder);
          exist = true;
          break;
        }
      }
      if (!exist) {
        newFolderList.add(await Folder.create(id, sourceType == .webdav));
      }
    }

    for (final folder in folderList) {
      if (newFolderList.contains(folder)) {
        continue;
      }
      folder.delete();
      layersManager.removeLayerIfNeed(folder);
    }

    folderList = newFolderList;
    await _folderIdListFile!.writeAsString(
      jsonEncode(folderList.map((e) => e.id).toList()),
    );

    folderListChangeNotifier.value++;
    return true;
  }

  Folder? getFolderById(String id) {
    for (final folder in folderList) {
      if (folder.id == id) {
        return folder;
      }
    }

    return null;
  }

  Future<void> initFolders() async {
    // must execute before loading metadata(set ios path)
    for (final id in await readJsonListFile(_folderIdListFile!)) {
      final folder = await Folder.from(id, sourceType == .webdav);
      folderList.add(folder);
    }
  }

  Future<void> load() async {
    if (isNotStreamSource) {
      await initFolders();
    }

    do {
      final rows = await (_metadataDB!.select(
        _metadataDB!.metadataItems,
      )..limit(1000, offset: songList.length)).get();

      if (rows.isEmpty) {
        break;
      }

      for (final row in rows) {
        final song = row.toMetadata();
        id2Song.putIfAbsent(row.id, () => song);
        songList.add(song);
      }

      if (songList.length == 1000 || songList.length % 10000 == 0) {
        changeNotifier.value++;
        layersManager.updateBackground();
      }
    } while (true);

    canModify = true;
    changeNotifier.value++;
    layersManager.updateBackground();

    if (sourceType == .local) {
      await _restoreCreatedTimes();
    } else {
      await _restoreServerCreatedTimes();
    }

    for (final folder in folderList) {
      await folder.load();
    }

    await _accumulateCache();

    // Warm the playlist-level lists (a few hundred songs at most) so the media
    // session has artwork and lyrics ready without the user asking. Phones only:
    // it exists for what a head unit shows, and a desktop has nothing to feed.
    // Idempotent, so it costs nothing the second time round.
    if (isMobile) {
      unawaited(precachePlaylists());
    }
  }

  /// A server's `created` value is not part of the metadata database either;
  /// restore it from the file written during the last sync, so sorting by added
  /// time still works after the app is restarted.
  Future<void> _restoreServerCreatedTimes() async {
    await serverCreatedTimes.ensureLoaded();
    for (final song in songList) {
      song.created ??= serverCreatedTimes.at(song.id);
    }
  }

  /// "Added time" is not part of the metadata database. Restore it from the
  /// creation-time cache written during the last scan, then resolve whatever is
  /// still unknown in the background, so an existing library sorts correctly
  /// without a manual rescan. Songs that stay unresolved fall back to their
  /// modified time in the comparator.
  Future<void> _restoreCreatedTimes() async {
    String pathOf(MyAudioMetadata song) =>
        Platform.isIOS ? revertIOSPath(song.id) : song.id;

    void apply(Map<String, DateTime> times) {
      if (times.isEmpty) {
        return;
      }
      for (final song in songList) {
        if (song.created == null) {
          song.created = times[pathOf(song)];
        }
      }
    }

    apply(await fileCreationTimes.cached());

    final unknown = [
      for (final song in songList)
        if (song.created == null) pathOf(song),
    ];
    if (unknown.isEmpty) {
      return;
    }

    unawaited(
      fileCreationTimes.resolve(unknown).then((times) {
        apply(times);
      }),
    );
  }

  Future<void> _accumulateCache() async {
    final entries = <CacheEntry>[];
    var totalBytes = 0;
    int totalOf() => totalBytes;

    // Cache files are named md5(song id) / md5(cover id), so map them back to
    // the songs: a cover belongs to every song that uses it, and the first one
    // is the row it is shown on (the total is still counted once).
    final byHash = <String, MyAudioMetadata>{};
    final byCover = <String, MyAudioMetadata>{};
    for (final song in songList) {
      byHash.putIfAbsent(
        md5.convert(utf8.encode(song.id)).toString(),
        () => song,
      );
      final coverId = song.picture.id;
      if (coverId.isNotEmpty) {
        byCover.putIfAbsent(
          md5.convert(utf8.encode(coverId)).toString(),
          () => song,
        );
      }
    }

    Future<void> collect(
      String dirPath,
      CacheKind kind, [
      Map<String, MyAudioMetadata>? index,
    ]) async {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return;
      }
      final lookup = index ?? byHash;
      await for (final file in dir.list()) {
        if (file is! File || file.path.endsWith('.part')) {
          continue;
        }
        final stat = await file.stat();
        totalBytes += stat.size;
        final name = file.path.substring(
          file.path.lastIndexOf(Platform.pathSeparator) + 1,
        );
        entries.add(
          CacheEntry(
            kind: kind,
            path: file.path,
            size: stat.size,
            modified: stat.modified,
            song: lookup[name],
          ),
        );
      }
    }

    await collect(getCachesPath(sourceType), CacheKind.song);
    await collect(getPicturesPath(sourceType), CacheKind.cover, byCover);
    await collect(getLrcPath(sourceType), CacheKind.lyric);

    // And the lists themselves: the database the library, artist, album and
    // playlist pages are built from, plus the sidecars holding a playlist's
    // songs, the folder list and the servers' added times. Opening a list reads
    // these; the server is only asked during a sync.
    final sourceDir = Directory('${appSupportDir.path}/${sourceType.name}');
    if (await sourceDir.exists()) {
      await for (final file in sourceDir.list()) {
        if (file is! File) {
          continue;
        }
        final name = file.path.substring(
          file.path.lastIndexOf(Platform.pathSeparator) + 1,
        );
        // `metadata.db` is a SQLite database: its write-ahead files belong to it.
        if (name.startsWith('metadata.db') || name == 'created_times.json') {
          if (file.path.endsWith('.part')) {
            continue;
          }
          final stat = await file.stat();
          totalBytes += stat.size;
          entries.add(
            CacheEntry(
              kind: CacheKind.list,
              path: file.path,
              size: stat.size,
              modified: stat.modified,
            ),
          );
        }
      }
    }
    await collect(getPlaylistConfigPath(sourceType), CacheKind.list);
    await collect(getFolderConfigPath(sourceType), CacheKind.list);

    entries.sort((a, b) => b.size.compareTo(a.size));
    cacheEntriesNotifier.value = entries;
    cacheSizeNotifier.value = totalOf() / (1024 * 1024);
  }

  /// Removes a single cached file and keeps the song's state in sync.
  Future<void> refreshCache() => _accumulateCache();

  Future<void> deleteCacheEntry(CacheEntry entry) async {
    final file = File(entry.path);
    if (await file.exists()) {
      final size = await file.length();
      await file.delete();
      cacheSizeNotifier.value = (cacheSizeNotifier.value - size / (1024 * 1024))
          .clamp(0, double.infinity);
    }
    if (entry.kind == CacheKind.song) {
      entry.song?.cacheExist = false;
    } else if (entry.kind == CacheKind.lyric) {
      entry.song?.parsedLyrics = null;
    } else if (entry.kind == CacheKind.list) {
      _forgetSyncIfListsAreGone(entry);
    }
    await _accumulateCache();
  }

  /// The metadata database is what a streamed source shows at launch; with it
  /// gone the app must fetch again, and that is exactly what the marker file
  /// `synced.keep` suppresses. Dropping this file has to drop the marker with
  /// it, or the next launch would come up with an empty library instead.
  void _forgetSyncIfListsAreGone(CacheEntry entry) {
    final name = entry.fileName;
    final isTheLibrary =
        name.startsWith('metadata.db') || name.startsWith('created_times');
    if (!isTheLibrary) {
      return;
    }

    final marker = File(getSyncedFilePath(sourceType));
    if (marker.existsSync()) {
      marker.deleteSync();
    }
  }

  /// Removes every cached file of one song - its audio, cover and lyrics - as
  /// one action, since the cache view shows them as a single row.
  Future<void> deleteCachedSong(CachedSong cached) async {
    for (final entry in cached.files) {
      final file = File(entry.path);
      if (await file.exists()) {
        final size = await file.length();
        await file.delete();
        cacheSizeNotifier.value =
            (cacheSizeNotifier.value - size / (1024 * 1024)).clamp(
              0,
              double.infinity,
            );
      }
      if (entry.kind == CacheKind.song) {
        entry.song?.cacheExist = false;
      } else if (entry.kind == CacheKind.lyric) {
        entry.song?.parsedLyrics = null;
      } else if (entry.kind == CacheKind.list) {
        _forgetSyncIfListsAreGone(entry);
      }
    }

    // The downscaled copy belongs to the cover it was made from.
    final cover = cached.cover;
    if (cover != null) {
      final small = File(mediaArt.targetPathFor(cover.path));
      if (await small.exists()) {
        await small.delete();
      }
    }

    await _accumulateCache();
  }

  /// Fetches the artwork and lyrics of [songs] and writes the downscaled cover
  /// copies the media session publishes.
  ///
  /// Idempotent: a cover already on disk and lyrics already parsed are skipped,
  /// so repeating a run - or running it over a list that overlaps an earlier
  /// one - costs nothing.
  Future<void> precacheSongs(Iterable<MyAudioMetadata> songs) async {
    final list = songs.toList();
    if (list.isEmpty) {
      return;
    }
    precacheProgressNotifier.value = (0, list.length);
    try {
      for (var i = 0; i < list.length; i++) {
        final song = list[i];
        try {
          if (!song.picture.isLoaded) {
            await loadPictureSafe(song.picture);
          }
          await setParsedLyrics(song);
          final path = song.picture.path;
          if (path.isNotEmpty && File(path).existsSync()) {
            await mediaArt.smallFor(path);
          }
        } catch (e) {
          logger.output('[cache] precache failed for ${song.id}: $e');
        }
        precacheProgressNotifier.value = (i + 1, list.length);
      }
    } finally {
      precacheProgressNotifier.value = null;
      await _accumulateCache();
    }
  }

  /// The default precache: the songs of the playlists, favourites included -
  /// a few hundred at most - so playing from a list needs no waiting. Run after
  /// a sync; the whole library is only cached when the user asks for it.
  Future<void> precachePlaylists() async {
    final songs = <MyAudioMetadata>{};
    for (final playlist in playlistManager.playlists) {
      songs.addAll(playlist.songList);
    }
    if (songs.isEmpty) {
      return;
    }
    await precacheSongs(songs);
  }

  /// Songs whose audio is being fetched right now. Playback and a batch
  /// download share the same fetch instead of writing the same `.part` twice.
  final Map<String, Future<bool>> _cacheInFlight = {};

  /// Downloads one song's audio into the offline cache.
  ///
  /// Returns true when the song is on disk afterwards. [cancelToken] aborts the
  /// request; the partial file is deleted, so a later retry starts from the
  /// beginning rather than resuming.
  Future<bool> tryAddCache(MyAudioMetadata song, {CancelToken? cancelToken}) {
    if (sourceType == .local || song.cacheExist) {
      return Future.value(true);
    }
    final running = _cacheInFlight[song.id];
    if (running != null) {
      return running;
    }
    final task = _downloadSongToCache(song, cancelToken);
    _cacheInFlight[song.id] = task;
    unawaited(
      task
          .then<void>((_) {}, onError: (Object _, StackTrace _) {})
          .whenComplete(() => _cacheInFlight.remove(song.id)),
    );
    return task;
  }

  Future<bool> _downloadSongToCache(
    MyAudioMetadata song,
    CancelToken? cancelToken,
  ) async {
    final savePath = "${song.cachePath!}.part";
    var success = false;

    // iOS only: request background execution time so the download is not
    // suspended halfway when the app is backgrounded.
    final backgroundTask = await BackgroundTaskService.begin();
    try {
      if (sourceType == .webdav) {
        success =
            await webdavClient?.download(
              remotePath: song.path!,
              localPath: savePath,
              cancelToken: cancelToken,
            ) ??
            false;
      } else {
        success =
            await streamClient?.downloadSong(
              song.id,
              savePath,
              cancelToken: cancelToken,
            ) ??
            false;
      }
      final tmp = File(savePath);
      if (await tmp.exists()) {
        if (success) {
          cacheSizeNotifier.value += await tmp.length() / (1024 * 1024);
          await tmp.rename(song.cachePath!);
          song.cacheExist = true;
        }
      }
      return success;
    } finally {
      // A failed or canceled download leaves a fragment behind. Without resume
      // support it is useless, and the cache view must not have to explain it.
      final tmp = File(savePath);
      if (!success && await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      await BackgroundTaskService.end(backgroundTask);
    }
  }

  Future<void> clearCache() async {
    Directory cacheDir = Directory(getCachesPath(sourceType));
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }

    cacheSizeNotifier.value = 0;
    cacheEntriesNotifier.value = [];
    for (final song in library.id2Song.values) {
      song.cacheExist = false;
    }
  }

  Future<void> clearPicture() async {
    Directory pictureDir = Directory(getPicturesPath(sourceType));
    if (await pictureDir.exists()) {
      await pictureDir.delete(recursive: true);
    }
    pictureLoadScheduler.clear();
    mediaArt.clear();
    for (final picture in globalPictureList) {
      picture.reset();
    }

    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  Future<void> clearLrcCache() async {
    Directory cacheDir = Directory(getLrcPath(sourceType));
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
    for (final song in library.id2Song.values) {
      song.parsedLyrics = null;
    }
  }

  Future<void> _saveMetadata() async {
    final db = _metadataDB!;
    await db.transaction(() async {
      await db.delete(db.metadataItems).go();

      await db.batch((batch) {
        batch.insertAll(
          db.metadataItems,
          songList.map((e) => e.toCompanion()).toList(),
        );
      });
    });
  }

  Future<void> _saveBatchMetadata(List<MyAudioMetadata> songs) async {
    final db = _metadataDB!;
    await db.transaction(() async {
      await db.batch((batch) {
        batch.insertAll(
          db.metadataItems,
          songs.map((e) => e.toCompanion()).toList(),
        );
      });
    });
  }

  Future<void> _clearMetadata() async {
    final db = _metadataDB!;
    db.transaction(() async {
      await db.delete(db.metadataItems).go();
    });
  }

  Future<void> updatePlayCount(MyAudioMetadata song) async {
    final db = _metadataDB!;
    await (db.update(
      db.metadataItems,
    )..where((t) => t.id.equals(song.id))).write(
      MetadataItemsCompanion(
        playCount: Value(song.playCount),
        lastPlayed: Value(song.lastPlayed!.millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> updateLyricsTimeOffset(MyAudioMetadata song) async {
    final db = _metadataDB!;
    await (db.update(
      db.metadataItems,
    )..where((t) => t.id.equals(song.id))).write(
      MetadataItemsCompanion(lyricsTimeOffset: Value(song.lyricsTimeOffset)),
    );
  }

  Future<void> updateMetadata(MyAudioMetadata song) async {
    final db = _metadataDB!;
    await (db.update(
      db.metadataItems,
    )..where((t) => t.id.equals(song.id))).write(
      MetadataItemsCompanion(
        title: Value(song.title),
        artist: Value(song.artist),
        album: Value(song.album),
        genre: Value(song.genre),
        lyrics: Value(song.lyrics),
        year: Value(song.year),
        track: Value(song.track),
        disc: Value(song.disc),
      ),
    );
  }

  void shuffle() {
    songList.shuffle();
    update();
  }

  void update() {
    changeNotifier.value++;
    layersManager.updateBackground();
    if (isNotStreamSource) {
      _saveMetadata();
    }
  }

  void _syncNotify() {
    changeNotifier.value++;
    layersManager.updateBackground();
  }

  Future<MyAudioMetadata?> _parseMetadataIfNeed(
    String id,
    String path,
    DateTime modified, {
    DateTime? created,
  }) async {
    MyAudioMetadata? song = library.id2Song[id];

    if ((song?.modified?.difference(modified).inSeconds.abs() ?? 2) > 1) {
      String readPath = path;
      Map<String, String>? headers;
      bool isWebdav = path.startsWith('http://') || path.startsWith('https://');
      if (isWebdav) {
        final tmpPath = await covertToRedirectPathIfNeed(path);
        if (tmpPath == null) {
          headers = webdavClient?.headers;
        } else {
          readPath = tmpPath;
        }
      }
      AudioMetadata? tmp;
      try {
        tmp = await readMetadataAsync(readPath, false, headers: headers);
      } catch (e) {
        logger.output("$path: $e");
      }

      if (tmp != null) {
        song = MyAudioMetadata(
          tmp,
          id: id,
          path: path,
          modified: modified,
          created: created,
        );
      } else {
        song = null;
      }
    }
    if (song != null) {
      // Local libraries can leave very short clips out entirely.
      if (sourceType == .local &&
          skipShortAudioNotifier.value &&
          song.duration != null &&
          song.duration!.inSeconds > 0 &&
          song.duration!.inSeconds < minAudioSecondsNotifier.value) {
        library.id2Song.remove(id);
        return null;
      }
      // Fill in the local "added time" even when the metadata itself did not
      // change, so sorting by added time also works for a library that was
      // already scanned before this key existed.
      if (song.created == null) {
        song.created = created;
      }
      // A song read before the size column existed has none yet; stat the file
      // once so album and artist sizes are complete.
      if (song.size == null && sourceType == .local) {
        try {
          song.size = File(song.path!).lengthSync();
        } catch (_) {}
      }
      library.id2Song[id] = song;
    } else {
      library.id2Song.remove(id);
    }
    return song;
  }

  Future<void> sync() async {
    canModify = false;

    switch (sourceType) {
      case .local:
      case .webdav:
        Map<String, DateTime> pathAndModified = {};
        Map<String, DateTime> pathAndCreated = {};

        final updateCount = sourceType == .local ? 1000 : 25;

        for (final folder in folderList) {
          folder.songList.clear();
          folder.changeNotifier.value++;
          await folder.setFileAndModified();
          pathAndModified.addAll(folder.pathAndModified);
          pathAndCreated.addAll(folder.pathAndCreated);
        }

        // Reading tags is per file and both I/O and CPU bound; a fixed six
        // workers left most cores idle during a first local scan.
        final pool = Pool(Platform.numberOfProcessors.clamp(4, 12));

        final tasks = <Future>[];

        Set<String> validId = {};

        Future<void> syncOne(
          String id,
          String path,
          DateTime modified, {
          DateTime? created,
        }) async {
          final song = await _parseMetadataIfNeed(
            id,
            path,
            modified,
            created: created,
          );
          if (song != null) {
            validId.add(id);
            songList.add(song);
            if (validId.length % updateCount == 0) {
              _syncNotify();
            }
          }
        }

        final songIdList = songList.map((e) => e.id).toList();
        songList.clear();

        changeNotifier.value++;

        for (final id in songIdList) {
          String path = id;

          DateTime? modified;
          DateTime? created;
          if (sourceType == .local) {
            if (Platform.isIOS) {
              path = revertIOSPath(path);
            }
            modified = pathAndModified.remove(path);
            created = pathAndCreated.remove(path);
          } else {
            if (webdavClient != null) {
              modified = pathAndModified.remove(
                path.substring(webdavClient!.cleanBaseUrl.length),
              );
            }
          }

          if (modified != null) {
            tasks.add(
              pool.withResource(() async {
                await syncOne(id, path, modified!, created: created);
              }),
            );
          }
        }

        await Future.wait(tasks);

        for (final entry in pathAndModified.entries) {
          String path = entry.key;
          String id = path;
          if (sourceType == .webdav) {
            path = webdavClient!.cleanBaseUrl + path;
            id = path;
          } else if (Platform.isIOS) {
            id = convertIOSPath(path);
          }
          tasks.add(pool.withResource(() => syncOne(id, path, entry.value)));
        }

        await Future.wait(tasks);

        await pool.close();

        id2Song.removeWhere((id, song) => !validId.contains(id));

        for (final folder in folderList) {
          await folder.sync();
          folder.clearPathAndModified();
        }

        await _saveMetadata();
      default:
        Map<String, MyAudioMetadata> id2SongTmp = {};

        // feiniu does not contain playcount field, we keep it.
        if (sourceType == .feiniu) {
          id2SongTmp = Map.fromEntries(
            id2Song.entries.where((entry) => entry.value.playCount > 0),
          );
        }

        id2Song.clear();
        songList.clear();

        await _clearMetadata();

        int songCount = await streamClient?.getSongCount() ?? 0;

        int nextIndex = 0;
        final results = <int, List<MyAudioMetadata>>{};

        final pool = Pool(6);
        final tasks = <Future>[];
        final batchSize = 1000;
        for (int i = 0; i * batchSize < songCount; i++) {
          tasks.add(
            pool.withResource(() async {
              final songs =
                  await streamClient?.getSongs(batchSize, i * batchSize) ?? [];

              results[i] = songs;

              while (results.containsKey(nextIndex)) {
                final songs = results.remove(nextIndex)!;

                if (sourceType == .feiniu) {
                  for (final song in songs) {
                    song.playCount = id2SongTmp[song.id]?.playCount ?? 0;
                    song.lastPlayed = id2SongTmp[song.id]?.lastPlayed;
                  }
                }
                songList.addAll(songs);

                for (final song in songs) {
                  serverCreatedTimes.record(song.id, song.created);
                }
                unawaited(serverCreatedTimes.flush());

                await _saveBatchMetadata(songs);

                if (songList.length == batchSize ||
                    songList.length % 10000 == 0) {
                  _syncNotify();
                }

                nextIndex++;
              }
            }),
          );
        }
        await Future.wait(tasks);
        await pool.close();
    }

    canModify = true;
    _syncNotify();

    // What was just written is what the cache view reports.
    await _accumulateCache();
  }
}
