import 'dart:io';

import 'package:sylvakru/base/services/cert_policy.dart';
import 'package:sylvakru/base/services/logger.dart';

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
  HttpServer? _lanServer;
  String? _baseUrl;
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
    final address = await _lanAddress();
    if (address == null) {
      return null;
    }

    final server = await _ensureLanStarted();
    final token = _addCover(url, headers, filePath);
    return 'http://$address:${server.port}/cover/$token';
  }

  /// Registers a cover and returns its token. Kept in the long term, unlike the
  /// stream targets: the media session publishes one per song and re-publishes
  /// the same URL when the user goes back to a track.
  String _addCover(String? url, Map<String, String>? headers, String? filePath) {
    if (_covers.length > 64) {
      _covers.remove(_covers.keys.first);
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
