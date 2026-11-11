import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/data/stream_quality.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/stream_client.dart';

class NavidromeClient extends StreamClient {
  NavidromeClient({
    required super.baseUrl,
    required super.username,
    required super.password,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
  }

  @protected
  String randomSalt() {
    final rand = Random();
    return List.generate(8, (_) => rand.nextInt(36).toRadixString(36)).join();
  }

  @protected
  Map<String, String> buildParams() {
    final salt = randomSalt();
    final token = md5.convert(utf8.encode(password + salt)).toString();

    return {
      'u': username,
      't': token,
      's': salt,
      'v': '1.16.1',
      'c': 'Sylvakru',
      'f': 'json',
    };
  }

  @protected
  Map<String, dynamic> params([Map<String, dynamic>? extra]) {
    return {...buildParams(), ...?extra};
  }

  @protected
  Future<T?> safeRequest<T>(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
    String errorMessage = '',
    bool showRealError = false,
  }) async {
    try {
      final res = await getWithFailover(
        path,
        queryParameters: params(query),
        options: options,
      );

      if (options?.responseType == .bytes) {
        return res.data;
      }

      final response = res.data['subsonic-response'];

      if (response['status'] != 'ok') {
        final resErrorMessage = response['error']?['message'];
        logger.output(
          '\n[$runtimeType]\n[request]$path\n[query]$query\n[options]$options\n[error]${resErrorMessage ?? 'Unknown error'}',
        );

        if (showRealError && resErrorMessage != null) {
          showCenterMessage(resErrorMessage, duration: 3000);
        }

        return null;
      }

      return response;
    } on DioException catch (e) {
      logger.output(
        '\n[$runtimeType]\n[request]$path\n[query]$query\n[options]$options\n[error]Dio: ${e.message} (${e.response?.statusCode}\n[data]${e.response?.data.toString()})',
      );

      if (errorMessage.isNotEmpty) {
        showCenterMessage(errorMessage, duration: 3000);
      }

      return null;
    } catch (e) {
      logger.output(
        '\n[$runtimeType]\n[request]$path\n[query]$query\n[options]$options\n[error]$e',
      );

      if (errorMessage.isNotEmpty) {
        showCenterMessage(errorMessage, duration: 3000);
      }

      return null;
    }
  }

  @override
  Future<bool> ping() async {
    return await safeRequest('/rest/ping.view', showRealError: true) != null;
  }

  @override
  Future<int> getSongCount() async {
    final response = await safeRequest('/rest/getScanStatus.view');

    if (response == null) {
      return 0;
    }

    return response['scanStatus']['count'];
  }

  @override
  Future<List<MyAudioMetadata>?> getSongs(int size, int offset) async {
    final response = await safeRequest(
      '/rest/search3.view',
      query: {
        'query': '',
        'albumCount': 0,
        'artistCount': 0,
        'songCount': size,
        'songOffset': offset,
      },
      errorMessage: "Failed to fetch songs",
    );

    if (response == null) {
      return null;
    }
    final songs = (normalize(response['searchResult3']['song']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .navidrome))
        .toList();

    if (songs.isNotEmpty) {
      logger.output('[Navidrome] Fetched ${offset + songs.length} songs...');
    }

    return songs;
  }

  @override
  Future<List<MyAudioMetadata>?> getStarredSongs() async {
    final response = await safeRequest('/rest/getStarred2.view');
    if (response == null) {
      return null;
    }

    // response['starred2'] is not empty but response['starred2']['song'] sometimes is null
    return (normalize(response['starred2']['song']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .navidrome))
        .toList();
  }

  @override
  Future<bool> updateStarredSongs(List<String> songIds) async {
    final response = await safeRequest('/rest/getStarred2.view');
    if (response == null) {
      return false;
    }

    final oldSongIds = (normalize(response['starred2']['song']) ?? [])
        .map((e) => e['id'].toString())
        .toList();

    final songToRemoveIds = [];
    for (int i = 0; i < oldSongIds.length; i++) {
      songToRemoveIds.add(oldSongIds[i]);
      if (songToRemoveIds.length % 100 == 0) {
        final res = await safeRequest(
          '/rest/unstar.view',
          query: {'id': songToRemoveIds},
        );
        if (res == null) {
          return false;
        }
        songToRemoveIds.clear();
      }
    }
    if (songToRemoveIds.isNotEmpty) {
      final res = await safeRequest(
        '/rest/unstar.view',
        query: {'id': songToRemoveIds},
      );

      if (res == null) {
        return false;
      }
    }

    final songToAddIds = [];
    for (int i = songIds.length - 1; i >= 0; i--) {
      songToAddIds.add(songIds[i]);
      if (songToAddIds.length % 100 == 0) {
        final res = await safeRequest(
          '/rest/star.view',
          query: {'id': songToAddIds},
        );
        if (res == null) {
          return false;
        }
        songToAddIds.clear();
      }
    }
    if (songToAddIds.isNotEmpty) {
      return await safeRequest(
            '/rest/star.view',
            query: {'id': songToAddIds},
          ) !=
          null;
    }
    return true;
  }

