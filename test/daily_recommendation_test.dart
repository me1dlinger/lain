import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/daily_recommendation.dart';
import 'package:lain/base/data/playback_journal.dart';
import 'package:lain/base/data/recommendation_weights.dart';
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

JournalEvent skip(String id) {
  final endedAt = DateTime.now().subtract(const Duration(days: 1));
  return JournalEvent(
    songId: id,
    title: id,
    artist: 'Artist',
    album: 'Album',
    startedAt: endedAt.subtract(const Duration(minutes: 3)),
    endedAt: endedAt,
    playedMs: 5000,
    durationMs: 200000,
    endedBy: 'next',
  );
}

ListeningSignals signalsWithSkips(String id, int times) {
  final session = JournalSession(
    id: 's',
    startedAt: DateTime.now(),
    sourceType: 'local',
    serverId: null,
    sourceKey: 'local:',
    queue: const [],
    queueIndex: 0,
    playMode: 0,
  );
  for (var i = 0; i < times; i++) {
    session.events.add(skip(id));
  }
  return ListeningSignals.fromJournal([session]);
}

void main() {
  setUpAll(() {
    appSupportDir = Directory.systemTemp.createTempSync('lain_test');
  });

  test('a daily mix has at most twenty unique songs', () {
    final songs = [
      for (var i = 0; i < 40; i++)
        song(
          's$i',
          plays: i,
          artist: 'Artist ${i % 6}',
          album: 'Album ${i % 9}',
        ),
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

  test('the same day without an explicit seed is still deterministic', () {
    final songs = [
      for (var i = 0; i < 30; i++)
        song('s$i', plays: i % 5, artist: 'Artist ${i % 4}'),
    ];
    final day = DateTime(2026, 11, 18);
    final a = buildDailyMix(songs, day);
    final b = buildDailyMix(songs, day);
    expect(a.map((item) => item.id), b.map((item) => item.id));
  });

  test('the source is part of the seed, so two sources draw differently', () {
    final songs = [
      for (var i = 0; i < 30; i++)
        song('s$i', plays: i % 5, artist: 'Artist ${i % 4}'),
    ];
    final day = DateTime(2026, 11, 18);
    final local = buildDailyMix(songs, day, sourceKey: 'local:');
    final server = buildDailyMix(songs, day, sourceKey: 'navidrome:srv');
    expect(
      local.map((item) => item.id).toSet(),
      isNot(equals(server.map((item) => item.id).toSet())),
    );
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
    expect(
      a.map((item) => item.id).toSet(),
      isNot(equals(b.map((item) => item.id).toSet())),
    );
  });

  test('repeatedly skipped songs are drawn less often when enabled', () {
    final songs = [for (var i = 0; i < 40; i++) song('s$i')];
    final signals = signalsWithSkips('s20', 4);
    var plainIncluded = 0;
    var skipAwareIncluded = 0;
    for (var seed = 0; seed < 60; seed++) {
      final plain = buildDailyMix(
        songs,
        DateTime(2026, 11, 18),
        seed: seed,
        listening: signals,
      );
      final aware = buildDailyMix(
        songs,
        DateTime(2026, 11, 18),
        seed: seed,
        listening: signals,
        skipAware: true,
      );
      if (plain.any((item) => item.id == 's20')) {
        plainIncluded++;
      }
      if (aware.any((item) => item.id == 's20')) {
        skipAwareIncluded++;
      }
    }
    expect(plainIncluded, greaterThan(skipAwareIncluded));
    expect(skipAwareIncluded, lessThan(plainIncluded ~/ 2));
  });

  test('recent daily appearances are rotated out of the next day', () {
    final songs = [for (var i = 0; i < 40; i++) song('s$i')];
    var included = 0;
    for (var seed = 0; seed < 60; seed++) {
      final mix = buildDailyMix(
        songs,
        DateTime(2026, 11, 18),
        seed: seed,
        recentRecommendationCounts: {'s20': 5},
      );
      if (mix.any((item) => item.id == 's20')) {
        included++;
      }
    }
    expect(included, lessThan(30));
  });
}
