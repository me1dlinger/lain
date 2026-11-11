import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/artist_album.dart';
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

  @override
  Widget build(BuildContext context) {
    return SongList(
      artist: artist,
      isRoot: false,
      mountedOnLabel: mountedOnLabel,
    );
  }
}