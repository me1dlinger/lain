import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/playback_journal.dart';

void main() {
  test('a session keeps queue, events and completion ratios', () {
    final session = JournalSession(
      id: 's1',
      startedAt: DateTime(2026, 11, 18),
      sourceType: 'navidrome',
      serverId: 'srv',
      sourceKey: 'navidrome:srv',
      queue: const [
        JournalTrack(
          id: 'a',
          title: 'A',
          artist: 'Artist',
          album: 'Album',
          durationMs: 200000,
        ),
      ],
      queueIndex: 0,
      playMode: 0,
      positionMs: 42000,
    );
    session.events.add(
      JournalEvent(
        songId: 'a',
        title: 'A',
        artist: 'Artist',
        album: 'Album',
        startedAt: DateTime(2026, 11, 18, 20),
        endedAt: DateTime(2026, 11, 18, 20, 3),
        playedMs: 180000,
        durationMs: 200000,
        endedBy: 'completed',
      ),
    );
    final restored = JournalSession.fromJson(session.toJson());
    expect(restored.queue.single.title, 'A');
    expect(restored.events.single.completionRatio, closeTo(.9, .0001));
    expect(restored.completedCount, 1);
    expect(restored.positionMs, 42000);
  });

  test(
    'on-this-day only returns earlier years with the same month and day',
    () {
      final now = DateTime(2026, 11, 18);
      final journal = PlaybackJournal();
      for (final year in [2024, 2025, 2026]) {
        journal.sessions.add(
          JournalSession(
            id: '$year',
            startedAt: DateTime(year, 11, 18),
            sourceType: 'local',
            serverId: null,
            sourceKey: 'local:',
            queue: const [],
            queueIndex: 0,
            playMode: 0,
          ),
        );
      }
      expect(journal.onThisDay(now).map((s) => s.id), ['2025', '2024']);
    },
  );
}
