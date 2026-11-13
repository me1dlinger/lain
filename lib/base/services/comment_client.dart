import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lain/base/data/comment_server.dart';
import 'package:lain/base/data/song_comment.dart';

/// How a comment list is ordered, as the server's `sort` parameter takes it.
enum CommentSort {
  recommended('recommended'),
  hot('hot'),
  time('time');

  final String value;
  const CommentSort(this.value);
}

/// What a comment source can be asked for.
///
/// The server pages and sorts on its side: `page` starts at 1, `pageSize`
/// tops out at 100 and `replyLimit` decides how many floor replies come
/// attached to each comment (0 is the fastest, the list alone).
class CommentQuery {
  /// The song the server already resolved, when known. Giving it skips the
  /// search, which is both faster and immune to a wrong match.
  final String? songId;

  final String songName;
  final String artistName;

  /// Album name, when known. It is optional: the server accepts it but does
  /// not require it, and passing it greatly improves the name match.
  final String? albumName;

  final CommentSort sort;

  /// Page index, one based.
  final int page;

  /// Comments per page, at most 100.
  final int pageSize;

  /// Floor replies attached to each comment; 0 turns them off.
  final int replyLimit;

  const CommentQuery({
    this.songId,
    required this.songName,
    required this.artistName,
    this.albumName,
    this.sort = CommentSort.recommended,
    this.page = 1,
    this.pageSize = 20,
    this.replyLimit = 3,
  }) : assert(page >= 1),
       assert(pageSize >= 1);
}

/// One page of the answer, with the song it belongs to.
class CommentPageResult {
  final CommentPage page;

  /// The song the server matched the query to, when it says so. A name query
  /// fills it in; an id query usually does not (the caller already knows).
  final CommentSong? song;

  /// The comment total the server reports, 0 when it did not.
  final int total;

  /// How many pages the server says there are, 0 when it did not.
  final int pageCount;

  final String sourceLabel;

  const CommentPageResult({
    required this.page,
    required this.sourceLabel,
    this.song,
    this.total = 0,
    this.pageCount = 0,
  });
}

/// One page of a comment's floor replies.
class CommentReplyResult {
  final List<SongComment> replies;

  /// Whether the floor has more after this page.
  final bool hasMore;

  /// What the next request needs as its `time` parameter.
  final String? nextTime;

  const CommentReplyResult({
    required this.replies,
    required this.hasMore,
    this.nextTime,
  });
}

/// Prints a diagnostic for this file.
///
/// A local function rather than the app logger on purpose: the app's logger
/// reaches the Flutter runtime, which this library must not depend on so the
/// comment path stays checkable with `dart run lib/tool/comment_probe.dart`.
void _log(String message) => stderr.writeln('[comment] $message');

/// Talks to one comment server.
///
/// The endpoints are the ncm-comment-api ones: `GET /api/comments` pages and
/// sorts a song's comments server-side, `GET /api/search` resolves keywords to
/// songs, `GET /api/replies` pages a comment's floor. The root path `/` keeps
/// the classic list answer, but the app asks the paged API so it never pulls
/// more than one page at a time.
class CommentClient {
  final CommentServer server;

  CommentClient(this.server);

  /// The address that answered the last request, so a subsequent one goes
  /// straight to it.
  String? _goodAddress;

  /// Called when an address answers, so the app can write it through to its
  /// settings and the next run asks that address first.
  ///
  /// A hook rather than a direct call: the settings layer holds the write,
  /// but it also pulls in the Flutter UI toolkit, and this client has to stay
  /// runnable under a bare `dart run` (see lib/tool/comment_probe.dart). The
  /// settings page assigns `markCommentServerAlive` to it at startup; the
  /// in-memory [CommentServer.lastGoodUrl] is set either way.
  static void Function(CommentServer server, String baseUrl)? rememberAddress;

  /// Timeout for connecting to one address. A dead address usually hangs
  /// rather than refusing, and every address in front of the working one adds
  /// this to the wait, so it stays short; the request itself gets
  /// [_requestTimeout].
  static const _connectTimeout = Duration(seconds: 3);

