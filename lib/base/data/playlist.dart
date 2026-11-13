import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/home_widget_service.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/utils/path.dart';
import 'package:lain/layer/layers_manager.dart';

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
      "${getPlaylistConfigPath(sourceType)}/lain_playlists.json",
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
      "${getPlaylistConfigPath(sourceType)}/lain_playlists.json",
    );
    initFile(_playlistsFile, true);
    if (isStreamSource) {
      final tmpPlaylist = await streamClient?.getPlaylists();
      for (final playlist in tmpPlaylist ?? <Playlist>[]) {
        if (playlist.name == '_lain_play_queue_') {
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

  /// Lets every playlist resolve the ids it could not resolve when it was
  /// read - after a library scan that filled the song map.
  void resolveAfterLibraryLoad() {
    for (final playlist in playlists) {
      playlist.resolveAfterLibraryLoad();
    }
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

  /// The ids as they are stored in this playlist's file. They are kept even
  /// when the library cannot resolve one (a scan that has not finished, a
  /// database migration that emptied the library): the file is the user's
  /// data, and dropping an id because the library was momentarily empty is
  /// what deleted playlists and favourites on an upgrade.
  final List<String> _storedIds = [];

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
  /// The Hero tag the home card and the detail page share.
  ///
  /// It is built from the playlist's identity, not from its current cover: the
  /// cover can change (the first song in the chosen order changes, a sync
  /// replaces the list) while the page transition is still running, and a Hero
  /// whose tag changes mid-flight leaves its destination hidden - a blank
  /// cover that only a restart repairs.
  String get heroTag => 'playlist:${id ?? name}';

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
    sortSongList(songSortTypeNotifier(sortKey).value, songs, addedOrder: addedOrder);
    return songs;
  }

  /// The playlist's own order of addition, oldest first, for the lists that
  /// have one: a local playlist keeps its newest song first, and the Navidrome
  /// client fetches a server playlist newest-first too (see
  /// [NavidromeClient.getPlaylistSongs]). Inside such a list "added time"
  /// means when the song joined *it* - not when its file was created. Other
  /// sources report no per-entry order, so they answer null and sorting falls
  /// back to each song's own added time.
  List<MyAudioMetadata>? get addedOrder {
    if (isFavorite) {
      return null;
    }
    if (isStreamSource && sourceType != .navidrome) {
      return null;
    }
    return songList.reversed.toList();
  }

  MyPicture? get picture =>
      serverCover ?? getFirstSong(sortedSongList)?.picture;

  int get totalCount => songList.length;

  Future<void> load() async {
    canModify = false;
    changeNotifier.value++;

    final decoded = await readJsonListFile(songListFile);
    _storedIds
      ..clear()
      ..addAll(decoded.whereType<String>());
    _resolveStoredIds();

    // Nothing is written back here. The old code wrote the *resolved* list,
    // so a library that was empty at that moment (a database migration, an
    // unfinished scan) turned the playlist into an empty file - a data loss
    // that a restart could not undo.
    canModify = true;
    changeNotifier.value++;
    layersManager.updateBackground();
  }

  /// Rebuilds [songList] from [_storedIds] in the stored order, keeping only
  /// what the library can resolve right now.
  void _resolveStoredIds() {
    final songs = <MyAudioMetadata>[];
    final seen = <String>{};
    for (final id in _storedIds) {
      final song = library.id2Song[id];
      if (song == null || !seen.add(id)) {
        continue;
      }
      songs.add(song);
      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
    songList
      ..clear()
      ..addAll(songs);
  }

  /// Called after the library has been (re)built: ids that could not be
  /// resolved when the playlist was read get their songs now.
  void resolveAfterLibraryLoad() {
    if (_storedIds.isEmpty) {
      return;
    }
    final before = songList.length;
    _resolveStoredIds();
    if (songList.length != before) {
      changeNotifier.value++;
    }
  }

  Future<void> sync() async {
    songList.clear();
    if (isNotStreamSource) {
      // Reload from disk. An id the library cannot resolve stays in the file
      // untouched, so a later library load brings the song back.
      await load();
      return;
    }

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
    _storedIds
      ..clear()
      ..addAll(songList.map((e) => e.id));
    canModify = true;
    changeNotifier.value++;
    layersManager.updateBackground();
    await songListFile.writeAsString(jsonEncode(_storedIds));
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
      if (!_storedIds.contains(song.id)) {
        _storedIds.insert(0, song.id);
      }

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
      _storedIds.remove(song.id);

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

    // The stored ids are authoritative: a song whose id is not resolvable
    // right now must not be dropped by an unrelated edit.
    final songIds = List<String>.of(_storedIds);
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