  @override
  Future<List<MyAudioMetadata>?> getPlaylistSongs(String playlistId) async {
    final response = await safeRequest(
      '/rest/getPlaylist.view',
      query: {'id': playlistId},
    );
    if (response == null) {
      return null;
    }
    return (normalize(response?['playlist']['entry']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .navidrome))
        .toList();
  }

  @override
  Future<String?> createPlaylist(String name) async {
    final response = await safeRequest(
      '/rest/createPlaylist.view',
      query: {'name': name},
    );
    return response?['playlist']['id'].toString();
  }

  @override
  Future<bool> deletePlaylist(String playlistId) async {
    return await safeRequest(
          '/rest/deletePlaylist.view',
          query: {'id': playlistId},
        ) !=
        null;
  }

  @override
  Future<List<Playlist>?> getPlaylists() async {
    final response = await safeRequest('/rest/getPlaylists.view');
    return (normalize(
      response?['playlists']['playlist'],
    ))?.map((e) => Playlist(name: e['name'], id: e['id'])).toList();
  }

  @override
  Future<bool> updatePlaylistSongs(
    String playlistId,
    List<String> songIds,
  ) async {
    final oldSongIds = await getPlaylistSongs(playlistId);
    if (oldSongIds == null) {
      return false;
    }
    final songIndexToRemove = [];
    for (int i = oldSongIds.length - 1; i >= 0; i--) {
      songIndexToRemove.add(i);
      if (songIndexToRemove.length % 100 == 0) {
        final res = await safeRequest(
          '/rest/updatePlaylist.view',
          query: {
            'playlistId': playlistId,
            'songIndexToRemove': songIndexToRemove,
          },
        );
        if (res == null) {
          return false;
        }
        songIndexToRemove.clear();
      }
    }
    if (songIndexToRemove.isNotEmpty) {
      final res = await safeRequest(
        '/rest/updatePlaylist.view',
        query: {
          'playlistId': playlistId,
          'songIndexToRemove': songIndexToRemove,
        },
      );

      if (res == null) {
        return false;
      }
    }

    final songToAddIds = [];
    for (int i = 0; i < songIds.length; i++) {
      songToAddIds.add(songIds[i]);
      if (songToAddIds.length % 100 == 0) {
        final res = await safeRequest(
          '/rest/updatePlaylist.view',
          query: {'playlistId': playlistId, 'songIdToAdd': songToAddIds},
        );
        if (res == null) {
          return false;
        }
        songToAddIds.clear();
      }
    }
    if (songToAddIds.isNotEmpty) {
      return await safeRequest(
            '/rest/updatePlaylist.view',
            query: {'playlistId': playlistId, 'songIdToAdd': songToAddIds},
          ) !=
          null;
    }
    return true;
  }

  @override
  String getStreamUrl(String id) {
    // Strings only: `Uri.replace` refuses an int in queryParameters, and this
    // URL is built by hand rather than handed to Dio.
    final query = <String, String>{'id': id};
    final maxBitRate = streamQualityNotifier.value.maxBitRate;
    if (maxBitRate != null) {
      // Subsonic transcodes on request: cap the bitrate and pick the container.
      query['maxBitRate'] = '$maxBitRate';
      query['format'] = streamFormatNotifier.value.subsonicValue;
    }
    return Uri.parse(baseUrl)
        .resolve('rest/stream.view')
        .replace(queryParameters: params(query))
        .toString();
  }

