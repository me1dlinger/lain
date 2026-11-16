import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/library.dart';
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
    List<MyAudioMetadata>? songs;
    if (useServerRandomNotifier.value &&
        isStreamSource &&
        !library.cachedOnly &&
        streamClient != null) {
      songs = await streamClient!.getRandomSongs(randomShelfSize);
    }
    if (songs == null || songs.isEmpty) {
      final pool = List<MyAudioMetadata>.from(library.songList);
      if (pool.isEmpty) {
        randomSongsNotifier.value = [];
        randomSongsChangeNotifier.value++;
        _loadedSource = sourceType;
        return;
      }
      pool.shuffle();
      songs = pool.take(randomShelfSize).toList();
    }
    randomSongsNotifier.value = songs;
    randomSongsChangeNotifier.value++;
    _loadedSource = sourceType;
  } catch (e) {
    logger.output('[random] $e');
    if (randomSongsNotifier.value.isEmpty) {
      final pool = List<MyAudioMetadata>.from(library.songList)..shuffle();
      randomSongsNotifier.value = pool.take(randomShelfSize).toList();
      randomSongsChangeNotifier.value++;
      _loadedSource = sourceType;
    }
  } finally {
    _loading = false;
  }
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
