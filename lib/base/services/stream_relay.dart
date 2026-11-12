import 'dart:io';

import 'package:lain/base/services/cert_policy.dart';
import 'package:lain/base/services/logger.dart';

final streamRelay = StreamRelay();

class _RelayTarget {
  final String url;
  final Map<String, String>? headers;

  /// Set instead of [url] when the target is a local file (cover art).
  final String? filePath;

  _RelayTarget(this.url, this.headers, {this.filePath});
}

/// mpv's bundled ffmpeg does TLS with macOS Secure Transport, which never got
/// TLS 1.3 - servers that require it (e.g. Emby behind a modern CDN) kill the
/// handshake before any proxy setting can matter. Dart's HttpClient
/// (BoringSSL) negotiates TLS 1.3 and follows the system proxy, so remote
/// streams are fetched Dart-side and re-served to mpv over plain localhost
/// HTTP: mpv never touches TLS or the proxy at all.
class StreamRelay {
  Future<HttpServer>? _starting;
  Future<HttpServer>? _startingLan;
  Future<void>? _warmingUp;
  DateTime? _lanLookupFailedAt;
  HttpServer? _lanServer;
  String? _baseUrl;

  /// The LAN-facing base URL, once [warmUp] has resolved it. Kept so a cover
  /// URL can be built without awaiting anything.
  String? _lanBaseUrl;

  /// When [_lanBaseUrl] was last confirmed. A phone moves between networks
  /// (home Wi-Fi, a car's hotspot), and its address there changes with it: a
  /// URL cached from the previous network is one the head unit can never
  /// fetch, which shows up as a cover that stays stale or missing.
  DateTime? _lanBaseUrlAt;

  /// Bumped whenever the LAN base URL changes, so callers that cache URLs
  /// built from it (the media session's cover URIs) can tell they are stale.
  int _lanBaseUrlGeneration = 0;

  int get lanBaseUrlGeneration => _lanBaseUrlGeneration;

  /// Confirm the cached LAN URL this often. Cheap enough to run on every track
  /// switch: it lists the interfaces, it does not open a socket.
  static const _lanBaseUrlTtl = Duration(seconds: 20);

  String? get lanBaseUrl => _lanBaseUrl;

  /// Cover file path (or remote URL) -> its relay token. Keyed so the same
  /// artwork always gets the same URL: the car can keep using it, and
  /// re-publishing a track does not leak a token on every publish.
  final Map<String, String> _coverTokenByKey = {};

  final _targets = <String, _RelayTarget>{};
  final _covers = <String, _RelayTarget>{};
  final _client = HttpClient();

  int _counter = 0;

  StreamRelay() {
    _client.connectionTimeout = const Duration(seconds: 10);
    _client.badCertificateCallback = (cert, host, port) => ignoreServerCert;
  }

  /// Registers [url] (with the auth [headers] mpv would otherwise have sent)
  /// and returns a plain-HTTP localhost URL for mpv to open.
  Future<String> register(String url, Map<String, String>? headers) async {
    await _ensureStarted();

    if (_targets.length > 16) {
      _targets.remove(_targets.keys.first);
    }

    final token = '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    _targets[token] = _RelayTarget(url, headers);

    return '$_baseUrl/audio/$token';
  }

  /// A cover URL for a *different* device - a car head unit reading the media
  /// session's artwork URI. `127.0.0.1` means the head unit itself, so the cover
  /// is served by a second, LAN-facing server that only knows about covers (the
  /// audio streams stay on loopback). Null when this device has no local network
  /// address, in which case the caller falls back to the loopback URL.
  Future<String?> registerCoverForLan({
    String? url,
    String? filePath,
    Map<String, String>? headers,
  }) async {
    await warmUp();
    return coverUrlSync(url: url, filePath: filePath, headers: headers);
  }