  /// Timeout for the whole request against one address. The server relays to
  /// an upstream that can be slow on a cold cache, so this is generous where
  /// the connect timeout is not.
  static const _requestTimeout = Duration(seconds: 15);

  /// A probe only has to prove the address is alive, and an unreachable one
  /// usually fails fast, so it does not wait as long as a real request.
  static const _probeTimeout = Duration(seconds: 3);

  HttpClient _clientFor(String url) {
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    // Only an https address can present a certificate; setting the callback
    // unconditionally would hide that mistake instead of surfacing it.
    if (server.isSecure) {
      final ignoreCert = server.isLan(url)
          ? server.ignoreLanCert
          : server.ignorePublicCert;
      if (ignoreCert) {
        client.badCertificateCallback = (cert, host, port) => true;
      }
    }
    return client;
  }

  /// Probes the configured addresses and keeps the first that answers.
  ///
  /// A probe is a request without the two required parameters, to which the
  /// endpoint answers HTTP 400 `params error`; any answer with a valid status
  /// proves the server is reachable at that address.
  Future<String?> probe() async {
    for (final url in _candidateAddresses()) {
      final ok = await _probeOne(url);
      if (ok) {
        server.lastGoodUrl = url;
        CommentClient.rememberAddress?.call(server, url);
        _goodAddress = url;
        return url;
      }
    }
    return null;
  }

  List<String> _candidateAddresses() {
    final result = <String>[];
    void add(String? url) {
      final value = url?.trim() ?? '';
      if (value.isNotEmpty && !result.contains(value)) {
        result.add(value);
      }
    }

    add(_goodAddress);
    // The one that answered last time, written through to the settings: it is
    // where the app already worked, so asking it first avoids waiting out a
    // dead address on every fresh open of the page.
    add(server.lastGoodUrl);
    add(server.lanUrl);
    add(server.publicUrl);
    return result;
  }

