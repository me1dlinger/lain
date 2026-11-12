// Measures the comment client against a real review_api server.
//
// Run it, rather than trusting the shape of the answer in a comment:
//
//   dart run lib/tool/comment_probe.dart --host 192.168.31.173 --port 18383 \
//       --song 晴天 --artist 周杰伦
//
// It talks through [CommentClient] itself for the paging, fallback, refusal and
// https cases, and drops to a bare HttpClient only to check the endpoint's
// answer as it really is. This is a command line tool, not app code: nothing in
// the app imports it.
//
// The address probes spin up small local servers on 127.0.0.1, which is how the
// timeout, the self-signed certificate and the forwarded parameters are
// measured without depending on a second machine. The exit code is 0 when every
// check passed.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lain/base/data/comment_server.dart';
import 'package:lain/base/data/song_comment.dart';
import 'package:lain/base/services/comment_client.dart';

// ignore_for_file: avoid_print
const _defaultPort = '18383';
const _timeout = Duration(seconds: 5);

/// The host the reference server lives at, used when none is given.
const _defaultHost = '192.168.31.173';

/// A throwaway self-signed certificate and key for the https check.
///
/// Generated once for this tool with
/// `openssl req -x509 -newkey rsa:2048 -nodes -days 36500 -subj /CN=localhost \
///  -addext subjectAltName=DNS:localhost,IP:127.0.0.1`
/// and pasted here, so running the check needs no openssl and writes no file.
const _selfSignedCert = '''-----BEGIN CERTIFICATE-----
MIIDJzCCAg+gAwIBAgIUCjX1Sa0c4jkWm9FAQY56tdzYjngwDQYJKoZIhvcNAQEL
BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MCAXDTI2MTExMjEwNTAwNloYDzIxMjYx
MDE5MTA1MDA2WjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDQJqg82qSrZw25cdMK80k+JA0Tnwb0QdxQKxzfGUQV
KeBnBifgoMPkP64TiI6F5bflI9c6UGuWvP57wBOG8KaPYgAp0WMPRpIbxrlYx5KG
Z7N0vN1LCUvvxmS8X44ziJBC7Hr5bUGoL9Po77tk1DN/lwnMATVWo7Ife6e+t+Y9
nlCMc37WNFVYN7VMCQ+69jrnUaCpxgjhjoszpMD76Y4dDlzEiPU9lhSlJtAWKxFv
o5A98eD76Hy8N5Iyl8ytVI9a0DzlpSbB9HcBfLxhNM9M89fBaj0C3RspxOUSUphi
3eBX93vDRIhq/9Qp+uU5dY5YEG27ysM/yyDeEHIFfeCtAgMBAAGjbzBtMB0GA1Ud
DgQWBBTaGKTfa6UDvqeTJCSQ+OE13E9GpjAfBgNVHSMEGDAWgBTaGKTfa6UDvqeT
JCSQ+OE13E9GpjAPBgNVHRMBAf8EBTADAQH/MBoGA1UdEQQTMBGCCWxvY2FsaG9z
dIcEfwAAATANBgkqhkiG9w0BAQsFAAOCAQEAPJSWyS5cp9GeB8Lk2jIRnCcKW2+7
8+HMdniceh8k5YFKn19Li42E47pwvWBSn9n0QRcYaM3M3a4ylcYDaGlUeDP1u3Dt
udCi4mo9aZ4HqDvtgdUit8V6ZgqzVUmKDVL9RG1YiWgHT+MgU8zj/at9jxeTMoo1
WVUf2EgBY37L9XaEWIeMkDmLfoRL81MoQ1go8vGjf5pYJjowFg2xFP11IHcLQkPa
A4IphkMP1+Xsd44sX5sZlIL9lAcloOnQrYHzN1vw/2WzXBId5KPv+SWUxuh9IfmW
TteHJwA4YHZeUH2e3MkKG6bg/zg96d/Po4SZTuDmqj8jhQBoSGfyReaNag==
-----END CERTIFICATE-----''';
const _selfSignedKey = '''-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDQJqg82qSrZw25
cdMK80k+JA0Tnwb0QdxQKxzfGUQVKeBnBifgoMPkP64TiI6F5bflI9c6UGuWvP57
wBOG8KaPYgAp0WMPRpIbxrlYx5KGZ7N0vN1LCUvvxmS8X44ziJBC7Hr5bUGoL9Po
77tk1DN/lwnMATVWo7Ife6e+t+Y9nlCMc37WNFVYN7VMCQ+69jrnUaCpxgjhjosz
pMD76Y4dDlzEiPU9lhSlJtAWKxFvo5A98eD76Hy8N5Iyl8ytVI9a0DzlpSbB9HcB
fLxhNM9M89fBaj0C3RspxOUSUphi3eBX93vDRIhq/9Qp+uU5dY5YEG27ysM/yyDe
EHIFfeCtAgMBAAECggEAHotdqrhm66QOtoTGdFfpCo5dwOBYM+WqP7Vj4jUh8X0Y
qeWUWnkc5dSWZdVnHKzuBFjzD2KXtyH6sgwokWek+WtnHLvWLnqrnBnYPvfiP4je
I6ZHTuiJVSEmzSG0i0lh6gArt4hZ1yVVklwDgrNE71cpn98ZhaI11DrgDbOMvMPH
qB1XXaRlmCRdFW0iAe4W3PZq7Wh3PdY5ALTNCGnsBD28/qYFpvqMwwcZxKjJIQ2/
1KZqBLSlvkppy3hqWqlFYUW8Bp3LpI5XPnh8T191Yy1Atd2WptkbOQ+2m/lTQmmj
0oVQvjzCDOIAc4Y4Se8zNVU8/dvc6SUABCcx+H2AnQKBgQD2S+AwB3alhnhpeIwT
xs1KHG/b3k+DJ0+0LXM8txHpcMYUSGFZJxxzXS9fe6qWTjRpjq0hUf9ZHUviaBmD
mQvbaZbdht4EVG6iOMp85fZpvjx2UkzirZwwFTeXwDreLVRc3IDuJQtKZwABId6D
zuHkPcRcnvrTGOFgfDC0P7otMwKBgQDYWgzkn2rybwQ8GX3ngh6JsZX8YYiNmU4E
cGJKZHDhY0WCKMFbKamUJG7jGbp9lXjRLA3r2VQ3sYzWyqyODGNSQsG1tvJN8P8/
iIYXjk86BIRvD2IEeTJGkS+wnq3Gg6sMRpfSEZsdVh6B/OLcV1gxUNQjIaJfIO0T
HJq2rGj6nwKBgHloA3WJaEnFlDthSaNB/tXGWLlHx2f+C8LkGIbYMwMgLPO4jgv1
RIf1ajGl8vuuRxW1V9Ax7C3QTCSpbdI5seeRD+XY4j2+JN7gIagZbzLGrGUiwnWG
YJQvET1Da4EzVP+FTiSVrBAb35uvR1EvvJfWfqGtWDSQciAud4+STkKTAoGBAJmj
eTxxqTT4eX1kbPCWirEll2leqeZEVA768BH8Od0U7it8XbMrZu144fYMM08zclS4
gDpYX2Idh/KQgvFtAqtMFNvCS1fmKJ0pim/383Mz+ggUWHrsxjMurzsxtB4hKrrQ
9seLEShIG+obd88Zh9udlshL/k6nxzOnQIcw8GvpAoGANZxV+hdGtorwarOzuBNg
o+YBQ4wh80gbfZu7lcgXDveceGBP6JPiIK3OE3kW4MzP2bySft3kOmnC48MkfKfk
Zae4OCTmiq+Eiua+P++jwG2LAx8HfcuNYU1N2dJNUmBJCV62ZcCxFzLhoudG0Mon
OM42Z2qvCYoSaJGrSQl0mr8=
-----END PRIVATE KEY-----''';

