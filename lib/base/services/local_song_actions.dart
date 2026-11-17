import 'dart:io';

import 'package:flutter/services.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';

/// The three things a local song can be removed from: the library view, the
/// file on disk, or neither - "show in folder" only opens the file manager.
class LocalSongActions {
  static const _channel = MethodChannel('com.meidlinger.lain.media');

  Future<bool> showInFolder(MyAudioMetadata song) async {
    final path = song.path;
    if (path == null || path.isEmpty) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('showInFolder', {
            'path': path,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Drops the song from the library but leaves its file alone.
  Future<void> removeFromLibrary(MyAudioMetadata song) {
    return library.removeSongFromLibrary(song);
  }

  /// Deletes the audio file and its library row. The caller confirms first;
  /// this method does not ask again.
  Future<bool> deleteFile(MyAudioMetadata song) async {
    final path = song.path;
    if (path == null || path.isEmpty) {
      return false;
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    await library.removeSongFromLibrary(song);
    return true;
  }
}

final localSongActions = LocalSongActions();
