import 'package:audio_service/audio_service.dart';

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
///
/// Kept as a pure function with only strings in, so the mapping can be unit
/// tested without a device, a car, or audio_service's platform channels.
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
    artUri: (fileArtUri != null && fileArtUri.isNotEmpty)
        ? Uri.tryParse(fileArtUri)
        : null,
    duration: duration,
    displayTitle: useLyricInTitle ? line : songTitle,
    displaySubtitle: subtitle,
    displayDescription: album,
    extras: <String, dynamic>{
      // audio_service loads this file and puts the bitmap straight into the
      // session metadata; a head unit then gets the image itself.
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
    },
  );
}