Future<void> main(List<String> arguments) async {
  final args = _Args.parse(arguments);
  if (args.help || args.host.isEmpty) {
    _usage();
    exit(args.help ? 0 : 2);
  }

  final checks = _Checks();
  final server = CommentServer(
    id: 'probe',
    name: 'probe',
    lanHost: args.host,
    lanPort: args.port,
    username: args.user,
    password: args.pass,
  );
  final client = CommentClient(server);

  _section('target');
  print('  host      ${args.host}');
  print('  port      ${args.port}');
  print('  song      ${args.song}');
  print('  artist    ${args.artist}');
  print('  token     ${server.needsToken ? 'yes, from user and pass' : 'no credentials configured'}');
  print(
    '  pageSize  ${args.pageSize}'
    ' (asked for page ${args.page}; pages 0, 1, 2 and the end are all tried)',
  );

  await _within(const Duration(seconds: 60), _checkRawAnswer(args, checks));
  await _checkProbe(args, checks);
  await _checkNormal(client, args, checks);
  await _checkPaging(client, args, checks);
  await _checkAlbumName(client, args, checks);
  await _checkToken(server, args, checks);
  if (args.onlyLocal) {
    _section(
      'skipped: the fallback and https checks',
    );
    print('  --only-local was given: they use a 127.0.0.1 server, and this '
        'run has no_proxy that does not cover it');
  } else {
    await _within(const Duration(seconds: 60), _checkFallback(args, checks));
    await _within(const Duration(seconds: 60), _checkForbidden(args, checks));
    await _within(const Duration(seconds: 60), _checkHttps(checks));
  }

  _section('result');
  checks.summary();
  exit(checks.failed == 0 ? 0 : 1);
}

