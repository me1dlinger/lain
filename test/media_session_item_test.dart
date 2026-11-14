import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/services/media_session_item.dart';

/// The car reads the media session, not the app, so these are the fields that
/// decide what it shows. Testing them here means the mapping can be checked
/// without a phone, a head unit, or a server.
void main() {
  MediaItem item({
    String? lyric,
    bool lyricInTitle = false,
    String? fileArtUri,
    String? artCacheFile,
    String? fetchableArtUri,
  }) {
    return buildServiceMediaItem(
      id: 'song-1',
      songTitle: 'Title',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(seconds: 200),
      lyric: lyric,
      lyricInTitle: lyricInTitle,
      fileArtUri: fileArtUri,
      artCacheFile: artCacheFile,
      fetchableArtUri: fetchableArtUri,
    );
  }

  test('without a lyric the track metadata carries no lyric at all', () {
    final result = item();

    expect(result.title, 'Title');
    expect(result.artist, 'Artist');
    expect(result.album, 'Album');
    expect(result.extras?.containsKey('android.media.metadata.LYRIC'), isFalse);
    expect(result.extras?.containsKey('android.media.metadata.LYRICS'), isFalse);
  });

  test('with broadcasting off a lyric is not published at all', () {
    final result = item(lyric: 'line one');

    expect(result.title, 'Title');
    expect(result.artist, 'Artist');
    expect(result.displaySubtitle, 'Artist');
    expect(result.extras?.containsKey('android.media.metadata.LYRIC'), isFalse);
    expect(result.extras?.containsKey('android.media.metadata.LYRICS'), isFalse);
  });

  test('with broadcasting on the lyric is the title and the identity the artist', () {
    final result = item(lyric: 'line one', lyricInTitle: true);

    expect(result.title, 'line one');
    expect(result.artist, 'Artist - Title');
    expect(result.displayTitle, 'line one');
    expect(result.displaySubtitle, 'Artist - Title');
    expect(result.extras?['android.media.metadata.LYRIC'], 'line one');
  });

  test('a track without a lyric line keeps its own title', () {
    final result = item(lyricInTitle: true);

    expect(result.title, 'Title');
    expect(result.artist, 'Artist - Title');
  });

  test('a blank lyric is treated as no lyric', () {
    final result = item(lyric: '   ', lyricInTitle: true);

    expect(result.title, 'Title');
    expect(result.artist, 'Artist - Title');
    expect(result.extras?.containsKey('android.media.metadata.LYRIC'), isFalse);
  });

  test('a fetchable URI is published for the car, the local one only for us',
      () {
    final result = item(
      fileArtUri: 'file:///data/user/0/app/covers/abc',
      fetchableArtUri: 'http://192.168.1.5:41234/cover/token',
    );

    expect(result.artUri.toString(), 'file:///data/user/0/app/covers/abc');
    expect(
      result.extras?['android.media.metadata.ALBUM_ART_URI'],
      'http://192.168.1.5:41234/cover/token',
    );
    expect(
      result.extras?['android.media.metadata.DISPLAY_ICON_URI'],
      'http://192.168.1.5:41234/cover/token',
    );
  });

  test('no fetchable URI yet means no car artwork keys, not an empty one', () {
    final result = item(fileArtUri: 'file:///data/app/covers/abc');

    expect(result.extras?.containsKey('android.media.metadata.ALBUM_ART_URI'),
        isFalse);
    expect(result.extras?.containsKey('android.media.metadata.DISPLAY_ICON_URI'),
        isFalse);
  });

  test('a lyric update keeps the artwork it was given', () {
    const art = 'http://192.168.1.5:41234/cover/token';
    final before = item(fetchableArtUri: art);
    final after = item(
      lyric: 'line two',
      lyricInTitle: true,
      fetchableArtUri: art,
    );

    // This is the regression behind "the cover appears and then vanishes": a
    // lyric-line publish must carry the same artwork, not drop it.
    expect(after.extras?['android.media.metadata.ALBUM_ART_URI'], art);
    expect(after.extras?['android.media.metadata.LYRIC'], 'line two');
    expect(after.title, 'line two');
    expect(before.artist, 'Artist');
  });

  test('a local cover file is handed to audio_service as a bitmap source', () {
    // audio_service decodes `artCacheFile` itself and puts the bitmap into the
    // session metadata, so the car needs no HTTP server, no LAN address and no
    // content provider - the artwork travels with the session.
    final result = item(artCacheFile: '/data/user/0/app/covers/abc');

    expect(result.extras?['artCacheFile'], '/data/user/0/app/covers/abc');
  });

  test('no local cover means no bitmap source', () {
    final result = item();

    expect(result.extras?.containsKey('artCacheFile'), isFalse);
  });
}