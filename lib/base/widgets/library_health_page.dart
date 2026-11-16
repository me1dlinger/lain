import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/metadata_completion_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// A read-only report of the local library: songs with incomplete tags, no
/// cover or no lyrics, and groups that look like the same track stored twice.
/// It changes nothing on disk; the song menu opened from a row is where any
/// edit or removal happens.
class LibraryHealthPage extends StatefulWidget {
  const LibraryHealthPage({super.key});

  @override
  State<LibraryHealthPage> createState() => _LibraryHealthPageState();
}

class _LibraryHealthPageState extends State<LibraryHealthPage> {
  int _filter = 0;

  static const _filters = [0, 1, 2, 3];

  List<MyAudioMetadata> get _songs => [
    for (final song in library.songList)
      if (song.path != null) song,
  ];

  List<MyAudioMetadata> _missingTags(List<MyAudioMetadata> songs) => [
    for (final song in songs)
      if (songHasMissingTags(song)) song,
  ];

  List<MyAudioMetadata> _missingCover(List<MyAudioMetadata> songs) => [
    for (final song in songs)
      if (songHasMissingCover(song)) song,
  ];

  List<MyAudioMetadata> _missingLyrics(List<MyAudioMetadata> songs) => [
    for (final song in songs)
      if (songHasMissingLyrics(song)) song,
  ];

  String _duplicateKey(MyAudioMetadata song) {
    final title = getTitle(song)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final artist = getArtist(song).toLowerCase().trim();
    final seconds = song.duration?.inSeconds ?? 0;
    // A different edit or live version is usually more than a few seconds
    // apart, so the duration bucket keeps those out of one group.
    final bucket = seconds <= 0 ? 0 : seconds ~/ 5;
    return '$title|$artist|$bucket';
  }

  List<List<MyAudioMetadata>> _duplicateGroups(List<MyAudioMetadata> songs) {
    final groups = <String, List<MyAudioMetadata>>{};
    for (final song in songs) {
      if (getTitle(song).trim().isEmpty || getArtist(song).trim().isEmpty) {
        continue;
      }
      groups.putIfAbsent(_duplicateKey(song), () => []).add(song);
    }
    final result = [
      for (final group in groups.values)
        if (group.length > 1) group,
    ];
    result.sort(
      (a, b) => getTitle(a.first).compareTo(getTitle(b.first)),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return opaqueSettingsPage(
      context: context,
      title: l10n.libraryHealth,
      body: ListenableBuilder(
        listenable: library.changeNotifier,
        builder: (context, child) {
          final songs = _songs;
          final noTags = _missingTags(songs);
          final noCover = _missingCover(songs);
          final noLyrics = _missingLyrics(songs);
          final duplicates = _duplicateGroups(songs);
          final textColor = colorManager.getSpecificTextColor();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                child: appleSegmented<int>(
                  _filters,
                  (value) => switch (value) {
                    0 => '${l10n.healthMissingTags} ${noTags.length}',
                    1 => '${l10n.healthMissingCover} ${noCover.length}',
                    2 => '${l10n.healthMissingLyrics} ${noLyrics.length}',
                    _ => '${l10n.healthDuplicates} ${duplicates.length}',
                  },
                  _filter,
                  (value) => setState(() => _filter = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.healthTotal(songs.length),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withAlpha(150),
                        ),
                      ),
                    ),
                    if (noTags.isEmpty &&
                        noCover.isEmpty &&
                        noLyrics.isEmpty &&
                        duplicates.isEmpty)
                      Text(
                        l10n.healthClean,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withAlpha(150),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: switch (_filter) {
                  0 => _songList(l10n, noTags, empty: l10n.healthNoMissingTags),
                  1 => _songList(l10n, noCover, empty: l10n.healthNoMissingCover),
                  2 => _songList(
                    l10n,
                    noLyrics,
                    empty: l10n.healthNoMissingLyrics,
                  ),
                  _ => _duplicateList(l10n, duplicates),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _songList(
    AppLocalizations l10n,
    List<MyAudioMetadata> songs, {
    required String empty,
  }) {
    if (songs.isEmpty) {
      return Center(
        child: Text(
          empty,
          style: TextStyle(
            fontSize: 14,
            color: colorManager.getSpecificTextColor().withAlpha(150),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: songs.length,
      itemBuilder: (context, index) => _songRow(context, songs[index]),
    );
  }

  Widget _duplicateList(
    AppLocalizations l10n,
    List<List<MyAudioMetadata>> groups,
  ) {
    if (groups.isEmpty) {
      return Center(
        child: Text(
          l10n.healthNoDuplicates,
          style: TextStyle(
            fontSize: 14,
            color: colorManager.getSpecificTextColor().withAlpha(150),
          ),
        ),
      );
    }
    final rows = <Widget>[];
    for (final group in groups) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
          child: Text(
            '${getTitle(group.first)} · '
            '${l10n.healthFileCount(group.length)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorManager.getSpecificTextColor().withAlpha(180),
            ),
          ),
        ),
      );
      for (final song in group) {
        rows.add(_songRow(context, song, showPath: true));
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 56),
      children: rows,
    );
  }

  Widget _songRow(
    BuildContext context,
    MyAudioMetadata song, {
    bool showPath = false,
  }) {
    final textColor = colorManager.getSpecificTextColor();
    final path = song.path ?? '';
    final fileName = path.isEmpty ? '' : path.split('/').last;
    return ListTile(
      leading: CoverArtWidget(
        size: 46,
        borderRadius: 6,
        picture: song.picture,
      ),
      title: Text(
        getTitle(song),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: textColor),
      ),
      subtitle: Text(
        showPath
            ? fileName
            : '${getArtist(song)} · ${getAlbum(song)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: textColor.withAlpha(160)),
      ),
      trailing: const Icon(Icons.more_horiz_rounded, size: 20),
      onTap: () {
        showSongOptions(
          context: context,
          song: song,
          includeGoToAlbum: true,
          includeGoToArtist: true,
          includeEdit: true,
        );
      },
    );
  }
}
