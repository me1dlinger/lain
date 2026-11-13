import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/services/emby_client.dart';
import 'package:lain/base/services/feiniu_client.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';

final history = History();

class History {
  static const _historyLimit = 200;

  final List<MyAudioMetadata> frequentlySongList = [];
  final List<MyAudioMetadata> recentlySongList = [];
  final frequentlyChangeNotifier = ValueNotifier(0);
  final recentlyChangeNotifier = ValueNotifier(0);

  Future<void> load() async {
    if (sourceType == .emby) {
      frequentlySongList.addAll(
        await (streamClient as EmbyClient?)?.getFrequentlySongs() ?? [],
      );
      _trim(frequentlySongList);
      frequentlyChangeNotifier.value++;

      recentlySongList.addAll(
        await (streamClient as EmbyClient?)?.getRecentlySongs() ?? [],
      );
      _trim(recentlySongList);
      recentlyChangeNotifier.value++;
      return;
    }

    for (final song in library.songList) {
      if (song.playCount > 0 && song.lastPlayed != null) {
        frequentlySongList.add(song);
        if (sourceType != .feiniu) {
          recentlySongList.add(song);
        }
      }
    }

    frequentlySongList.sort((a, b) {
      int tmp = b.playCount.compareTo(a.playCount);
      return tmp != 0 ? tmp : a.lastPlayed!.compareTo(b.lastPlayed!);
    });
    _trim(frequentlySongList);

    if (sourceType != .feiniu) {
      recentlySongList.sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
      _trim(recentlySongList);
    } else {
      recentlySongList.addAll(
        await (streamClient as FeiniuClient?)?.getRecentlySongs() ?? [],
      );
      _trim(recentlySongList);
    }

    frequentlyChangeNotifier.value++;
    recentlyChangeNotifier.value++;
  }

  void _trim(List<MyAudioMetadata> songs) {
    if (songs.length > _historyLimit) {
      songs.removeRange(_historyLimit, songs.length);
    }
  }

  /// Replaces the most-played list with [songs] - the server's own answer,
  /// already ordered - so the list the home shelf and its page show is the
  /// latest one without a full sync.
  void applyFrequently(List<MyAudioMetadata> songs) {
    frequentlySongList
      ..clear()
      ..addAll(songs);
    _trim(frequentlySongList);
    frequentlyChangeNotifier.value++;
  }

  void _addSongTimes(MyAudioMetadata song, int times) {
    int index = frequentlySongList.indexOf(song);

    song.playCount += times;

    if (index == -1) {
      frequentlySongList.add(song);
      index = frequentlySongList.length - 1;
    }

    for (int i = index - 1; i >= 0; i--) {
      if (frequentlySongList[i].playCount < song.playCount) {
        frequentlySongList[i + 1] = frequentlySongList[i];
        index = i;
      } else {
        break;
      }
    }
    frequentlySongList[index] = song;
    _trim(frequentlySongList);
    frequentlyChangeNotifier.value++;
  }

  Future<void> addSongTimes(MyAudioMetadata song, int times) async {
    _add2Recently(song);
    if (sourceType != .emby) {
      _addSongTimes(song, times);
      song.lastPlayed = DateTime.now();
      await library.updatePlayCount(song);
    }

    if (isStreamSource) {
      while (times-- > 0) {
        await streamClient?.scrobble(song.id);
      }
    }

    if (sourceType == .emby) {
      final songs = await (streamClient as EmbyClient?)?.getFrequentlySongs();
      if (songs?.isNotEmpty ?? false) {
        frequentlySongList.clear();
        frequentlySongList.addAll(songs!);
        _trim(frequentlySongList);
        frequentlyChangeNotifier.value++;
      }
    }

    layersManager.updateBackground();
  }

  void _add2Recently(MyAudioMetadata song) {
    recentlySongList.remove(song);
    recentlySongList.insert(0, song);
    _trim(recentlySongList);
    recentlyChangeNotifier.value++;
  }

  void clear() {
    frequentlySongList.clear();
    recentlySongList.clear();
  }
}
