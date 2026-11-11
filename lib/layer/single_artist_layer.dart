import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/artist_album.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/song_list.dart';

class SingleArtistLayer extends StatelessWidget {
  final Artist artist;

  /// Label of the page this detail is mounted on, when it is not the artist
  /// list (opening an artist from a song list keeps the list behind it).
  final String? mountedOnLabel;

  const SingleArtistLayer({
    super.key,
    required this.artist,
    this.mountedOnLabel,
  });

  /// The artist's songs as the page shows them. [Artist.songList] is built
  /// once, when the library is classified; a song whose tags were edited
  /// since then is no longer credited here, and one edited *into* the artist
  /// is not in the list yet. Deciding membership again on every build keeps the
  /// page, the artist list and the album grouping in agreement.
  List<MyAudioMetadata> get songs =>
      artist.songList.where((song) => songByArtist(song, artist.name)).toList();

  @override
  Widget build(BuildContext context) {
    return SongList(
      artist: artist,
      songListOverride: songs,
      isRoot: false,
      mountedOnLabel: mountedOnLabel,
    );
  }
}
