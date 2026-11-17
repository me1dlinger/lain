import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/utils/path.dart';

/// The last few searches, newest first, shared by every source. They are a
/// convenience only: the file is small, optional and safe to delete.
class SearchHistory {
  static const maxEntries = 12;

  final entries = ValueNotifier<List<String>>(const []);

  late File _file;
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _file = File('${appSupportDir.path}/search_history.json');
    initFile(_file, false);
    try {
      final json = await readJsonMapFile(_file);
      final raw = json['queries'];
      if (raw is List) {
        entries.value = [
          for (final item in raw)
            if (item is String && item.trim().isNotEmpty) item.trim(),
        ].take(maxEntries).toList();
      }
    } catch (_) {
      // A missing file is simply an empty history.
    }
  }

  Future<void> add(String query) async {
    final value = query.trim();
    if (value.isEmpty) {
      return;
    }
    await ensureLoaded();
    final next = [
      value,
      ...entries.value.where((item) => item.toLowerCase() != value.toLowerCase()),
    ];
    entries.value = next.take(maxEntries).toList();
    _save();
  }

  Future<void> remove(String query) async {
    await ensureLoaded();
    entries.value = [
      for (final item in entries.value)
        if (item != query) item,
    ];
    _save();
  }

  Future<void> clear() async {
    await ensureLoaded();
    entries.value = const [];
    _save();
  }

  void _save() {
    try {
      _file.writeAsStringSync(jsonEncode({'queries': entries.value}));
    } catch (_) {
      // Losing a recent search is not worth interrupting the page.
    }
  }
}

final searchHistory = SearchHistory();
