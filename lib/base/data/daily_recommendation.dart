import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:lain/base/app.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/data/library.dart';
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
    final generated = buildDailyMix(
      library.songList,
      DateTime.now(),
      excludeIds: exclude,
      seed: refresh ? DateTime.now().millisecondsSinceEpoch : null,
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

/// Picks 20 songs from the loaded library. The weights favour songs the
/// listener actually returns to, but quietly: a low-play favourite, a
/// rediscovered song and a fresh addition can all outrank a heavily played
/// one that was heard five minutes ago.
List<MyAudioMetadata> buildDailyMix(
  List<MyAudioMetadata> songs,
  DateTime day, {
  Set<String> excludeIds = const {},
  int? seed,
}) {
  if (songs.isEmpty) {
    return const [];
  }
  final now = DateTime.now();
  final artistPlays = <String, int>{};
  final albumPlays = <String, int>{};
  for (final song in songs) {
    final artist = getArtist(song);
    if (artist.isNotEmpty) {
      artistPlays[artist] = (artistPlays[artist] ?? 0) + song.playCount;
    }
    final album = getAlbum(song);
    if (album.isNotEmpty) {
      albumPlays[album] = (albumPlays[album] ?? 0) + song.playCount;
    }
  }

  double weightOf(MyAudioMetadata song) {
    var weight = 1 + log(1 + song.playCount) * 2.2;
    if (song.isFavoriteNotifier.value) {
      weight += 4;
    }
    final last = song.lastPlayed;
    if (last == null) {
      weight += 1.2;
    } else {
      final days = now.difference(last).inDays;
      if (days < 2) {
        weight *= 0.18;
      } else if (days < 7) {
        weight *= 0.38;
      } else if (days < 30) {
        weight *= 0.72;
      } else {
        weight *= 1.5;
      }
    }
    final created = song.created ?? song.modified;
    if (created != null && now.difference(created).inDays < 14) {
      weight += 1.4;
    }
    final artist = getArtist(song);
    final album = getAlbum(song);
    if (artist.isNotEmpty) {
      weight += min(3.0, log(1 + (artistPlays[artist] ?? 0)) * 0.35);
    }
    if (album.isNotEmpty) {
      weight += min(2.0, log(1 + (albumPlays[album] ?? 0)) * 0.22);
    }
    if (excludeIds.contains(song.id)) {
      weight *= 0.22;
    }
    return max(0.05, weight);
  }

  // A fixed seed for the day makes the list stable until the user refreshes;
  // refresh passes a different day-time-derived seed through the random call
  // below, so it prefers a different draw without becoming random noise.
  final random = Random(
    seed ?? (day.day * 100003 + day.month * 1009 + day.year),
  );
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
