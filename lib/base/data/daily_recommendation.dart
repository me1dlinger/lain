import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:lain/base/app.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/data/history.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/playback_journal.dart';
import 'package:lain/base/data/recommendation_weights.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/utils/path.dart';

/// One song saved in a day's recommendation. It is a snapshot, not a live
/// reference: a song removed later still has a title to show in history, and
/// playback can simply skip it.
class DailyMixEntry {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? coverId;

  const DailyMixEntry({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.coverId,
  });

  factory DailyMixEntry.fromSong(MyAudioMetadata song) => DailyMixEntry(
    id: song.id,
    title: getTitle(song),
    artist: getArtist(song),
    album: getAlbum(song),
    coverId: song.picture.id.isEmpty ? null : song.picture.id,
  );

  factory DailyMixEntry.fromJson(Map json) => DailyMixEntry(
    id: '${json['id'] ?? ''}',
    title: '${json['t'] ?? ''}',
    artist: '${json['a'] ?? ''}',
    album: '${json['b'] ?? ''}',
    coverId: json['c']?.toString(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    't': title,
    'a': artist,
    'b': album,
    if (coverId != null) 'c': coverId,
  };
}

class DailyMixDay {
  final String date;
  final DateTime generatedAt;
  final List<DailyMixEntry> songs;

  const DailyMixDay({
    required this.date,
    required this.generatedAt,
    required this.songs,
  });

  factory DailyMixDay.fromJson(Map json) => DailyMixDay(
    date: '${json['date'] ?? ''}',
    generatedAt:
        DateTime.tryParse('${json['generatedAt'] ?? ''}') ?? DateTime.now(),
    songs: [
      if (json['songs'] is List)
        for (final item in json['songs'] as List)
          if (item is Map) DailyMixEntry.fromJson(item),
    ],
  );

  Map<String, Object?> toJson() => {
    'date': date,
    'generatedAt': generatedAt.toIso8601String(),
    'songs': [for (final song in songs) song.toJson()],
  };
}

/// A song paired with the saved entry; the song is null when the source no
/// longer has that id.
class DailyMixResolved {
  final DailyMixEntry entry;
  final MyAudioMetadata? song;

  const DailyMixResolved(this.entry, this.song);
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class DailyRecommendations {
  File? _file;
  bool _loaded = false;

  /// source key -> date -> day
  final Map<String, Map<String, DailyMixDay>> _sources = {};

  String get sourceKey =>
      '${sourceType.name}:${config.activeServerId ?? ''}';

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _file = File('${appSupportDir.path}/daily_recommendations.json');
    initFile(_file!, false);
    try {
      final json = await readJsonMapFile(_file!);
      final sources = json['sources'];
      if (sources is Map) {
        sources.forEach((key, value) {
          if (value is! Map) {
            return;
          }
          final days = <String, DailyMixDay>{};
          value.forEach((date, raw) {
            if (raw is Map) {
              final day = DailyMixDay.fromJson(raw);
              if (day.date.isNotEmpty) {
                days[day.date] = day;
              }
            }
          });
          _sources['$key'] = days;
        });
      }
    } catch (_) {
      // A missing or corrupt file is simply an empty history.
    }
  }

