import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/data/stream_quality.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/stream_client.dart';

class NavidromeClient extends StreamClient {
  NavidromeClient({
    required super.baseUrl,
    required super.username,
    required super.password,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
  }

  /// Client for Navidrome's own (non-Subsonic) API. It carries real timeouts:
  /// a bare `Dio()` has none, so a dead address made every native call hang
  /// until the OS gave up - the seconds-long "connecting" the status page and
  /// the artist images showed.
  Dio? _nativeDioInstance;
  Dio get _nativeDio => _nativeDioInstance ??= Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

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
      'c': 'Lain',
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

  /// The fetch in flight, so the home card and the status page asking at the
  /// same time share one pass over the server instead of racing.
  Future<NavidromeLibraryStats?>? _libraryStatsFuture;

  /// Library-wide size and duration, summed once per client; see
  /// [_fetchLibraryStats].
  int? _cachedTotalSize;
  int? _cachedTotalDuration;

  /// The library and server snapshot used by the home stats card and the
  /// server status page.
  ///
  /// The total size and duration need one pass over every song, so the result
  /// is cached per client; pass [forceRefresh] to redo the whole snapshot.
  Future<NavidromeLibraryStats?> libraryStats({bool forceRefresh = false}) {
    if (forceRefresh) {
      _libraryStatsFuture = null;
    }
    return _libraryStatsFuture ??= _fetchLibraryStats();
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  /// Row count of a native list endpoint, from its `X-Total-Count` header;
  /// `_end=0` asks for no rows at all.
  Future<int?> _nativeCount(String path, Map<String, String> headers) async {
    try {
      final response = await _nativeDio.get(
        '$_nativeRoot$path',
        queryParameters: {'_start': 0, '_end': 0},
        options: Options(headers: headers),
      );
      return _asInt(response.headers.value('x-total-count'));
    } catch (e) {
      logger.output('[Navidrome] native count $path: $e');
      return null;
    }
  }

  Future<NavidromeLibraryStats?> _fetchLibraryStats() async {
    // The ping doubles as the latency measure and reports what the server is.
    final stopwatch = Stopwatch()..start();
    final ping = await safeRequest('/rest/ping.view');
    stopwatch.stop();
    if (ping == null) {
      // A failed run must not be cached as "the" result.
      _libraryStatsFuture = null;
      return null;
    }
    final serverType = ping['type']?.toString();
    final serverVersion = ping['serverVersion']?.toString();
    final subsonicVersion = ping['version']?.toString();
    final openSubsonic = ping['openSubsonic'] == true;

    // The scan status reports how many songs the library has, whether a scan
    // is running, and when the last one finished.
    int? songCount;
    bool? scanning;
    DateTime? lastScan;
    final scan = await safeRequest('/rest/getScanStatus.view');
    if (scan?['scanStatus'] is Map) {
      final status = scan!['scanStatus'] as Map;
      songCount = _asInt(status['count']);
      scanning = status['scanning'] == true;
      final lastScanRaw = status['lastScan']?.toString();
      if (lastScanRaw != null && lastScanRaw.isNotEmpty) {
        lastScan = DateTime.tryParse(lastScanRaw);
      }
    }

    int? folderCount;
    final folders = await safeRequest('/rest/getMusicFolders.view');
    if (folders?['musicFolders'] is Map) {
      final list = folders!['musicFolders']['musicFolder'];
      folderCount = list is List ? list.length : (list == null ? 0 : 1);
    }

    // Counts of artists and albums, plus the total size and duration, are
    // only available through Navidrome's own API, which needs its own login.
    int? artistCount;
    int? albumCount;
    // The totals are summed song by song - a pass over the whole library that
    // takes ages on a big one. They barely ever change, so they are computed
    // once per client and every later refresh (also the status page's) reuses
    // them and stays fast.
    int? totalSize;
    int? totalDuration;
    final token = await _nativeTokenIfAvailable();
    if (token != null) {
      final headers = {'x-nd-authorization': 'Bearer $token'};
      artistCount = await _nativeCount('/api/artist', headers);
      albumCount = await _nativeCount('/api/album', headers);

      if (_cachedTotalSize != null && _cachedTotalDuration != null) {
        totalSize = _cachedTotalSize;
        totalDuration = _cachedTotalDuration;
      } else {
        // One pass over the songs in pages: the total size and duration have
        // no dedicated endpoint, so they are summed song by song.
        int sizeSum = 0;
        int durationSum = 0;
        const pageSize = 500;
        try {
          for (var start = 0; ; start += pageSize) {
            final response = await _nativeDio.get(
              '$_nativeRoot/api/song',
              queryParameters: {
                '_start': start,
                '_end': start + pageSize,
                '_sort': 'id',
              },
              options: Options(headers: headers),
            );
            final page = response.data;
            if (page is! List || page.isEmpty) {
              break;
            }
            for (final raw in page) {
              if (raw is! Map) {
                continue;
              }
              sizeSum += _asInt(raw['size']) ?? 0;
              durationSum += _asInt(raw['duration']) ?? 0;
            }
            if (page.length < pageSize) {
              break;
            }
          }
        } catch (e) {
          logger.output('[Navidrome] library totals: $e');
        }
        if (sizeSum > 0 || durationSum > 0) {
          _cachedTotalSize = totalSize = sizeSum;
          _cachedTotalDuration = totalDuration = durationSum;
        }
      }
    }

    final stats = NavidromeLibraryStats(
      latency: stopwatch.elapsed,
      serverType: (serverType == null || serverType.isEmpty)
          ? null
          : serverType,
      serverVersion: (serverVersion == null || serverVersion.isEmpty)
          ? null
          : serverVersion,
      subsonicVersion: (subsonicVersion == null || subsonicVersion.isEmpty)
          ? null
          : subsonicVersion,
      openSubsonic: openSubsonic,
      songCount: songCount,
      artistCount: artistCount,
      albumCount: albumCount,
      folderCount: folderCount,
      totalSize: totalSize,
      totalDuration: totalDuration,
      scanning: scanning,
      lastScan: lastScan,
    );
    return stats;
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
    final songs = (normalize(response?['playlist']['entry']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .navidrome))
        .toList();

    // The Subsonic answer is the playlist's own order; what "added time"
    // should mean here is when each song joined *the playlist*. Navidrome
    // numbers its playlist rows in the order they were added, so its native
    // tracks endpoint - sorted by that row id, descending - is the playlist's
    // added order, newest first.
    final order = await _playlistAddedOrder(playlistId);
    if (order.isNotEmpty) {
      final position = {
        for (var index = 0; index < order.length; index++) order[index]: index,
      };
      songs.sort((a, b) {
        final positionA = position[a.id];
        final positionB = position[b.id];
        if (positionA == null || positionB == null) {
          return 0;
        }
        return positionA.compareTo(positionB);
      });
    }
    return songs;
  }

  /// Ids of the playlist's songs, newest added first. Navidrome's own
  /// playlist-tracks endpoint reports the rows it keeps per playlist; sorting
  /// them by `id`, descending, walks them backwards through the order they
  /// were added in. Empty when the native API is unavailable - the Subsonic
  /// order is then kept as before.
  Future<List<String>> _playlistAddedOrder(String playlistId) async {
    final token = await _nativeTokenIfAvailable();
    if (token == null) {
      return const [];
    }
    final headers = {'x-nd-authorization': 'Bearer $token'};
    final ids = <String>[];
    const pageSize = 500;
    try {
      for (var start = 0; ; start += pageSize) {
        final response = await Dio().get(
          '$_nativeRoot/api/playlist/$playlistId/tracks',
          queryParameters: {
            '_start': start,
            '_end': start + pageSize,
            '_sort': 'id',
            '_order': 'DESC',
          },
          options: Options(headers: headers),
        );
        final page = response.data;
        if (page is! List || page.isEmpty) {
          break;
        }
        for (final raw in page) {
          if (raw is! Map) {
            continue;
          }
          final id = raw['mediaFileId']?.toString();
          if (id != null && id.isNotEmpty) {
            ids.add(id);
          }
        }
        if (page.length < pageSize) {
          break;
        }
      }
    } catch (e) {
      logger.output('[Navidrome] playlist order $playlistId: $e');
    }
    return ids;
  }

  @override
  Future<List<MyAudioMetadata>?> getNewestSongs(int count) {
    return _nativeSongs(
      sort: 'createdAt',
      count: count,
      keep: (song) => true,
    );
  }

  @override
  Future<List<MyAudioMetadata>?> getMostPlayedSongs(int count) {
    return _nativeSongs(
      sort: 'playCount',
      count: count,
      keep: (song) => song.playCount > 0,
    );
  }

  /// The first [count] songs of the whole library in the native API's own
  /// order for [sort] (newest / most played / latest played first), for lists
  /// the Subsonic API has no sorted answer for. Null when the native API is
  /// unavailable; the caller then keeps what it already shows.
  Future<List<MyAudioMetadata>?> _nativeSongs({
    required String sort,
    required int count,
    required bool Function(MyAudioMetadata song) keep,
  }) async {
    final token = await _nativeTokenIfAvailable();
    if (token == null) {
      return null;
    }
    try {
      final response = await Dio().get(
        '$_nativeRoot/api/song',
        queryParameters: {
          '_start': 0,
          '_end': count,
          '_sort': sort,
          '_order': 'DESC',
        },
        options: Options(headers: {'x-nd-authorization': 'Bearer $token'}),
      );
      final page = response.data;
      if (page is! List) {
        return null;
      }
      final songs = <MyAudioMetadata>[];
      for (final raw in page) {
        if (raw is! Map) {
          continue;
        }
        final song = _metadataFromNativeSong(raw);
        if (song != null && keep(song)) {
          songs.add(song);
        }
      }
      return songs;
    } catch (e) {
      logger.output('[Navidrome] native songs ($sort): $e');
      return null;
    }
  }

  /// One song row of the native API, converted to the Subsonic-shaped map the
  /// metadata parser reads (the field names differ), with the fresh dynamic
  /// values written through to the song object the parser hands back - it
  /// reuses the one the library already holds, whose fields it does not touch.
  MyAudioMetadata? _metadataFromNativeSong(Map raw) {
    final id = raw['id']?.toString();
    if (id == null || id.isEmpty) {
      return null;
    }
    final duration = raw['duration'];
    final created = (raw['createdAt'] ?? raw['created'])?.toString();
    final played = (raw['playedAt'] ?? raw['played'])?.toString();
    final song = MyAudioMetadata.fromMap({
      'id': id,
      'title': raw['title'],
      'artist': raw['artist'],
      'album': raw['album'],
      'displayAlbumArtist': raw['displayAlbumArtist'] ?? raw['albumArtist'],
      'genre': raw['genre'],
      'year': raw['year'],
      'track': raw['trackNumber'],
      'discNumber': raw['discNumber'],
      'bitRate': raw['bitRate'],
      'samplingRate': raw['samplingRate'],
      'duration': duration is num ? duration.round() : duration,
      'contentType': raw['contentType'],
      'path': raw['path'],
      'created': created,
      'played': played,
      'playCount': (raw['playCount'] as num?)?.toInt(),
      'size': raw['size'],
      'albumId': raw['albumId'],
      'artistId': raw['artistId'],
    }, .navidrome);
    song.playCount = (raw['playCount'] as num?)?.toInt() ?? song.playCount;
    final playedTime = DateTime.tryParse(played ?? '');
    if (playedTime != null && playedTime.year > 2000) {
      song.lastPlayed = playedTime;
    }
    song.created ??= DateTime.tryParse(created ?? '');
    return song;
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
  Future<Uint8List?> getPictureBytes(String id, {int size = 600}) async {
    return safeRequest(
      '/rest/getCoverArt.view',
      // Navidrome can render a cover at an asked-for size; without it a
      // playlist cover is a multi-megabyte original that has to be decoded
      // every time it is shown. 600px is ample for most places the app draws
      // one; artist thumbnails ask for less.
      query: {'id': id, 'size': size},
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
    final items = normalize(
      response['starred2'][isArtist ? 'artist' : 'album'],
    );
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
    final imageUrl = (info['largeImageUrl'] ?? info['mediumImageUrl'])
        ?.toString();
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
  Future<({String? imageUrl, bool hasImage})?> getArtistImageInfo(
    String artistId,
  ) async {
    final token = await _nativeTokenIfAvailable();
    if (token == null) {
      return null;
    }
    try {
      final response = await Dio().get(
        '$_nativeRoot/api/artist/$artistId',
        options: Options(headers: {'x-nd-authorization': 'Bearer $token'}),
      );
      final data = response.data;
      final url = (data?['largeImageUrl'] ?? data?['imageUrl'])?.toString();
      final imageUrl = (url == null || url.isEmpty) ? null : url;
      // The same test the artist list uses: an image hash means the server has
      // its own image, and imageAbsent false means it visibly has one.
      final imageHash = data?['imageHash']?.toString() ?? '';
      final hasImage = imageHash.isNotEmpty || data?['imageAbsent'] == false;
      return (imageUrl: imageUrl, hasImage: hasImage);
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
  Future<bool> downloadSong(
    String songId,
    String savePath, {
    CancelToken? cancelToken,
  }) async {
    return _download(getStreamUrl(songId), savePath, cancelToken: cancelToken);
  }

  /// `/rest/download` with `format=raw&bitrate=0` hands over the file itself,
  /// where `/rest/stream` would honour the stream quality settings. A download
  /// is meant to be the original.
  @override
  Future<bool> downloadOriginal(
    String songId,
    String savePath, {
    CancelToken? cancelToken,
  }) async {
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
    return _download(url, savePath, cancelToken: cancelToken);
  }

  Future<bool> _download(
    String url,
    String savePath, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
      );
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

/// Snapshot of a Navidrome server and its library, for the home stats card
/// and the server status page.
///
/// Every field is what the server reported; a value the server does not give
/// stays null and the pages show a dash for it.
class NavidromeLibraryStats {
  /// How long the ping took, measured while the snapshot was fetched.
  final Duration latency;

  /// The server software behind the Subsonic API, e.g. `navidrome`.
  final String? serverType;

  /// The server's own version, e.g. `0.6.4.1 (285dc4f3)`.
  final String? serverVersion;

  /// The Subsonic API version the server speaks, e.g. `1.16.1`.
  final String? subsonicVersion;

  /// Whether the server answered with the OpenSubsonic flag.
  final bool openSubsonic;

  /// Songs visible through the Subsonic API (the scan count).
  final int? songCount;

  final int? artistCount;
  final int? albumCount;
  final int? folderCount;

  /// Sum of every song's file size, in bytes.
  final int? totalSize;

  /// Sum of every song's duration, in seconds.
  final int? totalDuration;

  /// Whether a scan was running when the snapshot was taken.
  final bool? scanning;

  /// When the last scan finished.
  final DateTime? lastScan;

  const NavidromeLibraryStats({
    required this.latency,
    this.serverType,
    this.serverVersion,
    this.subsonicVersion,
    this.openSubsonic = false,
    this.songCount,
    this.artistCount,
    this.albumCount,
    this.folderCount,
    this.totalSize = 0,
    this.totalDuration = 0,
    this.scanning,
    this.lastScan,
  });
}

/// `108.4 GB`-style formatting of a byte count for the stats display.
String formatLibrarySize(int bytes) {
  if (bytes <= 0) {
    return '0';
  }
  final gb = bytes / (1024 * 1024 * 1024);
  if (gb >= 1) {
    return gb >= 100
        ? gb.round().toString()
        : gb.toStringAsFixed(gb >= 10 ? 1 : 2);
  }
  final mb = bytes / (1024 * 1024);
  return mb >= 1 ? '${mb.round()} MB' : '${(bytes / 1024).round()} KB';
}

/// `273.4`-style hour value of a duration in seconds; larger libraries are
/// shown in whole days plus hours instead, with the unit chosen by the
/// caller through [inDays].
String formatLibraryDuration(int seconds, {required bool inDays}) {
  if (inDays) {
    return '${seconds ~/ 86400}';
  }
  final hours = seconds / 3600;
  return hours >= 100 ? hours.round().toString() : hours.toStringAsFixed(1);
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
    final fallbackStart = lineMeta is Map && lineMeta['start'] is num
        ? lineMeta['start'] as num
        : null;
    final startRaw = cueLines.first['start'];
    final start = startRaw is num ? startRaw : fallbackStart;
    if (start == null) {
      continue;
    }
    final lineStart = start.toInt() + offset;

    final cues = <(int, String)>[];
    for (final cueLine in cueLines) {
      for (final cue
          in ((cueLine['cue'] ?? const []) as List).whereType<Map>()) {
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
