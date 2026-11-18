import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/lyric.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:path/path.dart' as p;

/// A minimal drift database for the derived lyric index. It has no generated
/// tables: everything is created with custom SQL so a failed FTS5 probe can
/// degrade to a plain table without breaking the metadata database.
class LyricIndexDB extends GeneratedDatabase {
  LyricIndexDB(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy();
}

class LyricHit {
  final String songId;
  final String text;
  final String? translation;
  final Duration? start;
  final int lineIndex;
  final bool translationMatch;

  const LyricHit({
    required this.songId,
    required this.text,
    required this.translation,
    required this.start,
    required this.lineIndex,
    required this.translationMatch,
  });
}

/// Builds and queries the full-text index of lyrics.
///
/// The index is per source, separate from `metadata.db`. Only lyrics that can
/// be read without a network request are indexed by default: local tags and
/// sidecars, Emby's embedded lyrics, and already cached server lyrics. A
/// server-side lyric fetch during a full-library pass would turn one search
/// index build into thousands of requests.
class LyricIndexService {
  LyricIndexDB? _db;
  String? _sourceKey;
  bool _fts = false;
  Future<void>? _opening;
  Future<void>? _indexing;
  Timer? _scheduleTimer;
  int _generation = 0;

  final progress = ValueNotifier<(int done, int total)?>(null);

  static const _noLyricsPlaceholders = {'暂无歌词', 'No lyrics'};

  Future<LyricIndexDB> _open() async {
    final key = sourceType.name;
    if (_db != null && _sourceKey == key) {
      return _db!;
    }
    await _opening;
    if (_db != null && _sourceKey == key) {
      return _db!;
    }
    final future = () async {
      await _db?.close();
      _db = null;
      final dir = Directory('${appSupportDir.path}/$key')
        ..createSync(recursive: true);
      final file = File(p.join(dir.path, 'lyrics_index.db'));
      final db = LyricIndexDB(NativeDatabase.createInBackground(file));
      _sourceKey = key;
      await _createSchema(db);
      _db = db;
    }();
    _opening = future;
    try {
      await future;
    } finally {
      _opening = null;
    }
    return _db!;
  }

