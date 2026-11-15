import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/logger.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

/// Tag lookup for local songs: a keyword is built from the song's tags (and its
/// file name and folders when a tag is missing), each source is asked, and the
/// answers are scored so the closest match sorts first.
///
/// Only NetEase and QQ are implemented; both are public web endpoints of the
/// kind the reference project uses, and either can rate-limit or change shape -
/// a failing source is reported as such and never blocks writing tags.

class MetadataQuery {
  final String? title;
  final String? artist;
  final String? album;
  final int? track;
  final int? year;
  final String filename;
  final String? directory;
  final Set<String> excludeIds;

  const MetadataQuery({
    this.title,
    this.artist,
    this.album,
    this.track,
    this.year,
    this.filename = '',
    this.directory,
    this.excludeIds = const {},
  });

  MetadataQuery copyWith({
    String? title,
    String? artist,
    String? album,
    int? track,
    int? year,
    Set<String>? excludeIds,
  }) {
    return MetadataQuery(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      track: track ?? this.track,
      year: year ?? this.year,
      filename: filename,
      directory: directory,
      excludeIds: excludeIds ?? this.excludeIds,
    );
  }

  /// The string sent to the sources: `title|artist|album`, empty parts dropped.
  String get keyword {
    final parts = <String>[
      if (title != null && title!.trim().isNotEmpty) title!.trim(),
      if (artist != null && artist!.trim().isNotEmpty) artist!.trim(),
      if (album != null && album!.trim().isNotEmpty) album!.trim(),
    ];
    return parts.join('|');
  }
}