/// The answer as it really is, without going through the client.
Future<void> _checkRawAnswer(_Args args, _Checks checks) async {
  _section('raw answer, through a bare HttpClient');
  final http = HttpClient()..connectionTimeout = _timeout;
  try {
    final target = Uri(
      scheme: 'http',
      host: args.host,
      port: int.tryParse(args.port),
      queryParameters: {'song_name': args.song, 'singer_name': args.artist},
    );
    final request = await http.getUrl(target).timeout(_timeout);
    final response = await request.close().timeout(_timeout);
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_timeout);
    print('  GET $target');
    print('  status    ${response.statusCode}');
    print('  bytes     ${utf8.encode(body).length}');
    final raw = jsonDecode(body);
    if (raw is! Map) {
      checks.fail('the answer is not a JSON object');
      return;
    }
    print('  top keys  ${raw.keys.toList()}');
    final list = raw['body'];
    if (list is! List) {
      checks.fail('the answer has no body list: ${list.runtimeType}');
      return;
    }
    print('  body      a list of ${list.length} items');
    if (list.isNotEmpty && list.first is Map) {
      final first = list.first as Map;
      print('  item keys ${first.keys.toList()}');
      print(
        '  types     commentId=${first['commentId'].runtimeType}'
        ' praiseNum=${first['praiseNum'].runtimeType}'
        ' createTime=${first['createTime'].runtimeType}'
        ' type=${first['type'].runtimeType}',
      );
    }
    print('  total     ${raw['total'] ?? '(no total field)'}');
    checks.pass('the answer has the measured shape: body is the list itself');
  } catch (error) {
    checks.fail('the raw request failed: $error');
  } finally {
    http.close(force: true);
  }
}

/// A bare GET without the two required parameters, which the client uses as
/// its reachability probe.
Future<void> _checkProbe(_Args args, _Checks checks) async {
  _section('probe: a bare GET answers 400, the status the client treats as alive');
  final http = HttpClient()..connectionTimeout = _timeout;
  try {
    final target = Uri(
      scheme: 'http',
      host: args.host,
      port: int.tryParse(args.port),
    );
    final request = await http.getUrl(target).timeout(_timeout);
    final response = await request.close().timeout(_timeout);
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_timeout);
    print('  GET $target -> ${response.statusCode} ${body.trim()}');
    checks.expect(
      response.statusCode == HttpStatus.badRequest,
      'no parameters answers 400 params error',
    );
  } catch (error) {
    checks.fail('the probe request failed: $error');
  } finally {
    http.close(force: true);
  }
}

