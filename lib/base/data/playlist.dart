import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/home_widget_service.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/layer/layers_manager.dart';

final playlistManager = PlaylistManager();

class PlaylistManager {
  late File _playlistsFile;

  List<Playlist> playlists = [];
  Map<String, Playlist> playlistMap = {};
  ValueNotifier<int> updateNotifier = ValueNotifier(0);

  PlaylistManager() {
    addPlaylist(Playlist(name: 'Favorite'));
  }

  Future<void> _prepareForLoad() async {
    _playlistsFile = File(
      "${getPlaylistConfigPath(sourceType)}/sylvakru_playlists.json",
    );
    initFile(_playlistsFile, true);

    final contentList = await readJsonListFile(_playlistsFile);
    for (final content in contentList) {
      if (isNotStreamSource) {
        final playlist = Playlist(name: content);
        addPlaylist(playlist);
      } else {
        final playlist = Playlist(name: content['name'], id: content['id']);
        addPlaylist(playlist);
      }
    }
    updateNotifier.value++;
  }

  Future<void> _prepareForSync() async {
    _playlistsFile = File(
      "${getPlaylistConfigPath(sourceType)}/sylvakru_playlists.json",
    );
    initFile(_playlistsFile, true);
    if (isStreamSource) {
      final tmpPlaylist = await streamClient?.getPlaylists();
      for (final playlist in tmpPlaylist ?? <Playlist>[]) {
        if (playlist.name == '_sylvakru_play_queue_') {
          streamClient?.deletePlaylist(playlist.id!);
          continue;
        }
        if (playlistMap[playlist.name] == null) {
          addPlaylist(playlist);
        }
        playlistMap[playlist.name]!.id = playlist.id;
      }
      update();
    } else {
      final contentList = await readJsonListFile(_playlistsFile);
      for (final content in contentList) {
        final playlist = Playlist(name: content);
        addPlaylist(playlist);
      }

      updateNotifier.value++;
    }
  }

  Future<void> load() async {
    await _prepareForLoad();
    for (final playlist in playlists) {
      await playlist.load();
    }

    if (Platform.isIOS) {
      HomeWidgetService.updatePlaylistsWidget();
    }
  }

  Future<void> sync() async {
    await _prepareForSync();
    for (final playlist in playlists) {
      await playlist.sync();
    }

    if (Platform.isIOS) {
      HomeWidgetService.updatePlaylistsWidget();
    }
  }

  Playlist getPlaylistByIndex(int index) {
    assert(index >= 0 && index < playlists.length);
    return playlists[index];
  }

  Playlist? getPlaylistByName(String name) {
    return playlistMap[name];
  }

  void addPlaylist(Playlist playlist) {
    playlists.add(playlist);
    playlistMap[playlist.name] = playlist;
  }

  Future<void> createPlaylist(String name) async {
    for (Playlist playlist in playlists) {
      // check whether the name exists
      if (name == playlist.name) {
        showCenterMessage('Playlist exists');
        return;
      }
    }

    final playlist = Playlist(name: name);
    if (isStreamSource) {
      playlist.id = await streamClient?.createPlaylist(name);

      // failed
      if (playlist.id == null) {
        showCenterMessage('Create playlist failed');
        return;
      }
    }
    addPlaylist(playlist);

    update();

    if (Platform.isIOS) {
      HomeWidgetService.updatePlaylistsWidget();
    }
  }

  /// Renames a playlist that lives here: its songs file is renamed with it, the
  /// lookup key moves, and the name list on disk is rewritten. A server playlist
  /// is left alone - its name belongs to the server - as is the favourites list.
  Future<bool> renamePlaylist(Playlist playlist, String newName) async {
    final name = newName.trim();

    if (name.isEmpty || name == playlist.name) {
      return false;
    }
    if (playlist.isFavorite || isStreamSource) {
      return false;
    }
    if (playlistMap[name] != null) {
      showCenterMessage('Playlist exists');
      return false;
    }

    final oldFile = playlist.songListFile;
    final newFile = File('${getPlaylistConfigPath(sourceType)}/$name.json');

    try {
      if (await oldFile.exists()) {
        await oldFile.rename(newFile.path);
      } else {
        initFile(newFile, true);
      }
    } catch (e) {
      showCenterMessage('Rename failed');
      return false;
    }

    playlistMap.remove(playlist.name);
    playlist.songListFile = newFile;
    playlist.name = name;
    playlistMap[name] = playlist;

    update();

    if (Platform.isIOS) {
      HomeWidgetService.updatePlaylistsWidget();
    }

    return true;
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    playlist.songListFile.deleteSync();

    if (playlist.id != null && streamClient != null) {
      if (!await streamClient!.deletePlaylist(playlist.id!)) {
        showCenterMessage('Delete playlist failed');
        return;
      }
    }

    playlists.remove(playlist);
    playlistMap.remove(playlist.name);

    update();

    if (Platform.isIOS) {
      HomeWidgetService.updatePlaylistsWidget();
    }
  }

  void update() {
    _playlistsFile.writeAsStringSync(
      jsonEncode(
        playlists
            .map(
              (pl) => isStreamSource ? {'id': pl.id, 'name': pl.name} : pl.name,
            )
            .skip(1)
            .toList(),
      ),
    );

    updateNotifier.value++;
  }

