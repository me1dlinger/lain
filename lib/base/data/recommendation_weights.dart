import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/playback_journal.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/utils/metadata_utils.dart';

/// Whether recommendations should pay attention to songs the listener keeps
/// skipping. The signal itself is always collected; this only decides if it
/// changes the daily mix and the random shelf.
final skipAwareRecommendationsNotifier = ValueNotifier<bool>(true);

/// What the playback journal knows about one song.
///
/// Every event with a known duration is a listening attempt; a manual skip is
/// an attempt that ended by moving to another track before [ListeningSignals
/// .skipCompletionThreshold] of the song had played.
class SongListeningSignal {
  int attempts = 0;
  int listenedAttempts = 0;
  int skips = 0;
  double listenedCompletionTotal = 0;

  double get averageCompletion =>
      listenedAttempts == 0 ? 0 : listenedCompletionTotal / listenedAttempts;
}

/// The per-song view of the playback journal, reduced once per recommendation
/// build. It is deliberately built from the journal that is already on disk:
/// no separate database and no new event stream.
class ListeningSignals {
  static const skipReasons = {'next', 'previous'};

  /// A manual next/previous before this share of the song is a skip. A skip
  /// at the very end of a song (or a completed track) is not.
  static const skipCompletionThreshold = 0.15;

  /// One accidental tap is noise; the weight only drops once a song has been
  /// skipped at least this often in the lookback window.
  static const repeatedSkipThreshold = 2;

  static const lookbackWindow = Duration(days: 180);

  final Map<String, SongListeningSignal> bySongId;

  const ListeningSignals._(this.bySongId);

  factory ListeningSignals.fromJournal(
    Iterable<JournalSession> sessions, {
    DateTime? now,
    Duration lookback = lookbackWindow,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(lookback);
    final bySongId = <String, SongListeningSignal>{};
    for (final session in sessions) {
      for (final event in session.events) {
        if (event.songId.isEmpty || event.durationMs <= 0) {
          continue;
        }
        if (event.endedAt.isBefore(cutoff)) {
          continue;
        }
        // A lyric preview is a deliberate audition of a few seconds, not a
        // vote on the song.
        if (event.endedBy == 'lyricPreview') {
          continue;
        }
        final signal = bySongId.putIfAbsent(
          event.songId,
          SongListeningSignal.new,
        );
        signal.attempts++;
        final skipped = isSkipEvent(event);
        if (skipped) {
          signal.skips++;
        } else {
          // Completion is measured on attempts that were not a skip; a song
          // that is only ever skipped has no "listened through" evidence.
          signal.listenedAttempts++;
          signal.listenedCompletionTotal += event.completionRatio;
        }
      }
    }
    return ListeningSignals._(bySongId);
  }

  static bool isSkipEvent(JournalEvent event) =>
      skipReasons.contains(event.endedBy) &&
      event.completionRatio <= skipCompletionThreshold;

  int skipsOf(String songId) => bySongId[songId]?.skips ?? 0;

  bool wasRepeatedlySkipped(String songId) =>
      skipsOf(songId) >= repeatedSkipThreshold;

  /// Multiplier applied to a song's recommendation weight.
  ///
  /// Completion gently rewards songs that are actually listened through; the
  /// skip penalty is sharper but starts only after repeated skips, and is
  /// disabled entirely when the setting is off.
  double weightMultiplier(String songId, {bool skipAware = true}) {
    final signal = bySongId[songId];
    if (signal == null || signal.attempts == 0) {
      return 1;
    }
    var multiplier = 1.0;
    if (signal.listenedAttempts > 0) {
      multiplier *= 0.74 + 0.52 * signal.averageCompletion;
    }
    if (skipAware && signal.skips >= repeatedSkipThreshold) {
      multiplier *= 1 / (1 + 0.5 * (signal.skips - 1));
    }
    return multiplier.clamp(0.2, 1.3);
  }
}

/// Multi-dimensional score for one candidate song.
///
/// It is pure: everything it needs is passed in, which keeps the same day's
/// draw reproducible and makes each dimension testable on its own.
class RecommendationScorer {
  final DateTime now;
  final Map<String, int> artistPlays;
  final Map<String, int> albumPlays;
  final Set<String> rediscoveryIds;
  final Map<String, int> recentRecommendationCounts;
  final ListeningSignals? listening;
  final bool skipAware;
  final Set<String> excludeIds;

