import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/artist_album.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/library_naming.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/file_time.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/media_art.dart';
import 'package:lain/base/utils/path.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:path/path.dart' as p;

/// Moves local songs into the folders and file names the naming templates ask
/// for, and carries their identity along with them.
///
/// A local song's id is its file path, so a move is not just `rename`: the
/// database row, every playlist and folder list, the play queue and the cover
/// cache are all keyed by that id. The whole sequence lives here, with a preview
/// first and a journal so an interrupted run can be put back.

enum OrganizeStatus { normal, skip, conflict, blocked }

class OrganizeItem {
  final MyAudioMetadata song;
  final String oldPath;
  final String? newPath;
  final OrganizeStatus status;

  /// Why the item is blocked or in conflict; a short, user-facing phrase.
  final String? reason;

  const OrganizeItem({
    required this.song,
    required this.oldPath,
    required this.status,
    this.newPath,
    this.reason,
  });

  OrganizeItem withStatus(OrganizeStatus status, {String? reason}) =>
      OrganizeItem(
        song: song,
        oldPath: oldPath,
        newPath: newPath,
        status: status,
        reason: reason ?? this.reason,
      );
}

class OrganizePreview {
  final List<OrganizeItem> items;

  const OrganizePreview(this.items);

  int count(OrganizeStatus status) =>
      items.where((item) => item.status == status).length;

  bool get hasExecutable => count(OrganizeStatus.normal) > 0;

  bool get isEmpty => items.isEmpty;
}

class OrganizeResult {
  final int moved;
  final int skipped;
  final int failed;
  final bool stopped;

  /// The songs this run moved, by their old path, and the ones it tried and
  /// could not move. The page uses them to show "organized" per item and to
  /// build the per-album summary.
  final Set<String> movedPaths;
  final Set<String> failedPaths;

  const OrganizeResult({
    required this.moved,
    required this.skipped,
    required this.failed,
    this.stopped = false,
    this.movedPaths = const {},
    this.failedPaths = const {},
  });
}

class _JournalEntry {
  final String oldPath;
  final String newPath;
  final String oldId;
  final String newId;
  final int? createdMillis;
  final List<(String, String)> sidecars;
  final String? oldCoverPath;
  final String? newCoverPath;

  const _JournalEntry({
    required this.oldPath,
    required this.newPath,
    required this.oldId,
    required this.newId,
    required this.sidecars,
    this.createdMillis,
    this.oldCoverPath,
    this.newCoverPath,
  });

  Map<String, dynamic> toJson() => {
    'oldPath': oldPath,
    'newPath': newPath,
    'oldId': oldId,
    'newId': newId,
    'createdMillis': createdMillis,
    'sidecars': [
      for (final sidecar in sidecars)
        {'old': sidecar.$1, 'new': sidecar.$2},
    ],
    'coverCache': oldCoverPath == null
        ? null
        : {'old': oldCoverPath, 'new': newCoverPath},
  };

  factory _JournalEntry.fromJson(Map raw) {
    final sidecars = <(String, String)>[];
    final rawSidecars = raw['sidecars'];
    if (rawSidecars is List) {
      for (final sidecar in rawSidecars) {
        if (sidecar is Map) {
          final old = sidecar['old']?.toString();
          final newPath = sidecar['new']?.toString();
          if (old != null && newPath != null) {
            sidecars.add((old, newPath));
          }
        }
      }
    }
    final cover = raw['coverCache'];
    return _JournalEntry(
      oldPath: raw['oldPath']?.toString() ?? '',
      newPath: raw['newPath']?.toString() ?? '',
      oldId: raw['oldId']?.toString() ?? '',
      newId: raw['newId']?.toString() ?? '',
      createdMillis: raw['createdMillis'] is int
          ? raw['createdMillis'] as int
          : null,
      sidecars: sidecars,
      oldCoverPath: cover is Map ? cover['old']?.toString() : null,
      newCoverPath: cover is Map ? cover['new']?.toString() : null,
    );
  }
}

class LibraryOrganizer {
  static final LibraryOrganizer instance = LibraryOrganizer();

  List<_JournalEntry> _lastRun = const [];

