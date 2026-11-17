import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:crypto/crypto.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/services/lyric.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/utils/path.dart';

class MyAudioMetadata {
  final String id;
  final String? coverId;

  String? path;
  DateTime? modified;

  /// When the song was added to the server library (`created` in Navidrome),
  /// used by the "added time" sort orders.
  DateTime? created;

  final AudioMetadata _audioMetadata;

  late MyPicture picture;

  ParsedLyrics? parsedLyrics;

  bool cacheExist = false;
  String? cachePath;

  String? lrcPath;

  final isFavoriteNotifier = ValueNotifier(false);
  final updateNotifier = ValueNotifier(0);

  int playCount;
  DateTime? lastPlayed;

  /// File size in bytes as the source reports it; null when it does not.
  int? size;

  /// The server's album/artist id for this song, used to star the album or the
  /// artist as a whole. Null when the source has no such notion.
  String? albumId;
  String? artistId;

  late String compareTitle;
  late String compareArtist;
  late String compareAlbum;

  int lyricsTimeOffset;

  MyAudioMetadata(
    this._audioMetadata, {
    required this.id,
    this.coverId,
    this.path,
    this.modified,
    this.created,
    this.playCount = 0,
    this.lastPlayed,
    this.size,
    this.albumId,
    this.artistId,
    this.lyricsTimeOffset = 0,
  }) {
    picture = MyPicture.form(isStreamSource ? coverId ?? id : path!);

    final md5Hash = md5.convert(utf8.encode(id)).toString();
    if (sourceType != .local) {
      cachePath = '${getCachesPath(sourceType)}/$md5Hash';
      cacheExist = File(cachePath!).existsSync();
      lrcPath = '${getLrcPath(sourceType)}/$md5Hash';
    }

    compareTitle = PinyinHelper.getPinyinE(getTitle(this));
    compareArtist = PinyinHelper.getPinyinE(getArtist(this));
    compareAlbum = PinyinHelper.getPinyinE(getAlbum(this));
  }

  String? get format => _audioMetadata.format;
  String? get title => _audioMetadata.title;
  String? get artist => _audioMetadata.artist;
  String? get album => _audioMetadata.album;
  String? get albumArtist => _audioMetadata.albumArtist;
  String? get genre => _audioMetadata.genre;

  int? get year => _audioMetadata.year;
  int? get track => _audioMetadata.track;
  int? get disc => _audioMetadata.disc;
  int? get bitrate => _audioMetadata.bitrate;
  int? get samplerate => _audioMetadata.samplerate;

  Duration? get duration => _audioMetadata.duration;

  String? get lyrics => _audioMetadata.lyrics;

  set title(String? value) => _audioMetadata.title = value;
  set artist(String? value) => _audioMetadata.artist = value;
  set album(String? value) => _audioMetadata.album = value;
  set albumArtist(String? value) => _audioMetadata.albumArtist = value;
  set genre(String? value) => _audioMetadata.genre = value;

  set year(int? value) => _audioMetadata.year = value;
  set track(int? value) => _audioMetadata.track = value;
  set disc(int? value) => _audioMetadata.disc = value;
  set bitrate(int? value) => _audioMetadata.bitrate = value;
  set samplerate(int? value) => _audioMetadata.samplerate = value;

  set lyrics(String? value) => _audioMetadata.lyrics = value;
  set duration(Duration? value) => _audioMetadata.duration = value;