String? _clean(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

/// Builds the query for [song], preferring explicit overrides (what the user
/// typed in the dialog), then the tags, then the file name and its folders.
MetadataQuery buildMetadataQuery(
  MyAudioMetadata song, {
  String? title,
  String? artist,
  String? album,
  int? track,
  int? year,
  Set<String> excludeIds = const {},
}) {
  final path = song.path ?? '';
  final filename = p.basenameWithoutExtension(path);
  final directory = path.isEmpty ? null : p.dirname(path);
  final parentName = directory == null ? null : p.basename(directory);
  final grandParentName = directory == null
      ? null
      : p.basename(p.dirname(directory));

  String? clean(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value.trim();

  var resolvedTitle = clean(title) ?? clean(song.title);
  var resolvedArtist = clean(artist) ?? clean(song.artist);
  final resolvedAlbum = clean(album) ?? clean(song.album);

  if (resolvedTitle == null) {
    // `Artist - Title` is the convention the reference project parses; only
    // used when neither the user nor the tags supplied a title.
    final dash = filename.indexOf(' - ');
    if (dash > 0) {
      resolvedArtist ??= filename.substring(0, dash).trim();
      resolvedTitle = filename.substring(dash + 3).trim();
    } else {
      resolvedTitle = filename;
    }
  }
  if (resolvedArtist == null && grandParentName != null) {
    resolvedArtist = grandParentName;
  }

  var resolvedTrack = track ?? song.track;
  if (resolvedTrack == null) {
    final match = RegExp(r'^(\d{1,3})[.\-_ ]').firstMatch(filename);
    if (match != null) {
      resolvedTrack = int.tryParse(match.group(1)!);
    }
  }

  return MetadataQuery(
    title: resolvedTitle,
    artist: resolvedArtist,
    album: resolvedAlbum ?? parentName,
    track: resolvedTrack,
    year: year ?? song.year,
    filename: filename,
    directory: directory,
    excludeIds: excludeIds,
  );
}

class ScrapedCandidate {
  final String source;
  final String sourceId;
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? year;
  final int? track;
  final String? coverUrl;
  final Uint8List? coverBytes;
  final String? lyrics;
  final double score;

  const ScrapedCandidate({
    required this.source,
    required this.sourceId,
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.year,
    this.track,
    this.coverUrl,
    this.coverBytes,
    this.lyrics,
    this.score = 0,
  });

  String get key => '$source:$sourceId';

  ScrapedCandidate copyWith({
    double? score,
    Uint8List? coverBytes,
    String? lyrics,
    int? track,
    int? year,
    String? album,
    String? albumArtist,
    String? artist,
    String? title,
    String? coverUrl,
  }) {
    return ScrapedCandidate(
      source: source,
      sourceId: sourceId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      year: year ?? this.year,
      track: track ?? this.track,
      coverUrl: coverUrl ?? this.coverUrl,
      coverBytes: coverBytes ?? this.coverBytes,
      lyrics: lyrics ?? this.lyrics,
      score: score ?? this.score,
    );
  }
}

class RateLimitException implements Exception {
  final String message;
  const RateLimitException(this.message);
  @override
  String toString() => message;
}

abstract class MetadataProvider {
  String get id;
  String get displayName;

  Future<List<ScrapedCandidate>> search(MetadataQuery query);

  Future<Uint8List?> fetchCoverBytes(ScrapedCandidate candidate);

  Future<String?> fetchLyrics(ScrapedCandidate candidate);
}

/// How a scraped candidate is combined with what the file already carries.
enum ScrapeWriteMode {
  /// Only fields that are empty on the file are filled.
  fillEmpty,

  /// Every non-empty candidate field replaces the file's value.
  overwrite,
}

class ScrapedTagValues {
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final String? genre;
  final String lyrics;
  final int? year;
  final int? track;
  final int? disc;

  const ScrapedTagValues({
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.lyrics,
    this.genre,
    this.year,
    this.track,
    this.disc,
  });
}

/// The final tag values for applying [candidate] to [song]. Fields the
/// candidate does not carry keep their current value in either mode, and in
/// [ScrapeWriteMode.fillEmpty] a non-empty current value always wins.
ScrapedTagValues mergeScrapedTags({
  required MyAudioMetadata song,
  required ScrapedCandidate candidate,
  required ScrapeWriteMode mode,
}) {
  final overwrite = mode == ScrapeWriteMode.overwrite;

  String pick(String? current, String? scraped) {
    final currentText = current?.trim() ?? '';
    final scrapedText = scraped?.trim() ?? '';
    if (scrapedText.isEmpty) {
      return currentText;
    }
    if (overwrite || currentText.isEmpty) {
      return scrapedText;
    }
    return currentText;
  }

  int? pickNumber(int? current, int? scraped) {
    if (scraped == null) {
      return current;
    }
    if (overwrite || current == null) {
      return scraped;
    }
    return current;
  }

  return ScrapedTagValues(
    title: pick(song.title, candidate.title),
    artist: pick(song.artist, candidate.artist),
    album: pick(song.album, candidate.album),
    albumArtist: pick(song.albumArtist, candidate.albumArtist),
    genre: song.genre,
    lyrics: song.lyrics ?? '',
    year: pickNumber(song.year, candidate.year),
    track: pickNumber(song.track, candidate.track),
    disc: song.disc,
  );
}

// ---- scoring ---------------------------------------------------------------

const double _titleWeight = 10;
const double _artistWeight = 8;
const double _albumWeight = 6;
const double _trackWeight = 5;
const double _yearWeight = 4;

/// Comparison form of a tag value: full-width ASCII folded to ASCII, trimmed,
/// lower case, whitespace collapsed. Enough for the Chinese/Japanese tags these
/// sources carry without a Unicode normalisation table.
String normalizeMetadataText(String? value) {
  if (value == null) {
    return '';
  }
  final buffer = StringBuffer();
  for (final rune in value.trim().toLowerCase().runes) {
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      buffer.writeCharCode(rune - 0xFEE0);
    } else if (rune == 0x3000) {
      buffer.write(' ');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

double _textScore(String? keyword, String? candidate, double weight) {
  final k = normalizeMetadataText(keyword);
  if (k.isEmpty) {
    return 0;
  }
  final c = normalizeMetadataText(candidate);
  if (c.isEmpty) {
    return -weight * 0.8;
  }
  if (k == c) {
    return weight;
  }
  if (k.contains(c) || c.contains(k)) {
    return weight * 0.5;
  }
  return -weight * 0.8;
}

double scoreCandidate(MetadataQuery query, ScrapedCandidate candidate) {
  var score = 0.0;
  score += _textScore(query.title, candidate.title, _titleWeight);
  score += _textScore(query.artist, candidate.artist, _artistWeight);
  score += _textScore(query.album, candidate.album, _albumWeight);
  if (query.track != null && candidate.track != null) {
    score += query.track == candidate.track ? _trackWeight : -_trackWeight * 0.8;
  }
  if (query.year != null && candidate.year != null) {
    score += query.year == candidate.year
        ? _yearWeight
        : -_yearWeight * 0.75;
  }
  if (query.excludeIds.contains(candidate.sourceId)) {
    score -= 1000;
  }
  return score;
}

// ---- HTTP helpers ----------------------------------------------------------

const String _browserUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

Dio _httpClient({String? referer}) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': _browserUserAgent,
        if (referer != null) 'Referer': referer,
      },
      responseType: ResponseType.plain,
    ),
  );
}