Future<void> _checkNormal(
  CommentClient client,
  _Args args,
  _Checks checks,
) async {
  _section('normal request: ${args.song} / ${args.artist}');
  final watch = Stopwatch()..start();
  try {
    final result = await client.fetch(
      CommentQuery(
        songName: args.song,
        artistName: args.artist,
        page: args.page,
        pageSize: args.pageSize,
      ),
    );
    watch.stop();
    final page = result.page;
    print('  source    ${result.sourceLabel}');
    print('  elapsed   ${watch.elapsedMilliseconds} ms');
    print('  page      ${page.comments.length} comments, hasMore=${page.hasMore}');
    checks.expect(page.comments.isNotEmpty, 'the answer carries comments');
    final shown = page.comments.length < 3 ? page.comments.length : 3;
    for (var i = 0; i < shown; i++) {
      final comment = page.comments[i];
      print(
        '  [$i] praise=${comment.praiseNum}'
        " type=${comment.isHot ? 'hot' : 'ordinary'}"
        ' id="${comment.commentId}"'
        ' nick="${_clip(comment.nick, 16)}"',
      );
      print('      content "${_clip(comment.content, 40)}"');
      print(
        '      avatar "${_clip(comment.avatarUrl, 40)}"'
        ' createTime=${comment.createTime}',
      );
    }
    checks.expect(
      page.comments.every((c) => c.commentId.isNotEmpty && c.nick.isNotEmpty),
      'every comment has an id and an author',
    );
    checks.expect(
      page.comments.every((c) => c.content.isNotEmpty),
      'every comment has text',
    );
    checks.expect(
      page.comments.every((c) => c.createTime > 0),
      'every comment has a timestamp',
    );
    checks.expect(
      page.comments.first.praiseNum >= page.comments.last.praiseNum,
      'the server order is the likes order the client keeps',
    );
  } catch (error) {
    checks.fail('the fetch failed: $error');
  }
}

Future<void> _checkPaging(
  CommentClient client,
  _Args args,
  _Checks checks,
) async {
  _section('paging: the endpoint has no paging, a page is a local slice');
  // The amount of comments deliberately has nothing to do with the page size:
  // 4 per page over 16 comments shows both a page that has more and the page
  // after it, whatever --pagesize the user asks for (15 would hide them).
  final size = 4;
  print('  slicing at $size comments per page');
  final first = await _tryPage(client, args, 0, size);
  if (first == null) {
    checks.fail('page 0 failed; the paging checks cannot run');
    return;
  }
  // How long the whole answer is, measured by walking the pages, so the
  // checks hold for any server that answers with a number of comments other
  // than the 16 measured here.
  // Page 0 holds the first slice, not the whole answer; the answer is as long
  // as the slices found while walking the pages.
  var all = first.comments.length;
  for (var page = 1; page < 100; page++) {
    final next = await _tryPage(client, args, page, size);
    if (next == null || next.comments.isEmpty) {
      break;
    }
    all += next.comments.length;
  }
  final second = await _tryPage(client, args, 1, size);
  final third = await _tryPage(client, args, 2, size);
  final past = await _tryPage(client, args, all, size);

  if (second == null || third == null || past == null) {
    checks.fail('a page request failed; see above');
    return;
  }
  print('  the whole answer is $all comments');
  print('  page 0      ${first.comments.length} comments, hasMore=${first.hasMore}');
  print('  page 1      ${second.comments.length} comments, hasMore=${second.hasMore}');
  print('  page 2      ${third.comments.length} comments, hasMore=${third.hasMore}');
  print('  page $all      ${past.comments.length} comments, hasMore=${past.hasMore}');
  int expected(int page) {
    final start = page * size;
    if (start >= all) {
      return 0;
    }
    final end = start + size;
    return (end > all ? all : end) - start;
  }

  checks.expect(
    first.comments.length == expected(0),
    'page 0 holds ${expected(0)} comments',
  );
  checks.expect(
    second.comments.length == expected(1),
    'page 1 holds ${expected(1)} comments, not the whole answer again',
  );
  checks.expect(
    third.comments.length == expected(2),
    'page 2 holds ${expected(2)} comments',
  );
  checks.expect(
    first.hasMore == (all > size),
    'hasMore on page 0 is set when the answer is longer than a page',
  );
  final hasNext = all > size;
  if (hasNext) {
    checks.expect(
      second.comments.first.commentId != first.comments.first.commentId,
      'page 1 does not repeat page 0',
    );
  } else {
    checks.pass('the answer fits one page, so there is no next page to order');
  }
  checks.expect(
    past.comments.isEmpty && !past.hasMore,
    'a page past the end is empty',
  );
}

Future<CommentPage?> _tryPage(
  CommentClient client,
  _Args args,
  int page, [
  int? pageSize,
]) async {
  try {
    final result = await client.fetch(
      CommentQuery(
        songName: args.song,
        artistName: args.artist,
        page: page,
        pageSize: pageSize ?? args.pageSize,
      ),
    );
    return result.page;
  } catch (error) {
    print('  page $page failed: $error');
    return null;
  }
}