  factory MyAudioMetadata.fromMap(
    Map<String, dynamic> song,
    SourceType sourceType,
  ) {
    if (sourceType == .navidrome) {
      return library.id2Song.putIfAbsent(
        song['id'],
        () => MyAudioMetadata(
          AudioMetadata(
            format: (song['contentType'] as String?)?.split('audio/').last,
            title: song['title'],
            artist: song['artist'],
            album: song['album'],
            albumArtist: song['displayAlbumArtist'],
            genre: song['genre'],
            year: song['year'],
            track: song['track'],
            disc: song['discNumber'],
            bitrate: song['bitRate'],
            samplerate: song['samplingRate'],
            duration: song['duration'] != null
                ? Duration(seconds: song['duration'])
                : null,
          ),
          id: song['id'],
          path: song['path'],
          created: song['created'] != null
              ? DateTime.tryParse(song['created'])
              : null,
          playCount: song['playCount'] as int? ?? 0,
          lastPlayed: song['played'] != null
              ? DateTime.parse(song['played'])
              : null,
          size: (song['size'] as num?)?.toInt(),
          albumId: song['albumId']?.toString(),
          artistId: song['artistId']?.toString(),
        ),
      );
    }

    if (sourceType == .feiniu) {
      // The server's createdAt only arrives with a fresh row, and the database
      // has no column for it, so a song that is already known has to be given it
      // here - otherwise sorting by added time falls back to the modified time.
      final created = _epochToDate(song['createdAt']);
      final item = library.id2Song.putIfAbsent(song['guid'], () {
        final audioSpec = song['audioSpec'] as Map? ?? const {};
        final album = song['album'] as Map? ?? const {};
        final artists = (song['artists'] as List?) ?? const [];
        final genres = (song['genres'] as List?) ?? const [];
        final durationMs = (song['duration'] ?? audioSpec['duration']) as num?;
        final bitrate = audioSpec['bitrate'] as num?;
        final releaseDate = DateTime.tryParse(album['releaseDate'] ?? '');

        return MyAudioMetadata(
          AudioMetadata(
            format: audioSpec['format'],
            title: song['title'],
            artist: artists.map((artist) => artist['name']).join('/'),
            album: album['name'],
            genre: genres.map((genre) => genre['name']).join('/'),
            year: (song['year'] as num?)?.toInt() ?? releaseDate?.year,
            track: (song['trackNo'] as num?)?.toInt(),
            disc: (song['discNo'] as num?)?.toInt(),
            // 飞牛时长为毫秒、码率为 bps；播放器码率统一使用 kbps。
            bitrate: bitrate == null ? null : (bitrate / 1000).round(),
            samplerate: (audioSpec['sampleRate'] as num?)?.toInt(),
            duration: durationMs == null
                ? null
                : Duration(milliseconds: durationMs.toInt()),
          ),
          id: song['guid'],
          coverId: song['coverId'],
          path: audioSpec['path'],
          size: (audioSpec['size'] as num?)?.toInt() ??
              (song['size'] as num?)?.toInt(),
          // fnOS reports createdAt, which is what "added time" means for this
          // source; it is what the server sorts by with sort=createdAt,desc.
          created: created,
        );
      });
      item.created ??= created;
      return item;
    }

    final created = _epochToDate(
      song['created'] is String ? null : song['created'],
    );
    final createdText = song['created'] is String
        ? DateTime.tryParse(song['created'])
        : _parseEmbyDate(song['DateCreated']);
    final userData = song['UserData'] is Map ? song['UserData'] as Map : const {};
    final lastPlayedText = _parseEmbyDate(userData['LastPlayedDate']);

    final item = library.id2Song.putIfAbsent(song['Id'], () {
      final mediaSources = (song['MediaSources'] as List?) ?? [];
      final primarySource = mediaSources.isNotEmpty ? mediaSources.first : null;
      final streams = (primarySource?['MediaStreams'] as List?) ?? [];

      final audioStream = streams.firstWhere(
        (s) => s['Type'] == 'Audio',
        orElse: () => null,
      );

      final lyricStream = streams.firstWhere(
        (s) => s['Type'] == 'Subtitle',
        orElse: () => null,
      );
      return MyAudioMetadata(
        AudioMetadata(
          format: audioStream?['Codec'] ?? primarySource?['Container'],

          title: song['Name'],

          artist: _namedList(song['ArtistItems']) ??
              (song['Artists'] as List?)?.join('/'),

          album: song['Album'],

          // Emby gives both the display string and the structured list; the
          // list keeps multi-artist albums readable.
          albumArtist:
              _namedList(song['AlbumArtists']) ?? song['AlbumArtist'],

          genre: (song['Genres'] as List?)?.join('/'),

          year: _asInt(song['ProductionYear']),

          track: _asInt(song['IndexNumber']),

          disc: _asInt(song['ParentIndexNumber']),

          // Emby reports the audio bitrate in bits per second, while the rest
          // of the app (and the song info page) uses kbps.
          bitrate: _kbps(audioStream?['BitRate'] ?? primarySource?['Bitrate']),

          samplerate: _asInt(audioStream?['SampleRate']),

          duration: song['RunTimeTicks'] != null
              ? Duration(microseconds: song['RunTimeTicks'] ~/ 10)
              : null,

          lyrics: lyricStream?['Extradata'],
        ),

        id: song['Id'],

        playCount: _asInt(userData['PlayCount']) ?? 0,

        // An unplayed song has no last-played time; epoch zero made it look
        // played in 1970 in the song info page.
        lastPlayed: lastPlayedText,

        size: _asInt(primarySource?['Size'] ?? song['Size']),

        albumId: song['AlbumId']?.toString(),

        artistId: (song['ArtistItems'] as List?)?.isNotEmpty == true
            ? song['ArtistItems'][0]['Id']?.toString()
            : song['AlbumArtistIds'] is List &&
                  (song['AlbumArtistIds'] as List).isNotEmpty
            ? song['AlbumArtistIds'][0]?.toString()
            : null,
      );
    });
    item.created ??= createdText ?? created;
    return item;
  }

