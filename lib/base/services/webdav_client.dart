import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:lain/base/services/logger.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

WebDavClient? webdavClient;

class WebDavFile {
  final String path;
  final String name;
  final bool isDirectory;
  final DateTime? modified;

  /// The server's `creationdate`, used as the song's "added time"; null when
  /// the server does not report one.
  final DateTime? created;

  WebDavFile({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.modified,
    this.created,
  });
}

class WebDavClient {
  /// Mutable: a server may be reachable at two addresses; the app switches to
  /// the other one when this one stops answering.
  String baseUrl;

  /// The server's other address.
  String? alternativeBaseUrl;
  final String username;
  final String password;

  late String _cleanBaseUrl;
  late String _initialPath;

  late final Dio dio;

  WebDavClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  }) {
    // The stored address may carry a path (a mount point) and it may contain
    // percent-encoded Chinese or spaces. Slicing the encoded base URL by the
    // *decoded* path length - as this used to - cut it mid-escape, so every
    // request went to a broken URL and a WebDAV source showed nothing.
    final uri = Uri.tryParse(baseUrl);
    _initialPath = _normalizeBasePath(
      uri == null ? '' : _decodePath(uri.path),
    );
    _cleanBaseUrl = uri == null ? baseUrl.trim() : _originOf(uri);
    if (_cleanBaseUrl.endsWith('/')) {
      _cleanBaseUrl = _cleanBaseUrl.substring(0, _cleanBaseUrl.length - 1);
    }

    dio = Dio(
      BaseOptions(
        baseUrl: _cleanBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );

    _applyAuth();
  }

  String get cleanBaseUrl => _cleanBaseUrl;

  String get initialPath => _initialPath;

  /// Scheme, credentials and host of [uri], without any path: this is what a
  /// song's id is prefixed with, and hrefs the server sends already carry the
  /// base path.
  static String _originOf(Uri uri) {
    if (uri.scheme.isEmpty || uri.host.isEmpty) {
      return uri.toString();
    }
    final buffer = StringBuffer('${uri.scheme}://');
    if (uri.userInfo.isNotEmpty) {
      buffer.write('${uri.userInfo}@');
    }
    buffer.write(uri.host);
    if (uri.hasPort) {
      buffer.write(':${uri.port}');
    }
    return buffer.toString();
  }

  static String _decodePath(String path) {
    try {
      return Uri.decodeFull(path);
    } catch (_) {
      return path;
    }
  }

  /// Percent-encodes a decoded path segment by segment.
  ///
  /// The app keeps paths decoded (they come from `Uri.decodeFull`), but a name
  /// such as `Track #1` or `What?` would then make Dio read `#` or `?` as URL
  /// syntax and request the wrong resource - the collection failed and its
  /// whole subtree disappeared from the scan.
  static String _encodePath(String path) {
    if (path.isEmpty || path == '/') {
      return path.isEmpty ? '' : '/';
    }
    final leading = path.startsWith('/') ? '/' : '';
    final trailing = path.length > 1 && path.endsWith('/') ? '/' : '';
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return '$leading$segments$trailing';
  }

  /// Encodes the path part of a decoded absolute URL, leaving its scheme and
  /// host untouched. Used wherever a song's stored URL goes to a URL parser
  /// (lofty, http, the relay): a name containing `#` or `?` would otherwise be
  /// read as URL syntax and the request would hit the wrong resource.
  static String encodeRemoteUrl(String url) {
    final schemeEnd = url.indexOf('://');
    if (schemeEnd < 0) {
      return url;
    }
    final originEnd = url.indexOf('/', schemeEnd + 3);
    if (originEnd < 0) {
      return url;
    }
    final origin = url.substring(0, originEnd);
    return '$origin${_encodePath(url.substring(originEnd))}';
  }

  /// The base path without its trailing slash; the root is the empty string.
  static String _normalizeBasePath(String path) {
    var value = path;
    if (value == '/') {
      return '';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _withoutTrailingSlash(String path) {
    var value = path;
    while (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  void _applyAuth() {
    dio.options.headers['authorization'] =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  }

  Map<String, String> get headers {
    return Map<String, String>.from(dio.options.headers);
  }

  String _safeDecodeUri(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (e) {
      logger.output('[WebDav] Decode uri error: $e');
      return value;
    }
  }

  /// Turns a path the app holds (decoded, relative to the server's base path,
  /// and with or without a leading slash) into the absolute path a request
  /// needs. An absolute href the server already sent is kept as it is.
  String _fullPath(String remotePath) {
    var path = _safeDecodeUri(remotePath.trim());
    if (path.isEmpty) {
      path = '/';
    }
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    if (_initialPath.isEmpty) {
      return path;
    }
    if (path == _initialPath || path.startsWith('$_initialPath/')) {
      return path;
    }
    return '$_initialPath$path';
  }

  /// The opposite of [_fullPath]: a decoded href as a path relative to the
  /// configured base.
  String relativePath(String absolutePath) {
    final path = _safeDecodeUri(absolutePath);
    if (_initialPath.isEmpty) {
      return path;
    }
    if (path == _initialPath) {
      return '/';
    }
    if (path.startsWith('$_initialPath/')) {
      return path.substring(_initialPath.length);
    }
    return path;
  }

  /// The path of the configured base (a mount point), or `/` at the root.
  String get _rootPath => _initialPath.isEmpty ? '/' : _initialPath;

  /// WebDAV dates are RFC 8594 / HTTP dates on most servers (`Tue, 31 Mar
  /// 2026 10:36:13 GMT`), while some send ISO 8601. Accept both.
  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return HttpDate.parse(value).toLocal();
    } catch (_) {}
    return DateTime.tryParse(value);
  }

  Future<T?> _safeRequest<T>(
    String mark,
    Future<Response> Function() request,
    T? Function(Response response) parser,
  ) async {
    try {
      final response = await request();
      return parser(response);
    } on DioException catch (e) {
      logger.output(
        '[$runtimeType] [$mark] Dio error: ${e.message} '
        '(${e.response?.statusCode})',
      );

      if (e.response?.data != null) {
        logger.output(e.response!.data.toString());
      }

      return null;
    } catch (e) {
      logger.output('[$runtimeType] [$mark] Unknown error: $e');

      return null;
    }
  }

  Future<bool> _boolRequest(
    String mark,
    Future<Response> Function() request,
  ) async {
    return await _safeRequest(mark, request, (_) => true) ?? false;
  }

  Future<bool> ping() async {
    final result = await _safeRequest(
      'ping $_rootPath',
      () => dio.request(
        _encodePath(_rootPath),
        options: Options(method: 'PROPFIND', headers: {'Depth': '0'}),
      ),
      (response) {
        final code = response.statusCode ?? 0;
        return code >= 200 && code < 400;
      },
    );

    return result ?? false;
  }

  Future<List<WebDavFile>> list(String remotePath) async {
    return await _listAbsolute(_fullPath(remotePath)) ?? [];
  }

  /// Lists one collection by its absolute (decoded) path, retrying a failed
  /// request twice: a NAS behind a proxy does answer the occasional 502, and
  /// dropping that one collection used to lose a whole album from the scan.
  /// Null means every attempt failed.
  Future<List<WebDavFile>?> _listAbsolute(String absolutePath) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final result = await _listAbsoluteOnce(absolutePath);
      if (result != null) {
        return result;
      }
      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: 400 * (attempt + 1)),
        );
      }
    }
    return null;
  }

  /// Lists one collection by its absolute (decoded) path. The caller has
  /// already resolved the base path, so hrefs are used as they arrive.
  Future<List<WebDavFile>?> _listAbsoluteOnce(String absolutePath) async {
    var decodedPath = absolutePath;
    if (!decodedPath.endsWith('/')) {
      decodedPath += '/';
    }
    final requestPath = _encodePath(decodedPath);

    final result = await _safeRequest(
      'list $decodedPath',
      () => dio.request(
        requestPath,
        data: '''
<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:allprop />
</d:propfind>
''',
        options: Options(
          method: 'PROPFIND',
          headers: {'Depth': '1', 'Content-Type': 'text/xml; charset=utf-8'},
        ),
      ),
      (response) {
        final data = response.data;
        if (data is! String) {
          return <WebDavFile>[];
        }
        final document = XmlDocument.parse(data);

        final responses = document
            .findAllElements('*')
            .where((e) => e.name.local == 'response');

        final result = <WebDavFile>[];
        final selfPath = _withoutTrailingSlash(decodedPath);

        for (final item in responses) {
          try {
            final hrefElement = item.children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'href');

            final href = _safeDecodeUri(hrefElement.innerText);
            final cleanPath = _withoutTrailingSlash(href);
            if (cleanPath == selfPath) {
              continue;
            }

            final isDir = item
                .findAllElements('*')
                .any((e) => e.name.local == 'collection');

            final modifiedElement = item
                .findAllElements('*')
                .where((e) => e.name.local == 'getlastmodified')
                .firstOrNull;
            final createdElement = item
                .findAllElements('*')
                .where((e) => e.name.local == 'creationdate')
                .firstOrNull;

            final name = p.basename(cleanPath);
            result.add(
              WebDavFile(
                path: href,
                name: name,
                isDirectory: isDir,
                modified: _parseDate(modifiedElement?.innerText),
                created: _parseDate(createdElement?.innerText),
              ),
            );
          } catch (e) {
            logger.output('[WebDav] Parse item error: $e');
          }
        }

        return result;
      },
    );

    return result;
  }

  Stream<WebDavFile> listStream(
    String remotePath, {
    bool recursive = false,
  }) async* {
    final files = await listRecursive(remotePath, recursive: recursive);
    for (final file in files) {
      yield file;
    }
  }

  /// Walks [remotePath] and, when [recursive], every collection under it.
  ///
  /// The old walk asked one directory at a time and awaited the answer, so a
  /// music tree of thousands of collections took many minutes before the first
  /// song could appear. A few requests run at once instead; a collection that
  /// fails is skipped rather than aborting the whole scan.
  Future<List<WebDavFile>> listRecursive(
    String remotePath, {
    bool recursive = true,
    int concurrency = 8,
  }) async {
    final all = <WebDavFile>[];
    final seen = <String>{};
    var queue = <String>[_fullPath(remotePath)];

    while (queue.isNotEmpty) {
      final batch = <String>[];
      while (queue.isNotEmpty && batch.length < concurrency) {
        final path = queue.removeAt(0);
        if (!seen.add(_withoutTrailingSlash(path))) {
          continue;
        }
        batch.add(path);
      }
      if (batch.isEmpty) {
        continue;
      }
      final pages = await Future.wait(batch.map(_listAbsolute));
      for (final page in pages) {
        if (page == null) {
          continue;
        }
        all.addAll(page);
        if (!recursive) {
          continue;
        }
        for (final file in page) {
          if (file.isDirectory) {
            queue.add(file.path);
          }
        }
      }
    }
    return all;
  }

  Future<List<String>> listSubDirectories(String root) async {
    try {
      final dirList = <String>[];
      final dirQueue = Queue<String>();

      dirQueue.add(root);

      while (dirQueue.isNotEmpty) {
        final dir = dirQueue.removeFirst();

        final fileList = await list(dir);

        for (final f in fileList) {
          if (f.isDirectory) {
            dirList.add(f.path);
            dirQueue.add(f.path);
          }
        }
      }

      return dirList;
    } catch (e) {
      logger.output('[WebDav] List sub directories error: $e');
      return [];
    }
  }

  /// A full URL is used as it is (song ids are full URLs); a path the app
  /// holds is resolved against the configured base.
  String _requestPath(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      // The stored URL is decoded; encode it again before a URL parser sees
      // names containing `#` or `?`.
      return encodeRemoteUrl(path);
    }
    return _encodePath(_fullPath(path));
  }

  Future<bool> download({
    required String remotePath,
    required String localPath,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final path = _requestPath(remotePath);
    return _boolRequest(
      'download $path',
      () => dio.download(
        path,
        localPath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<bool> upload({
    required String localPath,
    required String remotePath,
    ProgressCallback? onSendProgress,
  }) async {
    final file = File(localPath);
    final length = await file.length();

    return _boolRequest(
      'upload $localPath',

      () => dio.put(
        _requestPath(remotePath),
        data: file.openRead(),
        options: Options(headers: {Headers.contentLengthHeader: length}),
        onSendProgress: onSendProgress,
      ),
    );
  }

  Future<bool> mkdir(String remotePath) async {
    return _boolRequest(
      'mkdir $remotePath',

      () => dio.request(
        _requestPath(remotePath),
        options: Options(method: 'MKCOL'),
      ),
    );
  }

  Future<bool> delete(String remotePath) async {
    return _boolRequest(
      'delete $remotePath',
      () => dio.delete(_requestPath(remotePath)),
    );
  }

  String _buildDestinationUrl(String destination) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final cleanDest = destination.startsWith('/')
        ? destination.substring(1)
        : destination;
    return '$cleanBase$cleanDest';
  }

  Future<bool> move({
    required String source,
    required String destination,
  }) async {
    return _boolRequest(
      'move ${source}to $destination',
      () => dio.request(
        _requestPath(source),
        options: Options(
          method: 'MOVE',
          headers: {'Destination': _buildDestinationUrl(destination)},
        ),
      ),
    );
  }

  Future<bool> copy({
    required String source,
    required String destination,
  }) async {
    return _boolRequest(
      'copy $source to $destination',

      () => dio.request(
        _requestPath(source),
        options: Options(
          method: 'COPY',
          headers: {'Destination': _buildDestinationUrl(destination)},
        ),
      ),
    );
  }
}