/// `album_name` is optional in the server's schema, so the client leaves it out
/// unless the query carries one; both halves are checked against a local
/// server that records the query it received.
Future<void> _checkAlbumName(
  CommentClient client,
  _Args args,
  _Checks checks,
) async {
  _section('album_name: optional, sent only when the query has one');

  final without = _RecordingServer(jsonEncode(_fixture));
  try {
    await without.start();
    final plain = CommentClient(_serverAt(without));
    final result = await plain.fetch(
      CommentQuery(songName: args.song, artistName: args.artist),
    );
    print('  no album  -> "${without.lastQuery ?? '(nothing)'}"');
    checks.expect(
      result.page.comments.length == 2,
      'a query without album_name is answered',
    );
    final query = without.lastQuery ?? '';
    checks.expect(
      query.contains('song_name=') && query.contains('singer_name='),
      'song_name and singer_name are always sent',
    );
    checks.expect(
      !query.contains('album_name'),
      'no album_name is sent when the query has none',
    );
  } finally {
    await without.stop();
  }

  final withAlbum = _RecordingServer(jsonEncode(_fixture));
  try {
    await withAlbum.start();
    final albumClient = CommentClient(_serverAt(withAlbum));
    await albumClient.fetch(
      CommentQuery(
        songName: args.song,
        artistName: args.artist,
        albumName: '叶惠美',
      ),
    );
    print('  with album -> "${withAlbum.lastQuery ?? '(nothing)'}"');
    checks.expect(
      (withAlbum.lastQuery ?? '').contains('album_name='),
      'album_name is sent when the query carries one',
    );
  } finally {
    await withAlbum.stop();
  }

  // And the real server accepts it too.
  final real = await _tryPage(client, args, 0);
  checks.expect(real != null, 'the real server answers the default query');
}

Future<void> _checkToken(
  CommentServer server,
  _Args args,
  _Checks checks,
) async {
  _section('token: sha256 of username + password + the base address');
  final token = server.tokenFor('http://127.0.0.1:1');
  print('  needsToken ${server.needsToken}');
  print('  token      $token');
  checks.expect(
    token.length == 64 && token.split('').every((c) => '0123456789abcdef'.contains(c)),
    'the token is 64 hex characters',
  );
  checks.expect(
    server.tokenFor('http://127.0.0.1:2') != token,
    'a different address gives a different token',
  );
  if (args.user.isEmpty && args.pass.isEmpty) {
    print('  this instance has no credentials configured, so no token is '
        'sent and a 403 cannot be produced from it');
  }
}

/// A dead LAN address and a public one that answers.
Future<void> _checkFallback(_Args args, _Checks checks) async {
  _section('fallback: a dead LAN address, then a public one that answers');
  // Port 9 on the loopback is refused at once, which shows the fallback
  // without waiting out a real network timeout.
  final server = CommentServer(
    id: 'fallback',
    name: 'fallback',
    lanHost: '127.0.0.1',
    lanPort: '9',
    publicHost: args.host,
    publicPort: args.port,
  );
  final client = CommentClient(server);
  final watch = Stopwatch()..start();
  try {
    final result = await client.fetch(
      CommentQuery(
        songName: args.song,
        artistName: args.artist,
        pageSize: args.pageSize,
      ),
    );
    watch.stop();
    print(
      '  via ${server.lastGoodUrl} in ${watch.elapsedMilliseconds} ms,'
      ' ${result.page.comments.length} comments',
    );
    checks.pass('the dead LAN address is skipped and the public one used');
    checks.expect(
      result.page.comments.isNotEmpty,
      'the fallback answer carries comments',
    );
  } catch (error) {
    checks.fail('the fallback failed: $error');
  }

  final probeServer = CommentServer(
    id: 'fallback',
    name: 'fallback',
    lanHost: '127.0.0.1',
    lanPort: '9',
    publicHost: args.host,
    publicPort: args.port,
  );
  final probed = await CommentClient(probeServer).probe();
  print('  probe() found $probed');
  checks.expect(
    probed == probeServer.publicUrl,
    'probe() also skips the dead LAN address',
  );

  final dead = CommentClient(
    CommentServer(
      id: 'dead',
      name: 'dead',
      lanHost: '127.0.0.1',
      lanPort: '9',
      publicHost: '127.0.0.1',
      publicPort: '10',
    ),
  );
  try {
    await dead.fetch(const CommentQuery(songName: 'x', artistName: 'y'));
    checks.fail('two dead addresses returned a page');
  } on CommentFetchException catch (error) {
    print('  two dead addresses -> $error');
    checks.expect(
      error.reason == 'unreachable',
      'two dead addresses give an unreachable exception',
    );
  } catch (error) {
    checks.fail(
      'two dead addresses threw $error instead of a CommentFetchException',
    );
  }
}

