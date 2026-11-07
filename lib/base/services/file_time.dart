import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/logger.dart';

const _fileTimeChannel = MethodChannel('com.afalphy.media');

/// Local file creation times, used as the "added time" sort key.
///
/// dart:io cannot report a local file's creation time on Android ([FileStat]
/// only has `changed`/`modified`/`accessed`, and `changed` is the metadata
/// change time there - it is the creation time only on Windows). Android can
/// report the real birth time through java.nio, so ask the platform once per
/// file and remember the answer in a small json file next to the source's other
/// state, so a rescan does not repeat the work.
class FileCreationTimes {
  final Map<String, int> _cache = {};
  File? _file;
  bool _dirty = false;

  Future<void> _load() async {
    if (_file != null) {
      return;
    }
    _file = File('${appSupportDir.path}/${sourceType.name}/file_created.json');
    try {
      if (!_file!.existsSync()) {
        return;
      }
      final json = jsonDecode(await _file!.readAsString());
      if (json is Map) {
        json.forEach((key, value) {
          if (value is int) {
            _cache['$key'] = value;
          }
        });
      }
    } catch (e) {
      logger.output('[fileTime] load failed: $e');
    }
  }

  Future<void> _save() async {
    if (!_dirty) {
      return;
    }
    _dirty = false;
    try {
      await _file!.writeAsString(jsonEncode(_cache));
    } catch (e) {
      logger.output('[fileTime] save failed: $e');
    }
  }

  /// Creation ("added") time of every resolvable path in [paths].
  Future<Map<String, DateTime>> resolve(List<String> paths) async {
    await _load();

    final missing = paths.where((p) => !_cache.containsKey(p)).toList();
    if (missing.isNotEmpty) {
      await _resolveMissing(missing);
      await _save();
    }

    final result = <String, DateTime>{};
    for (final path in paths) {
      final millis = _cache[path];
      if (millis != null && millis > 0) {
        result[path] = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }
    return result;
  }

  /// Everything already known, without asking the platform for anything.
  Future<Map<String, DateTime>> cached() async {
    await _load();
    final result = <String, DateTime>{};
    _cache.forEach((path, millis) {
      if (millis > 0) {
        result[path] = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    });
    return result;
  }

  Future<void> _resolveMissing(List<String> paths) async {
    if (Platform.isAndroid && await _resolveOnAndroid(paths)) {
      return;
    }

    for (final path in paths) {
      final millis = await _statChanged(path);
      if (millis != null && millis > 0) {
        _cache[path] = millis;
        _dirty = true;
      }
    }
  }

  Future<bool> _resolveOnAndroid(List<String> paths) async {
    try {
      final times = await _fileTimeChannel.invokeMethod<List<dynamic>>(
        'getFileCreatedTimes',
        {'paths': paths},
      );
      if (times == null || times.length != paths.length) {
        return false;
      }
      var resolved = false;
      for (var i = 0; i < paths.length; i++) {
        final millis = times[i];
        if (millis is int && millis > 0) {
          _cache[paths[i]] = millis;
          _dirty = true;
          resolved = true;
        }
      }
      // Not a single path resolved: let the dart:io fallback have a go.
      return resolved;
    } catch (e) {
      logger.output('[fileTime] platform query failed: $e');
      return false;
    }
  }

  /// Last resort: `FileStat.changed` - the closest dart:io can offer, and on
  /// Windows it is the creation time itself.
  Future<int?> _statChanged(String path) async {
    try {
      final stat = await File(path).stat();
      return stat.changed.millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }
}

final fileCreationTimes = FileCreationTimes();