import 'dart:io';
import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/artist_album.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/lyric.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/services/webdav_client.dart';
import 'package:lain/base/utils/contrast_color_generator.dart';
import 'package:lain/base/widgets/lyric_list_view.dart';
import 'package:lain/layer/layers_manager.dart';

/// Writes one local song's tags and brings everything that shows them back up
/// to date.
///
/// The metadata editor and the scraper both write tags, and the sequence after
/// the platform call (re-parse the lyrics, refresh the cover, update the
/// database and the theme) has to be the same for both - otherwise a scraped
/// cover would keep showing the old cached file while an edited one did not.
///
/// Every field is written as a whole: a field passed as null is left at its
/// current value, and a cover is only replaced when [pictureBytes] is given.
/// Returns whether the tags were written.
Future<bool> writeSongTags({
  required MyAudioMetadata song,
  String? title,
  String? artist,
  String? album,
  String? albumArtist,
  String? genre,
  String? lyrics,
  int? year,
  int? track,
  int? disc,
  Uint8List? pictureBytes,
  bool lyricsChanged = false,

  /// Removes the embedded cover instead of keeping it; used when restoring a
  /// song that had no cover before a scrape.
  bool deletePicture = false,

  /// Takes the numeric fields exactly as passed, including null. A normal edit
  /// keeps the current value when a field is null (a half-filled form must not
  /// wipe a track number); restoring a snapshot must be able to put null back.
  bool exactNumbers = false,
}) async {
  final path = song.path;
  if (path == null || path.isEmpty) {
    return false;
  }

  final finalTitle = title ?? song.title ?? '';
  final finalArtist = artist ?? song.artist ?? '';
  final finalAlbum = album ?? song.album ?? '';
  final finalAlbumArtist = albumArtist ?? song.albumArtist ?? '';
  final finalGenre = genre ?? song.genre ?? '';
  final finalLyrics = lyrics ?? song.lyrics ?? '';
  final finalYear = exactNumbers ? year : (year ?? song.year);
  final finalTrack = exactNumbers ? track : (track ?? song.track);
  final finalDisc = exactNumbers ? disc : (disc ?? song.disc);

  late bool success;
  try {
    success = writeMetadata(
      path: path,
      title: finalTitle,
      artist: finalArtist,
      album: finalAlbum,
      albumArtist: finalAlbumArtist,
      genre: finalGenre,
      year: finalYear,
      track: finalTrack,
      disc: finalDisc,
      lyrics: finalLyrics,
      pictureBytes: pictureBytes,
      deletePicture: deletePicture,
      headers: sourceType == .webdav ? webdavClient?.headers : null,
    );
  } catch (e) {
    logger.output('[metadata] write failed for $path: $e');
    success = false;
  }
  if (!success) {
    return false;
  }

  song.modified = DateTime.now();
  if (song.cacheExist && song.cachePath != null) {
    try {
      final cached = File(song.cachePath!);
      if (await cached.exists()) {
        await cached.delete();
      }
    } catch (e) {
      logger.output('[metadata] cached audio could not be dropped: $e');
    }
    song.cacheExist = false;
  }

  song.title = finalTitle;
  song.artist = finalArtist;
  song.album = finalAlbum;
  song.albumArtist = finalAlbumArtist;
  song.genre = finalGenre;
  song.lyrics = finalLyrics;
  song.parsedLyrics = null;
  await setParsedLyrics(song);
  song.year = finalYear;
  song.track = finalTrack;
  song.disc = finalDisc;

  await library.updateMetadata(song);

  if (pictureBytes != null || deletePicture) {
    // The cached picture file is what every cover widget reads first, so a new
    // tag is not enough: with the old file still there the UI kept showing the
    // previous artwork until the app was restarted.
    invalidateCoverFile(song.picture);
  } else {
    song.picture.reset();
  }
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.clear();
  imageCache.clearLiveImages();

  await computeColor(song.picture);
  if (song == currentSongNotifier.value) {
    currentCoverArtColor = song.picture.color!;
    contrastColorTheme = ContrastColorGenerator.generate(currentCoverArtColor);
    colorManager.updateLyricsPageColors();
  }
  artistAlbumManager.updateArtistAlbum();

  song.updateNotifier.value++;
  song.picture.changeNotifier.value++;
  layersManager.updateBackground();
  if (lyricsChanged && song == currentSongNotifier.value) {
    updateLyricsNotifier.value++;
  }

  return true;
}