  @override
  Future<Uint8List?> getPictureBytes(String id) async {
    return safeRequest(
      '/rest/getCoverArt.view',
      query: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  // Subsonic-style auth travels in the query string, so this URL can be fetched
  // by anything that can reach the server (no request headers needed).
  @override
  String getPictureUrl(String id) {
    return Uri.parse(baseUrl)
        .resolve('rest/getCoverArt.view')
        .replace(queryParameters: params({'id': id}))
        .toString();
  }

  @override
  bool get supportsEntityFavorites => true;

  @override
  Future<bool> setStarred(String id, bool starred) async {
    return await safeRequest(
          starred ? '/rest/star.view' : '/rest/unstar.view',
          query: {'id': id},
        ) !=
        null;
  }

  @override
  Future<Map<String, DateTime?>> getStarredIds({required bool isArtist}) async {
    final response = await safeRequest('/rest/getStarred2.view');
    if (response == null) {
      return {};
    }
    final items = normalize(response['starred2'][isArtist ? 'artist' : 'album']);
    return {
      for (final item in items ?? [])
        item['id'].toString(): item['starred'] != null
            ? DateTime.tryParse(item['starred'].toString())
            : null,
    };
  }

  @override
  Future<String?> getAlbumNotes(String albumId) async {
    final response = await safeRequest(
      '/rest/getAlbum.view',
      query: {'id': albumId},
    );
    final notes = response?['album']?['notes']?.toString();
    return (notes == null || notes.isEmpty) ? null : notes;
  }

  @override
  Future<({String? biography, String? imageUrl})?> getArtistInfo(
    String artistId,
  ) async {
    final response = await safeRequest(
      '/rest/getArtistInfo.view',
      query: {'id': artistId},
    );
    final info = response?['artistInfo'];
    if (info == null) {
      return null;
    }
    final biography = info['biography']?.toString();
    final imageUrl =
        (info['largeImageUrl'] ?? info['mediumImageUrl'])?.toString();
    return (
      biography: (biography == null || biography.isEmpty) ? null : biography,
      imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
    );
  }

  /// Token of Navidrome's own API, obtained once. It is a different scheme from
  /// Subsonic (a bearer token from /auth/login) and is only needed for the
  /// artist image, which the Subsonic endpoint leaves out when the server has
  /// no local one.
  String? _nativeToken;

  /// Root of the server, without a trailing slash, for the native API paths.
  String get _nativeRoot {
    final url = baseUrl.trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<String?> _nativeTokenIfAvailable() async {
    final cached = _nativeToken;
    if (cached != null) {
      return cached;
    }
    try {
      final response = await Dio().post(
        '$_nativeRoot/auth/login',
        data: {'username': username, 'password': password},
        options: Options(contentType: 'application/json'),
      );
      final token = response.data?['token']?.toString();
      _nativeToken = (token == null || token.isEmpty) ? null : token;
    } catch (e) {
      logger.output('[Navidrome] native login: $e');
      _nativeToken = null;
    }
    return _nativeToken;
  }

  @override
  Future<String?> getArtistImageUrl(String artistId) async {
    final token = await _nativeTokenIfAvailable();
    if (token == null) {
      return null;
    }
    try {
      final response = await Dio().get(
        '$_nativeRoot/api/artist/$artistId',
        options: Options(headers: {'x-nd-authorization': 'Bearer $token'}),
      );
      final url = (response.data?['largeImageUrl'] ?? response.data?['imageUrl'])
          ?.toString();
      return (url == null || url.isEmpty) ? null : url;
    } catch (e) {
      logger.output('[Navidrome] artist image $artistId: $e');
      return null;
    }
  }

  @override
  Future<String?> getAlbumDescription(String albumId) async {
    final token = await _nativeTokenIfAvailable();
    if (token == null) {
      return null;
    }
    try {
      final response = await Dio().get(
        '$_nativeRoot/api/album/$albumId',
        options: Options(headers: {'x-nd-authorization': 'Bearer $token'}),
      );
      final data = response.data;
      final description = data?['description']?.toString();
      final comment = data?['comment']?.toString();
      final value = (description != null && description.trim().isNotEmpty)
          ? description
          : comment;
      return (value == null || value.trim().isEmpty) ? null : value;
    } catch (e) {
      logger.output('[Navidrome] album description $albumId: $e');
      return null;
    }
  }

  @override
  Future<
    List<
      ({
        String id,
        String name,
        bool hasImage,
        String? biography,
        String? imageUrl,
      })
    >?
  >
  getArtistSummaries() async {
    final token = await _nativeTokenIfAvailable();
    if (token == null) {
      return null;
    }

    const pageSize = 500;
    final result =
        <
          ({
            String id,
            String name,
            bool hasImage,
            String? biography,
            String? imageUrl,
          })
        >[];
    try {
      for (var start = 0; ; start += pageSize) {
        final response = await Dio().get(
          '$_nativeRoot/api/artist',
          queryParameters: {
            '_start': start,
            '_end': start + pageSize,
            '_sort': 'name',
            '_order': 'ASC',
          },
          options: Options(headers: {'x-nd-authorization': 'Bearer $token'}),
        );
        final page = response.data;
        if (page is! List || page.isEmpty) {
          break;
        }
        for (final raw in page) {
          if (raw is! Map) {
            continue;
          }
          final id = raw['id']?.toString() ?? '';
          final name = raw['name']?.toString() ?? '';
          if (id.isEmpty || name.isEmpty) {
            continue;
          }
          final imageHash = raw['imageHash']?.toString() ?? '';
          final biography = raw['biography']?.toString();
          final imageUrl = raw['largeImageUrl']?.toString();
          result.add((
            id: id,
            name: name,
            // The list reports imageHash when the server has one, and
            // imageAbsent when it really has none.
            hasImage: imageHash.isNotEmpty || raw['imageAbsent'] == false,
            biography: (biography == null || biography.isEmpty)
                ? null
                : biography,
            imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
          ));
        }
        if (page.length < pageSize) {
          break;
        }
      }
    } catch (e) {
      logger.output('[Navidrome] artist summaries: $e');
      return result.isEmpty ? null : result;
    }
    return result;
  }

  @override
  Future<String> getLyricsById(String songId) async {
    final response = await safeRequest(
      '/rest/getLyricsBySongId.view',
      query: {'id': songId, 'enhanced': true},
    );

    if (response == null) {
      return '';
    }

    final lyricsList = response['lyricsList'];

    if (lyricsList != null && lyricsList['structuredLyrics'] != null) {
      final List structured = lyricsList['structuredLyrics'];

      if (structured.isNotEmpty) {
        return structuredLyricsToLrc(structured);
      }
    }

    final lyrics = response['lyrics'];

    if (lyrics != null) {
      return lyrics['value'] ?? '';
    }

    return '';
  }

  @override
  Future<bool> downloadSong(String songId, String savePath) async {
    return _download(getStreamUrl(songId), savePath);
  }

  /// `/rest/download` with `format=raw&bitrate=0` hands over the file itself,
  /// where `/rest/stream` would honour the stream quality settings. A download
  /// is meant to be the original.
  @override
  Future<bool> downloadOriginal(String songId, String savePath) async {
    final url = Uri.parse(baseUrl)
        .resolve('rest/download.view')
        .replace(
          queryParameters: params({
            'id': songId,
            'format': 'raw',
            'bitrate': '0',
          }),
        )
        .toString();
    return _download(url, savePath);
  }

  Future<bool> _download(String url, String savePath) async {
    try {
      final response = await dio.download(url, savePath);
      return response.statusCode == 200;
    } on DioException catch (e) {
      logger.output('[$runtimeType] Download failed: ${e.message}');
      return false;
    } catch (e) {
      logger.output('[$runtimeType] Download failed: $e');
      return false;
    }
  }

  @override
  Future<bool> scrobble(String songId) async {
    return await safeRequest(
          '/rest/scrobble.view',
          query: {'id': songId},
          errorMessage: 'Failed to scrobble',
        ) !=
        null;
  }
}

/// Formats milliseconds as `MM:SS.mmm`, the timestamp shape the LRC parser
/// understands for both line and angle-bracket word timestamps.
String _formatLrcTime(int milliseconds) {
  final minute = (milliseconds ~/ 60000).toString().padLeft(2, '0');
  final second = ((milliseconds % 60000) ~/ 1000).toString().padLeft(2, '0');
  final milli = (milliseconds % 1000).toString().padLeft(3, '0');
  return '$minute:$second.$milli';
}

/// Converts OpenSubsonic structured lyrics into LRC text: plain entries
/// become `[mm:ss.mmm]line` lines (as before), while entries carrying the
/// v2 karaoke extension (`cueLine`/`cue`, served by Navidrome 0.63+ for
/// TTML sidecars) keep their word timing as angle-bracket word timestamps.
/// `kind=translation` entries are emitted as same-timestamp lines so they
/// show up as translations.
@visibleForTesting
String structuredLyricsToLrc(List structured) {
  final entries = structured.whereType<Map>().toList();
  if (entries.isEmpty) {
    return '';
  }

  Map? cuedEntry;
  Map? plainEntry;
  var maxLength = 0;

  for (final entry in entries) {
    final kind = entry['kind'];
    final cueLines = entry['cueLine'];
    final lines = entry['line'];

    if (cuedEntry == null &&
        cueLines is List &&
        cueLines.isNotEmpty &&
        (kind == null || kind == 'main')) {
      cuedEntry = entry;
    }

    if (lines is List && lines.isNotEmpty) {
      final value = lines.first['value'];
      if (value is String && value.length > maxLength) {
        plainEntry = entry;
        maxLength = value.length;
      }
    }
  }

  final buffer = StringBuffer();

  if (cuedEntry != null) {
    _writeCuedEntry(buffer, cuedEntry, entries);
  } else if (plainEntry != null) {
    _writePlainEntry(buffer, plainEntry, entries);
  }

  return buffer.toString();
}

void _writeCuedEntry(StringBuffer buffer, Map entry, List entries) {
  final offset = _intOf(entry['offset']);
  final translations = _translationLines(entries);

  // Agent layers (background vocals etc.) share one index; the main layer
  // comes first per the spec, so its start timestamps the line.
  final layers = <int, List<Map>>{};
  for (final cueLine in (entry['cueLine'] as List).whereType<Map>()) {
    final index = cueLine['index'];
    if (index is num) {
      layers.putIfAbsent(index.toInt(), () => []).add(cueLine);
    }
  }

  final lines = entry['line'] is List ? entry['line'] as List : const [];

  for (final index in layers.keys.toList()..sort()) {
    final cueLines = layers[index]!;
    final lineMeta = index >= 0 && index < lines.length ? lines[index] : null;
    final fallbackStart =
        lineMeta is Map && lineMeta['start'] is num ? lineMeta['start'] as num : null;
    final startRaw = cueLines.first['start'];
    final start = startRaw is num ? startRaw : fallbackStart;
    if (start == null) {
      continue;
    }
    final lineStart = start.toInt() + offset;

    final cues = <(int, String)>[];
    for (final cueLine in cueLines) {
      for (final cue in ((cueLine['cue'] ?? const []) as List).whereType<Map>()) {
        final cueStart = cue['start'];
        if (cueStart is! num) {
          continue;
        }
        final text = _cueText(cueLine, cue);
        if (text.isEmpty) {
          continue;
        }
        cues.add((cueStart.toInt() + offset, text));
      }
    }
    cues.sort((a, b) => a.$1.compareTo(b.$1));

    buffer.write('[${_formatLrcTime(lineStart)}]');
    for (final (cueStart, text) in cues) {
      buffer.write('<${_formatLrcTime(cueStart)}>$text');
    }
    buffer.write('\n');

    _writeTranslations(buffer, translations, lineStart);
  }
}

void _writePlainEntry(StringBuffer buffer, Map entry, List entries) {
  final offset = _intOf(entry['offset']);
  final translations = _translationLines(entries);

  for (final line in ((entry['line'] ?? const []) as List).whereType<Map>()) {
    final start = line['start'];
    final lineStart = (start is num ? start.toInt() : 0) + offset;
    buffer.write('[${_formatLrcTime(lineStart)}]${line['value'] ?? ''}\n');
    _writeTranslations(buffer, translations, lineStart);
  }
}

Map<int, List<String>> _translationLines(List entries) {
  final translations = <int, List<String>>{};
  for (final entry in entries.whereType<Map>()) {
    if (entry['kind'] != 'translation') {
      continue;
    }
    final offset = _intOf(entry['offset']);
    final lines = entry['line'];
    if (lines is! List) {
      continue;
    }
    for (final line in lines.whereType<Map>()) {
      final start = line['start'];
      final value = line['value'];
      if (start is num && value is String && value.trim().isNotEmpty) {
        translations.putIfAbsent(start.toInt() + offset, () => []).add(value);
      }
    }
  }
  return translations;
}

void _writeTranslations(
  StringBuffer buffer,
  Map<int, List<String>> translations,
  int lineStart,
) {
  for (final text in translations[lineStart] ?? const <String>[]) {
    buffer.write('[${_formatLrcTime(lineStart)}]$text\n');
  }
}

/// Resolves a cue's text: byte offsets into the cueLine value are
/// authoritative and inclusive on both ends per the v2 spec (they preserve
/// exact spacing, e.g. between CJK words), falling back to the cue's own
/// value.
String _cueText(Map cueLine, Map cue) {
  final value = cueLine['value'];
  final byteStart = cue['byteStart'];
  final byteEnd = cue['byteEnd'];
  if (value is String && byteStart is num && byteEnd is num) {
    final bytes = utf8.encode(value);
    final start = byteStart.toInt();
    final end = byteEnd.toInt();
    if (start >= 0 && end < bytes.length && start <= end) {
      return utf8.decode(bytes.sublist(start, end + 1), allowMalformed: true);
    }
  }
  return cue['value'] is String ? cue['value'] as String : '';
}

int _intOf(dynamic raw) => raw is num ? raw.toInt() : 0;