Object? _decodeBody(Object? data) {
  if (data is Map || data is List) {
    return data;
  }
  if (data is! String) {
    return null;
  }
  var text = data.trim();
  // Some of the QQ endpoints answer JSONP even when asked for json.
  if (!text.startsWith('{') && !text.startsWith('[')) {
    final start = text.indexOf('(');
    final end = text.lastIndexOf(')');
    if (start != -1 && end > start) {
      text = text.substring(start + 1, end);
    }
  }
  try {
    return jsonDecode(text);
  } catch (e) {
    logger.output('[scrape] could not decode response: $e');
    return null;
  }
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Object?> _list(Object? value) => value is List ? value : const [];

String? _firstText(Object? value) => _clean(value);

// ---- NetEase ---------------------------------------------------------------

class NetEaseProvider implements MetadataProvider {
  final Dio _dio = _httpClient(referer: 'https://music.163.com/');

  @override
  String get id => 'netease';

  @override
  String get displayName => 'NetEase';

  @override
  Future<List<ScrapedCandidate>> search(MetadataQuery query) async {
    final keyword = query.keyword;
    if (keyword.isEmpty) {
      return const [];
    }
    Response<Object?> response;
    try {
      response = await _dio.post<Object?>(
        'https://music.163.com/api/search/get/web',
        data: {
          's': keyword,
          'type': 1,
          'limit': 20,
          'offset': 0,
          'total': true,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw const RateLimitException('NetEase is limiting requests');
      }
      logger.output('[scrape] netease search failed: ${e.message}');
      return const [];
    }

    final body = _map(_decodeBody(response.data));
    final result = _map(body?['result']);
    final songs = _list(result?['songs']);
    final candidates = <ScrapedCandidate>[];
    for (final raw in songs) {
      final song = _map(raw);
      if (song == null) {
        continue;
      }
      final id = _firstText(song['id']);
      if (id == null) {
        continue;
      }
      final artist = _artistsOf(song);
      final album = _map(song['al'] ?? song['album']);
      candidates.add(
        ScrapedCandidate(
          source: id,
          sourceId: id,
          title: _firstText(song['name'] ?? song['title']),
          artist: artist,
          album: _firstText(album?['name']),
        ),
      );
    }

    // The search result carries only the name; the detail call adds the album
    // year, the track number and the cover.
    final pool = Pool(6);
    final enriched = await Future.wait(
      candidates.map((candidate) => pool.withResource(() => _detail(candidate))),
    );
    await pool.close();
    return enriched;
  }

  String? _artistsOf(Map<String, dynamic> song) {
    final artists = _list(song['ar'] ?? song['artists']);
    final names = <String>[
      for (final raw in artists)
        if (_firstText(_map(raw)?['name']) case final name?) name,
    ];
    if (names.isEmpty) {
      return _firstText(song['artist'] ?? song['albumArtist']);
    }
    return names.join('/');
  }

  Future<ScrapedCandidate> _detail(ScrapedCandidate candidate) async {
    try {
      final response = await _dio.get<Object?>(
        'https://music.163.com/api/song/detail/',
        queryParameters: {'id': candidate.sourceId, 'ids': '[${candidate.sourceId}]'},
      );
      final body = _map(_decodeBody(response.data));
      final songs = _list(body?['songs']);
      if (songs.isEmpty) {
        return candidate;
      }
      final song = _map(songs.first);
      if (song == null) {
        return candidate;
      }
      final album = _map(song['al'] ?? song['album']);
      final publishTime = album?['publishTime'] ?? song['publishTime'];
      int? year;
      if (publishTime is num && publishTime > 0) {
        year = DateTime.fromMillisecondsSinceEpoch(
          publishTime.toInt(),
        ).year;
      }
      final picUrl = _firstText(album?['picUrl']);
      return candidate.copyWith(
        title: _firstText(song['name']),
        artist: _artistsOf(song),
        album: _firstText(album?['name']),
        albumArtist: _firstText(song['albumArtist']),
        track: song['no'] is num ? (song['no'] as num).toInt() : null,
        year: year,
        coverUrl: picUrl?.replaceFirst('http://', 'https://'),
      );
    } catch (e) {
      logger.output('[scrape] netease detail failed: $e');
      return candidate;
    }
  }

  @override
  Future<Uint8List?> fetchCoverBytes(ScrapedCandidate candidate) async {
    final url = candidate.coverUrl;
    if (url == null || url.isEmpty) {
      return null;
    }
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        return null;
      }
      return Uint8List.fromList(data);
    } catch (e) {
      logger.output('[scrape] netease cover failed: $e');
      return null;
    }
  }

  @override
  Future<String?> fetchLyrics(ScrapedCandidate candidate) async {
    try {
      final response = await _dio.get<Object?>(
        'https://music.163.com/api/song/lyric',
        queryParameters: {
          'id': candidate.sourceId,
          'lv': -1,
          'kv': -1,
          'tv': -1,
        },
      );
      final body = _map(_decodeBody(response.data));
      final lrc = _map(body?['lrc']);
      final text = _firstText(lrc?['lyric']);
      return (text == null || text.trim().isEmpty) ? null : text;
    } catch (e) {
      logger.output('[scrape] netease lyrics failed: $e');
      return null;
    }
  }
}