  /// Starts both servers and resolves this device's LAN address, once.
  ///
  /// Called early (at startup) so that from then on [coverUrlSync] can answer
  /// without awaiting anything - which is what lets a track's artwork be
  /// published in the same frame as the track, instead of a second later.
  Future<void> warmUp() async {
    await _ensureStarted();
    // Re-confirm the address instead of trusting the first answer forever: it
    // belongs to the network the phone is on right now, and a phone moves
    // between its home Wi-Fi and a car's hotspot.
    final resolvedAt = _lanBaseUrlAt;
    if (_lanBaseUrl != null &&
        resolvedAt != null &&
        DateTime.now().difference(resolvedAt) < _lanBaseUrlTtl) {
      return;
    }
    // Not resolved yet, and asking again on every publish would list the
    // interfaces over and over: retry occasionally instead.
    final failed = _lanLookupFailedAt;
    if (failed != null &&
        DateTime.now().difference(failed) < const Duration(seconds: 5)) {
      return;
    }
    final running = _warmingUp;
    if (running != null) {
      return running;
    }
    final warming = _warmUpLan();
    _warmingUp = warming;
    try {
      await warming;
    } finally {
      _warmingUp = null;
    }
  }

  Future<void> _warmUpLan() async {
    try {
      final address = await _lanAddress();
      if (address == null) {
        logger.output('[relay] no LAN address, covers stay on loopback');
        _lanLookupFailedAt = DateTime.now();
        // A URL from a previous network is not usable here either: drop it so
        // the caller falls back to a loopback/content URI until one is found.
        _lanBaseUrl = null;
        _lanBaseUrlAt = null;
        return;
      }
      final server = await _ensureLanStarted();
      final base = 'http://$address:${server.port}';
      final previous = _lanBaseUrl;
      _lanBaseUrl = base;
      _lanBaseUrlAt = DateTime.now();
      _lanLookupFailedAt = null;
      final rebuilt = previous != null && previous != base;
      if (rebuilt) {
        _lanBaseUrlGeneration++;
      }
      if (previous != base) {
        // Every token is still served by the same server object; only the host
        // it is reached through changed, so the published URLs are stale.
        logger.output('[relay] LAN covers now served from $base');
      }
    } catch (e) {
      logger.output('[relay] LAN cover server failed: $e');
      _lanLookupFailedAt = DateTime.now();
    }
  }

  /// A cover URL a head unit can fetch, resolved *synchronously*.
  ///
  /// Null when the relay has not warmed up yet or this device has no LAN
  /// address; the caller then resolves it asynchronously and re-publishes.
  String? coverUrlSync({
    String? url,
    String? filePath,
    Map<String, String>? headers,
  }) {
    final base = _lanBaseUrl;
    if (base == null) {
      return null;
    }
    final key = filePath ?? url ?? '';
    if (key.isEmpty) {
      return null;
    }
    final token = _coverTokenByKey.putIfAbsent(
      key,
      () => _addCover(url, headers, filePath),
    );
    return '$base/cover/$token';
  }

  /// Registers a cover and returns its token. Kept in the long term, unlike the
  /// stream targets: the media session publishes one per song and re-publishes
  /// the same URL when the user goes back to a track.
  String _addCover(String? url, Map<String, String>? headers, String? filePath) {
    // Generous: a token per distinct artwork, kept so the car can re-fetch the
    // track it is showing without a round trip. Each entry is a couple of
    // strings.
    if (_covers.length > 512) {
      final oldest = _covers.keys.first;
      _covers.remove(oldest);
      _coverTokenByKey.removeWhere((_, token) => token == oldest);
    }

    final token = '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    _covers[token] = _RelayTarget(url ?? '', headers, filePath: filePath);
    return token;
  }

  Future<HttpServer> _ensureLanStarted() {
    final existing = _lanServer;
    if (existing != null) {
      return Future.value(existing);
    }
    return _startingLan ??= _startLan();
  }

  Future<HttpServer> _startLan() async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _lanServer = server;

    server.listen(
      (request) {
        // Covers only: a head unit must not be able to pull the audio streams.
        _handle(request, coversOnly: true);
      },
      onError: (e) {
        logger.output('[StreamRelay] lan server error: $e');
      },
    );

