/// One song of a queue the server stores for this user.
///
/// The raw entry is kept intact though only the id is used to resolve it
/// locally: a server may report a song the library has never synced, and the
/// rest of the entry is what a later fallback could play from.
class CloudQueueTrack {
  final String id;
  final Map<String, dynamic> raw;

  const CloudQueueTrack(this.id, this.raw);
}

/// An OpenSubsonic play-queue snapshot (`getPlayQueue`).
///
/// The server keeps one queue per user, shared by every app that logs in with
/// that user - that is what makes continuing on another device possible.
class CloudPlayQueue {
  final List<CloudQueueTrack> tracks;
  final String? currentId;
  final Duration position;
  final String? username;
  final DateTime? changed;
  final String? changedBy;

  const CloudPlayQueue({
    this.tracks = const [],
    this.currentId,
    this.position = Duration.zero,
    this.username,
    this.changed,
    this.changedBy,
  });

  static const empty = CloudPlayQueue();

  bool get isEmpty => tracks.isEmpty;

  /// Reads the `playQueue` element of a Subsonic response. A server that has
  /// no queue for this user returns an empty element or none at all; both are
  /// a valid, empty snapshot rather than an error.
  factory CloudPlayQueue.fromSubsonic(dynamic data) {
    if (data is! Map) {
      return empty;
    }

    final tracks = <CloudQueueTrack>[];
    final entries = data['entry'];
    if (entries is List) {
      for (final entry in entries) {
        if (entry is! Map) {
          continue;
        }
        final id = _idText(entry['id']);
        if (id == null) {
          continue;
        }
        tracks.add(CloudQueueTrack(id, entry.cast<String, dynamic>()));
      }
    }

    final positionMs = _intValue(data['position']) ?? 0;
    return CloudPlayQueue(
      tracks: tracks,
      currentId: _idText(data['current']),
      position: Duration(milliseconds: positionMs < 0 ? 0 : positionMs),
      username: _text(data['username']),
      changed: DateTime.tryParse('${data['changed'] ?? ''}'),
      changedBy: _text(data['changedBy']),
    );
  }
}

/// A queue snapshot ready to send to `savePlayQueue`.
///
/// Large queues are sent as a window around the current song: every queue id
/// becomes a query parameter, and a whole 30 000-song library would be a URL
/// no server should have to parse.
class CloudQueueSnapshot {
  final List<String> songIds;
  final String? currentId;
  final Duration position;

  const CloudQueueSnapshot({
    this.songIds = const [],
    this.currentId,
    this.position = Duration.zero,
  });

  static const int defaultMaxIds = 500;

  bool get isEmpty => songIds.isEmpty;

  static CloudQueueSnapshot fromQueue(
    List<String> songIds, {
    required int index,
    Duration position = Duration.zero,
    int maxIds = defaultMaxIds,
  }) {
    if (songIds.isEmpty) {
      return const CloudQueueSnapshot();
    }

    final currentIndex = index < 0 ? 0 : index.clamp(0, songIds.length - 1);
    // A negative index is the app's "nothing is playing yet"; the queue is
    // still worth remembering, without claiming a current song.
    final currentId = index < 0 ? null : songIds[currentIndex];
    if (maxIds <= 0 || songIds.length <= maxIds) {
      return CloudQueueSnapshot(
        songIds: List.unmodifiable(songIds),
        currentId: currentId,
        position: position,
      );
    }

    var start = currentIndex - maxIds ~/ 2;
    start = start.clamp(0, songIds.length - maxIds);
    return CloudQueueSnapshot(
      songIds: List.unmodifiable(songIds.sublist(start, start + maxIds)),
      currentId: currentId,
      position: position,
    );
  }

  /// Identifies this snapshot for change detection. The position is bucketed
  /// so every seek or playback second does not count as a new queue.
  String get signature =>
      '${songIds.join('\u0001')}|$currentId|${position.inSeconds ~/ 10}';
}

/// What a server queue resolves to inside the local library.
class CloudQueueRestore<T> {
  final List<T> songs;
  final int index;
  final int missing;
  final Duration position;

  const CloudQueueRestore({
    required this.songs,
    required this.index,
    required this.missing,
    required this.position,
  });

  bool get isEmpty => songs.isEmpty;
  int get count => songs.length;
}

/// Maps a server queue onto local items through [lookup].
///
/// Items the lookup cannot resolve (the library does not know them, or offline
/// mode has no file) are skipped; the queue keeps its order and the current
/// song becomes the first playable one when the server's current song is
/// missing.
CloudQueueRestore<T> resolveCloudQueue<T>(
  CloudPlayQueue queue,
  T? Function(String id) lookup,
) {
  final songs = <T>[];
  final positions = <String, int>{};

  for (final track in queue.tracks) {
    final song = lookup(track.id);
    if (song == null) {
      continue;
    }
    positions[track.id] = songs.length;
    songs.add(song);
  }

  var index = 0;
  if (songs.isNotEmpty && queue.currentId != null) {
    index = (positions[queue.currentId] ?? 0).clamp(0, songs.length - 1);
  }

  return CloudQueueRestore<T>(
    songs: songs,
    index: index,
    missing: queue.tracks.length - songs.length,
    position: queue.position,
  );
}

String? _idText(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

String? _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _intValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}');
}
