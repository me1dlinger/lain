import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lain/base/services/logger.dart';

/// A read-only LAN view of what the app is currently broadcasting, so the PC
/// inspector can be used without an ADB connection. It serves metadata and the
/// exact cover file; it never changes playback.
class BroadcastInspector {
  BroadcastInspector._();

  static final BroadcastInspector instance = BroadcastInspector._();

  static const httpPort = 8790;
  static const discoveryPort = 8791;

  HttpServer? _server;
  RawDatagramSocket? _discovery;
  Map<String, Object?> _state = const {};
  String? _coverPath;
  bool _started = false;

  Map<String, Object?> get state => Map.unmodifiable(_state);

  void update({
    required String title,
    required String artist,
    required String album,
    required List<String> lines,
    String? lyric,
    String? translation,
    String? coverPath,
    String? fetchUri,
    String? debugUri,
    String? mode,
    required bool bitmap,
  }) {
    _coverPath = coverPath;
    _state = {
      'ok': true,
      'via': 'lan',
      'updatedAt': DateTime.now().toIso8601String(),
      'media': {
        'active': true,
        'lines': lines,
        'raw_description': lines.join(', '),
      },
      'publish': {
        'title': title,
        'artist': artist,
        'album': album,
        'lines': lines,
        'lyric': lyric,
        'translation': translation,
        'bitmap': bitmap ? 'yes' : 'none',
        'fetch': fetchUri,
        'debug': debugUri,
        'mode': mode,
      },
      'cover_url': fetchUri ?? debugUri,
    };
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, httpPort);
      unawaited(_serve());
      logger.output('[inspector] LAN state on port $httpPort');
    } catch (e) {
      _started = false;
      logger.output('[inspector] HTTP server failed: $e');
    }
    try {
      _discovery = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      );
      _discovery!.broadcastEnabled = true;
      _discovery!.listen((event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final datagram = _discovery!.receive();
        if (datagram == null) {
          return;
        }
        if (utf8.decode(datagram.data, allowMalformed: true).trim() ==
            'LAIN_INSPECT') {
          _discovery!.send(
            utf8.encode('LAIN_INSPECTOR:$httpPort'),
            datagram.address,
            datagram.port,
          );
        }
      });
      logger.output('[inspector] discovery on UDP $discoveryPort');
    } catch (e) {
      logger.output('[inspector] discovery failed: $e');
    }
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) {
      return;
    }
    await for (final request in server) {
      try {
        if (request.method != 'GET') {
          request.response.statusCode = HttpStatus.methodNotAllowed;
          await request.response.close();
          continue;
        }
        switch (request.uri.path) {
          case '/state':
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode(_state));
          case '/cover':
            final path = _coverPath;
            final file = path == null ? null : File(path);
            if (file == null || !file.existsSync()) {
              request.response.statusCode = HttpStatus.notFound;
            } else {
              request.response.headers.contentType = ContentType('image', 'jpeg');
              request.response.add(await file.readAsBytes());
            }
          default:
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'ok': true,
                'state': '/state',
                'cover': '/cover',
              }),
            );
        }
      } catch (e) {
        logger.output('[inspector] request failed: $e');
      } finally {
        await request.response.close();
      }
    }
  }
}

final broadcastInspector = BroadcastInspector.instance;
