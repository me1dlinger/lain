import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:lain/base/app.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/utils/path.dart';

/// What a background isolate needs to make the small copy.
class MediaArtRequest {
  final Uint8List bytes;
  final int maxSide;
  final int quality;

  const MediaArtRequest({
    required this.bytes,
    required this.maxSide,
    required this.quality,
  });
}

/// The encoded copy, or null when the bytes are not an image at all.
class MediaArtResult {
  final Uint8List? bytes;
  final int width;
  final int height;

  const MediaArtResult(this.bytes, this.width, this.height);
}

/// Decodes, downscales and re-encodes one cover.
///
/// Top-level (and run through [compute]) on purpose: a multi-megabyte cover
/// takes long enough to decode that doing it on the UI isolate would hitch the
/// app, and this runs for prefetched tracks too.
MediaArtResult downscaleMediaArt(MediaArtRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) {
    return const MediaArtResult(null, 0, 0);
  }

  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longest <= request.maxSide) {
    final encoded = img.encodeJpg(decoded, quality: request.quality);
    return MediaArtResult(encoded, decoded.width, decoded.height);
  }

  final scale = request.maxSide / longest;
  final width = (decoded.width * scale).round();
  final height = (decoded.height * scale).round();
  final fitted = img.copyResize(
    decoded,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );
  return MediaArtResult(
    img.encodeJpg(fitted, quality: request.quality),
    width,
    height,
  );
}

/// A small copy of a cached cover, for the media session.
///
/// The session metadata is a binder payload that a head unit receives whole, and
/// the cached artwork can be several megabytes; a car screen is small, so a
/// downscaled JPEG is published instead of the original. One file per cover
/// *and size*, written once and reused afterwards (the file is regenerated only
/// when the source cover is newer), so a track that is played again costs
/// nothing - and so a head unit's copy can never be handed to a caller that
/// asked for a different size.
final mediaArt = MediaArt();

class MediaArt {
  /// Longest side of the copy the media session publishes. A head unit shows
  /// the artwork at about the size of a thumbnail and cannot be tapped open, so
  /// this is all the resolution it can use; keeping it small is also what keeps
  /// the metadata payload cheap to send for every track.
  static const int broadcastSide = 100;

  /// Longest side of the copy the app's own UI surfaces use. A full-size copy
  /// of the original can be several megabytes and is what the phone renders
  /// from; only the head unit gets [broadcastSide].
  static const int maxSize = 512;

  static const int quality = 80;

  /// Copies that are ready, keyed by `<source path>|<max side>`: the same cover
  /// downscaled to two sizes must never be confused for one another.
  final Map<String, String> _ready = {};
  final Map<String, Future<String?>> _pending = {};

  static String _key(String coverPath, int maxSide) => '$coverPath|$maxSide';

  /// Where the downscaled copy of [coverPath] lives, if it has already been
  /// made.
  String? readyPath(String coverPath, {int maxSide = broadcastSide}) =>
      _ready[_key(coverPath, maxSide)];

  /// The broadcast-sized copy of [coverPath], if it has already been made.
  /// The relay key and the session's bitmap both use it: the original is never
  /// the copy a head unit gets.
  String? broadcastPathFor(String coverPath) => readyPath(coverPath);

  /// Where the copy of [coverPath] at [maxSide] belongs, whether or not it
  /// exists yet: the cache view uses it to drop the copy with the cover.
  String targetPathFor(String coverPath, {int maxSide = broadcastSide}) =>
      _targetPath(coverPath, maxSide);

  /// The copy of [coverPath] at [maxSide], making it if needed. Null when the
  /// cover cannot be read or decoded; the caller then publishes nothing for the
  /// artwork, so a later attempt can still succeed instead of pinning the
  /// failure.
  Future<String?> smallFor(String coverPath, {int maxSide = broadcastSide}) {
    final key = _key(coverPath, maxSide);
    final ready = _ready[key];
    if (ready != null) {
      return Future.value(ready);
    }
    return _pending.putIfAbsent(key, () => _make(coverPath, maxSide));
  }

  Future<String?> _make(String coverPath, int maxSide) async {
    final key = _key(coverPath, maxSide);
    try {
      final source = File(coverPath);
      if (!await source.exists()) {
        return null;
      }

      final target = File(_targetPath(coverPath, maxSide));
      if (await target.exists()) {
        final sourceTime = (await source.stat()).modified;
        final targetTime = (await target.stat()).modified;
        if (!targetTime.isBefore(sourceTime)) {
          _ready[key] = target.path;
          return target.path;
        }
      }

      final result = await compute(
        downscaleMediaArt,
        MediaArtRequest(
          bytes: await source.readAsBytes(),
          maxSide: maxSide,
          quality: quality,
        ),
      );
      if (result.bytes == null) {
        return null;
      }

      await target.create(recursive: true);
      await target.writeAsBytes(result.bytes!);
      _ready[key] = target.path;
      logger.output(
        '[media] art ${result.width}x${result.height} '
        '${await target.length()}B (side=$maxSide) for $coverPath',
      );
      return target.path;
    } catch (e) {
      logger.output('[media] art downscale failed for $coverPath: $e');
      return null;
    } finally {
      _pending.remove(key);
    }
  }

  /// Kept beside the covers, under the cover's own file name, so clearing the
  /// picture cache removes these too and the two can be matched up again. The
  /// size is part of the name, so one cover holds one copy per size.
  String _targetPath(String coverPath, int maxSide) {
    final name = coverPath.substring(coverPath.lastIndexOf('/') + 1);
    return '${getPicturesPath(sourceType)}/media/$name.$maxSide';
  }

  void clear() {
    _ready.clear();
    _pending.clear();
  }
}