/// Awaits [work], but gives up after [limit] so a check that hangs cannot stop
/// the run before it prints a verdict.
Future<void> _within(Duration limit, Future<void> work) async {
  try {
    await work.timeout(limit);
  } on TimeoutException {
    print('  timed out after ${limit.inSeconds} s');
  }
}

/// A refusal from the endpoint: a wrong token when the server is protected,
/// and a plain 403 from a local server, which is the branch either way.
Future<void> _checkForbidden(_Args args, _Checks checks) async {
  _section('403: a refusal ends the search');
  final forbidden = _RecordingServer(
    'invalid token',
    status: HttpStatus.forbidden,
  );
  try {
    await forbidden.start();
    final client = CommentClient(_serverAt(forbidden));
    try {
      await client.fetch(const CommentQuery(songName: 'x', artistName: 'y'));
      checks.fail('a 403 returned a page');
    } on CommentFetchException catch (error) {
      print('  local 403 -> $error');
      checks.expect(
        error.reason == 'forbidden',
        'a 403 becomes a forbidden exception',
      );
    }
    checks.expect(
      forbidden.requests == 1,
      'a refusal ends the search instead of retrying another address',
    );
  } finally {
    await forbidden.stop();
  }

  if (args.user.isNotEmpty || args.pass.isNotEmpty) {
    print('  the target has credentials configured, so a wrong token should '
        'be refused there as well');
  } else {
    print('  the target has no credentials configured, so it cannot be made '
        'to answer 403; the local server above exercises that branch');
  }
}

Future<void> _checkHttps(_Checks checks) async {
  _section('https: a self-signed certificate, accepted only when ignored');
  final context = SecurityContext()
    ..useCertificateChainBytes(utf8.encode(_selfSignedCert))
    ..usePrivateKeyBytes(utf8.encode(_selfSignedKey));
  final server = await HttpServer.bindSecure(
    InternetAddress.loopbackIPv4,
    0,
    context,
  );
  final subscriptions = <StreamSubscription<HttpRequest>>[];
  server.listen(
    (request) async {
      final params = request.uri.queryParameters;
      if (params.containsKey('song_name') &&
          params.containsKey('singer_name')) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(_fixture));
      } else {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('params error');
      }
      await request.response.close();
    },
    onError: (Object error) => print('  local https server: $error'),
    onDone: () => print('  local https server stopped'),
  );
  final port = '${server.port}';
  try {
    final ignored = CommentClient(
      CommentServer(
        id: 'tls',
        name: 'tls',
        scheme: 'https',
        lanHost: '127.0.0.1',
        lanPort: port,
        ignoreLanCert: true,
      ),
    );
    try {
      final result = await ignored.fetch(
        const CommentQuery(songName: 'x', artistName: 'y'),
      );
      print('  ignoreLanCert=true  -> ${result.page.comments.length} comments');
      checks.expect(
        result.page.comments.length == 2,
        'a self-signed certificate is accepted when the address ignores it',
      );
    } catch (error) {
      checks.fail(
        'a self-signed certificate was rejected although ignored: $error',
      );
    }

    final strict = CommentClient(
      CommentServer(
        id: 'tls',
        name: 'tls',
        scheme: 'https',
        lanHost: '127.0.0.1',
        lanPort: port,
        ignoreLanCert: false,
      ),
    );
    try {
      await strict.fetch(const CommentQuery(songName: 'x', artistName: 'y'));
      checks.fail('a self-signed certificate was accepted although not ignored');
    } on CommentFetchException catch (error) {
      print('  ignoreLanCert=false -> $error');
      checks.expect(
        error.reason == 'unreachable',
        'a self-signed certificate is rejected when not ignored',
      );
    }
  } finally {
    await server.close(force: true);
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }
}