  /// Parses an Emby timestamp (seven fractional digits, which Dart's own
  /// parser refuses); null for the placeholder dates Emby uses for "never".
  static DateTime? parseEmbyDate(Object? value) => _parseEmbyDate(value);

  @override
  String toString() {
    return "$_audioMetadata\n"
        "playCount:$playCount\n"
        "lastPlayed:$lastPlayed";
  }

  /// The same song under a new identity, for a file that was moved.
  ///
  /// The tags are shared (the object is immutable in practice), while the
  /// library-only state - play history, added time, size, favourite flag and
  /// the lyric offset - is carried over. The picture is rebuilt from the new
  /// path, which is what makes the cover cache migration in the organizer
  /// necessary.
  MyAudioMetadata cloneWithId(String newId, {String? newPath}) {
    final copy = MyAudioMetadata(
      _audioMetadata,
      id: newId,
      coverId: coverId,
      path: newPath ?? path,
      modified: modified,
      created: created,
      playCount: playCount,
      lastPlayed: lastPlayed,
      size: size,
      albumId: albumId,
      artistId: artistId,
      lyricsTimeOffset: lyricsTimeOffset,
    );
    copy.parsedLyrics = parsedLyrics;
    copy.cacheExist = cacheExist;
    copy.cachePath = cachePath;
    copy.lrcPath = lrcPath;
    copy.isFavoriteNotifier.value = isFavoriteNotifier.value;
    return copy;
  }
}

/// Emby's timestamps carry seven fractional digits (100 ns ticks), which Dart
/// refuses to parse - it accepts at most six. Trim the fraction before parsing
/// and treat the zero/placeholder dates Emby sends for "never" as null.
DateTime? _parseEmbyDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  var text = value;
  final dot = text.indexOf('.');
  if (dot >= 0) {
    var end = dot + 1;
    while (end < text.length) {
      final code = text.codeUnitAt(end);
      if (code < 48 || code > 57) {
        break;
      }
      end++;
    }
    if (end - dot - 1 > 6) {
      text = text.substring(0, dot + 7) + text.substring(end);
    }
  }
  final date = DateTime.tryParse(text);
  if (date == null || date.year <= 1) {
    return null;
  }
  return date;
}

/// The names of an Emby `ArtistItems` / `AlbumArtists` list, joined the same
/// way the other sources join multiple names.
String? _namedList(Object? value) {
  if (value is! List) {
    return null;
  }
  final names = [
    for (final item in value)
      if (item is Map && '${item['Name'] ?? ''}'.isNotEmpty)
        '${item['Name']}',
  ];
  return names.isEmpty ? null : names.join('/');
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

/// Emby reports bitrates in bps; the app displays kbps.
int? _kbps(Object? value) {
  final bps = _asInt(value);
  if (bps == null || bps <= 0) {
    return null;
  }
  return bps > 10000 ? bps ~/ 1000 : bps;
}

/// fnOS reports epoch milliseconds for createdAt / updatedAt, but seconds are
/// tolerated as well (they are three orders of magnitude apart).
DateTime? _epochToDate(Object? value) {
  if (value is! num) {
    return null;
  }
  final millis = value.toInt();
  if (millis <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(
    millis < 100000000000 ? millis * 1000 : millis,
  );
}
