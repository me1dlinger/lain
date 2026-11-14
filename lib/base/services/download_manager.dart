import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:lain/base/app.dart';
import 'package:lain/base/data/cache_download_settings.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/stream_quality.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/mobile_data_notice.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/utils/path.dart';
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

/// What a queued download is doing.
enum DownloadTaskState {
  /// Added while the connection is mobile data and the setting is off.
  waitingForWifi,
  downloading,
  paused,
  failed,
}

/// One requested download that is not finished yet. Persisted, so a task that
/// was waiting for Wi-Fi is still there on the next launch.
class DownloadTask {
  final String songId;
  final String title;
  final String artist;
  final String album;
  DownloadTaskState state;

  DownloadTask({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    this.state = DownloadTaskState.waitingForWifi,
  });

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'title': title,
    'artist': artist,
    'album': album,
    'state': state.name,
  };

  static DownloadTask? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final id = '${raw['songId'] ?? ''}';
    if (id.isEmpty) {
      return null;
    }
    return DownloadTask(
      songId: id,
      title: '${raw['title'] ?? ''}',
      artist: '${raw['artist'] ?? ''}',
      album: '${raw['album'] ?? ''}',
      state: DownloadTaskState.values.asNameMap()['${raw['state']}'] ??
          DownloadTaskState.waitingForWifi,
    );
  }
}

/// Everything the user has downloaded, newest first.
final downloadsNotifier = ValueNotifier<List<DownloadedSong>>([]);

/// The downloads that are queued, running, paused or failed.
final downloadTasksNotifier = ValueNotifier<List<DownloadTask>>([]);

/// Downloads a streamed song to the public Downloads folder and remembers it.
///
/// A task added while the connection is mobile data and "download over mobile
/// data" is off waits for Wi-Fi; on the next launch over Wi-Fi (or when the
/// page asks) it starts by itself.
class DownloadManager {
  final List<DownloadedSong> _items = [];
  final List<DownloadTask> _tasks = [];

  /// Songs being fetched right now, so a second tap does not start another.
  final Set<String> _inFlight = {};
  final Map<String, CancelToken> _tokens = {};
  final Map<String, String> _taskPaths = {};

  File? _file;
  File? _queueFile;
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

    _queueFile = File('${appSupportDir.path}/download_queue.json');
    initFile(_queueFile!, true);

    try {
      final raw = jsonDecode(await _queueFile!.readAsString());
      if (raw is List) {
        for (final entry in raw) {
          final task = DownloadTask.fromJson(entry);
          if (task == null) {
            continue;
          }
          // A task that was running when the app was killed is queued again.
          if (task.state == DownloadTaskState.downloading) {
            task.state = DownloadTaskState.waitingForWifi;
          }
          _tasks.add(task);
        }
      }
    } catch (e) {
      logger.output('[downloads] queue could not be read: $e');
    }

