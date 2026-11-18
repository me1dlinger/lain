import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/services/emby_client.dart';
import 'package:lain/base/services/feiniu_client.dart';
import 'package:lain/base/services/scrobble_queue.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';

final history = History();

class History {
  static const _historyLimit = 200;
  static const _rediscoveryLimit = 100;

  /// A song only counts as "long time no see" when it was played this often
  /// and has been resting for at least this long. Both keep a song that was
  /// played once, or last week, out of the shelf.
  static const _rediscoveryMinPlays = 2;
  static const _rediscoveryMinDays = 30;

  final List<MyAudioMetadata> frequentlySongList = [];
  final List<MyAudioMetadata> recentlySongList = [];
  final List<MyAudioMetadata> rediscoverySongList = [];
  final frequentlyChangeNotifier = ValueNotifier(0);
  final recentlyChangeNotifier = ValueNotifier(0);
  final rediscoveryChangeNotifier = ValueNotifier(0);

  Future<void> load() async {
    // Rebuilt from the library every time; loading twice must not duplicate.
    frequentlySongList.clear();
    recentlySongList.clear();

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
      _rebuildRediscovery();
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
    _rebuildRediscovery();
  }

  /// Songs that were played again and again but have been left alone for a
  /// while - the ones worth meeting again. Ordered by how strongly both hold:
  /// a long rest and a high play count each raise a song's place.
  void _rebuildRediscovery() {
    final now = DateTime.now();
    final candidates = <MyAudioMetadata>[];
    for (final song in library.songList) {
      final last = song.lastPlayed;
      if (last == null || song.playCount < _rediscoveryMinPlays) {
        continue;
      }
      if (now.difference(last).inDays < _rediscoveryMinDays) {
        continue;
      }
      candidates.add(song);
    }
    int score(MyAudioMetadata song) {
      final days = now.difference(song.lastPlayed!).inDays;
      return days * (10 + song.playCount);
    }

    candidates.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      return byScore != 0 ? byScore : a.lastPlayed!.compareTo(b.lastPlayed!);
    });
    rediscoverySongList
      ..clear()
      ..addAll(candidates.take(_rediscoveryLimit));
    rediscoveryChangeNotifier.value++;
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
      // The queue sends immediately when the server is reachable and keeps the
      // report otherwise; direct scrobbling here lost offline listens.
      await scrobbleQueue.enqueue(song, times);
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

    _rebuildRediscovery();
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
    rediscoverySongList.clear();
    rediscoveryChangeNotifier.value++;
  }
}
