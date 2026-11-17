import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lain/base/app.dart';
import 'package:lain/base/data/cache_download_settings.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/webdav_client.dart';

void setIOSFileProviderStorageIfNeed(String? iosPath) {
  if (iosFileProviderStorage == null && iosPath != null) {
    final tmp = iosPath.split('File Provider Storage/').first;
    iosFileProviderStorage = "${tmp}File Provider Storage/";
  }
}

bool isFileProviderStorePath(String path) {
  return path.contains('File Provider Storage/');
}

// full path to short path
String convertIOSPath(String path) {
  if (path.contains('File Provider Storage/')) {
    return path.split('File Provider Storage/').last;
  } else {
    path = path.substring(path.indexOf('Documents'));
    return path.replaceFirst('Documents', 'Lain');
  }
}

// short path to full path
String revertIOSPath(String path) {
  if (path.startsWith('Lain')) {
    return "${appDocsDir.parent.path}/${path.replaceFirst('Lain', 'Documents')}";
  } else {
    if (iosFileProviderStorage == null) {
      return '';
    }
    return iosFileProviderStorage! + path;
  }
}

// full path to short path
String convertIOSSupportPath(String path) {
  return path.split('Application Support/').last;
}

// short path to full path
String revertIOSSupportPath(String path) {
  return "${appSupportDir.path}/$path";
}

void initFile(File file, bool isList) {
  if (!file.existsSync()) {
    file.createSync(recursive: true);
    file.writeAsStringSync(isList ? '[]' : '{}');
  }
}

/// Decodes [file] as a JSON list, resetting it to `[]` and returning an
/// empty list if the content is missing or corrupted (e.g. a crash mid-write)
/// instead of letting the exception crash startup.
List<dynamic> readJsonListFileSync(File file) {
  try {
    return jsonDecode(file.readAsStringSync()) as List<dynamic>;
  } catch (e) {
    logger.output('Corrupted JSON file ${file.path}, resetting: $e');
    file.writeAsStringSync('[]');
    return [];
  }
}

/// Async counterpart of [readJsonListFileSync].
Future<List<dynamic>> readJsonListFile(File file) async {
  try {
    return jsonDecode(await file.readAsString()) as List<dynamic>;
  } catch (e) {
    logger.output('Corrupted JSON file ${file.path}, resetting: $e');
    await file.writeAsString('[]');
    return [];
  }
}

/// Decodes [file] as a JSON map, resetting it to `{}` and returning an empty
/// map if the content is missing or corrupted, instead of letting the
/// exception crash startup.
Map<String, dynamic> readJsonMapFileSync(File file) {
  try {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    logger.output('Corrupted JSON file ${file.path}, resetting: $e');
    file.writeAsStringSync('{}');
    return {};
  }
}

/// Async counterpart of [readJsonMapFileSync].
Future<Map<String, dynamic>> readJsonMapFile(File file) async {
  try {
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (e) {
    logger.output('Corrupted JSON file ${file.path}, resetting: $e');
    await file.writeAsString('{}');
    return {};
  }
}

String getFolderConfigPath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/folder_config';
}

String getPlaylistConfigPath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/playlist_config';
}

/// The per-source folder that holds cached audio, covers and lyrics.
///
/// [cacheDirNotifier] moves this tree to a folder the user chose; the default
/// stays in the app's support directory. Every helper below goes through it,
/// so clearing and accounting follow the setting without extra work.
String getCacheRootPath(SourceType sourceType) {
  final configured = cacheDirNotifier.value.trim();
  if (configured.isEmpty) {
    return '${appSupportDir.path}/${sourceType.name}';
  }
  final normalized = configured.replaceAll('\\', '/');
  return '$normalized/${sourceType.name}';
}

String getCachesPath(SourceType sourceType) {
  return '${getCacheRootPath(sourceType)}/caches';
}

String getPicturesPath(SourceType sourceType) {
  return '${getCacheRootPath(sourceType)}/pictures';
}

String getLrcPath(SourceType sourceType) {
  return '${getCacheRootPath(sourceType)}/lyrics';
}

String getSyncedFilePath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/synced.keep';
}

final _httpClient = http.Client();

Future<String?> covertToRedirectPathIfNeed(String path) async {
  // A decoded name with `#` or `?` would otherwise end the path at that
  // character and the HEAD request would look at the wrong resource.
  final request = http.Request(
    'HEAD',
    Uri.parse(WebDavClient.encodeRemoteUrl(path)),
  )
    ..followRedirects = false
    ..headers.addAll(webdavClient?.headers ?? {});

  final response = await _httpClient.send(request);

  if (response.statusCode == 302) {
    final redirectLocation = response.headers['location'];
    if (redirectLocation != null) {
      return redirectLocation;
    }
  }
  return null;
}
