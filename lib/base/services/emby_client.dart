import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/lan_direct_setting.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/data/server_stats.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/data/stream_quality.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/stream_client.dart';

/// A non-empty string value, or null when the server sent nothing.
String? _text(Object? value) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? null : text;
}

class EmbyClient extends StreamClient {
  String? accessToken;
  String? userId;

  Future<bool>? _loginFuture;

  /// The song whose "now playing" session was started by
  /// [reportPlaybackProgress]. Emby shows no live session (and no transcode
  /// count on the status page) until `Sessions/Playing` has been posted for it.
  String? _progressSessionSongId;

  EmbyClient({
    required super.baseUrl,
    required super.username,
    required super.password,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Authorization':
              'MediaBrowser Client="Lain", Device="Flutter", DeviceId="lain", Version="$versionNumber"',
        },
      ),
    );

    _applyInterceptor();
  }

  static String _normalizeBaseUrl(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  @override
  String normalizeBaseUrl(String url) => _normalizeBaseUrl(url);

  /// Fields every item query asks for.
  ///
  /// Emby only fills `UserData.PlayCount` and `UserData.LastPlayedDate` when
  /// the query names `UserDataPlayCount` / `UserDataLastPlayedDate`
  /// explicitly; without them every song reports a play count of 0, which is
  /// why the play-count sort and the most-played list were wrong. `DateCreated`
  /// is the server's "added to the library" time, and `MediaSources` carries
  /// the size, the codec and the embedded lyrics.
  static const _itemFields =
      'DateCreated,DatePlayed,UserDataPlayCount,UserDataLastPlayedDate,'
      'UserData,MediaSources,ProductionYear,Genres,PrimaryImageAspectRatio,'
      'Album,AlbumId,Artists,ArtistItems,AlbumArtist,AlbumArtists,'
      'RunTimeTicks,IndexNumber,ParentIndexNumber,Size';

  /// One item of an Emby answer, with its dynamic user fields written through
  /// to the song object the library already holds.
  ///
  /// `MyAudioMetadata.fromMap` reuses the existing object for a known id and
  /// therefore keeps its old play count and last-played time; the server's
  /// answer is authoritative and has to be applied here.
  MyAudioMetadata? _songFromItem(Map<String, dynamic> item) {
    final id = item['Id']?.toString();
    if (id == null || id.isEmpty) {
      return null;
    }
    final song = MyAudioMetadata.fromMap(item, .emby);
    final userData = item['UserData'];
    if (userData is Map) {
      final playCount = userData['PlayCount'];
      if (playCount is num) {
        song.playCount = playCount.toInt();
      }
      song.lastPlayed = MyAudioMetadata.parseEmbyDate(
        userData['LastPlayedDate'],
      );
    }
    song.created ??= MyAudioMetadata.parseEmbyDate(item['DateCreated']);
    if (song.size == null) {
      final sources = item['MediaSources'];
      if (sources is List && sources.isNotEmpty && sources.first is Map) {
        song.size = ((sources.first as Map)['Size'] as num?)?.toInt();
      }
    }
    return song;
  }

  void _applyInterceptor() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (accessToken != null) {
            options.headers['X-Emby-Token'] = accessToken;
          }
          handler.next(options);
        },
      ),
    );
  }

  @protected
  /// Runs one request; when it fails because the server cannot be reached, the
  /// same request is retried once against the server's other address.
  Future<Response> _runWithFailover(Future<Response> Function() request) async {
    try {
      return await request();
    } catch (error) {
      if (!StreamClient.isNetworkFailure(error) || !switchToAlternative()) {
        rethrow;
      }
      logger.output('[EmbyClient] switched to $baseUrl');
      return await request();
    }
  }

  Future<T?> safeRequest<T>(
    Future<Response> Function() request, {
    T? Function(Response response)? parser,
    String errorMessage = '',
    bool showRealError = false,
    bool ignoreMessage = false,
    bool isRetry = false,
  }) async {
    try {
      if (accessToken == null && userId == null) {
        final loggedIn = await login();
        if (!loggedIn) {
          return null;
        }
      }

      final response = await _runWithFailover(request);

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        if (parser != null) {
          return parser(response);
        }
        return response.data as T?;
      }

      return null;
    } on DioException catch (e) {
      // The token can be invalidated server-side (server restart / session
      // expiry); re-authenticate once and retry before giving up.
      if (e.response?.statusCode == 401 && !isRetry) {
        accessToken = null;
        userId = null;

        if (await login()) {
          return safeRequest(
            request,
            parser: parser,
            errorMessage: errorMessage,
            showRealError: showRealError,
            ignoreMessage: ignoreMessage,
            isRetry: true,
          );
        }

        return null;
      }

      if (ignoreMessage) {
        return null;
      }
      logger.output(
        '\n[$runtimeType]\n[error]Dio: ${e.message} (${e.response?.statusCode}\n[data]${e.response?.data.toString()})',
      );

      if (errorMessage.isNotEmpty) {
        showCenterMessage(errorMessage, duration: 3000);
      }

      return null;
    } catch (e) {
      if (ignoreMessage) {
        return null;
      }
      logger.output('\n[$runtimeType]\n[error]$e');

      if (errorMessage.isNotEmpty) {
        showCenterMessage(errorMessage, duration: 3000);
      }

      return null;
    }
  }

  /// Whether a request succeeded, judged by its status code.
  ///
  /// Emby answers several commands (stopping a session, deleting a playlist
  /// item, starting a task) with 204 and no body; `safeRequest` would then
  /// hand back null and a success would look like a failure.
  Future<bool> _ok(
    Future<Response> Function() request, {
    bool showRealError = false,
  }) async {
    final status = await safeRequest<int>(
      request,
      parser: (res) => res.statusCode,
      showRealError: showRealError,
    );
    return status != null && status >= 200 && status < 300;
  }

  /// Perform login and save user info and default music library
  ///
  /// Startup fires many safeRequest calls at once (songs, covers, playlists);
  /// they must share a single AuthenticateByName or the burst of concurrent
  /// logins can get throttled into intermittent 401s (same as FeiniuClient).
  Future<bool> login() async {
    if (accessToken != null) return true;

    final pending = _loginFuture;
    if (pending != null) return pending;

    final future = _login();
    _loginFuture = future;
    try {
      return await future;
    } finally {
      _loginFuture = null;
    }
  }

  Future<bool> _login() async {
    try {
      final response = await dio.post(
        '/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
      );

      accessToken = response.data['AccessToken'];
      userId = response.data['User']['Id'];

      return true;
    } catch (e) {
      showCenterMessage('[$runtimeType] Login failed');
      logger.output('[$runtimeType] Login failed: $e');
      return false;
    }
  }

  @override
  Future<bool> ping() async {
    final result = await safeRequest<dynamic>(
      () => dio.get('/System/Info/Public'),
      showRealError: true,
    );
    return result != null;
  }

  @override
  Future<int> getSongCount() async {
    // `/Items/Counts` counts every library on the server (films and episodes
    // included). The user's own Audio items are the music library this app
    // syncs, so ask for that total instead.
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Limit': 1,
          'Fields': 'Id',
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    final total = response?['TotalRecordCount'];
    return total is num ? total.toInt() : 0;
  }

  @override
  Future<List<MyAudioMetadata>?> getSongs(int size, int offset) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'StartIndex': offset,
          'Limit': size,
          // A stable order is what makes the paged sync cover every song
          // exactly once.
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
          'Fields': _itemFields,
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return null;
    }

    final songs = (normalize(response['Items']) ?? [])
        .map(_songFromItem)
        .whereType<MyAudioMetadata>()
        .toList();

    if (songs.isNotEmpty) {
      logger.output('[Emby] Fetched ${offset + songs.length} songs...');
    }

    return songs;
  }

  /// Songs in server order for [sort], newest/most played first.
  ///
  /// The old version only mapped ids that were already in the library, so a
  /// song added elsewhere since the last sync silently vanished from the
  /// list. The items are parsed instead, which also refreshes the play count
  /// and last-played time of the songs already known.
  Future<List<MyAudioMetadata>?> _getSortedSongs(
    String sort, {
    required int count,
    bool playedOnly = false,
    bool Function(MyAudioMetadata song)? keep,
  }) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'SortBy': '$sort,SortName',
          'SortOrder': 'Descending',
          'StartIndex': 0,
          'Limit': count,
          if (playedOnly) 'Filters': 'IsPlayed',
          'Fields': _itemFields,
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return null;
    }

    final songs = (normalize(response['Items']) ?? [])
        .map(_songFromItem)
        .whereType<MyAudioMetadata>()
        .where((song) => keep == null || keep(song))
        .toList();
    return songs;
  }

  /// The most recently played songs, newest play first.
  ///
  /// Emby only fills `LastPlayedDate` when the query asks for it, and sorting
  /// by `DatePlayed` puts unplayed items first unless the query filters them
  /// out with `IsPlayed`.
  Future<List<MyAudioMetadata>?> getRecentlySongs() {
    return _getSortedSongs(
      'DatePlayed',
      count: 200,
      playedOnly: true,
      keep: (song) => song.lastPlayed != null,
    );
  }

  Future<List<MyAudioMetadata>?> getFrequentlySongs() {
    return _getSortedSongs(
      'PlayCount',
      count: 200,
      keep: (song) => song.playCount > 0,
    );
  }

  @override
  Future<List<MyAudioMetadata>?> getMostPlayedSongs(int count) {
    return _getSortedSongs(
      'PlayCount',
      count: count,
      keep: (song) => song.playCount > 0,
    );
  }

  @override
  Future<List<MyAudioMetadata>?> getNewestSongs(int count) {
    return _getSortedSongs('DateCreated', count: count);
  }

  @override
  Future<List<MyAudioMetadata>?> getStarredSongs() async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Filters': 'IsFavorite',
          'SortBy': 'DateCreated,SortName',
          'SortOrder': 'Descending',
          'Fields': _itemFields,
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return null;
    }

    return (normalize(response['Items']) ?? [])
        .map(_songFromItem)
        .whereType<MyAudioMetadata>()
        .toList();
  }

  /// Every song id currently starred, or null when the server could not
  /// answer (an empty set would look like "nothing is starred").
  Future<Set<String>?> _favoriteSongIds() async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Filters': 'IsFavorite',
          'Fields': 'Id',
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return null;
    }
    return {
      for (final item in normalize(response['Items']) ?? [])
        if (item['Id'] != null) '${item['Id']}',
    };
  }

  @override
  Future<bool> updateStarredSongs(List<String> songIds) async {
    // Only the difference is sent: the old version unstarred every favourite
    // and re-starred the whole list on each save, which is a lot of requests
    // for an edit that usually changes one song.
    final oldSongIds = await _favoriteSongIds();
    if (oldSongIds == null) {
      return false;
    }
    final wanted = songIds.toSet();

    for (final id in oldSongIds.difference(wanted)) {
      final ok = await _ok(
        () => dio.delete('/Users/$userId/FavoriteItems/$id'),
      );
      if (!ok) {
        return false;
      }
    }

    for (final id in wanted.difference(oldSongIds)) {
      final ok = await _ok(
        () => dio.post('/Users/$userId/FavoriteItems/$id'),
      );
      if (!ok) {
        return false;
      }
    }

    return true;
  }

  @override
  bool get supportsEntityFavorites => true;

  @override
  Future<bool> setStarred(String id, bool starred) async {
    return _ok(
      () => starred
          ? dio.post('/Users/$userId/FavoriteItems/$id')
          : dio.delete('/Users/$userId/FavoriteItems/$id'),
    );
  }

  @override
  Future<Map<String, DateTime?>> getStarredIds({
    required bool isArtist,
  }) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': isArtist ? 'MusicArtist' : 'MusicAlbum',
          'Recursive': true,
          'Filters': 'IsFavorite',
          'Fields': 'UserData',
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );
    if (response == null) {
      return {};
    }
    // Emby does not report when an item was starred, so the time stays null;
    // the sort then falls back to the name.
    return {
      for (final item in normalize(response['Items']) ?? [])
        if (item['Id'] != null) '${item['Id']}': null,
    };
  }

  /// The snapshot in flight, so the home card and the status page asking at
  /// the same time share one pass over the server instead of racing.
  Future<ServerLibraryStats?>? _libraryStatsFuture;

  /// Library totals summed once per client; see [_fetchLibraryStats].
  int? _cachedTotalSize;
  int? _cachedTotalDuration;

  @override
  Future<ServerLibraryStats?> libraryStats({bool forceRefresh = false}) {
    if (forceRefresh) {
      _libraryStatsFuture = null;
    }
    return _libraryStatsFuture ??= _fetchLibraryStats();
  }

  /// Total record count of a user's items matching [query]; one row is enough.
  Future<int?> _itemTotal(Map<String, dynamic> query) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          ...query,
          'Recursive': true,
          'Limit': 1,
          'Fields': 'Id',
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
      ignoreMessage: true,
    );
    final total = response?['TotalRecordCount'];
    return total is num ? total.toInt() : null;
  }

  Future<ServerLibraryStats?> _fetchLibraryStats() async {
    // The public info endpoint answers without a session and doubles as the
    // latency measure.
    final stopwatch = Stopwatch()..start();
    final publicInfo = await safeRequest<Map<String, dynamic>>(
      () => dio.get('/System/Info/Public'),
      parser: (res) => res.data as Map<String, dynamic>?,
    );
    stopwatch.stop();
    if (publicInfo == null) {
      // A failed run must not be cached as "the" result.
      _libraryStatsFuture = null;
      return null;
    }

    final info = await safeRequest<Map<String, dynamic>>(
      () => dio.get('/System/Info'),
      parser: (res) => res.data as Map<String, dynamic>?,
      ignoreMessage: true,
    );

    final songCount = await _itemTotal({'IncludeItemTypes': 'Audio'});
    final albumCount = await _itemTotal({'IncludeItemTypes': 'MusicAlbum'});

    // The artist page in Emby Web lists album artists, not every per-track
    // artist, so count the same list.
    final artists = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Artists/AlbumArtists',
        queryParameters: {
          'userId': userId ?? '',
          'Recursive': true,
          'Limit': 1,
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
      ignoreMessage: true,
    );
    final artistTotal = artists?['TotalRecordCount'];
    final artistCount = artistTotal is num ? artistTotal.toInt() : null;

    int? folderCount;
    final views = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Views',
        queryParameters: {'Fields': 'Id,CollectionType'},
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
      ignoreMessage: true,
    );
    if (views != null) {
      final items = normalize(views['Items']) ?? [];
      folderCount = items
          .where((view) => view['CollectionType'] == 'music')
          .length;
    }

    // The totals are a pass over the whole music library. They barely ever
    // change, so they are computed once per client and every later refresh
    // reuses them. `Fields=Size` keeps the rows light (no media sources).
    int? totalSize = _cachedTotalSize;
    int? totalDuration = _cachedTotalDuration;
    if (totalSize == null || totalDuration == null) {
      var sizeSum = 0;
      var durationSum = 0;
      var hasSize = false;
      var hasDuration = false;
      const pageSize = 500;
      try {
        for (var start = 0; ; start += pageSize) {
          final page = await safeRequest<Map<String, dynamic>>(
            () => dio.get(
              '/Users/$userId/Items',
              queryParameters: {
                'IncludeItemTypes': 'Audio',
                'Recursive': true,
                'StartIndex': start,
                'Limit': pageSize,
                'SortBy': 'SortName',
                'SortOrder': 'Ascending',
                'Fields': 'Size,RunTimeTicks',
              },
            ),
            parser: (res) => res.data as Map<String, dynamic>?,
            ignoreMessage: true,
          );
          final items = normalize(page?['Items']) ?? [];
          if (items.isEmpty) {
            break;
          }
          for (final item in items) {
            final size = item['Size'];
            if (size is num) {
              sizeSum += size.toInt();
              hasSize = true;
            }
            final ticks = item['RunTimeTicks'];
            if (ticks is num) {
              durationSum += ticks.toInt() ~/ 10000000;
              hasDuration = true;
            }
          }
          final total = page?['TotalRecordCount'];
          if (items.length < pageSize ||
              (total is num && start + items.length >= total)) {
            break;
          }
        }
      } catch (e) {
        logger.output('[Emby] library totals: $e');
      }
      if (hasSize) {
        _cachedTotalSize = sizeSum;
        totalSize = sizeSum;
      }
      if (hasDuration) {
        _cachedTotalDuration = durationSum;
        totalDuration = durationSum;
      }
    }

    // "Scan media library" is the scheduled task Emby Web's own dashboard
    // starts; its last result carries the last scan time.
    bool? scanning;
    DateTime? lastScan;
    final tasks = await safeRequest<List<dynamic>>(
      () => dio.get('/ScheduledTasks'),
      parser: (res) => res.data as List<dynamic>?,
      ignoreMessage: true,
    );
    for (final task in tasks ?? const []) {
      if (task is! Map || task['Key'] != 'RefreshLibrary') {
        continue;
      }
      scanning = '${task['State']}' != 'Idle';
      final result = task['LastExecutionResult'];
      if (result is Map) {
        lastScan = MyAudioMetadata.parseEmbyDate(
          result['EndTimeUtc'] ?? result['StartTimeUtc'],
        );
      }
      break;
    }

    // Sessions with an item playing are the live streams; the play method
    // tells a direct play from a transcode.
    int? activeStreams;
    int? transcodeStreams;
    final sessions = await safeRequest<List<dynamic>>(
      () => dio.get('/Sessions'),
      parser: (res) => res.data as List<dynamic>?,
      ignoreMessage: true,
    );
    if (sessions != null) {
      var active = 0;
      var transcodes = 0;
      for (final session in sessions.whereType<Map>()) {
        if (session['NowPlayingItem'] is! Map) {
          continue;
        }
        active++;
        final state = session['PlayState'];
        if (state is Map && state['PlayMethod'] == 'Transcode') {
          transcodes++;
        }
      }
      activeStreams = active;
      transcodeStreams = transcodes;
    }

    return ServerLibraryStats(
      latency: stopwatch.elapsed,
      sourceType: 'emby',
      serverType: 'Emby',
      serverName: _text(publicInfo['ServerName']) ?? _text(info?['ServerName']),
      serverVersion:
          _text(publicInfo['Version']) ?? _text(info?['Version']),
      operatingSystem: _text(info?['OperatingSystemDisplayName']),
      hasUpdate: info?['HasUpdateAvailable'] as bool?,
      songCount: songCount,
      artistCount: artistCount,
      albumCount: albumCount,
      folderCount: folderCount,
      totalSize: totalSize,
      totalDuration: totalDuration,
      scanning: scanning,
      lastScan: lastScan,
      activeStreams: activeStreams,
      transcodeStreams: transcodeStreams,
    );
  }

  @override
  Future<bool> startScan() async {
    final tasks = await safeRequest<List<dynamic>>(
      () => dio.get('/ScheduledTasks'),
      parser: (res) => res.data as List<dynamic>?,
    );
    String? taskId;
    for (final task in tasks ?? const []) {
      if (task is Map && task['Key'] == 'RefreshLibrary' && task['Id'] != null) {
        taskId = '${task['Id']}';
        break;
      }
    }
    if (taskId == null) {
      return false;
    }
    return _ok(
      () => dio.post('/ScheduledTasks/Running/$taskId'),
      showRealError: true,
    );
  }

  @override
  Future<List<MyAudioMetadata>?> getPlaylistSongs(String playlistId) async {
    final response = await safeRequest<Map<String, dynamic>>(
      // No SortBy: the playlist endpoint's own order is the playlist order,
      // which is what the list shows until the user picks another sort.
      () => dio.get(
        '/Playlists/$playlistId/Items',
        queryParameters: {'Fields': _itemFields},
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return null;
    }

    return (normalize(response['Items']) ?? [])
        .map(_songFromItem)
        .whereType<MyAudioMetadata>()
        .toList();
  }

  @override
  Future<String?> createPlaylist(String name) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.post(
        '/Playlists',
        queryParameters: {'Name': name, 'Ids': '', 'MediaType': 'Audio'},
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    return response?['Id']?.toString();
  }

  @override
  Future<bool> deletePlaylist(String playlistId) async {
    return _ok(() => dio.delete('/Items/$playlistId'));
  }

  @override
  Future<List<Playlist>?> getPlaylists() async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': 'Playlist',
          'Recursive': true,
          // Emby Web lists playlists newest-created first; the app showed
          // whatever order the server happened to return.
          'SortBy': 'DateCreated,SortName',
          'SortOrder': 'Descending',
          'Fields': 'DateCreated,ChildCount',
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    return (normalize(
      response?['Items'],
    ))?.map((e) => Playlist(name: e['Name'], id: e['Id'].toString())).toList();
  }

  @override
  Future<bool> updatePlaylistSongs(
    String playlistId,
    List<String> songIds,
  ) async {
    final oldSongs = await getPlaylistSongs(playlistId);
    if (oldSongs == null) {
      return false;
    }

    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get('/Playlists/$playlistId/Items'),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response != null) {
      final rawItems = normalize(response['Items']) ?? [];
      final oldEntryIds = rawItems
          .map((e) => e['PlaylistItemId']?.toString() ?? e['Id']?.toString())
          .whereType<String>()
          .toList();

      if (oldEntryIds.isNotEmpty) {
        final ok = await _ok(
          () => dio.delete(
            '/Playlists/$playlistId/Items',
            queryParameters: {'EntryIds': oldEntryIds.join(',')},
          ),
        );
        if (!ok) {
          return false;
        }
      }
    }

    if (songIds.isNotEmpty) {
      final ok = await _ok(
        () => dio.post(
          '/Playlists/$playlistId/Items',
          queryParameters: {'Ids': songIds.join(',')},
        ),
      );
      if (!ok) {
        return false;
      }
    }

    return true;
  }

  @override
  String getStreamUrl(String id) {
    // LAN direct asks for the untouched file: `static=true` with no bitrate cap
    // and no codec, exactly like the original quality choice.
    final maxBitRate = lanDirectActive
        ? null
        : streamQualityNotifier.value.maxBitRate;
    // `static=true` asks Emby for the untouched file; when a quality is chosen
    // the server has to transcode instead, so request a bitrate cap and codec.
    final query = <String, String>{
      'UserId': userId ?? '',
      'api_key': accessToken ?? '',
      'static': (maxBitRate == null).toString(),
      if (maxBitRate != null) ...{
        'MaxStreamingBitrate': '${maxBitRate * 1000}',
        'AudioCodec': streamFormatNotifier.value.embyValue,
        // Without a container Emby may hand back a stream whose content type
        // does not match the requested codec.
        'Container': streamFormatNotifier.value.embyContainer,
      },
    };
    return Uri.parse(
      '${dio.options.baseUrl}/Audio/$id/stream',
    ).replace(queryParameters: query).toString();
  }

  /// `DirectPlay` while the server hands the stored file over, `Transcode`
  /// once a bitrate cap is asked for; the server status page reads this from
  /// the session list, so it has to match the URL actually requested.
  String get _playMethod =>
      (lanDirectActive || streamQualityNotifier.value.maxBitRate == null)
      ? 'DirectPlay'
      : 'Transcode';

  @override
  Future<Uint8List?> getPictureBytes(String songId, {int size = 600}) async {
    return safeRequest<Uint8List>(
      () => dio.get<List<int>>(
        '/Items/$songId/Images/Primary',
        options: Options(responseType: ResponseType.bytes),
      ),
      parser: (res) => Uint8List.fromList(res.data as List<int>),
      ignoreMessage: true,
    );
  }

  // Emby also accepts the token as an `api_key` query parameter, which makes the
  // URL fetchable without headers.
  @override
  String getPictureUrl(String songId) {
    return '${dio.options.baseUrl}/Items/$songId/Images/Primary'
        '?api_key=$accessToken';
  }

  @override
  Future<String> getLyricsById(String songId) async {
    // Emby stores lyrics as a text subtitle stream on the item; the dedicated
    // /Audio/{id}/Lyrics endpoint answers 500 on this server. Read them from
    // the media source instead.
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items/$songId',
        queryParameters: {'Fields': 'MediaSources'},
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
      ignoreMessage: true,
    );
    final sources = response?['MediaSources'];
    if (sources is List) {
      for (final source in sources.whereType<Map>()) {
        final streams = source['MediaStreams'];
        if (streams is! List) {
          continue;
        }
        for (final stream in streams.whereType<Map>()) {
          final text = stream['Extradata'];
          if (text is String &&
              text.isNotEmpty &&
              (stream['Type'] == 'Subtitle' || stream['Codec'] == 'text')) {
            return text;
          }
        }
      }
    }
    return '';
  }

  @override
  Future<bool> downloadSong(
    String songId,
    String savePath, {
    CancelToken? cancelToken,
    StreamQuality? quality,
    void Function(int received, int total)? onProgress,
  }) async {
    // A chosen quality downloads the same transcode the player would stream;
    // "original" (or no quality) fetches the stored file.
    final transcodes = quality != null && quality.transcodes;
    final url = transcodes
        ? Uri.parse(
            '${dio.options.baseUrl}/Audio/$songId/stream',
          ).replace(
            queryParameters: {
              'UserId': userId ?? '',
              'api_key': accessToken ?? '',
              'static': 'false',
              'MaxStreamingBitrate': '${quality.maxBitRate! * 1000}',
              'AudioCodec': streamFormatNotifier.value.embyValue,
              'Container': streamFormatNotifier.value.embyContainer,
            },
          ).toString()
        : '/Items/$songId/Download';
    try {
      final response = await dio.download(
        url,
        savePath,
        queryParameters: transcodes ? null : {'api_key': accessToken},
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) =>
            onProgress?.call(received, total),
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
    await safeRequest<dynamic>(
      () => dio.post(
        '/Sessions/Playing',
        data: {
          "ItemId": songId,
          "PlaySessionId": songId,
          "CanSeek": true,
          "IsPaused": false,
          "IsMuted": false,
          "PositionTicks": 0,
          "PlayMethod": _playMethod,
        },
      ),
    );
    await safeRequest<dynamic>(
      () => dio.post(
        '/Sessions/Playing/Stopped',
        data: {"ItemId": songId, "PlaySessionId": songId},
      ),
    );
    if (_progressSessionSongId == songId) {
      _progressSessionSongId = null;
    }

    safeRequest<dynamic>(() => dio.post('/Users/$userId/PlayedItems/$songId'));
    return true;
  }

  @override
  Future<String?> getAlbumDescription(String albumId) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items/$albumId',
        queryParameters: {'Fields': 'Overview'},
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
      ignoreMessage: true,
    );
    return _text(response?['Overview']);
  }

  @override
  Future<({String? biography, String? imageUrl})?> getArtistInfo(
    String artistId,
  ) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items/$artistId',
        queryParameters: {'Fields': 'Overview,ImageTags'},
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
      ignoreMessage: true,
    );
    if (response == null) {
      return null;
    }
    return (biography: _text(response['Overview']), imageUrl: null);
  }

  @override
  Future<({String? imageUrl, bool hasImage})?> getArtistImageInfo(
    String artistId,
  ) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items/$artistId',
        queryParameters: {'Fields': 'ImageTags'},
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
      ignoreMessage: true,
    );
    if (response == null) {
      return null;
    }
    final tags = response['ImageTags'];
    final primary = tags is Map ? tags['Primary']?.toString() ?? '' : '';
    return (imageUrl: null, hasImage: primary.isNotEmpty);
  }

  @override
  Future<List<({String name, String? id})>> getSimilarArtists(
    String artistId,
  ) async {
    final response = await safeRequest<dynamic>(
      () => dio.get('/Artists/$artistId/Similar', queryParameters: {'Limit': 8}),
    );
    final items = response?['Items'] as List? ?? const [];
    return [
      for (final item in items)
        if ((item['Name']?.toString() ?? '').isNotEmpty)
          (name: item['Name'].toString(), id: item['Id']?.toString()),
    ];
  }

  @override
  Future<void> reportPlaybackProgress(
    String songId,
    Duration position, {
    bool paused = false,
    double speed = 1.0,
  }) async {
    // A new song needs the session started, not just a progress update; without
    // it the server never lists the app as playing (and cannot report a
    // transcode on the status page).
    if (_progressSessionSongId != songId) {
      _progressSessionSongId = songId;
      await safeRequest<dynamic>(
        () => dio.post(
          '/Sessions/Playing',
          data: {
            "ItemId": songId,
            "PlaySessionId": songId,
            "PositionTicks": position.inMicroseconds * 10,
            "IsPaused": paused,
            "IsMuted": false,
            "CanSeek": true,
            "PlayMethod": _playMethod,
            "PlaybackRate": speed,
          },
        ),
      );
    }
    await safeRequest<dynamic>(
      () => dio.post(
        '/Sessions/Playing/Progress',
        data: {
          "ItemId": songId,
          "PlaySessionId": songId,
          "PositionTicks": position.inMicroseconds * 10,
          "IsPaused": paused,
          "IsMuted": false,
          "CanSeek": true,
          "PlayMethod": _playMethod,
          "PlaybackRate": speed,
        },
      ),
    );
  }
}
