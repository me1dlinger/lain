import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lain/base/data/comment_server.dart';
import 'package:lain/base/data/song_comment.dart';

/// What a comment source can be asked for.
///
/// The reference server returns every comment it has in a single answer, so a
/// page here is a slice of that one answer rather than a page the server
/// produced.
class CommentQuery {
  final String songName;
  final String artistName;

  /// Album name, when known. It is optional: the reference server accepts it
  /// but does not require it, and may not have it filled in at all.
  final String? albumName;

  /// NetEase song id, when the source knows it; a source that only understands
  /// names ignores it.
  final String? songId;

  /// Page index, zero based.
  final int page;

  /// Comments per page.
  final int pageSize;

  const CommentQuery({
    required this.songName,
    required this.artistName,
    this.albumName,
    this.songId,
    this.page = 0,
    this.pageSize = 15,
  }) : assert(page >= 0),
       assert(pageSize > 0);

  CommentQuery atPage(int page) => CommentQuery(
    songName: songName,
    artistName: artistName,
    albumName: albumName,
    songId: songId,
    page: page,
    pageSize: pageSize,
  );
}

/// Tags a page with the source that produced it, so the UI can say where the
/// comments came from.
class CommentPageResult {
  final CommentPage page;
  final String sourceLabel;

  const CommentPageResult({required this.page, required this.sourceLabel});
}

/// Prints a diagnostic for this file.
///
/// A local function rather than the app logger on purpose: the app's logger
/// reaches the Flutter runtime, which this library must not depend on so the
/// comment path stays checkable with `dart run lib/tool/comment_probe.dart`.
void _log(String message) => stderr.writeln('[comment] $message');

