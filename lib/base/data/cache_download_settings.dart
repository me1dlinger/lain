import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/stream_quality.dart';

/// When the app keeps a streamed song on disk without being asked.
///
/// Manual downloads (the download button, the cache dialog) are not affected:
/// these settings only decide what happens automatically while playing and
/// while a list is opened. Anything already cached is still read, whether or
/// not the switch is on.
final autoCacheSongsNotifier = ValueNotifier<bool>(true);
final autoCachePlaylistsNotifier = ValueNotifier<bool>(true);
final autoCacheArtistsNotifier = ValueNotifier<bool>(true);

/// Downloads the queue's next track before it is needed, so a skip starts
/// instantly even on a slow connection. Independent of
/// [autoCacheSongsNotifier]: it only warms the one track that is about to play.
final prefetchNextSongNotifier = ValueNotifier<bool>(true);

/// Where cached audio, covers and lyrics live. Empty means the app's own
/// support directory (`<support>/<source>/{caches,pictures,lyrics}`); a value
/// here is used as the root and the source folder is still created inside it.
final cacheDirNotifier = ValueNotifier<String>('');

/// Where downloaded songs are written. Empty means the platform default
/// (`Download/Lain` on Android, `<documents>/Lain` elsewhere).
final downloadDirNotifier = ValueNotifier<String>('');

/// The cache limit in gigabytes; zero means no limit.
final cacheLimitGbNotifier = ValueNotifier<int>(2);

/// Whether a download may run over mobile data. Off means a task added on a
/// cellular connection waits for Wi-Fi.
final downloadOnMobileDataNotifier = ValueNotifier<bool>(false);

/// The bitrate a manual download is fetched at; [StreamQuality.original] keeps
/// the server's own file.
final downloadQualityNotifier = ValueNotifier<StreamQuality>(
  StreamQuality.original,
);

/// Labels for [cacheLimitGbNotifier]'s choices, in the order the dialog shows
/// them. Kept here so the settings page and the enforcement agree on the set.
const List<int> cacheLimitChoices = [0, 1, 2, 5, 8];