  Future<void> _createSchema(LyricIndexDB db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS lyric_documents (
        song_id TEXT PRIMARY KEY,
        content_hash TEXT NOT NULL,
        source_modified INTEGER,
        format TEXT,
        line_count INTEGER,
        char_count INTEGER,
        indexed_at INTEGER,
        status TEXT
      )
    ''');
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS lyric_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id TEXT NOT NULL,
        line_index INTEGER NOT NULL,
        start_ms INTEGER,
        text TEXT NOT NULL,
        translation TEXT
      )
    ''');
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS lyric_lines_song ON lyric_lines(song_id)',
    );
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS lyric_index_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    try {
      await db.customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS lyric_lines_fts USING fts5(
          text,
          translation,
          content='lyric_lines',
          content_rowid='id',
          tokenize='trigram'
        )
      ''');
      _fts = true;
      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS lyric_lines_ai AFTER INSERT ON lyric_lines
        BEGIN
          INSERT INTO lyric_lines_fts(rowid, text, translation)
          VALUES (new.id, new.text, new.translation);
        END
      ''');
      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS lyric_lines_ad AFTER DELETE ON lyric_lines
        BEGIN
          INSERT INTO lyric_lines_fts(lyric_lines_fts, rowid, text, translation)
          VALUES ('delete', old.id, old.text, old.translation);
        END
      ''');
      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS lyric_lines_au AFTER UPDATE ON lyric_lines
        BEGIN
          INSERT INTO lyric_lines_fts(lyric_lines_fts, rowid, text, translation)
          VALUES ('delete', old.id, old.text, old.translation);
          INSERT INTO lyric_lines_fts(rowid, text, translation)
          VALUES (new.id, new.text, new.translation);
        END
      ''');
    } catch (e) {
      _fts = false;
      logger.output('[lyrics] FTS5 unavailable, using substring search: $e');
      await db.customStatement(
        'INSERT OR REPLACE INTO lyric_index_meta(key, value) VALUES (?, ?)',
        ['fts', '0'],
      );
    }
  }

  bool get ftsAvailable => _fts;

  /// Schedules a reconcile after the library has settled. Repeated calls
  /// collapse into one pass.
  void schedule({Duration delay = const Duration(seconds: 2)}) {
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer(delay, () {
      unawaited(ensureIndexed());
    });
  }

  Future<void> ensureIndexed({bool force = false}) async {
    if (_indexing != null) {
      return _indexing;
    }
    final future = _ensureIndexed(force: force);
    _indexing = future;
    try {
      await future;
    } finally {
      if (identical(_indexing, future)) {
        _indexing = null;
      }
    }
  }

  Future<void> _ensureIndexed({required bool force}) async {
    final generation = ++_generation;
    await _open();
    final songs = List<MyAudioMetadata>.from(library.songList);
    final ids = {for (final song in songs) song.id};
    final db = _db!;
    // Drop rows for songs that left the library. Search also verifies ids at
    // display time, but leaving them would make the index grow forever.
    final docs = await db
        .customSelect('SELECT song_id FROM lyric_documents')
        .get();
    for (final row in docs) {
      final id = row.read<String>('song_id');
      if (!ids.contains(id)) {
        await removeSong(id);
      }
    }

    progress.value = (0, songs.length);
    var done = 0;
    for (final song in songs) {
      if (generation != _generation || sourceType.name != _sourceKey) {
        return;
      }
      try {
        await indexSong(song, force: force);
      } catch (e) {
        logger.output('[lyrics] index ${song.id} failed: $e');
      }
      done++;
      if (done % 10 == 0 || done == songs.length) {
        progress.value = (done, songs.length);
        await Future<void>.delayed(Duration.zero);
      }
    }
    progress.value = null;
  }

  /// Parses for the index without touching [MyAudioMetadata.parsedLyrics].
  /// Keeping every song's parsed lines in memory made a full index grow the
  /// heap by the size of the whole library.
  Future<ParsedLyrics?> _parsedForIndex(MyAudioMetadata song) async {
    if (song.parsedLyrics != null) {
      return song.parsedLyrics;
    }
    String raw = '';
    try {
      switch (sourceType) {
        case .navidrome:
        case .feiniu:
          final path = song.lrcPath;
          if (path != null && File(path).existsSync()) {
            raw = await File(path).readAsString();
          }
        case .emby:
          raw = song.lyrics ?? '';
        case .webdav:
          raw = song.lyrics?.trim().isNotEmpty == true
              ? song.lyrics!
              : (song.lrcPath != null && File(song.lrcPath!).existsSync()
                    ? await File(song.lrcPath!).readAsString()
                    : '');
        case .local:
          if (song.lyrics?.trim().isNotEmpty == true) {
            raw = song.lyrics!;
          } else {
            final path = song.path;
            if (path != null) {
              final base = path.substring(0, path.lastIndexOf('.'));
              for (final ext in const ['.lrc', '.ttml', '.xml']) {
                final file = File('$base$ext');
                if (file.existsSync()) {
                  raw = await file.readAsString();
                  if (raw.trim().isNotEmpty) {
                    break;
                  }
                }
              }
            }
          }
      }
    } catch (e) {
      logger.output('[lyrics] raw read ${song.id} failed: $e');
      return null;
    }
    if (raw.trim().isEmpty) {
      return null;
    }
    final result = ParsedLyrics();
    final l10n = getAppLocalizations();
    try {
      if (looksLikeTtml(raw)) {
        applyTtmlParsing(
          result,
          raw,
          noLyricsMessage: l10n.noLyrics,
          parseFailedMessage: l10n.lyricsParseFailed,
          songDuration: song.duration,
        );
      } else {
        applyLrcParsing(
          result,
          raw.split(RegExp(r'\r?\n')),
          noLyricsMessage: l10n.noLyrics,
          parseFailedMessage: l10n.lyricsParseFailed,
          songDuration: song.duration,
        );
      }
    } catch (e) {
      logger.output('[lyrics] parse ${song.id} failed: $e');
      return null;
    }
    return result;
  }

  int? _sourceModified(MyAudioMetadata song) {
    var stamp = song.modified?.millisecondsSinceEpoch;
    void consider(String? path) {
      if (path == null) {
        return;
      }
      try {
        final file = File(path);
        if (file.existsSync()) {
          final cached = file.lastModifiedSync().millisecondsSinceEpoch;
          if (stamp == null || cached > stamp!) {
            stamp = cached;
          }
        }
      } catch (_) {}
    }

    consider(song.lrcPath);
    if (sourceType == .local) {
      final path = song.path;
      if (path != null && path.contains('.')) {
        final base = path.substring(0, path.lastIndexOf('.'));
        for (final ext in const ['.lrc', '.ttml', '.xml']) {
          consider('$base$ext');
        }
      }
    }
    return stamp;
  }

  bool _canReadWithoutNetwork(MyAudioMetadata song) {
    if (song.parsedLyrics != null) {
      return true;
    }
    switch (sourceType) {
      case .local:
      case .emby:
        return true;
      case .webdav:
        final lyricPath = song.lrcPath;
        return (song.lyrics?.trim().isNotEmpty ?? false) ||
            (lyricPath != null && File(lyricPath).existsSync());
      case .navidrome:
      case .feiniu:
        final lyricPath = song.lrcPath;
        return lyricPath != null && File(lyricPath).existsSync();
    }
  }

  Future<void> indexSong(MyAudioMetadata song, {bool force = false}) async {
    final db = await _open();
    if (!_canReadWithoutNetwork(song)) {
      return;
    }
    final modified = _sourceModified(song);
    final existing = await db
        .customSelect(
          'SELECT content_hash, source_modified, status FROM lyric_documents '
          'WHERE song_id = ?',
          variables: [Variable.withString(song.id)],
        )
        .getSingleOrNull();
    if (!force && existing != null) {
      final oldModified = existing.read<int?>('source_modified');
      if (oldModified == modified) {
        return;
      }
    }

    final parsed = await _parsedForIndex(song);
    final lines = [
      for (var i = 0; i < (parsed?.lines.length ?? 0); i++)
        if (_usableLine(parsed!.lines[i].text))
          (
            index: i,
            start: parsed.lines[i].start,
            text: parsed.lines[i].text.trim(),
            translation: parsed.lines[i].translates.join(' ').trim(),
          ),
    ];
    final hash = md5
        .convert(
          utf8.encode([
            for (final line in lines) '${line.index}|${line.text}|${line.translation}',
          ].join('\n')),
        )
        .toString();
    if (!force &&
        existing != null &&
        existing.read<String>('content_hash') == hash) {
      return;
    }

    await db.transaction(() async {
      await db.customStatement(
        'DELETE FROM lyric_lines WHERE song_id = ?',
        [song.id],
      );
      await db.customStatement(
        'DELETE FROM lyric_documents WHERE song_id = ?',
        [song.id],
      );
      await db.customStatement(
        'INSERT INTO lyric_documents('
        'song_id, content_hash, source_modified, format, line_count, '
        'char_count, indexed_at, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          song.id,
          hash,
          modified,
          song.format,
          lines.length,
          lines.fold<int>(0, (sum, line) => sum + line.text.length),
          DateTime.now().millisecondsSinceEpoch,
          lines.isEmpty ? 'empty' : 'ok',
        ],
      );
      for (final line in lines) {
        await db.customStatement(
          'INSERT INTO lyric_lines('
          'song_id, line_index, start_ms, text, translation) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            song.id,
            line.index,
            line.start.inMilliseconds,
            line.text,
            line.translation.isEmpty ? null : line.translation,
          ],
        );
      }
    });
  }

  bool _usableLine(String text) {
    final value = text.trim();
    if (value.isEmpty) {
      return false;
    }
    final l10n = getAppLocalizations();
    return value != l10n.noLyrics &&
        value != l10n.lyricsParseFailed &&
        !_noLyricsPlaceholders.contains(value);
  }

  Future<void> removeSong(String songId) async {
    final db = await _open();
    await db.customStatement('DELETE FROM lyric_lines WHERE song_id = ?', [
      songId,
    ]);
    await db.customStatement(
      'DELETE FROM lyric_documents WHERE song_id = ?',
      [songId],
    );
  }

  Future<List<LyricHit>> search(String raw, {int limit = 40}) async {
    final query = raw.trim();
    if (query.length < 2) {
      return const [];
    }
    final db = await _open();
    final List<QueryRow> rows;
    try {
      if (_fts && query.length >= 3) {
        final phrase = '"${query.replaceAll('"', '""')}"';
        rows = await db
            .customSelect(
              'SELECT l.song_id, l.line_index, l.start_ms, l.text, '
              'l.translation, bm25(lyric_lines_fts) AS rank '
              'FROM lyric_lines_fts '
              'JOIN lyric_lines l ON l.id = lyric_lines_fts.rowid '
              'WHERE lyric_lines_fts MATCH ? '
              'ORDER BY rank LIMIT ?',
              variables: [
                Variable.withString(phrase),
                Variable.withInt(limit * 3),
              ],
            )
            .get();
      } else {
        final needle = query.toLowerCase();
        rows = await db
            .customSelect(
              'SELECT song_id, line_index, start_ms, text, translation '
              'FROM lyric_lines '
              'WHERE instr(lower(text), ?) > 0 '
              'OR instr(lower(coalesce(translation, \'\')), ?) > 0 '
              'LIMIT ?',
              variables: [
                Variable.withString(needle),
                Variable.withString(needle),
                Variable.withInt(limit * 3),
              ],
            )
            .get();
      }
    } catch (e) {
      logger.output('[lyrics] search failed: $e');
      return const [];
    }

    final bySong = <String, LyricHit>{};
    for (final row in rows) {
      final id = row.read<String>('song_id');
      if (bySong.containsKey(id)) {
        continue;
      }
      final text = row.read<String>('text');
      final translation = row.read<String?>('translation');
      final startMs = row.read<int?>('start_ms');
      final needle = query.toLowerCase();
      bySong[id] = LyricHit(
        songId: id,
        text: text,
        translation: translation,
        start: startMs == null ? null : Duration(milliseconds: startMs),
        lineIndex: row.read<int>('line_index'),
        translationMatch:
            translation != null &&
            translation.toLowerCase().contains(needle) &&
            !text.toLowerCase().contains(needle),
      );
      if (bySong.length >= limit) {
        break;
      }
    }
    return bySong.values.toList();
  }
}

final lyricIndex = LyricIndexService();