  void reset() {
    playlists.clear();
    playlistMap.clear();
    addPlaylist(Playlist(name: 'Favorite'));
    updateNotifier.value++;
  }
}

class Playlist {
  String name;

  String? id;

  late File songListFile;

  List<MyAudioMetadata> songList = [];

  late bool isFavorite;
  late bool isNotFavorite;

  final changeNotifier = ValueNotifier(0);

  bool canModify = true;

  Playlist({required this.name, this.id}) {
    songListFile = File("${getPlaylistConfigPath(sourceType)}/$name.json");
    initFile(songListFile, true);

    isFavorite = name == 'Favorite';
    isNotFavorite = !isFavorite;
  }

  /// Key of this playlist's remembered sort order, shared with the song list
  /// page (see [songSortTypeNotifier]).
  String get sortKey => 'playlist:${id ?? name}';

  MyPicture? _serverCover;

  /// The server's own artwork for this playlist, if it has any: Navidrome keeps
  /// it under the playlist's id, so it downloads like any other cover. The
  /// favourited-songs list is built locally and has no id at all.
  MyPicture? get serverCover {
    if (sourceType != .navidrome) {
      return null;
    }
    final coverId = id;
    if (coverId == null || coverId.isEmpty) {
      return null;
    }
    return _serverCover ??= MyPicture.form(coverId);
  }

  /// The songs in the order chosen for this playlist. A copy, since the stored
  /// list is also what gets written back to the server.
  List<MyAudioMetadata> get sortedSongList {
    final songs = List<MyAudioMetadata>.from(songList);
    sortSongList(songSortTypeNotifier(sortKey).value, songs);
    return songs;
  }

  MyPicture? get picture =>
      serverCover ?? getFirstSong(sortedSongList)?.picture;

  int get totalCount => songList.length;

  Future<void> load() async {
    canModify = false;
    changeNotifier.value++;

    final decoded = await readJsonListFile(songListFile);
    for (String id in decoded) {
      MyAudioMetadata? song = library.id2Song[id];
      if (song == null) {
        continue;
      }
      songList.add(song);
      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
    await songListFile.writeAsString(
      jsonEncode(songList.map((e) => e.id).toList()),
    );

    canModify = true;
    changeNotifier.value++;
    layersManager.updateBackground();
  }

  Future<void> sync() async {
    songList.clear();
    if (isNotStreamSource) {
      await load();
    } else {
      canModify = false;
      changeNotifier.value++;
      List<MyAudioMetadata>? tmpSongs;
      if (isFavorite) {
        tmpSongs = (await streamClient?.getStarredSongs());
      } else {
        tmpSongs = (await streamClient?.getPlaylistSongs(id!));
      }
      for (final song in tmpSongs ?? []) {
        songList.add(song);
        if (isFavorite) {
          song.isFavoriteNotifier.value = true;
        }
      }
      canModify = true;
      changeNotifier.value++;
      layersManager.updateBackground();
    }
    final songIds = songList.map((e) => e.id).toList();
    await songListFile.writeAsString(jsonEncode(songIds));
  }

  Future<void> add(List<MyAudioMetadata> songList) async {
    if (!canModify) {
      showCenterMessage('Can not modify, it\'s updating');
      return;
    }
    for (MyAudioMetadata song in songList) {
      final targetSongList = this.songList;
      if (targetSongList.contains(song)) {
        continue;
      }
      targetSongList.insert(0, song);

      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
    await update();
  }

  Future<void> remove(List<MyAudioMetadata> songList) async {
    if (!canModify) {
      showCenterMessage('Can not modify, it\'s updating');
      return;
    }
    for (MyAudioMetadata song in songList) {
      final targetSongList = this.songList;
      targetSongList.remove(song);

      if (isFavorite) {
        song.isFavoriteNotifier.value = false;
      }
    }
    await update();
  }

  Future<void> update() async {
    if (!canModify) {
      showCenterMessage('Can not modify, it\'s updating');
      return;
    }
    canModify = false;
    changeNotifier.value++;
    playlistManager.updateNotifier.value++;

    if (Platform.isIOS) {
      HomeWidgetService.updatePlaylistsWidget();
    }

    layersManager.updateBackground();

    final songIds = songList.map((e) => e.id).toList();
    await songListFile.writeAsString(jsonEncode(songIds));
    if (isStreamSource) {
      late bool success;
      if (isFavorite) {
        success = await streamClient?.updateStarredSongs(songIds) ?? false;
      } else {
        success =
            await streamClient?.updatePlaylistSongs(id!, songIds) ?? false;
      }
      if (!success) {
        showCenterMessage('Update playlist failed');
      }
    }
    canModify = true;
    changeNotifier.value++;
  }
}

void toggleFavoriteState(MyAudioMetadata song) async {
  final favorite = playlistManager.playlists.first;
  if (!favorite.canModify) {
    return;
  }
  final isFavorite = song.isFavoriteNotifier;
  if (isFavorite.value) {
    favorite.remove([song]);
  } else {
    favorite.add([song]);
  }
  if (Platform.isIOS && song == currentSongNotifier.value) {
    HomeWidgetService.updateIsFavorite();
  }
}
