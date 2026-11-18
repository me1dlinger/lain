import 'dart:io';

import 'package:lain/base/app.dart';
import 'package:lain/base/data/database.dart';
import 'package:lain/base/extensions/metadata_extension.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/utils/metadata_utils.dart';

/// Finds the same song in the local library when a streamed server cannot
/// serve it. It only matches metadata - the app has no content hashes - so the
/// threshold is deliberately conservative and an ambiguous pair is rejected
/// rather than playing the wrong song.
class EquivalentTrackFinder {
  Future<MyAudioMetadata?> findLocal(MyAudioMetadata song) async {
    if (sourceType == .local) {
      return null;
    }
    final file = File('${appSupportDir.path}/local/metadata.db');
    if (!file.existsSync()) {
      return null;
    }
    final title = getTitle(song).trim();
    if (title.isEmpty) {
      return null;
    }
    final db = MetadataDB(openMetadataDB('local/metadata.db'));
    try {
      final rows = await (db.select(
        db.metadataItems,
      )..where((table) => table.title.equals(title))).get();
      if (rows.isEmpty) {
        return null;
      }
      final wantedDuration = song.duration?.inMilliseconds ?? 0;
      final wantedArtist = getArtist(song).trim().toLowerCase();
      final wantedAlbum = getAlbum(song).trim().toLowerCase();
      MyAudioMetadata? best;
      var bestScore = -1;
      for (final row in rows) {
        final candidate = row.toMetadata();
        final path = candidate.path;
        if (path == null || !File(path).existsSync()) {
          continue;
        }
        final duration =
            candidate.duration?.inMilliseconds ?? 0;
        if (wantedDuration > 0 && duration > 0) {
          if ((duration - wantedDuration).abs() > 8000) {
            continue;
          }
        }
        var score = 0;
        if (wantedDuration > 0 && duration > 0) {
          final delta = (duration - wantedDuration).abs();
          score += delta <= 1500
              ? 40
              : delta <= 3000
              ? 25
              : 10;
        }
        if (getArtist(candidate).trim().toLowerCase() == wantedArtist) {
          score += 15;
        }
        if (getAlbum(candidate).trim().toLowerCase() == wantedAlbum) {
          score += 10;
        }
        if (song.size != null && candidate.size == song.size) {
          score += 30;
        }
        if (score > bestScore) {
          best = candidate;
          bestScore = score;
        } else if (score == bestScore && best != null) {
          // Two equally good local candidates: do not guess.
          best = null;
        }
      }
      return bestScore >= 25 ? best : null;
    } catch (_) {
      return null;
    } finally {
      await db.close();
    }
  }
}

final equivalentTrackFinder = EquivalentTrackFinder();
