import 'package:flutter/foundation.dart';

/// Per-folder scan settings, keyed by folder id. A missing entry scans
/// subdirectories, which is what a music root folder is expected to mean.
final Map<String, bool> folderScanSubdirectories = {};

bool folderScansSubdirectories(String id) =>
    folderScanSubdirectories[id] ?? true;

/// Local folders whose contents must not enter the library, even when they sit
/// inside an added folder.
final ValueNotifier<List<String>> blockedFoldersNotifier = ValueNotifier(
  const [],
);

/// Audio files shorter than [minAudioSecondsNotifier] can be left out of the
/// library, which keeps notification jingles and tiny clips out of it.
final ValueNotifier<bool> skipShortAudioNotifier = ValueNotifier(true);
final ValueNotifier<int> minAudioSecondsNotifier = ValueNotifier(60);

String _normalizedPath(String path) =>
    path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');

/// Whether [path] is inside one of the blocked folders.
bool isBlockedFolderPath(String path) {
  final target = _normalizedPath(path);
  for (final blocked in blockedFoldersNotifier.value) {
    final root = _normalizedPath(blocked);
    if (root.isEmpty) {
      continue;
    }
    if (target == root || target.startsWith('$root/')) {
      return true;
    }
  }
  return false;
}