// ---- QQ Music --------------------------------------------------------------

class QqMusicProvider implements MetadataProvider {
  final Dio _dio = _httpClient(referer: 'https://y.qq.com/');

  @override
  String get id => 'qq';

  @override
  String get displayName => 'QQ Music';

  @override
  Future<List<ScrapedCandidate>> search(MetadataQuery query) async {
    final keyword = query.keyword;
    if (keyword.isEmpty) {
      return const [];
    }
    Response<Object?> response;
    try {
      response = await _dio.get<Object?>(
        'https://c.y.qq.com/soso/fcgi-bin/client_search_cp',
        queryParameters: {
          'p': 1,
          'n': 20,
          'w': keyword,
          'format': 'json',
          'new_json': 1,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw const RateLimitException('QQ Music is limiting requests');
      }
      logger.output('[scrape] qq search failed: ${e.message}');
      return const [];
    }

    final body = _map(_decodeBody(response.data));
    final data = _map(body?['data']);
    final songs = _list(_map(data?['song'])?['list']);
    final candidates = <ScrapedCandidate>[];
    for (final raw in songs) {
      final song = _map(raw);
      if (song == null) {
        continue;
      }
      final mid = _firstText(song['mid'] ?? song['songmid']);
      if (mid == null) {
        continue;
      }
      final singers = _list(song['singer']);
      final names = <String>[
        for (final rawSinger in singers)
          if (_firstText(_map(rawSinger)?['name']) case final name?) name,
      ];
      final album = _map(song['album']);
      final albumMid = _firstText(album?['mid'] ?? song['albummid']);
      final published = _firstText(song['time_public']);
      final year = published == null ? null : DateTime.tryParse(published)?.year;
      candidates.add(
        ScrapedCandidate(
          source: id,
          sourceId: mid,
          title: _firstText(song['title'] ?? song['songname']),
          artist: names.isEmpty ? _firstText(song['singer']) : names.join('/'),
          album: _firstText(album?['name'] ?? song['albumname']),
          track: song['index_album'] is num
              ? (song['index_album'] as num).toInt()
              : null,
          year: year,
          coverUrl: albumMid == null
              ? null
              : 'https://y.gtimg.cn/music/photo_new/'
                    'T002R300x300M000$albumMid.jpg',
        ),
      );
    }
    return candidates;
  }

  @override
  Future<Uint8List?> fetchCoverBytes(ScrapedCandidate candidate) async {
    final url = candidate.coverUrl;
    if (url == null || url.isEmpty) {
      return null;
    }
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        return null;
      }
      return Uint8List.fromList(data);
    } catch (e) {
      logger.output('[scrape] qq cover failed: $e');
      return null;
    }
  }

  @override
  Future<String?> fetchLyrics(ScrapedCandidate candidate) async {
    try {
      final response = await _dio.get<Object?>(
        'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg',
        queryParameters: {
          'songmid': candidate.sourceId,
          'format': 'json',
          'nobase64': 1,
          'g_tk': 5381,
        },
      );
      final body = _map(_decodeBody(response.data));
      var text = _firstText(body?['lyric']);
      if (text == null) {
        return null;
      }
      // `nobase64=1` is honoured by most responses; the others still answer
      // base64, which never contains a timestamp bracket.
      if (!text.contains('[')) {
        try {
          text = utf8.decode(base64Decode(text));
        } catch (_) {
          return null;
        }
      }
      return text.trim().isEmpty ? null : text;
    } catch (e) {
      logger.output('[scrape] qq lyrics failed: $e');
      return null;
    }
  }
}