    _publish();
    _publishTasks();
  }

  bool isDownloaded(String songId) => _items.any((item) => item.songId == songId);

  DownloadTask? taskFor(String songId) {
    for (final task in _tasks) {
      if (task.songId == songId) {
        return task;
      }
    }
    return null;
  }

  Future<Directory> directory() async {
    final configured = downloadDirNotifier.value.trim();
    final path = configured.isNotEmpty
        ? configured
        : Platform.isAndroid
        ? '/storage/emulated/0/Download/$downloadFolderName'
        : '${appDocsDir.path}/$downloadFolderName';

    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> _canDownloadNow() async {
    if (downloadOnMobileDataNotifier.value) {
      return true;
    }
    return !await mobileDataNotice.isCellularNetwork();
  }

  /// Queues [song]. When the connection allows it the download starts at once;
  /// on mobile data with the setting off it waits for Wi-Fi.
  Future<bool> startDownload(MyAudioMetadata song) async {
    final client = streamClient;
    if (client == null) {
      return false;
    }
    await ensureLoaded();

    if (isDownloaded(song.id) || taskFor(song.id) != null) {
      _message(getAppLocalizations().downloaded);
      return true;
    }

    final task = DownloadTask(
      songId: song.id,
      title: getTitle(song),
      artist: getArtist(song),
      album: getAlbum(song),
    );
    _tasks.insert(0, task);

    if (!await _canDownloadNow()) {
      task.state = DownloadTaskState.waitingForWifi;
      _publishTasks();
      await _saveQueue();
      _message(getAppLocalizations().downloadWaitingForWifi);
      return true;
    }

    _message(getAppLocalizations().downloadAdded);
    unawaited(_runTask(task));
    return true;
  }

  Future<void> _runTask(DownloadTask task) async {
    final l10n = getAppLocalizations();
    final client = streamClient;
    final song = library.id2Song[task.songId];

    if (client == null || song == null) {
      task.state = DownloadTaskState.failed;
      _publishTasks();
      await _saveQueue();
      _message(l10n.downloadFailed);
      return;
    }

    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request() == .denied) {
        task.state = DownloadTaskState.failed;
        _publishTasks();
        await _saveQueue();
        _message(l10n.downloadFailed);
        return;
      }
    }

    final token = CancelToken();
    _tokens[task.songId] = token;
    _inFlight.add(task.songId);
    task.state = DownloadTaskState.downloading;
    _publishTasks();
    await _saveQueue();

    String path = '';
    try {
      final dir = await directory();
      path = await _freshPath(dir, _fileNameFor(song));
      _taskPaths[task.songId] = path;

      final quality = downloadQualityNotifier.value;
      final ok = quality == StreamQuality.original
          ? await client.downloadOriginal(song.id, path, cancelToken: token)
          : await client.downloadSong(
              song.id,
              path,
              cancelToken: token,
              quality: quality,
            );

      if (token.isCancelled) {
        task.state = DownloadTaskState.paused;
        await _deleteFile(path);
        return;
      }
      if (!ok) {
        task.state = DownloadTaskState.failed;
        await _deleteFile(path);
        _message(l10n.downloadFailed);
        return;
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

      _tasks.remove(task);
      _message(l10n.downloaded);
    } catch (e) {
      logger.output('[downloads] $e');
      if (path.isNotEmpty) {
        await _deleteFile(path);
      }
      task.state = DownloadTaskState.failed;
      _message(l10n.downloadFailed);
    } finally {
      _tokens.remove(task.songId);
      _taskPaths.remove(task.songId);
      _inFlight.remove(task.songId);
      _publishTasks();
      await _saveQueue();
    }
  }

  /// Stops [task]. A running request is cancelled and its partial file removed,
  /// so it restarts from the beginning when continued.
  Future<void> pauseTask(DownloadTask task) async {
    _tokens[task.songId]?.cancel();
    final path = _taskPaths[task.songId];
    if (path != null) {
      await _deleteFile(path);
    }
    task.state = DownloadTaskState.paused;
    _publishTasks();
    await _saveQueue();
  }

  Future<void> resumeTask(DownloadTask task) async {
    if (task.state == DownloadTaskState.downloading) {
      return;
    }
    if (!await _canDownloadNow()) {
      task.state = DownloadTaskState.waitingForWifi;
      _publishTasks();
      await _saveQueue();
      _message(getAppLocalizations().downloadWaitingForWifi);
      return;
    }
    unawaited(_runTask(task));
  }

  Future<void> deleteTask(DownloadTask task) async {
    _tokens[task.songId]?.cancel();
    final path = _taskPaths[task.songId];
    if (path != null) {
      await _deleteFile(path);
    }
    _tasks.remove(task);
    _publishTasks();
    await _saveQueue();
  }

  Future<void> pauseAll() async {
    for (final task in List<DownloadTask>.of(_tasks)) {
      if (task.state == DownloadTaskState.downloading) {
        await pauseTask(task);
      } else {
        task.state = DownloadTaskState.paused;
      }
    }
    _publishTasks();
    await _saveQueue();
  }

  Future<void> resumeAll() async {
    await ensureLoaded();
    final allowed = await _canDownloadNow();
    for (final task in _tasks) {
      if (task.state == DownloadTaskState.downloading) {
        continue;
      }
      if (allowed) {
        unawaited(_runTask(task));
      } else {
        task.state = DownloadTaskState.waitingForWifi;
      }
    }
    _publishTasks();
    await _saveQueue();
  }

  Future<void> deleteAllTasks() async {
    for (final task in List<DownloadTask>.of(_tasks)) {
      await deleteTask(task);
    }
    _publishTasks();
    await _saveQueue();
  }

  /// Starts the tasks that were waiting for Wi-Fi, if the connection allows it.
  /// Called when the app opens; the message tells the listener that the queue
  /// moved on its own.
  Future<void> resumeWaitingForWifi() async {
    await ensureLoaded();
    if (!await _canDownloadNow()) {
      return;
    }
    final waiting = [
      for (final task in _tasks)
        if (task.state == DownloadTaskState.waitingForWifi) task,
    ];
    if (waiting.isEmpty) {
      return;
    }
    for (final task in waiting) {
      unawaited(_runTask(task));
    }
    _message(getAppLocalizations().downloadResumedOnWifi(waiting.length));
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

  /// Moves every recorded download into [newRoot] and rewrites the records so
  /// they keep pointing at the files. Returns how many files were moved.
  Future<int> moveToDirectory(String newRoot) async {
    await ensureLoaded();
    final target = Directory(newRoot);
    await target.create(recursive: true);
    final moved = <DownloadedSong>[];
    var count = 0;
    for (final item in downloadsNotifier.value) {
      final source = File(item.path);
      if (!await source.exists()) {
        continue;
      }
      final name = p.basename(item.path);
      var dest = File('${target.path}/$name');
      var suffix = 1;
      while (await dest.exists()) {
        dest = File('${target.path}/${suffix}_$name');
        suffix++;
      }
      try {
        try {
          await source.rename(dest.path);
        } catch (_) {
          await source.copy(dest.path);
          await source.delete();
        }
        count++;
        moved.add(
          DownloadedSong(
            songId: item.songId,
            title: item.title,
            artist: item.artist,
            album: item.album,
            source: item.source,
            path: dest.path,
            bytes: item.bytes,
            time: item.time,
          ),
        );
      } catch (e) {
        logger.output('[downloads] could not move ${item.path}: $e');
        moved.add(item);
      }
    }
    downloadsNotifier.value = moved;
    await _save();
    return count;
  }

  /// `Artist - Title.<suffix>`, with what a file name cannot contain replaced.
  String _fileNameFor(MyAudioMetadata song) {
    final suffix = song.format ??
        song.path?.split('.').last ??
        song.cachePath?.split('.').last;
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
    for (var i = 2; i < 1000; i++) {
      path = '${dir.path}$separator$base ($i)$extension';
      if (!await File(path).exists()) {
        return path;
      }
    }
    return path;
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      logger.output('[downloads] could not delete $path: $e');
    }
  }

  void _publish() {
    downloadsNotifier.value = List<DownloadedSong>.unmodifiable(_items);
  }

  void _publishTasks() {
    downloadTasksNotifier.value = List<DownloadTask>.unmodifiable(_tasks);
  }

  Future<void> _save() async {
    try {
      await _file?.writeAsString(
        jsonEncode(_items.map((item) => item.toJson()).toList()),
      );
    } catch (e) {
      logger.output('[downloads] could not be saved: $e');
    }
  }

  Future<void> _saveQueue() async {
    try {
      await _queueFile?.writeAsString(
        jsonEncode(_tasks.map((task) => task.toJson()).toList()),
      );
    } catch (e) {
      logger.output('[downloads] queue could not be saved: $e');
    }
  }

  void _message(String text, {int duration = 3000}) {
    final context = globalNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    showCenterMessage(text, duration: duration);
  }
}

final downloadManager = DownloadManager();
