import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/album_timeline.dart';

AlbumTimelineSong song(
  String albumKey,
  String albumName,
  String songId,
  DateTime created, {
  String artist = 'Artist',
  int? year,
}) {
  return AlbumTimelineSong(
    albumKey: albumKey,
    albumName: albumName,
    artistName: artist,
    songId: songId,
    created: created,
    year: year,
  );
}

DateTime day(int month, int dayOfMonth, [int hour = 12]) =>
    DateTime(2026, month, dayOfMonth, hour);

void main() {
  final now = day(11, 15);

  group('grouping', () {
    test('an album appears on every day it gained songs', () {
      final days = groupAlbumTimeline(
        [
          song('a', 'A', 'a-old', day(11, 13)),
          song('a', 'A', 'a-new', day(11, 14, 10)),
          song('a', 'A', 'a-later', day(11, 14, 12)),
        ],
        now: now,
        range: AlbumTimelineRange.month,
      );

      expect(days.length, 2);
      expect(days[0].date.day, 14);
      expect(days[0].entries.single.count, 2);
      expect(
        days[0].entries.single.songIds,
        ['a-later', 'a-new'],
      );
      expect(days[1].date.day, 13);
      expect(days[1].entries.single.count, 1);
    });

    test('days run newest first, albums inside a day newest first', () {
      final days = groupAlbumTimeline(
        [
          song('a', 'Album A', 'x', day(11, 14, 10)),
          song('b', 'Album B', 'y', day(11, 14, 11)),
          song('c', 'Album C', 'z', day(11, 14, 13)),
          song('d', 'Album D', 'w', day(11, 15, 9)),
        ],
        now: now,
        range: AlbumTimelineRange.month,
      );

      expect(days.length, 2);
      expect(days[0].date.day, 15);
      expect(days[1].date.day, 14);
      expect(
        [for (final entry in days[1].entries) entry.albumKey],
        ['c', 'b', 'a'],
      );
      expect(days[1].songCount, 3);
    });

    test('same arrival time falls back to the album name', () {
      final days = groupAlbumTimeline(
        [
          song('z', 'Zebra', '1', day(11, 14, 10)),
          song('a', 'Alpha', '2', day(11, 14, 10)),
        ],
        now: now,
        range: AlbumTimelineRange.month,
      );
      expect(
        [for (final entry in days.single.entries) entry.albumName],
        ['Alpha', 'Zebra'],
      );
    });

    test('one album with no arrival is left out of the groups', () {
      final days = groupAlbumTimeline(
        [song('b', 'B', 'b1', day(11, 14))],
        now: now,
        range: AlbumTimelineRange.month,
      );
      expect(days.single.entries.single.albumKey, 'b');
      expect(
        albumsMissingCreated([
          [null],
          [day(11, 14)],
        ]),
        1,
      );
    });
  });

  group('ranges', () {
    test('month keeps the last 30 days, quarter 91, all everything', () {
      final songs = [
        song('recent', 'Recent', '1', day(11, 14)),
        song('forty', 'Forty', '2', now.subtract(const Duration(days: 40))),
        song('eighty', 'Eighty', '3', now.subtract(const Duration(days: 80))),
        song('long', 'Long', '4', now.subtract(const Duration(days: 120))),
      ];

      String keys(List<AlbumTimelineDay> days) =>
          (days.map((day) => day.entries.map((e) => e.albumKey)).expand((e) => e).toList().join(','));

      expect(
        keys(groupAlbumTimeline(songs, now: now, range: AlbumTimelineRange.month)),
        'recent',
      );
      expect(
        keys(
          groupAlbumTimeline(songs, now: now, range: AlbumTimelineRange.quarter),
        ),
        contains('eighty'),
      );
      final all = keys(
        groupAlbumTimeline(songs, now: now, range: AlbumTimelineRange.all),
      );
      expect(all, contains('long'));
      expect(all, contains('recent'));
    });
  });

  group('song dates', () {
    test('created wins, then the cached value, then modified', () {
      final created = DateTime(2026, 1, 2);
      final modified = DateTime(2025, 12, 1);
      final cached = DateTime(2025, 11, 1);
      expect(
        resolveAlbumTimelineDate(
          created: created,
          modified: modified,
          cached: cached,
        ),
        created,
      );
      expect(
        resolveAlbumTimelineDate(modified: modified, cached: cached),
        cached,
      );
      expect(resolveAlbumTimelineDate(modified: modified), modified);
      expect(resolveAlbumTimelineDate(), isNull);
    });
  });

  group('day keys', () {
    test('are local dates with zero padded parts', () {
      expect(albumTimelineDayKey(DateTime(2026, 1, 2)), '2026-01-02');
      expect(albumTimelineDayLabel(DateTime(2026, 1, 2)), '2026.01.02');
      expect(albumTimelineLocalDate(DateTime(2026, 1, 2, 23, 59)).day, 2);
    });
  });
}