    return server;
  }

  /// This device's address on the local network, preferring a private one.
  Future<String?> _lanAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );

      final addresses = [
        for (final interface in interfaces) ...interface.addresses,
      ];

      for (final address in addresses) {
        if (_isPrivateAddress(address.address)) {
          return address.address;
        }
      }
    } catch (e) {
      logger.output('[StreamRelay] could not read the network addresses: $e');
    }

    return null;
  }

  bool _isPrivateAddress(String address) {
    if (address.startsWith('192.168.') || address.startsWith('10.')) {
      return true;
    }
    if (address.startsWith('172.')) {
      final second = int.tryParse(address.split('.').elementAt(1)) ?? 0;
      return second >= 16 && second <= 31;
    }
    return false;
  }

  /// Returns a plain-HTTP localhost URL that serves cover art, either proxied
  /// from [url] (with auth [headers]) or read from the local [filePath].
  ///
  /// The media session advertises this so that artwork can be shown by system
  /// UIs and car head units: they cannot read an app-private `file://` path,
  /// and a `content://` URI exposed by a non-exported provider is not readable
  /// by another process either.
  Future<String> registerCover({
    String? url,
    String? filePath,
    Map<String, String>? headers,
  }) async {
    await _ensureStarted();

    final token = _addCover(url, headers, filePath);

    return '$_baseUrl/cover/$token';
  }

  Future<HttpServer> _ensureStarted() {
    return _starting ??= _start();
  }

  Future<HttpServer> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    _baseUrl = 'http://127.0.0.1:${server.port}';

    server.listen(
      (request) {
        _handle(request);
      },
      onError: (e) {
        logger.output('[StreamRelay] server error: $e');
      },
    );

    return server;
  }

  Future<void> _handle(HttpRequest request, {bool coversOnly = false}) async {
    try {
      final segments = request.uri.pathSegments;
      _RelayTarget? target;
      if (segments.length == 2) {
        if (!coversOnly && segments[0] == 'audio') {
          target = _targets[segments[1]];
        } else if (segments[0] == 'cover') {
          target = _covers[segments[1]];
        }
      }

      if (target == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      if (target.filePath != null) {
        await _serveFile(request, target.filePath!);
        return;
      }

      final upstream = await _client.openUrl('GET', Uri.parse(target.url));
      target.headers?.forEach(upstream.headers.set);

      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        upstream.headers.set(HttpHeaders.rangeHeader, range);
      }

      final response = await upstream.close();

      // mpv decides how a stream ends from the response status and length
      // alone. A chunked -1-length response (the server did not state one, or
      // the request was a plain GET) leaves it reading until the connection
      // closes, and a stall then looks exactly like the end of the song, which
      // showed up as the same track playing twice. When the length is known,
      // pass it on so the end is unambiguous.
      final status = response.statusCode;
      if (request.method != 'HEAD' &&
          response.contentLength >= 0 &&
          status >= 200 &&
          status < 300) {
        request.response.contentLength = response.contentLength;
      }
      request.response.statusCode = response.statusCode;
      for (final name in [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
        HttpHeaders.lastModifiedHeader,
        HttpHeaders.etagHeader,
      ]) {
        final value = response.headers.value(name);
        if (value != null) {
          request.response.headers.set(name, value);
        }
      }

      if (request.method == 'HEAD') {
        await request.response.close();
        return;
      }

      await for (final chunk in response) {
        request.response.add(chunk);
      }
      await request.response.close();
    } catch (e) {
      // mpv aborts requests mid-stream when seeking or switching tracks;
      // that surfaces here as a write/socket error and is not a problem.
      logger.output('[StreamRelay] request ended: $e');
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveFile(HttpRequest request, String path) async {
    final file = File(path);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    request.response.headers.contentType = await _imageContentType(path);
    request.response.headers.contentLength = await file.length();
    if (request.method == 'HEAD') {
      await request.response.close();
      return;
    }

    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  // Cached cover files have no extension, so sniff the magic bytes.
  Future<ContentType> _imageContentType(String path) async {
    final raf = await File(path).open();
    try {
      final head = await raf.read(12);
      bool startsWith(List<int> magic) {
        if (head.length < magic.length) {
          return false;
        }
        for (var i = 0; i < magic.length; i++) {
          if (head[i] != magic[i]) {
            return false;
          }
        }
        return true;
      }

      if (startsWith([0xff, 0xd8, 0xff])) {
        return ContentType('image', 'jpeg');
      }
      if (startsWith([0x89, 0x50, 0x4e, 0x47])) {
        return ContentType('image', 'png');
      }
      if (startsWith([0x47, 0x49, 0x46, 0x38])) {
        return ContentType('image', 'gif');
      }
      if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
          head.length >= 12 &&
          head[8] == 0x57 &&
          head[9] == 0x45 &&
          head[10] == 0x42 &&
          head[11] == 0x50) {
        return ContentType('image', 'webp');
      }
      return ContentType.binary;
    } finally {
      await raf.close();
    }
  }
}