  const RecommendationScorer({
    required this.now,
    required this.artistPlays,
    required this.albumPlays,
    this.rediscoveryIds = const {},
    this.recentRecommendationCounts = const {},
    this.listening,
    this.skipAware = false,
    this.excludeIds = const {},
  });

  factory RecommendationScorer.fromSongs(
    Iterable<MyAudioMetadata> songs, {
    required DateTime now,
    Set<String> rediscoveryIds = const {},
    Map<String, int> recentRecommendationCounts = const {},
    ListeningSignals? listening,
    bool skipAware = false,
    Set<String> excludeIds = const {},
  }) {
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
    return RecommendationScorer(
      now: now,
      artistPlays: artistPlays,
      albumPlays: albumPlays,
      rediscoveryIds: rediscoveryIds,
      recentRecommendationCounts: recentRecommendationCounts,
      listening: listening,
      skipAware: skipAware,
      excludeIds: excludeIds,
    );
  }

  double weightOf(MyAudioMetadata song) {
    // Familiarity: a song that is returned to often is worth more, but the
    // logarithm keeps one heavily played track from crowding out everything.
    var weight = 1 + log(1 + song.playCount) * 2.2;
    if (song.isFavoriteNotifier.value) {
      weight += 3.5;
    }

    // Recency: just heard songs step back so the mix is not yesterday's queue.
    // Long-rested songs come forward; that is the rediscovery direction.
    final last = song.lastPlayed;
    if (last == null) {
      weight += 1.0;
    } else {
      final days = now.difference(last).inDays;
      if (days < 1) {
        weight *= 0.2;
      } else if (days < 3) {
        weight *= 0.35;
      } else if (days < 7) {
        weight *= 0.55;
      } else if (days < 30) {
        weight *= 0.8;
      } else if (days < 90) {
        weight *= 1.1;
      } else {
        weight *= 1.45;
      }
    }

    // New additions get a short window of attention, then fade into the pool.
    final created = song.created ?? song.modified;
    if (created != null) {
      final days = now.difference(created).inDays;
      if (days <= 7) {
        weight += 1.8;
      } else if (days <= 30) {
        weight += 0.9;
      } else if (days <= 90) {
        weight += 0.3;
      }
    }

    // Artist and album affinity: what the listener's history says about the
    // surrounding work, weaker than the song's own play count.
    final artist = getArtist(song);
    final album = getAlbum(song);
    if (artist.isNotEmpty) {
      weight += min(3.0, log(1 + (artistPlays[artist] ?? 0)) * 0.35);
    }
    if (album.isNotEmpty) {
      weight += min(2.0, log(1 + (albumPlays[album] ?? 0)) * 0.22);
    }

    // Rediscovery is the existing "long time no see" shelf: songs that were
    // played before and rested. They get one of the strongest nudges.
    if (rediscoveryIds.contains(song.id)) {
      weight = (weight + 1.6) * 1.25;
    }

    // Journal signals: completion ratio and, when enabled, repeated skips.
    final signals = listening;
    if (signals != null) {
      weight *= signals.weightMultiplier(song.id, skipAware: skipAware);
    }

    // Rotation: a song that appeared in the last fortnight returns less often.
    final recentCount = recentRecommendationCounts[song.id] ?? 0;
    if (recentCount > 0) {
      weight *= 1 / (1 + 0.55 * recentCount);
    }

    // A refresh asks for a different set; these are pushed down, not banned,
    // so a small library can still fill twenty places.
    if (excludeIds.contains(song.id)) {
      weight *= 0.18;
    }

    return max(0.03, weight);
  }
}

/// Draws [count] distinct items, each with probability proportional to its
/// weight. Used by both the daily mix and the local random shelf.
List<T> weightedSample<T>(
  Iterable<T> items,
  double Function(T item) weightOf,
  int count,
  Random random,
) {
  final pool = List<T>.of(items);
  final picked = <T>[];
  while (picked.length < count && pool.isNotEmpty) {
    final weights = [for (final item in pool) max(0.0, weightOf(item))];
    var total = 0.0;
    for (final weight in weights) {
      total += weight;
    }
    if (total <= 0) {
      pool.shuffle(random);
      picked.addAll(pool.take(count - picked.length));
      break;
    }
    var target = random.nextDouble() * total;
    var index = pool.length - 1;
    for (var i = 0; i < pool.length; i++) {
      target -= weights[i];
      if (target <= 0) {
        index = i;
        break;
      }
    }
    picked.add(pool.removeAt(index));
  }
  return picked;
}