/// The tags and cover a song had before a scrape, for the single-step undo.
class SongMetadataSnapshot {
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final String genre;
  final String lyrics;
  final int? year;
  final int? track;
  final int? disc;
  final Uint8List? coverBytes;
  final bool hadCover;

  const SongMetadataSnapshot({
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.genre,
    required this.lyrics,
    required this.coverBytes,
    required this.hadCover,
    this.year,
    this.track,
    this.disc,
  });
}

/// Captures what [song] currently carries. The cover is read from the cached
/// picture file, loading it first when the app has not needed it yet.
Future<SongMetadataSnapshot> captureSongMetadata(MyAudioMetadata song) async {
  await loadPictureSafe(song.picture);
  Uint8List? coverBytes;
  final picturePath = song.picture.path;
  if (picturePath.isNotEmpty) {
    try {
      final file = File(picturePath);
      if (await file.exists()) {
        coverBytes = await file.readAsBytes();
      }
    } catch (e) {
      logger.output('[metadata] could not read the old cover: $e');
    }
  }
  return SongMetadataSnapshot(
    title: song.title ?? '',
    artist: song.artist ?? '',
    album: song.album ?? '',
    albumArtist: song.albumArtist ?? '',
    genre: song.genre ?? '',
    lyrics: song.lyrics ?? '',
    year: song.year,
    track: song.track,
    disc: song.disc,
    coverBytes: coverBytes,
    hadCover: coverBytes != null,
  );
}

/// Puts a captured snapshot back, including removing a cover the scrape added.
Future<bool> restoreSongMetadata(
  MyAudioMetadata song,
  SongMetadataSnapshot snapshot,
) {
  return writeSongTags(
    song: song,
    title: snapshot.title,
    artist: snapshot.artist,
    album: snapshot.album,
    albumArtist: snapshot.albumArtist,
    genre: snapshot.genre,
    lyrics: snapshot.lyrics,
    year: snapshot.year,
    track: snapshot.track,
    disc: snapshot.disc,
    pictureBytes: snapshot.hadCover ? snapshot.coverBytes : null,
    deletePicture: !snapshot.hadCover,
    lyricsChanged: true,
    exactNumbers: true,
  );
}

/// The single-step undo of the last scrape application.
///
/// One application can cover several songs (a batch), so the undo restores all
/// of them together. Recording a new application replaces whatever was there:
/// there is one step of history, like the organizer.
class ScrapeUndo {
  final List<(MyAudioMetadata, SongMetadataSnapshot)> _entries = [];

  bool get canUndo => _entries.isNotEmpty;
  int get count => _entries.length;

  void record(Iterable<(MyAudioMetadata, SongMetadataSnapshot)> entries) {
    _entries
      ..clear()
      ..addAll(entries);
  }

  void clear() => _entries.clear();

  Future<bool> undo() async {
    if (_entries.isEmpty) {
      return false;
    }
    var allRestored = true;
    for (final entry in _entries) {
      final ok = await restoreSongMetadata(entry.$1, entry.$2);
      if (!ok) {
        allRestored = false;
      }
    }
    if (allRestored) {
      _entries.clear();
    }
    return allRestored;
  }
}

final scrapeUndo = ScrapeUndo();

/// Whether [bytes] look like a cover the tag can carry: JPEG or PNG, no larger
/// than 5 MB. Anything else is skipped rather than written into the file.
bool isValidCoverBytes(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    return false;
  }
  if (bytes.length >= 3) {
    final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    if (isJpeg) {
      return true;
    }
  }
  if (bytes.length >= 8) {
    const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (var i = 0; i < pngSignature.length; i++) {
      if (bytes[i] != pngSignature[i]) {
        return false;
      }
    }
    return true;
  }
  return false;
}
