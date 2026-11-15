import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/utils/metadata_utils.dart';

MyAudioMetadata song(String id) {
  return MyAudioMetadata(AudioMetadata(title: id), id: id, path: 'test-$id');
}

List<String> idsOf(List<MyAudioMetadata> songs) =>
    [for (final song in songs) song.id];

void main() {
  // MyAudioMetadata's constructor reads appSupportDir for the cached cover.
  setUpAll(() {
    appSupportDir = Directory.systemTemp.createTempSync('lain_test');
  });

  test('a newest-first playlist sorts ascending oldest first', () {
    // Navidrome's Subsonic getPlaylist answer is the playlist's own order: the
    // first entry is the most recently added one and the last is the oldest
    // (confirmed live: id 1 / NOMELON end newest, id 262 / 桂花 oldest).
    final newestFirst = [song('newest'), song('middle'), song('oldest')];
    final addedOrder = newestFirst.reversed.toList();
    expect(idsOf(addedOrder), ['oldest', 'middle', 'newest']);

    final ascending = List<MyAudioMetadata>.of(newestFirst);
    sortSongList(13, ascending, addedOrder: addedOrder);
    expect(idsOf(ascending), ['oldest', 'middle', 'newest']);

    final descending = List<MyAudioMetadata>.of(newestFirst);
    sortSongList(14, descending, addedOrder: addedOrder);
    expect(idsOf(descending), ['newest', 'middle', 'oldest']);
  });

  test('without an added order the created time is the fallback', () {
    final songs = [
      MyAudioMetadata(
        AudioMetadata(title: 'old'),
        id: 'old',
        path: 'test-old',
        created: DateTime(2020),
      ),
      MyAudioMetadata(
        AudioMetadata(title: 'new'),
        id: 'new',
        path: 'test-new',
        created: DateTime(2024),
      ),
    ];
    final ascending = List<MyAudioMetadata>.of(songs);
    sortSongList(13, ascending);
    expect(idsOf(ascending), ['old', 'new']);

    final descending = List<MyAudioMetadata>.of(songs);
    sortSongList(14, descending);
    expect(idsOf(descending), ['new', 'old']);
  });
}
