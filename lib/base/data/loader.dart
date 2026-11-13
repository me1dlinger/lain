import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/data/artist_album.dart';
import 'package:lain/base/data/font_manager.dart';
import 'package:lain/base/services/bookmark_service.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/history.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/comment_client.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/offline_setting.dart';
import 'package:lain/base/data/comment_setting.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/data/setting.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/picture_load_scheduler.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:lain/base/utils/path.dart';
import 'package:lain/layer/layers_manager.dart';

bool firstLaunch = true;

class Loader {
  static bool _busy = false;

  static bool get busy => _busy;

  static final stateNotifier = ValueNotifier(0);

  static Future<void> init() async {
    if (Platform.isAndroid) {
      // Best-effort and time limited: a permission dialog that is dismissed by
      // the system (or an activity that is rebuilt while it is open) must not
      // keep the app on the launch window forever.
      await _requestPermission(Permission.storage);
      await _requestPermission(Permission.audio);
    } else if (Platform.isIOS) {
      try {
        await BookmarkService.init();
        File keepFile = File('${appDocsDir.path}/lain.keep');
        if (!keepFile.existsSync()) {
          keepFile.createSync();
        }
      } catch (e) {
        logger.output('[startup] bookmark init failed: $e');
      }
    }

    // Each step is independent: a corrupt or unreadable one leaves the rest of
    // the startup defaults in place instead of aborting before runApp.
    try {
      _handleLegacyVersionData();
    } catch (e) {
      logger.output('[startup] legacy migration failed: $e');
    }

    try {
      await config.load();
    } catch (e) {
      logger.output('[startup] config load failed: $e');
    }
    try {
      await setting.load();
    } catch (e) {
      logger.output('[startup] settings load failed: $e');
    }

    // A comment server that answered is written through to the settings, so
    // the next launch asks it first instead of probing both addresses. The
    // client holds the hook; the settings layer holds the write.
    CommentClient.rememberAddress = markCommentServerAlive;

    // Offline mode is persisted, so a launch that would otherwise come up on
    // the last server always starts on the local library instead.
    if (offlineModeNotifier.value && sourceType != .local) {
      try {
        await config.activateLocal();
      } catch (e) {
        logger.output('[startup] activate local failed: $e');
      }
    }

    colorManager.updateColors();

    try {
      await fontManager.loadFonts();
    } catch (e) {
      logger.output('[startup] font load failed: $e');
    }
  }

  static Future<void> _requestPermission(Permission permission) async {
    try {
      await permission.request().timeout(const Duration(seconds: 20));
    } catch (e) {
      logger.output('[startup] permission request failed: $e');
    }
  }

  static Future<void> load() async {
    _busy = true;
    stateNotifier.value++;

    // try/finally: an early return (a first sync, an interrupted scan) and a
    // throw both used to leave `_busy` true for the life of the process, which
    // silently disabled every action guarded by it.
    try {
      if (isStreamSource && streamClient != null) {
        if (!File(getSyncedFilePath(sourceType)).existsSync()) {
          await firstSync();
          return;
        }
      }

      await library.load();

      if (isNotStreamSource &&
          library.songList.isEmpty &&
          library.folderList.isNotEmpty) {
        // Nothing is indexed, yet folders are configured: the previous scan was
        // interrupted (the app was closed while it ran), so build the library now
        // instead of leaving an empty page behind.
        await firstSync();
        return;
      }

      audioHandler.loadStates();

      // Read before the lists are built, so a local library can show what
      // Navidrome cached for the same artists. Navidrome's own artist list then
      // fills the cache (biographies, and whether each artist has an image) in
      // one go, so the artist lists are decided from the first frame.
      try {
        await loadArtistInfoCache();
      } catch (e) {
        logger.output('[startup] artist cache load failed: $e');
      }

      artistAlbumManager.classify();

      try {
        await history.load();
      } catch (e) {
        logger.output('[startup] history load failed: $e');
      }

      try {
        await playlistManager.load();
      } catch (e) {
        logger.output('[startup] playlist load failed: $e');
      }

      // The artist biography/image prefetch hits the network; run it after the
      // cached data has been put on screen, so a cold start with an online
      // source shows its lists first instead of an empty page. The call reads
      // the same disk cache again (idempotent) and bumps the artist list's
      // notifier when the fresh summaries arrive.
      unawaited(prefetchArtistInfo());

      // The cached lists are what is on screen; the server may have newer data
      // (songs added there, plays scrobbled elsewhere, playlists edited).
      // Refresh the dynamic lists in the background - never blocking the first
      // paint - so the home page is up to date without a manual sync. Covers
      // are the sync's job and stay untouched.
      unawaited(refreshServerLists());
    } catch (e) {
      logger.output('[startup] load failed: $e');
    } finally {
      _busy = false;
      stateNotifier.value++;
    }
  }

