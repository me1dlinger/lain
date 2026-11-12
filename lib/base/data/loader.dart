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
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/offline_setting.dart';
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
      await Permission.storage.request();
      await Permission.audio.request();
    } else if (Platform.isIOS) {
      await BookmarkService.init();
      File keepFile = File('${appDocsDir.path}/lain.keep');
      if (!keepFile.existsSync()) {
        keepFile.createSync();
      }
    }

    _handleLegacyVersionData();

    await config.load();
    await setting.load();

    // Offline mode is persisted, so a launch that would otherwise come up on
    // the last server always starts on the local library instead.
    if (offlineModeNotifier.value && sourceType != .local) {
      await config.activateLocal();
    }

    colorManager.updateColors();

    await fontManager.loadFonts();
  }

  static Future<void> load() async {
    _busy = true;
    stateNotifier.value++;

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
    await loadArtistInfoCache();
    // Artist pictures (and default detection) depend on this, so it finishes
    // before the artist list is built.
    await prefetchArtistInfo();

    artistAlbumManager.classify();

    await history.load();

    await playlistManager.load();

    _busy = false;
    stateNotifier.value++;
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

    File tmp = File('${appSupportDir.path}/version.json');
    if (tmp.existsSync()) {
      firstLaunch = false;
      if (compareVersion('4.0.1', jsonDecode(tmp.readAsStringSync())) > 0) {
        File playlistsFile = File(
          "${getPlaylistConfigPath(.local)}/lain_playlists.json",
        );
        if (playlistsFile.existsSync()) {
          final content = playlistsFile.readAsStringSync();
          final list = jsonDecode(content) as List;
          if (list.isNotEmpty && list[0] == 'Favorite') {
            playlistsFile.writeAsStringSync(jsonEncode(list.skip(1).toList()));
          }
        }

        playlistsFile = File(
          "${getPlaylistConfigPath(.webdav)}/lain_playlists.json",
        );
        if (playlistsFile.existsSync()) {
          final content = playlistsFile.readAsStringSync();
          final list = jsonDecode(content) as List;
          if (list.isNotEmpty && list[0] == 'Favorite') {
            playlistsFile.writeAsStringSync(jsonEncode(list.skip(1).toList()));
          }
        }
      }

      if (compareVersion('4.2.0', jsonDecode(tmp.readAsStringSync())) > 0) {
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
    tmp.writeAsStringSync(jsonEncode(versionNumber));
  }
}
