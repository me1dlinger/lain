import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/daily_recommendation.dart';
import 'package:lain/base/my_audio_metadata.dart';

MyAudioMetadata song(
  String id, {
  int plays = 0,
  int daysAgo = 60,
  String artist = 'Artist',
  String album = 'Album',
}) {
  return MyAudioMetadata(
    AudioMetadata(
      title: id,
      artist: artist,
      album: album,
      duration: const Duration(minutes: 3),
    ),
    id: id,
    path: 'test-$id',
    playCount: plays,
    lastPlayed: DateTime.now().subtract(Duration(days: daysAgo)),
  );
}

void main() {
  setUpAll(() {
    appSupportDir = Directory.systemTemp.createTempSync('lain_test');
  });

  test('a daily mix has at most twenty unique songs', () {
    final songs = [
      for (var i = 0; i < 40; i++)
        song('s$i', plays: i, artist: 'Artist ${i % 6}', album: 'Album ${i % 9}'),
    ];
    final mix = buildDailyMix(songs, DateTime(2026, 11, 18));
    expect(mix, hasLength(20));
    expect(mix.map((item) => item.id).toSet(), hasLength(mix.length));
  });

  test('the same day and seed draws the same list', () {
    final songs = [for (var i = 0; i < 30; i++) song('s$i', plays: i)];
    final a = buildDailyMix(songs, DateTime(2026, 11, 18), seed: 77);
    final b = buildDailyMix(songs, DateTime(2026, 11, 18), seed: 77);
    expect(a.map((item) => item.id), b.map((item) => item.id));
  });

  test('a refreshed seed can pick a different set', () {
    final songs = [
      for (var i = 0; i < 60; i++)
        song('s$i', plays: i % 7, artist: 'Artist ${i % 8}'),
    ];
    final a = buildDailyMix(songs, DateTime(2026, 11, 18), seed: 1);
    final b = buildDailyMix(
      songs,
      DateTime(2026, 11, 18),
      seed: 2,
      excludeIds: a.map((item) => item.id).toSet(),
    );
    expect(a.map((item) => item.id).toSet(), isNot(equals(b.map((item) => item.id).toSet())));
  });
}
