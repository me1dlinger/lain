import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/playback_journal.dart';
import 'package:lain/base/data/recommendation_weights.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/my_audio_metadata.dart';

/// The home page's random shelf, and the page it opens.
///
/// When "use server random" is on and the source can answer it, the list comes
/// from the server, which draws from its whole library. Otherwise it is 100
/// songs drawn from the songs already saved on this device - the same set a
/// server would have after a sync, without a request per refresh.
final randomSongsNotifier = ValueNotifier<List<MyAudioMetadata>>([]);

/// Bumped whenever the list is replaced, for pages that only listen to a
/// version counter.
final randomSongsChangeNotifier = ValueNotifier<int>(0);

final useServerRandomNotifier = ValueNotifier<bool>(true);

const randomShelfSize = 100;

SourceType? _loadedSource;
bool _loading = false;

/// Fills the shelf if it is empty or the source changed. [force] draws a new
/// set even when one is already shown.
Future<void> refreshRandomSongs({bool force = false}) async {
  if (_loading) {
    return;
  }
  if (!force &&
      randomSongsNotifier.value.isNotEmpty &&
      _loadedSource == sourceType) {
    return;
  }
  _loading = true;
  try {
    final signals = await _skipAwareSignals();
    List<MyAudioMetadata>? songs;
    if (useServerRandomNotifier.value &&
        isStreamSource &&
        !library.cachedOnly &&
        streamClient != null) {
      songs = await streamClient!.getRandomSongs(randomShelfSize);
      if (signals != null && songs != null && songs.isNotEmpty) {
        songs = _softenServerList(songs, signals);
      }
    }
    if (songs == null || songs.isEmpty) {
      final pool = List<MyAudioMetadata>.from(library.songList);
      if (pool.isEmpty) {
        randomSongsNotifier.value = [];
        randomSongsChangeNotifier.value++;
        _loadedSource = sourceType;
        return;
      }
      songs = _drawLocal(pool, signals);
    }
    randomSongsNotifier.value = songs;
    randomSongsChangeNotifier.value++;
    _loadedSource = sourceType;
  } catch (e) {
    logger.output('[random] $e');
    if (randomSongsNotifier.value.isEmpty) {
      final pool = List<MyAudioMetadata>.from(library.songList);
      randomSongsNotifier.value = _drawLocal(pool, null);
      randomSongsChangeNotifier.value++;
      _loadedSource = sourceType;
    }
  } finally {
    _loading = false;
  }
}

/// The journal view used for skip-aware draws, or null when the setting is
/// off or nothing has been listened to yet.
Future<ListeningSignals?> _skipAwareSignals() async {
  if (!skipAwareRecommendationsNotifier.value) {
    return null;
  }
  await playbackJournal.ensureLoaded();
  final key = playbackJournal.sourceKey;
  final signals = ListeningSignals.fromJournal(
    playbackJournal.sessions.where((session) => session.sourceKey == key),
  );
  return signals.bySongId.isEmpty ? null : signals;
}

List<MyAudioMetadata> _drawLocal(
  List<MyAudioMetadata> pool,
  ListeningSignals? signals,
) {
  return weightedSample(
    pool,
    (song) => signals?.weightMultiplier(song.id) ?? 1,
    min(randomShelfSize, pool.length),
    Random(),
  );
}

/// A server draws the random set itself, so the local contribution is to
/// reorder it by weight and, when a song has been skipped severely, drop it
/// and fill the place from the saved library. A weighted draw keeps the same
/// songs visible but moves heavy skips behind songs that are actually heard.
List<MyAudioMetadata> _softenServerList(
  List<MyAudioMetadata> songs,
  ListeningSignals signals,
) {
  final kept = <MyAudioMetadata>[];
  var removed = 0;
  for (final song in songs) {
    if (signals.weightMultiplier(song.id) < 0.45) {
      removed++;
    } else {
      kept.add(song);
    }
  }
  if (removed == 0) {
    return weightedSample(
      songs,
      (song) => signals.weightMultiplier(song.id),
      songs.length,
      Random(),
    );
  }
  if (kept.length >= randomShelfSize) {
    return kept;
  }
  final present = {for (final song in kept) song.id};
  final pool = [
    for (final song in library.songList)
      if (!present.contains(song.id)) song,
  ];
  if (pool.isEmpty) {
    return kept;
  }
  final fill = weightedSample(
    pool,
    (song) => signals.weightMultiplier(song.id),
    min(randomShelfSize - kept.length, pool.length),
    Random(),
  );
  final combined = [...kept, ...fill];
  return weightedSample(
    combined,
    (song) => signals.weightMultiplier(song.id),
    combined.length,
    Random(),
  );
}

/// A source change invalidates the set: the next visit redraws it from the new
/// library.
void invalidateRandomSongs() {
  _loadedSource = null;
  if (randomSongsNotifier.value.isNotEmpty) {
    randomSongsNotifier.value = [];
    randomSongsChangeNotifier.value++;
  }
}