  /// Fetches the lists the home page shows straight from the server and
  /// updates what is on screen: the newest songs (merged into the library),
  /// the most played, and the playlists' contents. Every step is best-effort: a source that cannot answer one of them keeps the
  /// list it already shows.
  static Future<void> refreshServerLists() async {
    final client = streamClient;
    if (client == null || !isStreamSource) {
      return;
    }

    final newest = await client.getNewestSongs(100);
    if (newest != null && newest.isNotEmpty) {
      try {
        await library.mergeFreshSongs(newest);
      } catch (e) {
        logger.output('[refresh] newest songs: $e');
      }
    }

    final mostPlayed = await client.getMostPlayedSongs(100);
    if (mostPlayed != null) {
      history.applyFrequently(mostPlayed);
    }

    // Playlists: the list of them and each one's songs, fresh from the
    // server. The covers stay as cached - they are only re-downloaded by a
    // full sync.
    try {
      await playlistManager.sync();
    } catch (e) {
      logger.output('[refresh] playlists: $e');
    }
  }

  static Future<void> reload() async {
    if (viewModeNotifier.value == .normal) {
      layersManager.clearDataLayers();
    }
    pictureLoadScheduler.clear();
    audioHandler.justClear();

    globalPictureList = [];

    library = Library();
    artistAlbumManager.clear();
    history.clear();
    playlistManager.reset();

    await load();
  }

  /// Switches to the local library and scans it. Used when enabling offline
  /// mode and when scanning from the local-music settings page.
  static Future<void> switchToLocal() async {
    if (sourceType == .local) {
      return;
    }
    await config.activateLocal();
    layersManager.clearDataLayers();
    audioHandler.clear();
    library = Library();
    await library.initFolders();
    await sync();
  }

  /// Syncs the current library. Returns false when it failed; the caller can
  /// report the result. `_busy` is cleared even then, so a failed sync does not
  /// leave the app unable to try again.
  static Future<bool> sync() async {
    _busy = true;
    stateNotifier.value++;

    try {
      if (viewModeNotifier.value == .normal) {
        layersManager.clearDataLayers();
      }

      globalPictureList = [];

      artistAlbumManager.clear();

      history.clear();

      playlistManager.reset();

      await library.sync();

      audioHandler.sync();

      // Read before the lists are built, so a local library can show what
      // Navidrome cached for the same artists. Navidrome's own artist list then
      // fills the cache (biographies, and whether each artist has an image) in
      // one go, so the artist lists are decided from the first frame.
      await loadArtistInfoCache();
      // Artist pictures (and default detection) depend on this, so it finishes
      // before the artist list is built.
      await prefetchArtistInfo();

      artistAlbumManager.classify();

      await history.load();

      await playlistManager.sync();

      if (isStreamSource) {
        File syncedFile = File(getSyncedFilePath(sourceType));

        if (streamClient != null && !syncedFile.existsSync()) {
          syncedFile.createSync(recursive: true);
        }

        if (streamClient == null && syncedFile.existsSync()) {
          syncedFile.deleteSync(recursive: true);
        }
      }

      return true;
    } catch (e) {
      logger.output('[sync] $e');
      return false;
    } finally {
      _busy = false;
      stateNotifier.value++;
    }
  }