  List<DailyMixDay> days() {
    final map = _sources[sourceKey] ?? const <String, DailyMixDay>{};
    final list = map.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  DailyMixDay? day(String date) => _sources[sourceKey]?[date];

  DailyMixDay? today() => day(_dateKey(DateTime.now()));

  /// Returns today's list, generating it on first use. Refresh replaces the
  /// day's snapshot but never touches another day.
  Future<DailyMixDay> ensureToday({bool refresh = false}) async {
    await ensureLoaded();
    final key = _dateKey(DateTime.now());
    final existing = _sources[sourceKey]?[key];
    if (existing != null && !refresh) {
      return existing;
    }
    final exclude = refresh
        ? (existing?.songs.map((song) => song.id).toSet() ?? const <String>{})
        : const <String>{};
    final signals = await _loadListeningSignals();
    final generated = buildDailyMix(
      library.songList,
      DateTime.now(),
      excludeIds: exclude,
      seed: refresh ? DateTime.now().millisecondsSinceEpoch : null,
      sourceKey: sourceKey,
      listening: signals,
      skipAware: skipAwareRecommendationsNotifier.value,
      rediscoveryIds: {for (final song in history.rediscoverySongList) song.id},
      recentRecommendationCounts: _recentRecommendationCounts(),
    );
    final day = DailyMixDay(
      date: key,
      generatedAt: DateTime.now(),
      songs: [for (final song in generated) DailyMixEntry.fromSong(song)],
    );
    _sources.putIfAbsent(sourceKey, () => {})[key] = day;
    // Keep a year at most; a recommendation older than that is not useful and
    // the file must not grow forever.
    final map = _sources[sourceKey]!;
    if (map.length > 365) {
      final dates = map.keys.toList()..sort();
      final excess = map.length - 365;
      for (final date in dates.take(excess)) {
        map.remove(date);
      }
    }
    _save();
    return day;
  }

  List<DailyMixResolved> resolve(DailyMixDay day) {
    return [
      for (final entry in day.songs)
        DailyMixResolved(entry, library.id2Song[entry.id]),
    ];
  }

  /// Journal events for the active source only. A song's history on another
  /// server or in the local library must not steer this source's mix.
  Future<ListeningSignals> _loadListeningSignals() async {
    await playbackJournal.ensureLoaded();
    final key = sourceKey;
    return ListeningSignals.fromJournal(
      playbackJournal.sessions.where((session) => session.sourceKey == key),
    );
  }

  /// How often each song appeared in the last two weeks, so a mix rotates
  /// instead of returning the same small set. Today's snapshot is skipped:
  /// it is the list being replaced.
  Map<String, int> _recentRecommendationCounts({int days = 14}) {
    final counts = <String, int>{};
    final today = _dateKey(DateTime.now());
    final cutoff = DateTime.now().subtract(Duration(days: days));
    for (final day in this.days()) {
      if (day.date == today) {
        continue;
      }
      final date = DateTime.tryParse(day.date);
      if (date == null || date.isBefore(cutoff)) {
        continue;
      }
      for (final entry in day.songs) {
        counts[entry.id] = (counts[entry.id] ?? 0) + 1;
      }
    }
    return counts;
  }

  void _save() {
    try {
      _file?.writeAsStringSync(
        jsonEncode({
          'sources': {
            for (final source in _sources.entries)
              source.key: {
                for (final day in source.value.entries) day.key: day.value.toJson(),
              },
          },
        }),
      );
    } catch (_) {
      // A failed history write must not block playback.
    }
  }
}

final dailyRecommendations = DailyRecommendations();

/// Picks up to 20 songs from the loaded library.
///
/// The score is the sum of a few bounded dimensions: play count, favourites,
/// recency, new additions, artist/album affinity, rediscovery, journal
/// completion and repeated skips. Rotation against the last two weeks keeps
/// the draw from settling on the same small set. Everything is derived from
/// data the app already stores, and the day plus the source salt make an
/// unrefreshed day reproducible.
List<MyAudioMetadata> buildDailyMix(
  List<MyAudioMetadata> songs,
  DateTime day, {
  Set<String> excludeIds = const {},
  int? seed,
  String sourceKey = '',
  ListeningSignals? listening,
  bool skipAware = false,
  Set<String> rediscoveryIds = const {},
  Map<String, int> recentRecommendationCounts = const {},
}) {
  if (songs.isEmpty) {
    return const [];
  }

  // Using [day] as the reference point rather than DateTime.now() keeps the
  // score stable for that date; the stored snapshot then stays still.
  final scorer = RecommendationScorer.fromSongs(
    songs,
    now: day,
    rediscoveryIds: rediscoveryIds,
    recentRecommendationCounts: recentRecommendationCounts,
    listening: listening,
    skipAware: skipAware,
    excludeIds: excludeIds,
  );
  final weights = {for (final song in songs) song.id: scorer.weightOf(song)};
  double weightOf(MyAudioMetadata song) => weights[song.id] ?? 0.03;

  // A fixed seed for the day makes the list stable until the user refreshes;
  // refresh passes a different day-time-derived seed through the random call
  // below, so it prefers a different draw without becoming random noise. The
  // source key is part of the seed so two sources do not draw the same list.
  final random = Random(seed ?? _dailySeed(day, sourceKey));
  final pool = List<MyAudioMetadata>.from(songs);
  final picked = <MyAudioMetadata>[];
  final perArtist = <String, int>{};
  final perAlbum = <String, int>{};
  final maxItems = min(20, pool.length);

  bool allowed(MyAudioMetadata song, {required bool strict}) {
    if (!strict) {
      return true;
    }
    final artist = getArtist(song);
    final album = getAlbum(song);
    if (artist.isNotEmpty && (perArtist[artist] ?? 0) >= 2) {
      return false;
    }
    if (album.isNotEmpty && (perAlbum[album] ?? 0) >= 3) {
      return false;
    }
    return true;
  }

  void add(MyAudioMetadata song) {
    picked.add(song);
    final artist = getArtist(song);
    final album = getAlbum(song);
    if (artist.isNotEmpty) {
      perArtist[artist] = (perArtist[artist] ?? 0) + 1;
    }
    if (album.isNotEmpty) {
      perAlbum[album] = (perAlbum[album] ?? 0) + 1;
    }
  }

  while (picked.length < maxItems && pool.isNotEmpty) {
    // The final places relax the artist/album caps so a small library can
    // still fill the day instead of stopping at a handful.
    final strict = picked.length < maxItems - 3;
    final candidates = [
      for (final song in pool)
        if (allowed(song, strict: strict)) song,
    ];
    final usable = candidates.isEmpty ? pool : candidates;
    final total = usable.fold<double>(0, (sum, song) => sum + weightOf(song));
    var target = random.nextDouble() * total;
    var chosen = usable.last;
    for (final song in usable) {
      target -= weightOf(song);
      if (target <= 0) {
        chosen = song;
        break;
      }
    }
    add(chosen);
    pool.remove(chosen);
  }
  return picked;
}

int _dailySeed(DateTime day, String sourceKey) {
  var sourceHash = 17;
  for (final unit in sourceKey.codeUnits) {
    sourceHash = (sourceHash * 31 + unit) & 0x7fffffff;
  }
  return day.year * 1000003 + day.month * 1009 + day.day * 100003 + sourceHash;
}