  Future<bool> _probeOne(String url) async {
    final client = _clientFor(url);
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(_probeTimeout);
      final response = await request.close().timeout(_probeTimeout);
      final status = response.statusCode;
      await response.drain<void>();
      // 200 for a working server that had something to answer, 400 for a bare
      // probe: either means the server itself answered. A method or path
      // mismatch is an error and proves nothing about reachability.
      return status == 200 || status == HttpStatus.badRequest;
    } catch (error) {
      _log('probe failed: $url $error');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// The page the source answers for [query].
  ///
  /// Addresses are tried in turn; a server that answers with a refusal (403)
  /// is still an answer, so it ends the search rather than falling through to
  /// an address that cannot be reached anyway. A 404 means the song could not
  /// be resolved, which is also final. When nothing answers, the failure is a
  /// [CommentFetchException] rather than whatever the last error was.
  Future<CommentPageResult> fetch(CommentQuery query) async {
    final params = <String, String>{
      'page': '${query.page}',
      'pageSize': '${query.pageSize}',
      'sort': query.sort.value,
      'reply_limit': '${query.replyLimit}',
    };
    if (query.songId != null && query.songId!.trim().isNotEmpty) {
      params['id'] = query.songId!.trim();
    } else {
      params['song_name'] = query.songName;
      params['singer_name'] = query.artistName;
      final albumName = query.albumName?.trim() ?? '';
      if (albumName.isNotEmpty) {
        params['album_name'] = albumName;
      }
    }
    final body = await _getJson('/api/comments', params);
    final pageBody = body is Map ? body : null;
    if (pageBody == null) {
      throw const CommentFetchException('badResponse');
    }
    final song = _parseSong(pageBody['song']);
    final comments = <SongComment>[];
    final songId = song?.id ?? query.songId ?? '';
    for (final item in (pageBody['comments'] as List? ?? const [])) {
      final comment = _parseComment(item, songId);
      if (comment != null) {
        comments.add(comment);
      }
    }
    return CommentPageResult(
      page: CommentPage(
        comments: comments,
        hasMore: pageBody['hasMore'] as bool? ?? false,
      ),
      song: song,
      total: (pageBody['total'] as num?)?.toInt() ?? 0,
      pageCount: (pageBody['pageCount'] as num?)?.toInt() ?? 0,
      sourceLabel: server.name,
    );
  }

  /// Songs matching [keywords], so the user can pick the song the comments
  /// should really be about.
  Future<List<CommentSong>> searchSongs(String keywords, {int limit = 20}) async {
    final words = keywords.trim();
    if (words.isEmpty) {
      return const [];
    }
    final body = await _getJson('/api/search', {
      'keywords': words,
      'type': '1',
      'limit': '$limit',
    });
    final songs = body is Map ? body['songs'] as List? : null;
    if (songs == null) {
      return const [];
    }
    final result = <CommentSong>[];
    for (final item in songs) {
      final song = _parseSong(item);
      if (song != null) {
        result.add(song);
      }
    }
    return result;
  }

  /// One page of the replies under one comment.
  ///
  /// [time] is the previous page's [CommentReplyResult.nextTime]; the first
  /// page does without it.
  Future<CommentReplyResult> fetchReplies(
    String songId,
    String commentId, {
    int limit = 20,
    String? time,
  }) async {
    final params = <String, String>{
      'id': songId,
      'comment_id': commentId,
      'limit': '$limit',
    };
    final timeValue = time?.trim() ?? '';
    if (timeValue.isNotEmpty) {
      params['time'] = timeValue;
    }
    final body = await _getJson('/api/replies', params);
    final floor = body is Map ? body : null;
    if (floor == null) {
      throw const CommentFetchException('badResponse');
    }
    final replies = <SongComment>[];
    for (final item in (floor['replies'] as List? ?? const [])) {
      final reply = _parseComment(item, songId);
      if (reply != null) {
        replies.add(reply);
      }
    }
    return CommentReplyResult(
      replies: replies,
      hasMore: floor['hasMore'] as bool? ?? false,
      nextTime: floor['nextTime'] == null ? null : '${floor['nextTime']}',
    );
  }

  /// One GET against whichever address answers first, returning the parsed
  /// `body` of the envelope.
  ///
  /// Throws [CommentFetchException] for the final failures: `forbidden` for a
  /// refusal, `notFound` when the server says there is no such song. An
  /// address that answers with anything else unusable counts as reached, and
  /// the next address is tried; nothing answering at all is `unreachable`.
  Future<Object?> _getJson(String path, Map<String, String> params) async {
    var answered = false;
    final failures = <String>[];
    for (final base in _candidateAddresses()) {
      final outcome = await _getFrom(base, path, params, failures);
      if (outcome.body != null) {
        server.lastGoodUrl = base;
        // Written through so the address survives a restart: without it the
        // app probes both addresses on every launch, and the one that was
        // down comes back first.
        CommentClient.rememberAddress?.call(server, base);
        _goodAddress = base;
        return outcome.body;
      }
      answered = answered || outcome.reached;
    }
    if (answered) {
      throw const CommentFetchException('badResponse');
    }
    throw CommentFetchException(
      'unreachable',
      failures.isEmpty ? null : failures.join('; '),
    );
  }

  /// The body from one address. A null body means that address had nothing
  /// usable (the caller then tries the next one), and the reason is appended
  /// to [failures].
  ///
  /// Throws [CommentFetchException] for a refusal or a missing song, which
  /// are final.
  Future<_Outcome> _getFrom(
    String base,
    String path,
    Map<String, String> params,
    List<String> failures,
  ) async {
    final target = Uri.parse(base);
    final withToken = Map<String, String>.of(params);
    // The server derives its token from its own configured URL, which is the
    // address used here; a token for another address would be rejected.
    if (server.needsToken) {
      withToken['token'] = server.tokenFor(base);
    }
    final uri = target.replace(
      path: target.path == '/' || target.path.isEmpty ? path : '${target.path}$path',
      queryParameters: withToken,
    );

    final client = _clientFor(base);
    try {
      final request = await client.getUrl(uri).timeout(_requestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_requestTimeout);
      final status = response.statusCode;
      if (status != 200) {
        await response.drain<void>();
        if (status == HttpStatus.unauthorized ||
            status == HttpStatus.forbidden) {
          throw const CommentFetchException('forbidden');
        }
        if (status == HttpStatus.notFound) {
          throw const CommentFetchException('notFound');
        }
        _log('unexpected status $status from $base');
        failures.add('$base HTTP $status');
        return const _Outcome(null, reached: true);
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_requestTimeout);
      return _Outcome(_envelopeBody(body), reached: true);
    } on CommentFetchException {
      rethrow;
    } catch (error) {
      _log('fetch failed: $base $error');
      failures.add('$base $error');
      return const _Outcome(null, reached: false);
    } finally {
      client.close(force: true);
    }
  }

  /// The `body` of one answer, or null when the answer is not a success
  /// envelope.
  Object? _envelopeBody(String body) {
    final Object? raw;
    try {
      raw = jsonDecode(body);
    } on FormatException catch (error) {
      _log('not json: $error');
      return null;
    }
    if (raw is! Map) {
      return null;
    }
    final code = (raw['code'] as num?)?.toInt();
    if (code != null && code != 200) {
      _log('server said $code: ${raw['msg'] ?? ''}');
      return null;
    }
    return raw['body'];
  }

  /// The song of a `song` / search item.
  CommentSong? _parseSong(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final id = '${raw['songId'] ?? raw['id'] ?? ''}';
    final name = '${raw['name'] ?? ''}';
    if (id.isEmpty || name.isEmpty) {
      return null;
    }
    return CommentSong(
      id: id,
      name: name,
      artist: '${raw['artist'] ?? ''}',
      album: '${raw['album'] ?? ''}',
      coverUrl: '${raw['coverUrl'] ?? ''}',
      duration: (raw['duration'] as num?)?.toInt() ?? 0,
    );
  }

  /// One comment of any level, with its attached floor replies.
  ///
  /// The measured shape: `{"id","commentId","nick","avatarurl","content",
  /// "praiseNum","createTime","type"}` plus the extended
  /// `ipLocation`,`isHot`,`replyCount`,`replies`,`repliesHasMore`.
  SongComment? _parseComment(Object? raw, String fallbackSongId) {
    if (raw is! Map) {
      return null;
    }
    final commentId = '${raw['commentId'] ?? ''}';
    if (commentId.isEmpty) {
      return null;
    }
    final replies = <SongComment>[];
    for (final item in (raw['replies'] as List? ?? const [])) {
      final reply = _parseComment(item, fallbackSongId);
      if (reply != null) {
        replies.add(reply);
      }
    }
    final type = (raw['type'] as num?)?.toInt();
    return SongComment(
      songId: '${raw['id'] ?? fallbackSongId}',
      commentId: commentId,
      nick: '${raw['nick'] ?? ''}',
      // The field really is all lower case in the server's answer.
      avatarUrl: '${raw['avatarurl'] ?? raw['avatarUrl'] ?? ''}',
      content: '${raw['content'] ?? ''}',
      praiseNum: (raw['praiseNum'] as num?)?.toInt() ?? 0,
      createTime: (raw['createTime'] as num?)?.toInt() ?? 0,
      replies: replies,
      replyCount: (raw['replyCount'] as num?)?.toInt() ?? replies.length,
      repliesHasMore: raw['repliesHasMore'] as bool? ?? false,
      ipLocation: '${raw['ipLocation'] ?? ''}',
      // NetEase marks the featured comments 0 and 1; 2 is an ordinary one.
      isHot: (raw['isHot'] as bool? ?? false) || type == 0 || type == 1,
    );
  }
}

/// What one address produced: the envelope body, when there is one, and
/// whether the address answered at all.
class _Outcome {
  final Object? body;
  final bool reached;

  const _Outcome(this.body, {required this.reached});
}

/// A failure with a reason the UI can turn into a sentence.
class CommentFetchException implements Exception {
  /// One of `unreachable`, `forbidden`, `notFound`, `badResponse`.
  final String reason;

  /// What went wrong underneath, for the log; not shown to the user.
  final String? detail;

  const CommentFetchException(this.reason, [this.detail]);

  @override
  String toString() =>
      detail == null
      ? 'CommentFetchException($reason)'
      : 'CommentFetchException($reason: $detail)';
}
