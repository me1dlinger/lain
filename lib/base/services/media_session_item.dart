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
/// * [MediaItem.title] / `artist` / `album` become the track metadata. With
///   broadcasting off, title is the song and artist is the performer; with it
///   on, title is the current lyric line and artist is `<< artist - title >>`,
///   so the unit always shows both the line and which song it belongs to.
/// * `artCacheFile` in [MediaItem.extras] is a *local path* audio_service reads
///   itself and turns into the session's `ALBUM_ART` / `DISPLAY_ICON` bitmap -
///   the artwork travels to the car inside the session metadata, with no HTTP
///   server, no LAN address and no content provider involved. It carries the
///   broadcast-sized JPEG, so a cover update is a few kilobytes, not the
///   original several megabytes. This is the path every phone uses.
/// * [MediaItem.artUri] is only set on desktop, where the media integration
///   reads the file itself.
/// * The current lyric line also travels in extras
///   (`android.media.metadata.LYRIC`), for units that render the lyric field.
/// * `ALBUM_ART_URI` / `DISPLAY_ICON_URI` are deliberately not published when a
///   local bitmap exists: two artwork sources make a unit re-fetch the image on
///   every metadata update, and the bitmap is already in the session.
///
/// Kept as a pure function with only strings in, so the mapping can be unit
/// tested without a device, a car, or audio_service's platform channels.
///
/// The [id] is the track's own id and stays the same for every publish of that
/// track, artwork included: an artwork that arrives after the first publish is
/// a metadata change, not a new item. A changing media id means "another
/// track" to a head unit, which costs a redraw and, on some units, another
/// cover transfer for nothing.
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
  // A blank line is not a lyric, and with broadcasting off the line is not
  // published at all: the head unit gets the track's own metadata and nothing
  // that would make it re-read the item on every lyric tick.
  final line = (lyricInTitle && lyric != null && lyric.trim().isNotEmpty)
      ? lyric
      : null;

  // Broadcasting lyrics means the head unit's two text lines are used for what
  // a driver can actually read at a glance: the current lyric line on the
  // primary line, and the song identity - "artist - title" - on the secondary
  // one. A track that has not reached its first lyric line yet keeps its title
  // on the primary line, so the unit never shows a blank while it waits.
  final lyricsOn = lyricInTitle;
  final titleText = (lyricsOn && line != null) ? line : songTitle;
  final artistText = lyricsOn ? '<< $artist - $songTitle >>' : artist;

  return MediaItem(
    id: id,
    title: titleText,
    artist: artistText,
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
    displayTitle: titleText,
    displaySubtitle: artistText,
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