  static Future<void> firstSync() async {
    _busy = true;
    stateNotifier.value++;

    logger.output('${sourceType.name} first sync');

    layersManager.switchRootLayer('songs');

    playlistManager.reset();

    await library.sync();

    audioHandler.loadStates();

    // Read before the lists are built, so a local library can show what
    // Navidrome cached for the same artists. Navidrome's own artist list then
    // fills the cache (biographies, and whether each artist has an image) in
    // one go, so the artist lists are decided from the first frame.
    await loadArtistInfoCache();
    // Artist pictures (and default detection) depend on this, so it finishes
    // before the artist list is built.
    await prefetchArtistInfo();

    artistAlbumManager.classify();

    await history.load();

    await playlistManager.sync();

    if (isStreamSource) {
      File syncedFile = File(getSyncedFilePath(sourceType));

      if (streamClient != null && !syncedFile.existsSync()) {
        syncedFile.createSync(recursive: true);
      }

      if (streamClient == null && syncedFile.existsSync()) {
        syncedFile.deleteSync(recursive: true);
      }
    }

    _busy = false;
    stateNotifier.value++;
  }

  static void _handleLegacyVersionData() {
    // The album/artist ids are saved with the library from now on. A library
    // written before that has none, so its sync marker is dropped once and the
    // library is fetched from the server again (the old rows were deleted by
    // the database migration).
    final metaFlag = File('${appSupportDir.path}/meta_v8.keep');
    if (!metaFlag.existsSync()) {
      for (final type in SourceType.values) {
        final synced = File(getSyncedFilePath(type));
        if (synced.existsSync()) {
          synced.deleteSync();
        }
      }
      metaFlag.createSync(recursive: true);
    }

    // Covers are now requested at a sensible size; the ones cached from before
    // (a playlist cover used to be a multi-megabyte original) would still be
    // decoded on every visit, so they are dropped once.
    final coversFlag = File('${appSupportDir.path}/covers_v600.keep');
    if (!coversFlag.existsSync()) {
      for (final type in SourceType.values) {
        final dir = Directory(getPicturesPath(type));
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      }
      final artistDir = Directory('${appSupportDir.path}/artist_images');
      if (artistDir.existsSync()) {
        artistDir.deleteSync(recursive: true);
      }
      coversFlag.createSync(recursive: true);
    }

    final versionFile = File('${appSupportDir.path}/version.json');
    String? storedVersion;
    if (versionFile.existsSync()) {
      firstLaunch = false;
      try {
        final raw = jsonDecode(versionFile.readAsStringSync());
        if (raw is String && raw.isNotEmpty) {
          storedVersion = raw;
        }
      } catch (_) {}
    }

    // The app version was deliberately reset to 1.0.0-beta1. The pre-4.x
    // migrations must not run again on that "downgrade"; one of them removes
    // the server data directories. They already ran on 4.x installations.
    final legacyFlag = File('${appSupportDir.path}/legacy_pre_4.3.keep');
    if (!legacyFlag.existsSync()) {
      final isReset =
          storedVersion != null &&
          (storedVersion == versionNumber || storedVersion.contains('-'));
      if (!isReset && storedVersion != null) {
        if (compareVersion('4.0.1', storedVersion) > 0) {
          File playlistsFile = File(
            "${getPlaylistConfigPath(.local)}/lain_playlists.json",
          );
          if (playlistsFile.existsSync()) {
            final content = playlistsFile.readAsStringSync();
            final list = jsonDecode(content) as List;
            if (list.isNotEmpty && list[0] == 'Favorite') {
              playlistsFile.writeAsStringSync(
                jsonEncode(list.skip(1).toList()),
              );
            }
          }

          playlistsFile = File(
            "${getPlaylistConfigPath(.webdav)}/lain_playlists.json",
          );
          if (playlistsFile.existsSync()) {
            final content = playlistsFile.readAsStringSync();
            final list = jsonDecode(content) as List;
            if (list.isNotEmpty && list[0] == 'Favorite') {
              playlistsFile.writeAsStringSync(
                jsonEncode(list.skip(1).toList()),
              );
            }
          }
        }

        if (compareVersion('4.2.0', storedVersion) > 0) {
          Directory tmpDir = Directory('${appSupportDir.path}/subsonic');
          if (tmpDir.existsSync()) {
            tmpDir.deleteSync(recursive: true);
          }

          tmpDir = Directory('${appSupportDir.path}/navidrome');
          if (tmpDir.existsSync()) {
            tmpDir.deleteSync(recursive: true);
          }

          tmpDir = Directory('${appSupportDir.path}/emby');
          if (tmpDir.existsSync()) {
            tmpDir.deleteSync(recursive: true);
          }
        }
      }
      legacyFlag.createSync(recursive: true);
    }
    versionFile.writeAsStringSync(jsonEncode(versionNumber));
  }
}
