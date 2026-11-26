import 'dart:io';
import 'dart:math';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/playback_journal.dart';
import 'package:lain/base/data/recommendation_weights.dart';
import 'package:lain/base/my_audio_metadata.dart';

MyAudioMetadata song(
  String id, {
  int plays = 0,
  int? daysAgo = 60,
  DateTime? created,
  bool favorite = false,
}) {
  final item = MyAudioMetadata(
    AudioMetadata(
      title: id,
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
    ),
    id: id,
    path: 'test-$id',
    playCount: plays,
    lastPlayed: daysAgo == null
        ? null
        : DateTime(2026, 11, 18).subtract(Duration(days: daysAgo)),
    created: created,
  );
  item.isFavoriteNotifier.value = favorite;
  return item;
}

JournalEvent event(
  String id, {
  String by = 'next',
  double completion = 0.05,
  int daysAgo = 0,
}) {
  final endedAt = DateTime(2026, 11, 18).subtract(Duration(days: daysAgo));
  return JournalEvent(
    songId: id,
    title: id,
    artist: 'Artist',
    album: 'Album',
    startedAt: endedAt.subtract(const Duration(minutes: 3)),
    endedAt: endedAt,
    playedMs: (200000 * completion).round(),
    durationMs: 200000,
    endedBy: by,
  );
}

JournalSession session(List<JournalEvent> events) {
  return JournalSession(
    id: 's',
    startedAt: DateTime(2026, 11, 18),
    sourceType: 'local',
    serverId: null,
    sourceKey: 'local:',
    queue: const [],
    queueIndex: 0,
    playMode: 0,
  )..events.addAll(events);
}

ListeningSignals signalsOf(List<JournalEvent> events) =>
    ListeningSignals.fromJournal([
      session(events),
    ], now: DateTime(2026, 11, 18));

RecommendationScorer scorer({
  ListeningSignals? listening,
  bool skipAware = false,
  Set<String> rediscoveryIds = const {},
  Map<String, int> recent = const {},
  Map<String, int> artistPlays = const {},
  Map<String, int> albumPlays = const {},
}) {
  return RecommendationScorer(
    now: DateTime(2026, 11, 18),
    artistPlays: artistPlays,
    albumPlays: albumPlays,
    listening: listening,
    skipAware: skipAware,
    rediscoveryIds: rediscoveryIds,
    recentRecommendationCounts: recent,
  );
}

