import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/cloud_play_queue.dart';
import 'package:lain/base/services/navidrome_client.dart';

CloudPlayQueue queueOf(
  List<String> ids, {
  String? current,
  int positionMs = 0,
}) {
  return CloudPlayQueue.fromSubsonic({
    'entry': [
      for (final id in ids) {'id': id, 'title': 'T$id'},
    ],
    'current': current,
    'position': positionMs,
  });
}

void main() {
  group('CloudPlayQueue.fromSubsonic', () {
    test('reads entries, current song, position and metadata', () {
      final queue = CloudPlayQueue.fromSubsonic({
        'entry': [
          {'id': '1', 'title': 'One', 'duration': 120},
          {'id': 2, 'title': 'Two'},
        ],
        'current': '2',
        'position': 42000,
        'username': 'me',
        'changed': '2026-11-26T10:00:00Z',
        'changedBy': 'phone',
      });

      expect(queue.tracks.map((track) => track.id), ['1', '2']);
      expect(queue.tracks.first.raw['title'], 'One');
      expect(queue.currentId, '2');
      expect(queue.position, const Duration(seconds: 42));
      expect(queue.username, 'me');
      expect(queue.changedBy, 'phone');
      expect(queue.changed?.toUtc(), DateTime.utc(2026, 11, 26, 10));
    });

    test('an absent or null playQueue is an empty snapshot', () {
      expect(CloudPlayQueue.fromSubsonic(null).isEmpty, isTrue);
      expect(
        CloudPlayQueue.fromSubsonic({'entry': null, 'position': 0}).isEmpty,
        isTrue,
      );
    });

    test('entries without an id are skipped, a negative position clamps', () {
      final queue = CloudPlayQueue.fromSubsonic({
        'entry': [
          {'title': 'nameless'},
          'not a map',
          {'id': ''},
          {'id': 'kept'},
        ],
        'position': -5,
      });

      expect(queue.tracks.single.id, 'kept');
      expect(queue.position, Duration.zero);
    });
  });

  group('resolveCloudQueue', () {
    test('keeps order and points at the server current song', () {
      final queue = queueOf(['a', 'b', 'c'], current: 'c');
      final resolved = resolveCloudQueue<String>(
        queue,
        (id) => id.toUpperCase(),
      );

      expect(resolved.songs, ['A', 'B', 'C']);
      expect(resolved.index, 2);
      expect(resolved.missing, 0);
    });

    test('skips unknown songs and still finds the current one', () {
      final queue = queueOf(['a', 'gone', 'c'], current: 'c');
      final resolved = resolveCloudQueue<String>(
        queue,
        (id) => id == 'gone' ? null : id,
      );

      expect(resolved.songs, ['a', 'c']);
      expect(resolved.index, 1);
      expect(resolved.missing, 1);
    });

    test('a missing current song falls back to the first playable one', () {
      final queue = queueOf(['gone', 'b'], current: 'gone');
      final resolved = resolveCloudQueue<String>(
        queue,
        (id) => id == 'gone' ? null : id,
      );

      expect(resolved.songs, ['b']);
      expect(resolved.index, 0);
      expect(resolved.missing, 1);
    });

    test('nothing playable leaves an empty restore', () {
      final queue = queueOf(['x', 'y'], current: 'x');
      final resolved = resolveCloudQueue<String>(queue, (_) => null);

      expect(resolved.isEmpty, isTrue);
      expect(resolved.missing, 2);
    });

    test('position is carried over to the restore', () {
      final queue = queueOf(['a'], current: 'a', positionMs: 61500);
      final resolved = resolveCloudQueue<String>(queue, (id) => id);

      expect(resolved.position, const Duration(milliseconds: 61500));
    });
  });

  group('CloudQueueSnapshot', () {
    test('an empty queue has no snapshot', () {
      final snapshot = CloudQueueSnapshot.fromQueue([], index: 0);
      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.currentId, isNull);
    });

    test('keeps the current id and position', () {
      final snapshot = CloudQueueSnapshot.fromQueue(
        ['a', 'b', 'c'],
        index: 1,
        position: const Duration(seconds: 30),
      );

      expect(snapshot.songIds, ['a', 'b', 'c']);
      expect(snapshot.currentId, 'b');
      expect(snapshot.position, const Duration(seconds: 30));
    });

    test('an out-of-range index clamps to the last song', () {
      final snapshot = CloudQueueSnapshot.fromQueue(['a', 'b'], index: 99);
      expect(snapshot.currentId, 'b');
    });

    test('a negative index keeps the queue without a current song', () {
      final snapshot = CloudQueueSnapshot.fromQueue(['a', 'b'], index: -1);
      expect(snapshot.songIds, ['a', 'b']);
      expect(snapshot.currentId, isNull);
    });

    test('a long queue keeps a window around the current song', () {
      final ids = [for (var i = 0; i < 20; i++) '$i'];
      final snapshot = CloudQueueSnapshot.fromQueue(ids, index: 10, maxIds: 6);

      expect(snapshot.songIds.length, 6);
      expect(snapshot.songIds.contains(snapshot.currentId), isTrue);
      expect(snapshot.currentId, '10');
    });

    test('a queue at the front keeps the first window', () {
      final ids = [for (var i = 0; i < 20; i++) '$i'];
      final snapshot = CloudQueueSnapshot.fromQueue(ids, index: 0, maxIds: 5);

      expect(snapshot.songIds, ['0', '1', '2', '3', '4']);
      expect(snapshot.currentId, '0');
    });

    test('signature ignores sub-ten-second position changes', () {
      final first = CloudQueueSnapshot.fromQueue(
        ['a', 'b'],
        index: 0,
        position: const Duration(seconds: 12),
      );
      final second = CloudQueueSnapshot.fromQueue(
        ['a', 'b'],
        index: 0,
        position: const Duration(seconds: 19),
      );
      final third = CloudQueueSnapshot.fromQueue(
        ['a', 'b'],
        index: 0,
        position: const Duration(seconds: 21),
      );

      expect(first.signature, second.signature);
      expect(first.signature, isNot(third.signature));
    });
  });

  group('buildSavePlayQueueQuery', () {
    test('sends repeated ids, the current song and the position in ms', () {
      final query = buildSavePlayQueueQuery(
        ['a', 'b', 'c'],
        currentId: 'b',
        position: const Duration(milliseconds: 1234),
      );

      expect(query['id'], ['a', 'b', 'c']);
      expect(query['current'], 'b');
      expect(query['position'], 1234);
    });

    test('omits an empty current and clamps a negative position', () {
      final query = buildSavePlayQueueQuery(
        ['a'],
        currentId: '',
        position: const Duration(seconds: -2),
      );

      expect(query.containsKey('current'), isFalse);
      expect(query['position'], 0);
    });

    test('the id list is copied, not shared with the queue', () {
      final ids = ['a'];
      final query = buildSavePlayQueueQuery(ids, currentId: 'a');
      ids.add('b');

      expect(query['id'], ['a']);
    });
  });
}
