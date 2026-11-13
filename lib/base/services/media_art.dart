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

  /// The most a broadcast cover may weigh. A head unit shows a thumbnail, and
  /// the image travels over a Bluetooth link that is slow enough for a large
  /// one to be the reason a cover arrives long after the title did.
  static const int maxBroadcastBytes = 50 * 1024;

  /// Copies that are ready, keyed by `<source path>|<max side>`: the same cover
  /// downscaled to two sizes must never be confused for one another.
  final Map<String, String> _ready = {};
  final Map<String, Future<String?>> _pending = {};

  static String _key(String coverPath, int maxSide) => '$coverPath|$maxSide';

  /// Where the downscaled copy of [coverPath] lives, if it has already been
  /// made.
  ///
  /// The file is checked, not just the in-memory map: a copy made in an earlier
  /// run (or by the cache page) is on disk and must not cost a request again.
  /// A path whose file was cleared behind the map - the OS reclaims the cache
  /// directory - is forgotten instead of being handed out.
  String? readyPath(String coverPath, {int maxSide = broadcastSide}) {
    final key = _key(coverPath, maxSide);
    final ready = _ready[key];
    if (ready != null) {
      if (File(ready).existsSync()) {
        return ready;
      }
      _ready.remove(key);
    }
    final target = _targetPath(coverPath, maxSide);
    if (File(target).existsSync()) {
      _ready[key] = target;
      return target;
    }
    return null;
  }

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
    final ready = readyPath(coverPath, maxSide: maxSide);
    if (ready != null) {
      return Future.value(ready);
    }
    final key = _key(coverPath, maxSide);
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
      var encoded = result.bytes;
      if (encoded == null) {
        return null;
      }
      encoded = await _fitBudget(encoded, maxSide);

      await target.create(recursive: true);
      await target.writeAsBytes(encoded, flush: true);
      _ready[key] = target.path;
      logger.output(
        '[media] art ${result.width}x${result.height} '
        '${encoded.length}B (side=$maxSide) for $coverPath',
      );
      return target.path;
    } catch (e) {
      logger.output('[media] art downscale failed for $coverPath: $e');
      return null;
    } finally {
      _pending.remove(key);
    }
  }

  /// Writes a cover the server already rendered at the broadcast size (a
  /// streamed track asks its server for exactly that, instead of downloading
  /// and decoding the large original). Re-encoded only when the answer is
  /// larger than the budget.
  Future<String?> smallFromBytes(
    String coverPath,
    Uint8List bytes, {
    int maxSide = broadcastSide,
  }) async {
    if (coverPath.isEmpty || bytes.isEmpty) {
      return null;
    }
    // A thumbnail made in an earlier run is reused: this is what keeps a
    // streamed cover from being requested again on every launch.
    final ready = readyPath(coverPath, maxSide: maxSide);
    if (ready != null) {
      return ready;
    }
    final key = _key(coverPath, maxSide);
    try {
      // Always decode and re-encode: a server that ignores the requested size
      // would otherwise hand the head unit a 600 px image, and the car only
      // needs a 100 px thumbnail.
      final result = await compute(
        downscaleMediaArt,
        MediaArtRequest(bytes: bytes, maxSide: maxSide, quality: quality),
      );
      var encoded = result.bytes ?? bytes;
      if (encoded.length > maxBroadcastBytes || result.bytes == null) {
        encoded = await _fitBudget(encoded, maxSide);
      }
      final target = File(_targetPath(coverPath, maxSide));
      await target.create(recursive: true);
      await target.writeAsBytes(encoded, flush: true);
      _ready[key] = target.path;
      logger.output(
        '[media] art ${encoded.length}B (side=$maxSide) from server '
        'for $coverPath',
      );
      return target.path;
    } catch (e) {
      logger.output('[media] art thumbnail failed for $coverPath: $e');
      return null;
    }
  }

  /// Re-encodes [bytes] with a lower quality (and, if that is not enough, a
  /// smaller side) until it fits [maxBroadcastBytes].
  Future<Uint8List> _fitBudget(Uint8List bytes, int maxSide) async {
    var encoded = bytes;
    for (final quality in const [70, 55, 40, 30]) {
      if (encoded.length <= maxBroadcastBytes) {
        return encoded;
      }
      final smaller = await compute(
        downscaleMediaArt,
        MediaArtRequest(bytes: encoded, maxSide: maxSide, quality: quality),
      );
      if (smaller.bytes == null) {
        break;
      }
      encoded = smaller.bytes!;
    }
    if (encoded.length > maxBroadcastBytes) {
      final tiny = await compute(
        downscaleMediaArt,
        MediaArtRequest(
          bytes: encoded,
          maxSide: maxSide ~/ 2,
          quality: 40,
        ),
      );
      encoded = tiny.bytes ?? encoded;
    }
    return encoded;
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