void main() {
  setUpAll(() {
    appSupportDir = Directory.systemTemp.createTempSync('lain_weights_test');
  });

  group('skip signal', () {
    test('manual next or previous before 15% is a skip', () {
      expect(ListeningSignals.isSkipEvent(event('a')), isTrue);
      expect(
        ListeningSignals.isSkipEvent(event('a', completion: 0.15)),
        isTrue,
      );
      expect(
        ListeningSignals.isSkipEvent(event('a', completion: 0.16)),
        isFalse,
      );
      expect(ListeningSignals.isSkipEvent(event('a', by: 'previous')), isTrue);
    });

    test('completed tracks, queue moves and previews are not skips', () {
      expect(
        ListeningSignals.isSkipEvent(event('a', by: 'completed')),
        isFalse,
      );
      expect(ListeningSignals.isSkipEvent(event('a', by: 'queue')), isFalse);
      expect(
        ListeningSignals.isSkipEvent(event('a', by: 'lyricPreview')),
        isFalse,
      );
    });

    test('only manual skips in the lookback window are counted', () {
      final signals = ListeningSignals.fromJournal([
        session([
          event('a'),
          event('a', daysAgo: 10),
          event('a', daysAgo: 400),
        ]),
      ], now: DateTime(2026, 11, 18));
      expect(signals.skipsOf('a'), 2);
      expect(signals.wasRepeatedlySkipped('a'), isTrue);
      expect(signals.skipsOf('missing'), 0);
    });

    test('one skip does not count as repeated', () {
      expect(signalsOf([event('a')]).wasRepeatedlySkipped('a'), isFalse);
      expect(signalsOf([event('a'), event('a')]).skipsOf('a'), 2);
    });
  });

  group('weight multiplier', () {
    test(
      'a song that is only skipped is untouched when the setting is off',
      () {
        final signals = signalsOf([event('a'), event('a'), event('a')]);
        expect(signals.weightMultiplier('a', skipAware: false), 1);
        expect(signals.weightMultiplier('a'), lessThanOrEqualTo(0.5));
      },
    );

    test('more repeated skips lower the multiplier further', () {
      final two = signalsOf([event('a'), event('a')]);
      final four = signalsOf([event('a'), event('a'), event('a'), event('a')]);
      expect(four.weightMultiplier('a'), lessThan(two.weightMultiplier('a')));
    });

    test('listened-through attempts raise the multiplier', () {
      final signals = signalsOf([
        event('a', by: 'completed', completion: 1),
        event('a', by: 'completed', completion: 1),
      ]);
      expect(signals.weightMultiplier('a'), greaterThan(1));
    });

    test('completion is not dragged down by skip attempts', () {
      final signals = signalsOf([
        event('a', by: 'completed', completion: 1),
        event('a'),
        event('a'),
      ]);
      expect(signals.weightMultiplier('a', skipAware: false), greaterThan(1));
    });
  });

  group('recommendation score', () {
    test('play count, favourite and affinity all raise the score', () {
      final base = scorer();
      final played = song('b', plays: 40);
      expect(base.weightOf(played), greaterThan(base.weightOf(song('a'))));
      expect(
        base.weightOf(song('c', favorite: true)),
        greaterThan(base.weightOf(song('d'))),
      );
      expect(
        scorer(artistPlays: {'Artist': 400}).weightOf(song('e')),
        greaterThan(base.weightOf(song('e'))),
      );
      expect(
        scorer(albumPlays: {'Album': 400}).weightOf(song('f')),
        greaterThan(base.weightOf(song('f'))),
      );
    });

    test('recently played steps back, long rest comes forward', () {
      final base = scorer();
      final justPlayed = song('a', daysAgo: 0);
      final rested = song('b', daysAgo: 200);
      expect(base.weightOf(rested), greaterThan(base.weightOf(justPlayed)));
    });

    test('new additions and rediscovery are boosted', () {
      final base = scorer();
      final fresh = song('a', created: DateTime(2026, 11, 17));
      final old = song('b', created: DateTime(2025, 1, 1));
      expect(base.weightOf(fresh), greaterThan(base.weightOf(old)));
      expect(
        scorer(rediscoveryIds: {'c'}).weightOf(song('c')),
        greaterThan(base.weightOf(song('c'))),
      );
    });

    test('recent daily appearances lower the score', () {
      final base = scorer();
      expect(
        scorer(recent: {'a': 4}).weightOf(song('a')),
        lessThan(base.weightOf(song('a'))),
      );
    });

    test('skip-aware scoring lowers a repeatedly skipped song', () {
      final signals = signalsOf([event('a'), event('a'), event('a')]);
      final off = scorer(listening: signals);
      final on = scorer(listening: signals, skipAware: true);
      expect(on.weightOf(song('a')), lessThan(off.weightOf(song('a'))));
    });

    test('completion raises the score', () {
      final signals = signalsOf([
        event('a', by: 'completed', completion: 1),
        event('a', by: 'completed', completion: 1),
      ]);
      final withSignals = scorer(listening: signals, skipAware: true);
      expect(
        withSignals.weightOf(song('a')),
        greaterThan(scorer().weightOf(song('a'))),
      );
    });
  });

  group('weighted sample', () {
    test('draws distinct items and respects the count', () {
      final items = [for (var i = 0; i < 30; i++) i];
      final picked = weightedSample(items, (_) => 1, 10, Random(4));
      expect(picked, hasLength(10));
      expect(picked.toSet(), hasLength(10));
    });

    test('a much heavier item is drawn first', () {
      final picked = weightedSample(
        ['heavy', 'light'],
        (item) => item == 'heavy' ? 1000000 : 0.00001,
        2,
        Random(9),
      );
      expect(picked.first, 'heavy');
    });

    test('the same seed draws the same list', () {
      final items = [for (var i = 0; i < 20; i++) i];
      final a = weightedSample(items, (item) => item + 1.0, 8, Random(11));
      final b = weightedSample(items, (item) => item + 1.0, 8, Random(11));
      expect(a, b);
    });
  });
}
