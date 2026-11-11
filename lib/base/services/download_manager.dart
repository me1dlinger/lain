import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:lain/base/utils/path.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/utils/source_type.dart';

/// Folder every download is kept in, under the public Downloads directory so the
/// files are where the user (and any other player) expects them.
const downloadFolderName = 'Lain';

/// One song the user downloaded from a server. Kept on disk, so the list
/// survives a restart and says where each file came from.
class DownloadedSong {
  final String songId;
  final String title;
  final String artist;
  final String album;

  /// The source's [SourceType.name] - which server the file came from.
  final String source;

  final String path;
  final int bytes;
  final DateTime time;

  const DownloadedSong({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    required this.source,
    required this.path,
    required this.bytes,
    required this.time,
  });

  SourceType? get sourceType => SourceType.values.asNameMap()[source];

  String get fileName {
    final index = path.lastIndexOf(Platform.pathSeparator);
    return index == -1 ? path : path.substring(index + 1);
  }

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'title': title,
    'artist': artist,
    'album': album,
    'source': source,
    'path': path,
    'bytes': bytes,
    'time': time.millisecondsSinceEpoch,
  };

  static DownloadedSong? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    return DownloadedSong(
      songId: '${raw['songId'] ?? ''}',
      title: '${raw['title'] ?? ''}',
      artist: '${raw['artist'] ?? ''}',
      album: '${raw['album'] ?? ''}',
      source: '${raw['source'] ?? ''}',
      path: '${raw['path'] ?? ''}',
      bytes: raw['bytes'] is int ? raw['bytes'] as int : 0,
      time: DateTime.fromMillisecondsSinceEpoch(
        raw['time'] is int ? raw['time'] as int : 0,
      ),
    );
  }
}

/// Everything the user has downloaded, newest first.
final downloadsNotifier = ValueNotifier<List<DownloadedSong>>([]);

/// Downloads a streamed song to the public Downloads folder, at the quality the
/// server stores it in, and remembers it.
class DownloadManager {
  final List<DownloadedSong> _items = [];

  /// Songs being fetched right now, so a second tap does not start another.
  final Set<String> _inFlight = {};

  File? _file;
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;

    _file = File('${appSupportDir.path}/downloads.json');
    initFile(_file!, true);

    try {
      final raw = jsonDecode(await _file!.readAsString());
      if (raw is List) {
        for (final entry in raw) {
          final item = DownloadedSong.fromJson(entry);
          if (item != null && item.songId.isNotEmpty) {
            _items.add(item);
          }
        }
      }
    } catch (e) {
      logger.output('[downloads] could not be read: $e');
    }

    _publish();
  }

  bool isDownloaded(String songId) => _items.any((item) => item.songId == songId);

  Future<Directory> directory() async {
    final path = Platform.isAndroid
        ? '/storage/emulated/0/Download/$downloadFolderName'
        : '${appDocsDir.path}/$downloadFolderName';

    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Fetches [song] and records it. Safe to call twice; the second call is a
  /// no-op while the first is still running.
  Future<bool> startDownload(MyAudioMetadata song) async {
    final client = streamClient;
    final l10n = getAppLocalizations();

    if (client == null) {
      return false;
    }

    await ensureLoaded();

    if (_inFlight.contains(song.id) || isDownloaded(song.id)) {
      showCenterMessage(l10n.downloaded);
      return true;
    }

    // Writing into the public Downloads folder needs "all files access" on a
    // modern Android, the same permission the metadata editor asks for.
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request() == .denied) {
        showCenterMessage(l10n.downloadFailed, duration: 3000);
        return false;
      }
    }

    _inFlight.add(song.id);
    showCenterMessage(l10n.downloading, duration: 3000);

    try {
      final dir = await directory();
      final path = await _freshPath(dir, _fileNameFor(song));

      if (!await client.downloadOriginal(song.id, path)) {
        await _deleteIfEmpty(path);
        showCenterMessage(l10n.downloadFailed, duration: 3000);
        return false;
      }

      final bytes = await File(path).length();
      _items.insert(
        0,
        DownloadedSong(
          songId: song.id,
          title: getTitle(song),
          artist: getArtist(song),
          album: getAlbum(song),
          source: sourceType.name,
          path: path,
          bytes: bytes,
          time: DateTime.now(),
        ),
      );
      await _save();
      _publish();

      showCenterMessage(l10n.downloaded, duration: 3000);
      return true;
    } catch (e) {
      logger.output('[downloads] $e');
      showCenterMessage(l10n.downloadFailed, duration: 3000);
      return false;
    } finally {
      _inFlight.remove(song.id);
    }
  }

  /// Removes the file and the record.
  Future<void> delete(DownloadedSong item) async {
    await ensureLoaded();

    try {
      final file = File(item.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      logger.output('[downloads] could not delete ${item.path}: $e');
    }

    _items.removeWhere((entry) => entry.songId == item.songId);
    await _save();
    _publish();
  }

  /// `Artist - Title.<suffix>`, with what a file name cannot contain replaced.
  String _fileNameFor(MyAudioMetadata song) {
    final suffix =
        song.format ?? song.path?.split('.').last ?? song.cachePath?.split('.').last;
    final title = getTitle(song).trim();
    final artist = getArtist(song).trim();

    var name = artist.isEmpty ? title : '$artist - $title';
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (name.isEmpty) {
      name = song.id;
    }

    final extension = (suffix == null || suffix.isEmpty || suffix.length > 5)
        ? ''
        : '.$suffix';
    return '$name$extension';
  }

  /// [name] in [dir], with " (2)" and so on when that name is taken.
  Future<String> _freshPath(Directory dir, String name) async {
    final separator = Platform.pathSeparator;
    var path = '${dir.path}$separator$name';
    if (!await File(path).exists()) {
      return path;
    }

    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';

    var index = 2;
    while (await File(path).exists()) {
      path = '${dir.path}$separator$base ($index)$extension';
      index++;
    }
    return path;
  }

  Future<void> _deleteIfEmpty(String path) async {
    try {
      final file = File(path);
      if (await file.exists() && await file.length() == 0) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    await ensureLoaded();
    await _file?.writeAsString(
      jsonEncode([for (final item in _items) item.toJson()]),
    );
  }

  void _publish() {
    downloadsNotifier.value = List.of(_items);
  }
}

final downloadManager = DownloadManager();