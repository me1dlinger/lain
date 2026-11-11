import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/artist_album.dart';
import 'package:lain/base/widgets/song_list.dart';

class SingleAlbumLayer extends StatelessWidget {
  final Album album;
  final bool isHomeDetaile;

  /// Label of the page this detail is mounted on, when it is not the album list
  /// (opening an album from a song list keeps the list behind it).
  final String? mountedOnLabel;

  const SingleAlbumLayer({
    super.key,
    required this.album,
    this.isHomeDetaile = false,
    this.mountedOnLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SongList(
      album: album,
      isRoot: false,
      isHomeDetail: isHomeDetaile,
      mountedOnLabel: mountedOnLabel,
    );
  }
}