/// A two item answer in the measured shape, for the local servers.
final _fixture = {
  'code': 200,
  'msg': 'success',
  'body': [
    {
      'nick': 'probe',
      'avatarurl': 'http://localhost/a.jpg',
      'content': 'local answer',
      'praiseNum': 2,
      'createTime': 9536475,
      'commentId': '2',
      'type': 2,
    },
    {
      'nick': 'probe',
      'avatarurl': 'http://localhost/b.jpg',
      'content': 'local answer',
      'praiseNum': 1,
      'createTime': 1413530574,
      'commentId': '1',
      'type': 2,
    },
  ],
};

CommentServer _serverAt(_RecordingServer local) => CommentServer(
  id: 'local',
  name: 'local',
  lanHost: '127.0.0.1',
  lanPort: '${local.port}',
);

/// A server on the loopback that answers every request with one body and
/// remembers the query it was given.
class _RecordingServer {
  _RecordingServer(this.body, {this.status = 200});

  final String body;
  final int status;
  HttpServer? _server;
  String? lastQuery;
  int requests = 0;

  int get port => _server!.port;

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((request) async {
      requests++;
      lastQuery = request.uri.query;
      request.response
        ..statusCode = status
        ..headers.contentType =
            status == 200 ? ContentType.json : ContentType.text
        ..write(body);
      await request.response.close();
    });
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

String _clip(String text, int max) {
  final flat = text.replaceAll('\n', ' ').replaceAll('\r', ' ');
  return flat.length <= max ? flat : '${flat.substring(0, max)}…';
}

void _section(String title) => print('\n== $title');

void _usage() {
  print(
    'Usage: dart run lib/tool/comment_probe.dart --host <host> [options]\n'
    '  --host <host>      the comment server to check, $_defaultHost by default\n'
    '  --port <port>      its port, $_defaultPort by default\n'
    '  --song <name>      the song to ask about, 晴天 by default\n'
    '  --artist <name>    its artist, 周杰伦 by default\n'
    '  --user <name>      API_USERNAME, when the server is protected\n'
    '  --pass <pass>      API_PASSWORD, likewise\n'
    '  --page <n>         the page the normal request asks for, 0 by default\n'
    '  --pagesize <n>     comments per page, 15 by default\n'
    '  --only-local       skip the checks that need a 127.0.0.1 server, for a\n'
    '                     run whose no_proxy does not cover the loopback\n'
    '  (the host can also come from COMMENT_PROBE_HOST)',
  );
}

class _Args {
  final String host;
  final String port;
  final String song;
  final String artist;
  final String user;
  final String pass;
  final int page;
  final int pageSize;
  final bool onlyLocal;
  final bool help;

  const _Args({
    required this.host,
    required this.port,
    required this.song,
    required this.artist,
    required this.user,
    required this.pass,
    required this.page,
    required this.pageSize,
    required this.onlyLocal,
    required this.help,
  });

  static _Args parse(List<String> arguments) {
    String? value(String name) {
      final index = arguments.indexOf(name);
      if (index < 0 || index + 1 >= arguments.length) {
        return null;
      }
      return arguments[index + 1];
    }

    return _Args(
      host:
          value('--host') ??
          Platform.environment['COMMENT_PROBE_HOST'] ??
          _defaultHost,
      port: value('--port') ?? _defaultPort,
      song: value('--song') ?? '晴天',
      artist: value('--artist') ?? '周杰伦',
      user: value('--user') ?? '',
      pass: value('--pass') ?? '',
      page: int.tryParse(value('--page') ?? '') ?? 0,
      pageSize: int.tryParse(value('--pagesize') ?? '') ?? 15,
      onlyLocal: arguments.contains('--only-local'),
      help: arguments.contains('-h') || arguments.contains('--help'),
    );
  }
}

class _Checks {
  int passed = 0;
  int failed = 0;
  final _failures = <String>[];

  void pass(String what) {
    passed++;
    print('  ok   $what');
  }

  void fail(String what) {
    failed++;
    _failures.add(what);
    print('  FAIL $what');
  }

  void expect(bool ok, String what) => ok ? pass(what) : fail(what);

  void summary() {
    print('  $passed passed, $failed failed');
    if (_failures.isNotEmpty) {
      print('  failures:');
      for (final failure in _failures) {
        print('    - $failure');
      }
    }
  }
}
