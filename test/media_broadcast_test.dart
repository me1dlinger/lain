import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/services/media_broadcast.dart';

/// What actually reaches the media session, in this test: a head unit sees the
/// items that were delivered, in the order they were delivered.
class FakeSession {
  final List<String> delivered = [];

  void deliver(MediaSnapshot snapshot) => delivered.add(snapshot.id);

  List<String> get last => delivered.isEmpty ? const [] : [delivered.last];
}

MediaSnapshot snapshot(
  FakeSession session,
  String id, {
  bool hasArt = true,
  Object? key,
}) {
  return MediaSnapshot(
    id: id,
    key: key ?? id,
    hasArt: hasArt,
    deliver: session.deliver,
  );
}

void main() {
  group('generations', () {
    test('a result from an older generation is dropped', () {
      final broadcaster = MediaBroadcaster(debounce: Duration.zero);
      final first = broadcaster.nextGeneration();
      // The user presses next: the broadcast that started `first` is over.
      final second = broadcaster.nextGeneration();

      expect(broadcaster.isCurrent(second), isTrue);
      expect(broadcaster.isCurrent(first), isFalse);

      // A cover resolved for the first broadcast must not be applied.
      final verdict = broadcaster.handleCoverOutcome(
        '/covers/a.jpg',
        CoverOutcome(generation: first, artPath: '/covers/a.100'),
      );
      expect(verdict.current, isFalse);
      expect(broadcaster.failureFor('/covers/a.jpg'), isNull);
    });

    test('a cover failure of an old broadcast does not poison the new one', () {
      final broadcaster = MediaBroadcaster(debounce: Duration.zero);
      final first = broadcaster.nextGeneration();
      final second = broadcaster.nextGeneration();

      final old = broadcaster.handleCoverOutcome(
        '/covers/b.jpg',
        CoverOutcome(generation: first, artPath: null),
      );
      expect(old.current, isFalse);

      // The new broadcast has no memory of the failure: it may try again.
      expect(broadcaster.shouldAttemptCover('/covers/b.jpg'), isTrue);

      final fresh = broadcaster.handleCoverOutcome(
        '/covers/b.jpg',
        CoverOutcome(generation: second, artPath: null),
      );
      expect(fresh.current, isTrue);
      expect(fresh.retryable, isTrue);
      expect(broadcaster.failureFor('/covers/b.jpg'), isNotNull);
    });

    test('the generation only moves when a new broadcast starts', () {
      final broadcaster = MediaBroadcaster(debounce: Duration.zero);
      final generation = broadcaster.nextGeneration();
      expect(broadcaster.nextGeneration(), generation + 1);
      expect(broadcaster.isCurrent(generation), isFalse);
      // Same broadcast, many publishes: the generation must stay put, or the
      // artwork work started for it would be discarded by its own lyric line.
      expect(broadcaster.generation, generation + 1);
    });
  });

  group('coalescing', () {
    test('a burst of N switches publishes only the last one', () async {
      final session = FakeSession();
      final broadcaster = MediaBroadcaster();
      const burst = 6;

      for (var i = 0; i < burst; i++) {
        broadcaster.nextGeneration();
        broadcaster.publish(snapshot(session, 'song-$i'));
      }

      // Nothing has reached the session yet: the burst is still settling.
      expect(session.delivered, isEmpty);
      expect(broadcaster.hasPending, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(session.delivered, ['song-5']);
    });

    test('switches that are minutes apart are each published', () async {
      final session = FakeSession();
      final broadcaster = MediaBroadcaster(debounce: Duration.zero);

      broadcaster.nextGeneration();
      broadcaster.publish(snapshot(session, 'a'));
      await Future<void>.delayed(Duration.zero);
      broadcaster.nextGeneration();
      broadcaster.publish(snapshot(session, 'b'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(session.delivered, ['a', 'b']);
    });

    test('a track switch is published before the debounce elapses', () async {
      final session = FakeSession();
      final broadcaster = MediaBroadcaster();
      broadcaster.publish(snapshot(session, 'now'), immediate: true);

      await Future<void>.delayed(Duration.zero);

      expect(session.delivered, ['now']);
    });

    test('a publish identical to the session is skipped', () async {
      final session = FakeSession();
      final broadcaster = MediaBroadcaster(debounce: Duration.zero);

      broadcaster.publish(
        snapshot(session, 'song-1', key: 'title|artist|cover'),
        immediate: true,
      );
      await Future<void>.delayed(Duration.zero);

      // The same lyric line ticked again: nothing changed, so nothing is sent.
      broadcaster.publish(
        snapshot(session, 'song-1', key: 'title|artist|cover'),
        immediate: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(session.delivered, ['song-1']);
      expect(broadcaster.publishCount, 1);
      expect(broadcaster.skipCount, 1);
    });

    test('new artwork for the same song is published under the new id', () async {
      final session = FakeSession();
      final broadcaster = MediaBroadcaster(debounce: Duration.zero);

      broadcaster.publish(snapshot(session, 'song-1'), immediate: true);
      await Future<void>.delayed(Duration.zero);
      // The cover landed: same song, new artwork version.
      broadcaster.publish(snapshot(session, 'song-1#art:1'), immediate: true);
      await Future<void>.delayed(Duration.zero);

      expect(session.delivered, ['song-1', 'song-1#art:1']);
      expect(session.last, ['song-1#art:1']);
    });

    test('reset drops what is pending', () async {
      final session = FakeSession();
      final broadcaster = MediaBroadcaster();
      broadcaster.publish(snapshot(session, 'stale'));
      broadcaster.reset();

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(session.delivered, isEmpty);
    });
  });

  group('cover recovery', () {
    test('a failed cover is retried by the next broadcast', () {
      final broadcaster = MediaBroadcaster(debounce: Duration.zero);
      final generation = broadcaster.nextGeneration();

      final verdict = broadcaster.handleCoverOutcome(
        '/covers/c.jpg',
        CoverOutcome(generation: generation, artPath: null),
      );
      expect(verdict.current, isTrue);
      expect(verdict.retryable, isTrue);
      expect(broadcaster.shouldAttemptCover('/covers/c.jpg'), isTrue);

      // Second failure within the same broadcast: still remembered, so a
      // burst of republishes does not restart the same doomed download.
      broadcaster.handleCoverOutcome(
        '/covers/c.jpg',
        CoverOutcome(generation: generation, artPath: null),
      );
      expect(broadcaster.shouldAttemptCover('/covers/c.jpg'), isFalse);

      // The user switches track: a new broadcast, and the next publish still
      // carries the cover.
      final next = broadcaster.nextGeneration();
      expect(broadcaster.shouldAttemptCover('/covers/c.jpg'), isTrue);

      final success = broadcaster.handleCoverOutcome(
        '/covers/c.jpg',
        CoverOutcome(generation: next, artPath: '/covers/c.jpg.100'),
      );
      expect(success.current, isTrue);
      expect(broadcaster.failureFor('/covers/c.jpg'), isNull);
      expect(broadcaster.shouldAttemptCover('/covers/c.jpg'), isTrue);
    });

    test('a failure on another network is forgotten', () {
      final broadcaster = MediaBroadcaster(debounce: Duration.zero);
      final generation = broadcaster.nextGeneration();

      broadcaster.handleCoverOutcome(
        '/covers/d.jpg',
        CoverOutcome(generation: generation, artPath: null, relayGeneration: 1),
      );
      expect(broadcaster.failureFor('/covers/d.jpg'), isNotNull);

      // The phone moved to another Wi-Fi: the old address cannot serve the
      // cover any more, so a failure on it is a fresh start, not a repeat.
      final verdict = broadcaster.handleCoverOutcome(
        '/covers/d.jpg',
        CoverOutcome(generation: nextGeneration(broadcaster), artPath: null),
        relayGeneration: 2,
      );
      expect(verdict.reset, isTrue);
      expect(verdict.retryable, isTrue);
      expect(
        broadcaster.shouldAttemptCover('/covers/d.jpg', relayGeneration: 2),
        isTrue,
      );
    });

    test('a success clears the failure and the snapshot can carry art', () async {
      final session = FakeSession();
      final broadcaster = MediaBroadcaster(debounce: Duration.zero);
      final generation = broadcaster.nextGeneration();

      broadcaster.handleCoverOutcome(
        '/covers/e.jpg',
        CoverOutcome(generation: generation, artPath: null),
      );
      broadcaster.handleCoverOutcome(
        '/covers/e.jpg',
        CoverOutcome(generation: generation, artPath: null),
      );
      expect(broadcaster.shouldAttemptCover('/covers/e.jpg'), isFalse);

      broadcaster.handleCoverOutcome(
        '/covers/e.jpg',
        CoverOutcome(
          generation: nextGeneration(broadcaster),
          artPath: '/covers/e.jpg.100',
        ),
      );

      broadcaster.publish(
        snapshot(session, 'song-e#art:2', hasArt: true),
        immediate: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(session.delivered, ['song-e#art:2']);
    });
  });
}

/// The next broadcast generation, as the handler takes it on every switch.
int nextGeneration(MediaBroadcaster broadcaster) => broadcaster.nextGeneration();
