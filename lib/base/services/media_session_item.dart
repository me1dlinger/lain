import 'package:audio_service/audio_service.dart';

/// Longest side of the artwork the media session carries.
///
/// A head unit renders the artwork as a small thumbnail it cannot open full
/// screen, so this is all the resolution it can use - and every broadcast track
/// changing the artwork then costs a thumbnail read instead of a decode of the
/// original.
const int mediaBroadcastThumbnailSide = 100;

/// Builds the item the system media session - and therefore the Android media
/// notification, Bluetooth/AVRCP and a car head unit - reads.
///
/// The mapping matters, because anything not set here never reaches the car:
///
/// * [MediaItem.title] / `artist` / `album` become the track metadata.
/// * [MediaItem.artUri] is what produces the notification's artwork bitmap;
///   it may be a `file://` URI, which only this process can read.
/// * `artCacheFile` in [MediaItem.extras] is a *local path* audio_service reads
///   itself and turns into the session's `ALBUM_ART` / `DISPLAY_ICON` bitmap -
///   so the artwork travels to the car inside the session metadata, with no
///   HTTP server, no LAN address and no content provider involved. This is the
///   path to prefer: it works for a local file with Wi-Fi switched off.
/// * `ALBUM_ART_URI` / `DISPLAY_ICON_URI` in [MediaItem.extras] are the URIs a
///   *car* fetches itself, so they must point at something reachable from the
///   head unit (the server's URL, or this phone on the LAN). Kept as a fallback
///   for units that read a URI instead of the bitmap.
/// * The current lyric line travels in extras (`android.media.metadata.LYRIC`)
///   and in the subtitle, which is the line a head unit renders.
/// * `loadThumbnailUri` in [MediaItem.extras] with a `THUMBNAIL_SIZE` makes
///   audio_service (Android 10+) read the artwork through
///   `ContentResolver.loadThumbnail` at that size instead of decoding the whole
///   image - the artwork a head unit shows is a thumbnail, so this is the size
///   the session should carry.
///
/// Kept as a pure function with only strings in, so the mapping can be unit
/// tested without a device, a car, or audio_service's platform channels.
///
/// The [id] is what a consumer caches the item (and its artwork) by, so a
/// published artwork must carry an id that changes when the artwork does:
/// [serviceMediaItemId] versions it.
MediaItem buildServiceMediaItem({
  required String id,
  required String songTitle,
  required String artist,
  required String album,
  Duration? duration,
  String? lyric,
  bool lyricInTitle = false,
  String? fileArtUri,
  String? artCacheFile,
  String? fetchableArtUri,
}) {
  // A blank line is not a lyric; publishing one would wipe the car's line.
  final line = (lyric != null && lyric.trim().isNotEmpty) ? lyric : null;

  // "Control Center Lyrics" decides which line carries the lyric: on = the
  // primary line (the iOS control centre and the notification's title), off =
  // the secondary line, which is what a head unit renders as the artist and
  // what the notification shows as its content text.
  final useLyricInTitle = lyricInTitle && line != null;
  final subtitle = useLyricInTitle ? artist : (line ?? artist);

  return MediaItem(
    id: id,
    title: useLyricInTitle ? line : songTitle,
    artist: subtitle,
    album: album,
    // A content:// URI is what audio_service reads asynchronously (and, on
    // Android 10+, through `loadThumbnail` at [mediaBroadcastThumbnailSide]).
    // A file:// URI is only published when no content URI could be resolved,
    // since audio_service hands that one to the platform on an unguarded async
    // path - see the note in the handler's artwork branch.
    artUri: (fileArtUri != null && fileArtUri.isNotEmpty)
        ? Uri.tryParse(fileArtUri)
        : null,
    duration: duration,
    displayTitle: useLyricInTitle ? line : songTitle,
    displaySubtitle: subtitle,
    displayDescription: album,
    extras: <String, dynamic>{
      // audio_service loads this file and puts the bitmap straight into the
      // session metadata; a head unit then gets the image itself. Only the
      // broadcast-sized copy is published: the original can be several
      // megabytes, and the car shows a thumbnail.
      if (artCacheFile != null && artCacheFile.isNotEmpty)
        'artCacheFile': artCacheFile,
      if (line != null) ...{
        'android.media.metadata.LYRIC': line,
        'android.media.metadata.LYRICS': line,
      },
      if (fetchableArtUri != null && fetchableArtUri.isNotEmpty) ...{
        'android.media.metadata.DISPLAY_ICON_URI': fetchableArtUri,
        'android.media.metadata.ALBUM_ART_URI': fetchableArtUri,
      },
      // A bitmap the platform should read at thumbnail size. Android 10+ asks
      // the content provider for a thumbnail at this size instead of decoding
      // the original, which is what keeps a cover change cheap to broadcast.
      if (fileArtUri != null && fileArtUri.isNotEmpty) ...{
        'loadThumbnailUri': fileArtUri,
        'android.media.metadata.THUMBNAIL_SIZE': {
          'width': mediaBroadcastThumbnailSide,
          'height': mediaBroadcastThumbnailSide,
        },
      },
    },
  );
}

/// The item id the session gets for [songId]'s [artworkVersion].
///
/// A head unit (and audio_service's own bitmap cache) keys artwork off the
/// item, so the same song published with a *different* cover must not reuse the
/// id: that is how a cover that arrived late - or one that was rebuilt after a
/// failure - never reached the car. The version is folded in only once there is
/// artwork, so the plain song id is kept for a track with none.
String serviceMediaItemId(String songId, String? artworkVersion) {
  if (artworkVersion == null || artworkVersion.isEmpty) {
    return songId;
  }
  return '$songId#art:$artworkVersion';
}