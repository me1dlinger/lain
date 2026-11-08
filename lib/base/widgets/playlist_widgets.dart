import 'dart:io';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/home_widget_service.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/utils/common_utils.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:smooth_corner/smooth_corner.dart';

class Add2PlaylistPanel extends StatefulWidget {
  final List<MyAudioMetadata> songList;
  const Add2PlaylistPanel({super.key, required this.songList});

  @override
  State<StatefulWidget> createState() => _Add2PlaylistPanelState();
}

class _Add2PlaylistPanelState extends State<Add2PlaylistPanel> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        lyricsPageForegroundColor.valueNotifier,
        miniViewForegroundColor.valueNotifier,
      ]),
      builder: (context, _) {
        final specificTextColor = colorManager.getSpecificTextColor();

        return Column(
          children: [
            ListTile(
              leading: SmoothClipRRect(
                smoothness: 1,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  color: Colors.white30,
                  child: ImageIcon(
                    addImage,
                    size: 40,
                    color: colorManager.getSpecificIconColor(),
                  ),
                ),
              ),
              title: Text(
                l10n.createPlaylist,
                style: TextStyle(fontSize: 14, color: specificTextColor),
              ),
              onTap: () async {
                if (await showCreatePlaylistDialog(context)) {
                  setState(() {});
                }
              },
            ),
            SizedBox(height: 5),
            Divider(
              height: 1,
              thickness: 0.5,
              color: colorManager.getSpecificDividerColor(),
            ),
            SizedBox(height: 5),
            Expanded(
              child: ListView.builder(
                itemCount: playlistManager.playlists.length,
                itemExtent: 54,
                itemBuilder: (_, index) {
                  final playlist = playlistManager.getPlaylistByIndex(index);
                  return ListTile(
                    leading: CoverArtWidget(
                      size: 40,
                      borderRadius: 4,
                      picture: playlist.picture,
                    ),
                    title: Text(
                      index == 0 ? l10n.favorites : playlist.name,
                      style: TextStyle(fontSize: 14, color: specificTextColor),
                    ),

                    onTap: () {
                      playlist.add(widget.songList);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<bool> showCreatePlaylistDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  if (Loader.busy) {
    showCenterMessage(l10n.syncingTryLater);
    return false;
  }

  final result = await getInputTextDialog(context, l10n.createPlaylist);
  if (result != '') {
    await playlistManager.createPlaylist(result);
    return true;
  }
  return false;
}

/// Creates a playlist from a text file: the file's name (without its suffix) is
/// the playlist's name, every line is one song's path, and lines that match no
/// song are skipped.
///
/// The songs go in from the *last* line backwards, because a playlist keeps its
/// newest song first: that way the file's first line ends up as the newest
/// entry, so reading the playlist by added time (newest first) gives the file
/// back in the order it was written.
/// Writes a playlist to `Download/<name>.txt`: one song path per line, which is
/// what [showImportPlaylistDialog] reads back. The order is the playlist's own
/// (newest first), which is the order the importer expects - so exporting and
/// importing the same file leaves the playlist as it was.
Future<void> exportPlaylist(Playlist playlist) async {
  final l10n = getAppLocalizations();

  if (Platform.isAndroid) {
    if (await Permission.manageExternalStorage.request() == .denied) {
      showCenterMessage(l10n.exportFailed, duration: 3000);
      return;
    }
  }

  final lines = <String>[];
  for (final song in playlist.songList) {
    final path = song.path;
    if (path != null && path.isNotEmpty) {
      lines.add(path);
    }
  }

  if (lines.isEmpty) {
    showCenterMessage(l10n.exportFailed, duration: 3000);
    return;
  }

  var name = playlist.name.replaceAll(RegExp(r'[\/:*?"<>|]'), '_').trim();
  if (name.isEmpty) {
    name = 'playlist';
  }

  try {
    final dir = Platform.isAndroid
        ? Directory('/storage/emulated/0/Download')
        : appDocsDir;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File('${dir.path}${Platform.pathSeparator}$name.txt');
    await file.writeAsString(lines.join('\n'));

    showCenterMessage('${l10n.exported} Download/$name.txt', duration: 4000);
  } catch (e) {
    logger.output('[export] $e');
    showCenterMessage(l10n.exportFailed, duration: 3000);
  }
}

Future<void> showImportPlaylistDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  if (Loader.busy) {
    showCenterMessage(l10n.syncingTryLater);
    return;
  }

  // The system picker: the user chooses the file, no path to type.
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['txt'],
  );
  if (files.isEmpty) {
    return;
  }

  final chosen = files.first.path;
  if (chosen == null || chosen.isEmpty) {
    return;
  }

  final file = File(chosen);
  if (!await file.exists()) {
    showCenterMessage(l10n.fileNotFound);
    return;
  }

  final content = await file.readAsString();
  final paths = [
    for (final line in content.split(RegExp(r'\r?\n')))
      if (line.trim().isNotEmpty && !line.trim().startsWith('#')) line.trim(),
  ];

  final songs = _matchSongs(paths);
  if (songs.isEmpty) {
    showCenterMessage(l10n.noMatchingSongs);
    return;
  }

  var name = file.uri.pathSegments.last;
  final dot = name.lastIndexOf('.');
  if (dot > 0) {
    name = name.substring(0, dot);
  }

  final playlist =
      playlistManager.playlistMap[name] ?? Playlist(name: name, id: null);
  if (playlistManager.playlistMap[name] == null) {
    playlistManager.addPlaylist(playlist);
  }

  // Reversed: see the note above about the order.
  await playlist.add(songs.reversed.toList());

  showCenterMessage('${l10n.importedSongs} ${songs.length}');
}

/// The songs named by [paths], in the order they appear, skipping the ones that
/// match nothing. A path is looked up as it is, then by its file name, so a list
/// written on another device still lands.
List<MyAudioMetadata> _matchSongs(List<String> paths) {
  final byName = <String, MyAudioMetadata>{};
  for (final song in library.songList) {
    final path = song.path;
    if (path == null || path.isEmpty) {
      continue;
    }
    final index = path.lastIndexOf(Platform.pathSeparator);
    final name = index == -1 ? path : path.substring(index + 1);
    byName.putIfAbsent(name.toLowerCase(), () => song);
  }

  final result = <MyAudioMetadata>[];
  for (final path in paths) {
    final exact = library.id2Song[path];
    if (exact != null) {
      result.add(exact);
      continue;
    }
    final index = path.lastIndexOf(Platform.pathSeparator);
    final name = index == -1 ? path : path.substring(index + 1);
    final matched = byName[name.toLowerCase()];
    if (matched != null) {
      result.add(matched);
    }
  }
  return result;
}

void showAddPlaylistDialog(
  BuildContext context,
  List<MyAudioMetadata> songList,
) async {
  await showAnimationDialog(
    context: context,
    child: OrientationBuilder(
      builder: (context, orientation) {
        final size = MediaQuery.of(context).size;
        final shortSide = size.shortestSide;

        bool isPhone = shortSide < 600;
        return SizedBox(
          height: max(350, size.height * 0.7),
          width: isPhone ? 300 : 400,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Add2PlaylistPanel(songList: songList),
          ),
        );
      },
    ),
  );
}

Widget reorderablePlaylistsView(BuildContext context) {
  return ReorderableListView.builder(
    header: MediaQuery.removePadding(
      context: context,
      removeLeft: true, // for mobile
      removeRight: true,
      child: _playlistListTile(playlistManager.playlists[0]),
    ),
    buildDefaultDragHandles: false,
    onReorderItem: (oldIndex, newIndex) {
      final item = playlistManager.playlists.removeAt(oldIndex + 1);
      playlistManager.playlists.insert(newIndex + 1, item);
      playlistManager.update();
      HomeWidgetService.updatePlaylistsWidget();
    },
    onReorderStart: (_) {
      tryVibrate();
    },
    onReorderEnd: (_) {
      tryVibrate();
    },
    proxyDecorator: (Widget child, int index, Animation<double> animation) {
      return Material(color: Colors.transparent, child: child);
    },
    itemCount: playlistManager.playlists.length - 1,
    itemBuilder: (context, index) {
      final playlist = playlistManager.getPlaylistByIndex(index + 1);
      return MediaQuery.removePadding(
        key: ValueKey(index),
        context: context,
        removeLeft: true, // for mobile
        removeRight: true,
        child: Row(
          children: [
            Expanded(child: _playlistListTile(playlist)),

            SizedBox(
              width: 60,
              child: ReorderableDragStartListener(
                index: index,
                child: Container(
                  // must set color to make area valid
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      SizedBox(width: 10),
                      ImageIcon(reorderImage, color: iconColor.value),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _playlistListTile(Playlist playlist) {
  return Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),

      leading: CoverArtWidget(
        size: 50,
        borderRadius: 5,
        picture: playlist.picture,
      ),
      title: Text(playlist.name),
      subtitle: Builder(
        builder: (context) {
          return Text(
            AppLocalizations.of(context).songCount(playlist.totalCount),
          );
        },
      ),
    ),
  );
}
