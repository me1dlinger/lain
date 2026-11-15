/// Grouping behind the album timeline: which albums gained songs on which day.
///
/// One album can appear on more than one day - an album added in two sittings
/// shows up on both, each time with the songs that arrived then - and the
/// counts are per day, not for the album as a whole.
library;

enum AlbumTimelineRange { month, quarter, all }

int albumTimelineRangeDays(AlbumTimelineRange range) {
  switch (range) {
    case .month:
      return 30;
    case .quarter:
      return 91;
    case .all:
      return 0;
  }
}

/// One song of an album, reduced to what the timeline needs.
class AlbumTimelineSong {
  final String albumKey;
  final String albumName;
  final String artistName;
  final int? year;
  final String songId;
  final DateTime created;

  const AlbumTimelineSong({
    required this.albumKey,
    required this.albumName,
    required this.artistName,
    required this.songId,
    required this.created,
    this.year,
  });
}

/// One album on one day.
class AlbumTimelineEntry {
  final String albumKey;
  final String albumName;
  final String artistName;
  final int? year;
  final DateTime date;
  final List<String> songIds;

  const AlbumTimelineEntry({
    required this.albumKey,
    required this.albumName,
    required this.artistName,
    required this.year,
    required this.date,
    required this.songIds,
  });

  int get count => songIds.length;

  String get dayKey => albumTimelineDayKey(date);
}

class AlbumTimelineDay {
  final DateTime date;
  final List<AlbumTimelineEntry> entries;

  const AlbumTimelineDay({required this.date, required this.entries});

  int get songCount => entries.fold(0, (sum, entry) => sum + entry.count);
}

/// The date a song is placed under: the file's real created time when it is
/// known, otherwise the modified time (a library whose created times have not
/// been resolved yet must still show something), and a cached value in between
/// so a later resolve can replace it.
DateTime? resolveAlbumTimelineDate({
  DateTime? created,
  DateTime? modified,
  DateTime? cached,
}) {
  if (created != null) {
    return created;
  }
  return cached ?? modified;
}

String albumTimelineDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime albumTimelineLocalDate(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String albumTimelineDayLabel(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.'
    '${date.day.toString().padLeft(2, '0')}';

/// Albums that carry no created time at all, so they cannot be placed.
int albumsMissingCreated(Iterable<Iterable<DateTime?>> albumTimes) {
  var missing = 0;
  for (final times in albumTimes) {
    if (!times.any((time) => time != null)) {
      missing++;
    }
  }
  return missing;
}

/// Groups [songs] into days, newest day first, and inside a day the album with
/// the latest arrival first; ties fall back to album name and artist so the
/// order is stable across rebuilds.
List<AlbumTimelineDay> groupAlbumTimeline(
  Iterable<AlbumTimelineSong> songs, {
  required DateTime now,
  required AlbumTimelineRange range,
}) {
  final cutoffDays = albumTimelineRangeDays(range);
  final cutoff = cutoffDays == 0
      ? null
      : now.subtract(Duration(days: cutoffDays));

  final byDay = <String, Map<String, List<AlbumTimelineSong>>>{};
  final dayDates = <String, DateTime>{};

  for (final song in songs) {
    if (cutoff != null && song.created.isBefore(cutoff)) {
      continue;
    }
    final day = albumTimelineLocalDate(song.created);
    final key = albumTimelineDayKey(day);
    dayDates[key] = day;
    byDay.putIfAbsent(key, () => {}).putIfAbsent(
      song.albumKey,
      () => [],
    ).add(song);
  }

  final days = <AlbumTimelineDay>[];
  final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  for (final key in keys) {
    final albums = byDay[key]!;
    final entries = <AlbumTimelineEntry>[];
    for (final albumKey in albums.keys) {
      final albumSongs = albums[albumKey]!;
      albumSongs.sort((a, b) => b.created.compareTo(a.created));
      final first = albumSongs.first;
      entries.add(
        AlbumTimelineEntry(
          albumKey: albumKey,
          albumName: first.albumName,
          artistName: first.artistName,
          year: first.year,
          date: dayDates[key]!,
          songIds: [for (final song in albumSongs) song.songId],
        ),
      );
    }
    entries.sort((a, b) {
      final at = _newest(albums[a.albumKey]!);
      final bt = _newest(albums[b.albumKey]!);
      final byTime = bt.compareTo(at);
      if (byTime != 0) {
        return byTime;
      }
      final byName = a.albumName.toLowerCase().compareTo(
        b.albumName.toLowerCase(),
      );
      return byName != 0
          ? byName
          : a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase());
    });
    days.add(AlbumTimelineDay(date: dayDates[key]!, entries: entries));
  }

  return days;
}

DateTime _newest(List<AlbumTimelineSong> songs) {
  var newest = songs.first.created;
  for (final song in songs) {
    if (song.created.isAfter(newest)) {
      newest = song.created;
    }
  }
  return newest;
}