/// Talks to one comment server.
///
/// The endpoint is the review_api one: a GET to the server's root with
/// `song_name`, `singer_name`, an optional `album_name` and a `token` when the
/// server is password protected. It answers `{code, msg, body:[...]}` where
/// `body` holds the comments; the server has no paging of its own, so a page is
/// a slice of that answer and a page past its end is empty.
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

  /// Timeout for one address. Short enough that falling back to the other
  /// address is not a waiting game.
  static const _timeout = Duration(seconds: 8);

  /// A probe only has to prove the address is alive, and an unreachable one
  /// usually fails fast, so it does not wait as long as a real request.
  static const _probeTimeout = Duration(seconds: 3);

  HttpClient _clientFor(String url) {
    final client = HttpClient()..connectionTimeout = _timeout;
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
  /// Addresses are tried in turn; a server that answers with a refusal (403) is
  /// still an answer, so it ends the search rather than falling through to an
  /// address that cannot be reached anyway. When nothing answers, the failure
  /// is a [CommentFetchException] rather than whatever the last error was.
  Future<CommentPageResult> fetch(CommentQuery query) async {
    // Someone answered and had nothing usable for this request: that is a bad
    // answer, not a dead address. Nothing answering at all is unreachable.
    var answered = false;
    final failures = <String>[];
    for (final base in _candidateAddresses()) {
      final outcome = await _fetchFrom(base, query, failures);
      if (outcome.page != null) {
        server.lastGoodUrl = base;
        // Written through so the address survives a restart: without it the
        // app probes both addresses on every launch, and the one that was
        // down comes back first.
        CommentClient.rememberAddress?.call(server, base);
        _goodAddress = base;
        return CommentPageResult(page: outcome.page!, sourceLabel: server.name);
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

  /// The page from one address. A null page means that address had nothing
  /// useful (the caller then tries the next one), and the reason is appended to
  /// [failures].
  ///
  /// Throws [CommentFetchException] for a refusal, which is final.
  Future<_Outcome> _fetchFrom(
    String base,
    CommentQuery query,
    List<String> failures,
  ) async {
    final uri = Uri.parse(base);
    final params = <String, String>{
      'song_name': query.songName,
      'singer_name': query.artistName,
    };
    final albumName = query.albumName?.trim() ?? '';
    if (albumName.isNotEmpty) {
      params['album_name'] = albumName;
    }
    // The server derives its token from its own configured URL, which is the
    // address used here; a token for another address would be rejected.
    if (server.needsToken) {
      params['token'] = server.tokenFor(base);
    }
    final target = uri.replace(queryParameters: params);

    final client = _clientFor(base);
    try {
      final request = await client.getUrl(target).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_timeout);
      final status = response.statusCode;
      if (status != 200) {
        await response.drain<void>();
        if (status == HttpStatus.unauthorized ||
            status == HttpStatus.forbidden) {
          throw const CommentFetchException('forbidden');
        }
        _log('unexpected status $status from $base');
        failures.add('$base HTTP $status');
        return const _Outcome(null, reached: true);
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      return _Outcome(_parse(body, query), reached: true);
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

  /// Parses one answer.
  ///
  /// The real shape, measured against the reference server:
  /// `{"code":200,"msg":"success","body":[{"nick":"…","avatarurl":"…",
  /// "content":"…","praiseNum":823201,"createTime":1413530574,
  /// "commentId":"4956438","type":2}, …]}`
  /// - `body` is the list itself, not an object wrapping one, and there is no
  ///   `total` and no second level reply field.
  /// - `commentId` is a string, `praiseNum` and `createTime` are numbers, and
  ///   `avatarurl` is all lower case.
  /// - `type` 0/1 are the featured ("hot") comments, 2 is an ordinary one.
  /// - A failure carries `code` and a plain text `msg` instead of `body`.
  ///
  /// Two shapes are accepted, because only the first was measured:
  /// - the flat one above, where `body` is the list;
  /// - the same inside a `data` object, as `{"code":200,"data":{"list":[…]}}`,
  ///   which is what the NetEase endpoints the server proxies tend to answer.
  ///   The list wrapper is only used when `body` itself is not a list.
  ///
  /// The endpoint has no paging, so the answer is sliced here; the order the
  /// server sent is kept, because it is already by likes and re-sorting would
  /// only hide a change on the server side.
  CommentPage _parse(String body, CommentQuery query) {
    final Object? raw;
    try {
      raw = jsonDecode(body);
    } on FormatException catch (error) {
      _log('not json: $error');
      return CommentPage.empty;
    }
    if (raw is! Map) {
      return CommentPage.empty;
    }
    final code = (raw['code'] as num?)?.toInt();
    if (code != null && code != 200) {
      _log('server said $code: ${raw['msg'] ?? ''}');
      return CommentPage.empty;
    }
    final list = _commentList(raw);
    if (list == null) {
      return CommentPage.empty;
    }

    final all = <SongComment>[];
    for (final item in list) {
      if (item is! Map) {
        continue;
      }
      final rawType = item['type'];
      final type = rawType is num ? rawType.toInt() : null;
      all.add(
        SongComment(
          songId: query.songId ?? '',
          commentId: '${item['commentId'] ?? ''}',
          nick: '${item['nick'] ?? ''}',
          // The field really is all lower case in the server's answer.
          avatarUrl: '${item['avatarurl'] ?? item['avatarUrl'] ?? ''}',
          content: '${item['content'] ?? ''}',
          praiseNum: (item['praiseNum'] as num?)?.toInt() ?? 0,
          createTime: (item['createTime'] as num?)?.toInt() ?? 0,
          // NetEase marks the featured comments 0 and 1; 2 is an ordinary one.
          isHot: type == 0 || type == 1,
        ),
      );
    }

    final page = query.page;
    final pageSize = query.pageSize;
    final start = page * pageSize;
    if (start >= all.length) {
      return CommentPage.empty;
    }
    final end = start + pageSize;
    return CommentPage(
      comments: all.sublist(start, end > all.length ? all.length : end),
      hasMore: end < all.length,
    );
  }

  /// The comment list of an answer: `body` when it is a list, else the list
  /// inside `data` (either `data.list` or `data` itself).
  static List? _commentList(Map raw) {
    final body = raw['body'];
    if (body is List) {
      return body;
    }
    final data = raw['data'];
    if (data is List) {
      return data;
    }
    if (data is Map) {
      for (final key in const ['list', 'comments', 'body']) {
        final value = data[key];
        if (value is List) {
          return value;
        }
      }
    }
    return null;
  }
}

/// What one address produced: a page, when there is one, and whether the
/// address answered at all.
class _Outcome {
  final CommentPage? page;
  final bool reached;

  const _Outcome(this.page, {required this.reached});
}

/// A failure with a reason the UI can turn into a sentence.
class CommentFetchException implements Exception {
  /// One of `unreachable`, `forbidden`, `badResponse`.
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
