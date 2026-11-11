import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/utils/path.dart';

/// One song's totals, kept per year and shared by every source: the same song
/// played from Navidrome and from a local folder lands in the same bucket.
class StatsSong {
  final String title;
  final String artist;
  final String album;
  int plays;
  int millis;

  StatsSong({
    required this.title,
    required this.artist,
    required this.album,
    this.plays = 0,
    this.millis = 0,
  });

  factory StatsSong.fromJson(Map json) => StatsSong(
    title: '${json['t'] ?? ''}',
    artist: '${json['a'] ?? ''}',
    album: '${json['b'] ?? ''}',
    plays: json['p'] as int? ?? 0,
    millis: json['m'] as int? ?? 0,
  );

  Map<String, Object?> toJson() => {
    't': title,
    'a': artist,
    'b': album,
    'p': plays,
    'm': millis,
  };
}

/// A single square of the yearly heatmap.
class StatsDay {
  int plays;
  int millis;

  /// song key -> plays that day (the keys of [StatsYear.songs]).
  final Map<String, int> songs = {};

  StatsDay({this.plays = 0, this.millis = 0});
}

class StatsYear {
  final Map<String, StatsDay> days = {};

  /// key: lowercased "title|artist"
  final Map<String, StatsSong> songs = {};

  final Map<String, int> artists = {};
  final Map<String, int> albums = {};

  int get plays {
    var total = 0;
    for (final day in days.values) {
      total += day.plays;
    }
    return total;
  }

  int get millis {
    var total = 0;
    for (final day in days.values) {
      total += day.millis;
    }
    return total;
  }
}

/// Local listening statistics, written to a single json file in the app data
/// directory so that every music source contributes to the same report.
class ListeningStats {
  late File file;
  bool _loaded = false;

  /// year -> aggregates
  final Map<String, StatsYear> years = {};

  /// Loads the file on first use (the getters below stay synchronous).
  Future<void> ensureLoaded() => _ensureLoaded();

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    file = File('${appSupportDir.path}/listening_stats.json');
    initFile(file, false);
    try {
      final json = await readJsonMapFile(file);
      final rawYears = json['years'];
      if (rawYears is! Map) {
        return;
      }
      rawYears.forEach((year, data) {
        if (data is! Map) {
          return;
        }
        final statsYear = StatsYear();
        final rawDays = data['days'];
        if (rawDays is Map) {
          rawDays.forEach((day, value) {
            if (value is Map) {
              final statsDay = StatsDay(
                plays: value['p'] as int? ?? 0,
                millis: value['m'] as int? ?? 0,
              );
              final daySongs = value['s'];
              if (daySongs is Map) {
                daySongs.forEach((key, count) {
                  if (count is int) {
                    statsDay.songs['$key'] = count;
                  }
                });
              }
              statsYear.days['$day'] = statsDay;
            }
          });
        }
        final rawSongs = data['songs'];
        if (rawSongs is Map) {
          rawSongs.forEach((key, value) {
            if (value is Map) {
              statsYear.songs['$key'] = StatsSong.fromJson(value);
            }
          });
        }
        final rawArtists = data['artists'];
        if (rawArtists is Map) {
          rawArtists.forEach((key, value) {
            if (value is int) {
              statsYear.artists['$key'] = value;
            }
          });
        }
        final rawAlbums = data['albums'];
        if (rawAlbums is Map) {
          rawAlbums.forEach((key, value) {
            if (value is int) {
              statsYear.albums['$key'] = value;
            }
          });
        }
        years['$year'] = statsYear;
      });
    } catch (error) {
      logger.output('[stats] load failed: $error');
    }
  }

  void _save() {
    try {
      file.writeAsStringSync(
        jsonEncode({
          'years': {
            for (final entry in years.entries)
              entry.key: {
                'days': {
                  for (final day in entry.value.days.entries)
                    day.key: {
                      'p': day.value.plays,
                      'm': day.value.millis,
                      's': day.value.songs,
                    },
                },
                'songs': {
                  for (final song in entry.value.songs.entries)
                    song.key: song.value.toJson(),
                },
                'artists': entry.value.artists,
                'albums': entry.value.albums,
              },
          },
        }),
      );
    } catch (error) {
      logger.output('[stats] save failed: $error');
    }
  }

  /// Records one finished (or mostly finished) listen.
  Future<void> recordPlay(MyAudioMetadata song, Duration listened) async {
    final millis = listened.inMilliseconds;
    if (millis <= 0) {
      return;
    }
    await _ensureLoaded();

    final now = DateTime.now();
    final year = '${now.year}';
    final dayKey =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final statsYear = years.putIfAbsent(year, StatsYear.new);
    final day = statsYear.days.putIfAbsent(dayKey, StatsDay.new);
    day.plays++;
    day.millis += millis;

    final title = getTitle(song);
    final artist = getArtist(song);
    final album = getAlbum(song);

    final songKey = '${title.toLowerCase()}|${artist.toLowerCase()}';
    final statsSong = statsYear.songs.putIfAbsent(
      songKey,
      () => StatsSong(title: title, artist: artist, album: album),
    );
    statsSong.plays++;
    statsSong.millis += millis;
    day.songs[songKey] = (day.songs[songKey] ?? 0) + 1;

    if (artist.isNotEmpty) {
      statsYear.artists[artist] = (statsYear.artists[artist] ?? 0) + 1;
    }
    if (album.isNotEmpty) {
      statsYear.albums[album] = (statsYear.albums[album] ?? 0) + 1;
    }

    _save();
  }

  /// Years that have any data, newest first.
  List<String> get availableYears {
    final list = years.entries
        .where((entry) => entry.value.plays > 0)
        .map((entry) => entry.key)
        .toList();
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  StatsYear year(String year) => years[year] ?? StatsYear();

  /// Songs played on one day, most played first. Titles come from the year's
  /// songs, which is where the names are kept.
  List<StatsSong> topSongsOfDay(String year, StatsDay? day, int limit) {
    if (day == null || day.songs.isEmpty) {
      return const [];
    }
    final entries = day.songs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <StatsSong>[];
    for (final entry in entries) {
      if (result.length >= limit) {
        break;
      }
      final song = this.year(year).songs[entry.key];
      if (song != null) {
        result.add(song);
      }
    }
    return result;
  }

  List<StatsSong> topSongs(String year, int limit) {
    final songs = this.year(year).songs.values.toList()
      ..sort((a, b) => b.plays.compareTo(a.plays));
    return songs.take(limit).toList();
  }

  List<MapEntry<String, int>> topOf(Map<String, int> counts, int limit) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  Future<void> clear() async {
    await _ensureLoaded();
    years.clear();
    _save();
  }
}

final stats = ListeningStats();