// ---- façade ----------------------------------------------------------------

class MetadataScrapeResult {
  /// Candidates per provider, best first.
  final Map<String, List<ScrapedCandidate>> groups;

  /// Providers that answered with an error, by id.
  final Map<String, String> errors;

  const MetadataScrapeResult({required this.groups, required this.errors});

  bool get isEmpty => groups.values.every((list) => list.isEmpty);

  Iterable<ScrapedCandidate> get all sync* {
    for (final list in groups.values) {
      yield* list;
    }
  }

  ScrapedCandidate? get best {
    ScrapedCandidate? winner;
    for (final candidate in all) {
      if (winner == null || candidate.score > winner.score) {
        winner = candidate;
      }
    }
    return winner;
  }
}

class MetadataScraper {
  final List<MetadataProvider> providers;

  MetadataScraper({List<MetadataProvider>? providers})
    : providers = providers ?? [NetEaseProvider(), QqMusicProvider()];

  static final MetadataScraper instance = MetadataScraper();

  MetadataProvider? providerOf(String id) {
    for (final provider in providers) {
      if (provider.id == id) {
        return provider;
      }
    }
    return null;
  }

  /// Searches the sources in order and stops at the first that has results,
  /// unless [allSources] is set. [excludeIds] keeps a "next batch" request from
  /// repeating what is already on screen.
  Future<MetadataScrapeResult> search(
    MetadataQuery query, {
    bool allSources = false,
  }) async {
    final groups = <String, List<ScrapedCandidate>>{};
    final errors = <String, String>{};
    for (final provider in providers) {
      if (!allSources && groups.values.any((list) => list.isNotEmpty)) {
        break;
      }
      try {
        final found = await provider.search(query);
        if (found.isEmpty) {
          continue;
        }
        final scored = <ScrapedCandidate>[
          for (final candidate in found)
            candidate.copyWith(score: scoreCandidate(query, candidate)),
        ];
        final moving = <(int, ScrapedCandidate)>[];
        for (var i = 0; i < scored.length; i++) {
          moving.add((i, scored[i]));
        }
        // Same score keeps the source's own order, which is the relevance the
        // source itself decided.
        moving.sort((a, b) {
          final byScore = b.$2.score.compareTo(a.$2.score);
          return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
        });
        final visible = <ScrapedCandidate>[];
        for (final entry in moving) {
          if (visible.length >= 5) {
            break;
          }
          if (query.excludeIds.contains(entry.$2.sourceId)) {
            continue;
          }
          visible.add(entry.$2);
        }
        if (visible.isNotEmpty) {
          groups[provider.id] = visible;
        }
      } on RateLimitException catch (e) {
        errors[provider.id] = e.message;
      } catch (e) {
        errors[provider.id] = '$e';
        logger.output('[scrape] ${provider.id} failed: $e');
      }
    }
    return MetadataScrapeResult(groups: groups, errors: errors);
  }
}

