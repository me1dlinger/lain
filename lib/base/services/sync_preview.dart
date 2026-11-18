import 'package:lain/base/app.dart';
import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/utils/metadata_utils.dart';

class SyncPreviewItem {
  final String id;
  final String title;
  final String artist;
  final String path;
  final int? size;

  const SyncPreviewItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.path,
    this.size,
  });

  factory SyncPreviewItem.fromSong(MyAudioMetadata song) => SyncPreviewItem(
    id: song.id,
    title: getTitle(song),
    artist: getArtist(song),
    path: song.path ?? '',
    size: song.size,
  );
}

class SyncPreview {
  final int added;
  final int removed;
  final int changed;
  final int unchanged;
  final int cachedRemoved;
  final int playlistRefs;
  final List<SyncPreviewItem> addedSamples;
  final List<SyncPreviewItem> removedSamples;
  final String sourceLabel;

  const SyncPreview({
    required this.added,
    required this.removed,
    required this.changed,
    required this.unchanged,
    required this.cachedRemoved,
    required this.playlistRefs,
    required this.addedSamples,
    required this.removedSamples,
    required this.sourceLabel,
  });

  bool get hasChanges => added > 0 || removed > 0 || changed > 0;
}

/// Computes what a sync would change without touching the library. The actual
/// sync is still the existing Loader.sync(); this preview exists so the user
/// sees the destructive half before it happens.
class SyncPreviewService {
  Future<SyncPreview> build() async {
    final existing = {for (final song in library.songList) song.id: song};
    final found = <String, MyAudioMetadata>{};
    final modifiedById = <String, DateTime>{};
    if (isStreamSource && streamClient != null) {
      const page = 1000;
      for (var offset = 0; ; offset += page) {
        final songs = await streamClient!.getSongs(page, offset);
        if (songs == null) {
          throw StateError('server returned no song page');
        }
        if (songs.isEmpty) {
          break;
        }
        for (final song in songs) {
          found[song.id] = song;
          if (song.modified != null) {
            modifiedById[song.id] = song.modified!;
          }
        }
        if (songs.length < page) {
          break;
        }
      }
    } else {
      for (final folder in library.folderList) {
        await folder.setFileAndModified();
        for (final entry in folder.pathAndModified.entries) {
          final song = library.id2Song[entry.key];
          found[entry.key] = song ??
              MyAudioMetadata(
                AudioMetadata(
                  title: entry.key.split('/').last,
                  duration: null,
                ),
                id: entry.key,
                path: entry.key,
                modified: entry.value,
              );
          modifiedById[entry.key] = entry.value;
        }
      }
    }

    var changed = 0;
    var unchanged = 0;
    final addedIds = <String>{};
    final removedIds = <String>{};
    for (final id in found.keys) {
      final old = existing[id];
      if (old == null) {
        addedIds.add(id);
        continue;
      }
      final fresh = found[id]!;
      final freshModified = modifiedById[id] ?? fresh.modified;
      final differs =
          (fresh.title != null && old.title != fresh.title) ||
          (fresh.artist != null && old.artist != fresh.artist) ||
          (fresh.album != null && old.album != fresh.album) ||
          (freshModified != null && freshModified != old.modified);
      if (differs) {
        changed++;
      } else {
        unchanged++;
      }
    }
    for (final id in existing.keys) {
      if (!found.containsKey(id)) {
        removedIds.add(id);
      }
    }

    var cachedRemoved = 0;
    for (final id in removedIds) {
      final song = existing[id];
      if (song?.cacheExist == true) {
        cachedRemoved++;
      }
    }
    var playlistRefs = 0;
    for (final playlist in playlistManager.playlists) {
      for (final song in playlist.songList) {
        if (removedIds.contains(song.id)) {
          playlistRefs++;
        }
      }
    }

    final added = [
      for (final id in addedIds.take(100)) SyncPreviewItem.fromSong(found[id]!),
    ];
    final removed = [
      for (final id in removedIds.take(100))
        SyncPreviewItem.fromSong(existing[id]!),
    ];
    return SyncPreview(
      added: addedIds.length,
      removed: removedIds.length,
      changed: changed,
      unchanged: unchanged,
      cachedRemoved: cachedRemoved,
      playlistRefs: playlistRefs,
      addedSamples: added,
      removedSamples: removed,
      sourceLabel: sourceType.name,
    );
  }
}

final syncPreviewService = SyncPreviewService();