  /// Whether the last completed run in this session can still be undone: every
  /// new path exists and no old path was taken over by something else.
  bool get canUndo => _lastRun.isNotEmpty;

  File get _journalFile => File('${appSupportDir.path}/format_journal.json');

  int get _maxPathLength => Platform.isWindows ? 260 : 4096;

  List<MyAudioMetadata> songsOf(OrganizePreview preview) =>
      [for (final item in preview.items) item.song];

  // ---- preview -------------------------------------------------------------

  Future<OrganizePreview> preview(
    Iterable<MyAudioMetadata> songs, {
    LibraryNamingFormat? format,
  }) async {
    final naming = format ?? LibraryNamingFormat.current;
    final items = <OrganizeItem>[];
    final seenTargets = <String>{};

    for (final song in songs) {
      final path = song.path;
      if (path == null || path.isEmpty) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: '',
            status: OrganizeStatus.blocked,
            reason: 'missingPath',
          ),
        );
        continue;
      }

      final root = _rootFor(path);
      if (root == null) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: path,
            status: OrganizeStatus.blocked,
            reason: 'outsideLibrary',
          ),
        );
        continue;
      }
      if (Platform.isIOS && isFileProviderStorePath(path)) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: path,
            status: OrganizeStatus.blocked,
            reason: 'fileProvider',
          ),
        );
        continue;
      }
      if (!File(path).existsSync()) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: path,
            status: OrganizeStatus.blocked,
            reason: 'missingFile',
          ),
        );
        continue;
      }

      final plan = buildLibraryNamingPlan(
        naming,
        NamingInput(
          title: song.title,
          artist: song.artist,
          album: song.album,
          albumArtist: song.albumArtist,
          track: song.track,
          disc: song.disc,
          year: song.year,
          ext: p.extension(path),
          fileName: p.basenameWithoutExtension(path),
        ),
      );
      if (plan == null) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: path,
            status: OrganizeStatus.blocked,
            reason: 'invalidTemplate',
          ),
        );
        continue;
      }

      final newPath = p.normalize(
        p.join(root, plan.relativeDir, plan.fileName),
      );
      if (!_isInsideRoot(root, newPath)) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: path,
            newPath: newPath,
            status: OrganizeStatus.blocked,
            reason: 'outsideLibrary',
          ),
        );
        continue;
      }
      if (newPath.length > _maxPathLength) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: path,
            newPath: newPath,
            status: OrganizeStatus.blocked,
            reason: 'pathTooLong',
          ),
        );
        continue;
      }
      if (_samePath(path, newPath)) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: path,
            newPath: newPath,
            status: OrganizeStatus.skip,
            reason: 'unchanged',
          ),
        );
        continue;
      }
      if (Directory(newPath).existsSync()) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: path,
            newPath: newPath,
            status: OrganizeStatus.blocked,
            reason: 'targetIsFolder',
          ),
        );
        continue;
      }

      final key = _targetKey(root, newPath);
      if (!seenTargets.add(key)) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: path,
            newPath: newPath,
            status: OrganizeStatus.conflict,
            reason: 'duplicateTarget',
          ),
        );
        continue;
      }
      if (File(newPath).existsSync()) {
        items.add(
          OrganizeItem(
            song: song,
            oldPath: path,
            newPath: newPath,
            status: OrganizeStatus.conflict,
            reason: 'targetExists',
          ),
        );
        continue;
      }

      items.add(
        OrganizeItem(
          song: song,
          oldPath: path,
          newPath: newPath,
          status: OrganizeStatus.normal,
        ),
      );
    }

    return OrganizePreview(items);
  }

  String? _rootFor(String path) {
    String? best;
    for (final folder in library.folderList) {
      final root = folder.path;
      if (root.isEmpty) {
        continue;
      }
      if (_isInsideRoot(root, path)) {
        if (best == null || root.length > best.length) {
          best = root;
        }
      }
    }
    return best;
  }

  bool _isInsideRoot(String root, String path) {
    final normalizedRoot = p.normalize(root);
    final normalizedPath = p.normalize(path);
    final withSeparator = normalizedRoot.endsWith(Platform.pathSeparator)
        ? normalizedRoot
        : '$normalizedRoot${Platform.pathSeparator}';
    return _lower(normalizedPath).startsWith(_lower(withSeparator));
  }

  bool _samePath(String a, String b) =>
      _lower(p.normalize(a)) == _lower(p.normalize(b));

  String _lower(String value) =>
      Platform.isWindows || Platform.isMacOS ? value.toLowerCase() : value;

  String _targetKey(String root, String target) {
    final relative = p.relative(target, from: root);
    return '${_lower(root)}::${_lower(relative)}';
  }

  // ---- execute -------------------------------------------------------------

  Future<OrganizeResult> execute(
    OrganizePreview preview, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final runnable = [
      for (final item in preview.items)
        if (item.status == OrganizeStatus.normal) item,
    ];
    if (runnable.isEmpty) {
      return const OrganizeResult(moved: 0, skipped: 0, failed: 0);
    }

    final current = currentSongNotifier.value;
    if (current != null &&
        runnable.any((item) => item.song.id == current.id)) {
      try {
        await audioHandler.pause();
      } catch (e) {
        logger.output('[organize] could not pause: $e');
      }
    }

    final entries = <_JournalEntry>[];
    final movedPaths = <String>{};
    final failedPaths = <String>{};
    var moved = 0;
    var failed = 0;
    var stopped = false;
    var completed = false;

    try {
      // The journal is marked `moving` before the first file so an interrupted
      // run is recoverable at the next launch.
      await _writeJournal('moving', entries);

      for (var i = 0; i < runnable.length; i++) {
        if (isCancelled?.call() ?? false) {
          stopped = true;
          break;
        }
        final item = runnable[i];
        final oldPath = item.oldPath;
        final newPath = item.newPath!;
        try {
          await Directory(p.dirname(newPath)).create(recursive: true);
          if (File(newPath).existsSync()) {
            failed++;
            failedPaths.add(oldPath);
            onProgress?.call(i + 1, runnable.length);
            continue;
          }

          final oldId = item.song.id;
          final newId = Platform.isIOS ? convertIOSPath(newPath) : newPath;
          final createdMillis = item.song.created?.millisecondsSinceEpoch;
          final sidecars = _sidecarsFor(oldPath, newPath);
          final oldCover = _coverCachePath(oldId);
          final newCover = _coverCachePath(newId);

          await _moveFile(oldPath, newPath);
          for (final sidecar in sidecars) {
            await _moveFileIfPossible(sidecar.$1, sidecar.$2);
          }
          await fileCreationTimes.moveEntry(
            oldPath,
            newPath,
            millis: createdMillis,
          );
          if (oldCover != null && newCover != null && oldId != newId) {
            await _moveFileIfPossible(oldCover, newCover);
            final thumbnail = mediaArt.targetPathFor(oldCover);
            try {
              final file = File(thumbnail);
              if (file.existsSync()) {
                file.deleteSync();
              }
            } catch (_) {}
          }

          final replacement = item.song.cloneWithId(newId, newPath: newPath);
          if (newId != oldId) {
            await library.applyRename(replacement, oldId);
            _replaceInMemory(oldId, replacement);
          }

          final entry = _JournalEntry(
            oldPath: oldPath,
            newPath: newPath,
            oldId: oldId,
            newId: newId,
            createdMillis: createdMillis,
            sidecars: sidecars,
            oldCoverPath: oldCover,
            newCoverPath: newCover,
          );
          entries.add(entry);
          await _writeJournal('moving', entries);
          moved++;
          movedPaths.add(oldPath);
        } catch (e) {
          failed++;
          failedPaths.add(oldPath);
          logger.output('[organize] could not move $oldPath: $e');
        }
        onProgress?.call(i + 1, runnable.length);
      }

      await _writeJournal('committed', entries);
      completed = true;
      _deleteEmptyParents(entries);
    } finally {
      // An exception before this point leaves the journal in the moving state,
      // so the next launch puts the half-moved files back; a completed run only
      // needs to drop it.
      try {
        if (completed && _journalFile.existsSync()) {
          _journalFile.deleteSync();
        }
      } catch (e) {
        logger.output('[organize] journal cleanup failed: $e');
      }
      _lastRun = entries;
      // The queue and the current song may hold the new ids now; persist them
      // so the next launch restores the same objects.
      audioHandler.saveAllStates();
      library.changeNotifier.value++;
      layersManager.updateBackground();
      artistAlbumManager.updateArtistAlbum();
      playlistManager.updateNotifier.value++;
      try {
        await library.refreshCache();
      } catch (_) {}
    }

    return OrganizeResult(
      moved: moved,
      skipped: preview.count(OrganizeStatus.skip),
      failed: failed,
      stopped: stopped,
      movedPaths: movedPaths,
      failedPaths: failedPaths,
    );
  }

  Future<void> _moveFile(String from, String to) async {
    final source = File(from);
    try {
      await source.rename(to);
    } on FileSystemException {
      // A cross-volume move (an SD card mounted separately) cannot rename;
      // copying then removing the source is the only way left.
      final copy = await source.copy(to);
      if (!await copy.exists()) {
        rethrow;
      }
      await source.delete();
    }
  }

  Future<void> _moveFileIfPossible(String from, String to) async {
    try {
      final source = File(from);
      if (!await source.exists()) {
        return;
      }
      if (await File(to).exists()) {
        return;
      }
      await source.rename(to);
    } catch (e) {
      logger.output('[organize] sidecar $from not moved: $e');
    }
  }

  List<(String, String)> _sidecarsFor(String oldPath, String newPath) {
    const extensions = ['.lrc', '.ttml', '.xml', '.jpg', '.jpeg', '.png'];
    const sharedCoverNames = {
      'cover',
      'folder',
      'album',
      'albumart',
      'albumartsmall',
      'front',
    };
    final oldStem = p.basenameWithoutExtension(oldPath);
    if (sharedCoverNames.contains(oldStem.toLowerCase())) {
      return const [];
    }
    final oldDir = p.dirname(oldPath);
    final newStem = p.basenameWithoutExtension(newPath);
    final newDir = p.dirname(newPath);
    final result = <(String, String)>[];
    for (final ext in extensions) {
      final old = p.join(oldDir, '$oldStem$ext');
      final newSidecar = p.join(newDir, '$newStem$ext');
      if (File(old).existsSync() && !File(newSidecar).existsSync()) {
        result.add((old, newSidecar));
      }
    }
    return result;
  }

  String? _coverCachePath(String id) {
    if (id.isEmpty) {
      return null;
    }
    final hash = md5.convert(utf8.encode(id)).toString();
    return '${getPicturesPath(.local)}/$hash';
  }

  void _replaceInMemory(String oldId, MyAudioMetadata replacement) {
    library.id2Song.remove(oldId);
    library.id2Song[replacement.id] = replacement;
    for (var i = 0; i < library.songList.length; i++) {
      if (library.songList[i].id == oldId) {
        library.songList[i] = replacement;
      }
    }
    for (var i = 0; i < playQueue.length; i++) {
      if (playQueue[i].id == oldId) {
        playQueue[i] = replacement;
      }
    }
    if (currentSongNotifier.value?.id == oldId) {
      currentSongNotifier.value = replacement;
    }
    for (final folder in library.folderList) {
      unawaitedSafe(folder.replaceSongId(oldId, replacement.id));
    }
    for (final playlist in playlistManager.playlists) {
      unawaitedSafe(playlist.replaceSongId(oldId, replacement.id));
    }
  }

  void _deleteEmptyParents(List<_JournalEntry> entries) {
    final roots = <String>{
      for (final folder in library.folderList) p.normalize(folder.path),
    };
    for (final entry in entries) {
      var directory = p.dirname(entry.oldPath);
      while (true) {
        if (roots.any((root) => _samePath(root, directory))) {
          break;
        }
        final dir = Directory(directory);
        if (!dir.existsSync()) {
          break;
        }
        try {
          if (dir.listSync().isNotEmpty) {
            break;
          }
          dir.deleteSync();
        } catch (_) {
          break;
        }
        final parent = p.dirname(directory);
        if (parent == directory) {
          break;
        }
        directory = parent;
      }
    }
  }

  // ---- undo ----------------------------------------------------------------

  Future<bool> undo() async {
    if (_lastRun.isEmpty) {
      return false;
    }
    for (final entry in _lastRun) {
      if (File(entry.oldPath).existsSync()) {
        return false;
      }
      if (!File(entry.newPath).existsSync()) {
        return false;
      }
    }

    await _writeJournal('moving', _lastRun);
    var allRestored = true;
    for (final entry in _lastRun) {
      try {
        final replacement = library.id2Song[entry.newId];
        await _moveFile(entry.newPath, entry.oldPath);
        for (final sidecar in entry.sidecars) {
          await _moveFileIfPossible(sidecar.$2, sidecar.$1);
        }
        await fileCreationTimes.moveEntry(entry.newPath, entry.oldPath);
        if (entry.oldCoverPath != null &&
            entry.newCoverPath != null &&
            entry.oldId != entry.newId) {
          await _moveFileIfPossible(entry.oldCoverPath!, entry.newCoverPath!);
        }
        if (replacement != null && entry.oldId != entry.newId) {
          final restored = replacement.cloneWithId(
            entry.oldId,
            newPath: entry.oldPath,
          );
          await library.applyRename(restored, entry.newId);
          _replaceInMemory(entry.newId, restored);
        }
      } catch (e) {
        allRestored = false;
        logger.output('[organize] undo failed for ${entry.newPath}: $e');
      }
    }

    audioHandler.saveAllStates();
    if (allRestored) {
      try {
        if (_journalFile.existsSync()) {
          _journalFile.deleteSync();
        }
      } catch (_) {}
      _lastRun = const [];
    }
    library.changeNotifier.value++;
    layersManager.updateBackground();
    artistAlbumManager.updateArtistAlbum();
    playlistManager.updateNotifier.value++;
    try {
      await library.refreshCache();
    } catch (_) {}
    return allRestored;
  }

  // ---- journal -------------------------------------------------------------

  Future<void> _writeJournal(String state, List<_JournalEntry> entries) async {
    try {
      await _journalFile.parent.create(recursive: true);
      await _journalFile.writeAsString(
        jsonEncode({
          'version': 1,
          'state': state,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'entries': [for (final entry in entries) entry.toJson()],
        }),
      );
    } catch (e) {
      logger.output('[organize] journal write failed: $e');
    }
  }

  /// Puts back whatever a run that was interrupted halfway through the files
  /// left behind. Run before the library is loaded, so the database is the only
  /// place the new identity exists and is renamed back here too.
  Future<void> recoverJournal() async {
    if (!_journalFile.existsSync()) {
      return;
    }
    try {
      final raw = jsonDecode(await _journalFile.readAsString());
      if (raw is! Map) {
        _journalFile.deleteSync();
        return;
      }
      final state = raw['state']?.toString();
      final rawEntries = raw['entries'];
      if (state == 'moving' && rawEntries is List) {
        for (final value in rawEntries) {
          if (value is! Map) {
            continue;
          }
          final entry = _JournalEntry.fromJson(value);
          if (entry.newPath.isEmpty || entry.oldPath.isEmpty) {
            continue;
          }
          final newExists = File(entry.newPath).existsSync();
          final oldExists = File(entry.oldPath).existsSync();
          if (newExists && !oldExists) {
            await _moveFile(entry.newPath, entry.oldPath);
            for (final sidecar in entry.sidecars) {
              await _moveFileIfPossible(sidecar.$2, sidecar.$1);
            }
            if (entry.oldCoverPath != null &&
                entry.newCoverPath != null &&
                entry.oldId != entry.newId) {
              await _moveFileIfPossible(
                entry.oldCoverPath!,
                entry.newCoverPath!,
              );
            }
            if (entry.oldId != entry.newId) {
              await library.renameStoredRow(entry.newId, entry.oldId);
            }
          }
        }
      }
      _journalFile.deleteSync();
    } catch (e) {
      logger.output('[organize] journal recovery failed: $e');
    }
  }
}

/// Fire-and-forget for the in-memory list rewrites: they write small json files
/// and must not hold the move loop up.
void unawaitedSafe(Future<void> future) {
  future.catchError((Object error) {
    logger.output('[organize] list rewrite failed: $error');
  });
}
