import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lain/base/app.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/utils/path.dart';
import 'package:path/path.dart' as p;

/// Which parts of the app a backup contains. The library itself is never
/// copied: it is rebuilt from the music folders, and a backup is meant to be
/// small enough to move between phones.
class BackupSelection {
  final bool settings;
  final bool servers;
  final bool playlists;
  final bool statistics;

  const BackupSelection({
    this.settings = true,
    this.servers = true,
    this.playlists = true,
    this.statistics = true,
  });

  BackupSelection copyWith({
    bool? settings,
    bool? servers,
    bool? playlists,
    bool? statistics,
  }) {
    return BackupSelection(
      settings: settings ?? this.settings,
      servers: servers ?? this.servers,
      playlists: playlists ?? this.playlists,
      statistics: statistics ?? this.statistics,
    );
  }
}

/// What an imported file contains, shown before anything is overwritten.
class BackupPreview {
  final DateTime? createdAt;
  final bool settings;
  final bool servers;
  final bool statistics;
  final int playlists;
  final int playlistFiles;

  const BackupPreview({
    this.createdAt,
    required this.settings,
    required this.servers,
    required this.statistics,
    required this.playlists,
    required this.playlistFiles,
  });
}

class BackupService {
  static const _format = 1;

  File get _settingsFile => File('${appSupportDir.path}/setting.json');
  File get _configFile => File('${appSupportDir.path}/config.json');
  File get _statsFile => File('${appSupportDir.path}/listening_stats.json');

  Future<Uint8List> export({
    BackupSelection selection = const BackupSelection(),
  }) async {
    final data = <String, Object?>{
      'app': 'lain',
      'format': _format,
      'createdAt': DateTime.now().toIso8601String(),
    };
    if (selection.settings) {
      data['settings'] = _readMap(_settingsFile);
    }
    if (selection.servers) {
      data['servers'] = await config.exportBackup();
    }
    if (selection.statistics) {
      data['stats'] = _readMap(_statsFile);
    }
    if (selection.playlists) {
      final playlists = <String, Map<String, String>>{};
      for (final type in SourceType.values) {
        final dir = Directory(getPlaylistConfigPath(type));
        if (!dir.existsSync()) {
          continue;
        }
        final files = <String, String>{};
        for (final entity in dir.listSync()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
            try {
              files[p.basename(entity.path)] = await entity.readAsString();
            } catch (_) {
              // A half-written file is skipped; the rest is still backed up.
            }
          }
        }
        if (files.isNotEmpty) {
          playlists[type.name] = files;
        }
      }
      data['playlists'] = playlists;
    }

    final text = const JsonEncoder.withIndent('  ').convert(data);
    return Uint8List.fromList(utf8.encode(text));
  }

  BackupPreview inspect(String text) {
    final data = _decode(text);
    final playlists = data['playlists'];
    var playlistGroups = 0;
    var playlistFiles = 0;
    if (playlists is Map) {
      for (final value in playlists.values) {
        if (value is Map && value.isNotEmpty) {
          playlistGroups++;
          playlistFiles += value.length;
        }
      }
    }
    return BackupPreview(
      createdAt: DateTime.tryParse('${data['createdAt'] ?? ''}'),
      settings: data['settings'] is Map,
      servers: data['servers'] is Map,
      statistics: data['stats'] is Map,
      playlists: playlistGroups,
      playlistFiles: playlistFiles,
    );
  }

  /// Writes the file's contents over the current data. A rollback backup of
  /// everything that is about to be replaced is written first and its path is
  /// returned, so a restore is itself undoable.
  Future<String> restore(String text) async {
    final data = _decode(text);

    final rollback = await _writeRollback();

    final settings = data['settings'];
    if (settings is Map) {
      await _writeAtomic(_settingsFile, jsonEncode(settings));
    }

    final servers = data['servers'];
    if (servers is Map) {
      await _writeAtomic(_configFile, jsonEncode(servers));
    }

    final stats = data['stats'];
    if (stats is Map) {
      await _writeAtomic(_statsFile, jsonEncode(stats));
    }

    final playlists = data['playlists'];
    if (playlists is Map) {
      for (final entry in playlists.entries) {
        final type = SourceType.values.asNameMap()['${entry.key}'];
        final files = entry.value;
        if (type == null || files is! Map) {
          continue;
        }
        final dir = Directory(getPlaylistConfigPath(type));
        await dir.create(recursive: true);
        for (final file in files.entries) {
          // Only a plain file name is accepted: a backup must not be able to
          // write outside the playlist folder.
          final name = p.basename('${file.key}');
          if (!name.toLowerCase().endsWith('.json') || file.value is! String) {
            continue;
          }
          await _writeAtomic(File(p.join(dir.path, name)), '${file.value}');
        }
      }
    }

    return rollback;
  }

  Future<String> _writeRollback() async {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final dir = Directory('${appSupportDir.path}/backups');
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, 'before-restore-$stamp.json'));
    final bytes = await export();
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Map<String, dynamic> _decode(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const FormatException('not-json');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != 'lain' ||
        decoded['format'] is! int ||
        (decoded['format'] as int) > _format) {
      throw const FormatException('not-lain-backup');
    }
    return decoded;
  }

  Map<String, dynamic> _readMap(File file) {
    if (!file.existsSync()) {
      return {};
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAtomic(File target, String content) async {
    await target.parent.create(recursive: true);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    try {
      await tmp.rename(target.path);
    } catch (_) {
      await target.writeAsString(content, flush: true);
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}

final backupService = BackupService();
