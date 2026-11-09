import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/utils/path.dart';

/// A small copy of a cached cover, for the media session.
///
/// The session metadata is a binder payload that a head unit receives whole, and
/// the cached artwork can be several megabytes; a car screen is small, so a
/// downscaled JPEG is published instead of the original. One file per cover,
/// written once and reused afterwards (the file is regenerated only when the
/// source cover is newer), so a track that is played again costs nothing.
final mediaArt = MediaArt();

class MediaArt {
  /// Longest side of the copy. Comfortably more than a head unit's screen needs
  /// while keeping the payload in the tens of kilobytes.
  static const int maxSide = 512;
  static const int quality = 80;

  final Map<String, String> _ready = {};
  final Map<String, Future<String?>> _pending = {};

  /// Where the small copy of [coverPath] lives, if it has already been made.
  String? readyPath(String coverPath) => _ready[coverPath];

  /// Where the small copy of [coverPath] belongs, whether or not it exists yet:
  /// the cache view uses it to drop the copy along with the cover.
  String targetPathFor(String coverPath) => _targetPath(coverPath);

  /// The small copy of [coverPath], making it if needed. Null when the cover
  /// cannot be read or decoded (the caller then publishes the original).
  Future<String?> smallFor(String coverPath) {
    final ready = _ready[coverPath];
    if (ready != null) {
      return Future.value(ready);
    }
    return _pending.putIfAbsent(coverPath, () => _make(coverPath));
  }

  Future<String?> _make(String coverPath) async {
    try {
      final source = File(coverPath);
      if (!await source.exists()) {
        return null;
      }

      final target = File(_targetPath(coverPath));
      if (await target.exists()) {
        final sourceTime = (await source.stat()).modified;
        final targetTime = (await target.stat()).modified;
        if (!targetTime.isBefore(sourceTime)) {
          _ready[coverPath] = target.path;
          return target.path;
        }
      }

      final decoded = img.decodeImage(await source.readAsBytes());
      if (decoded == null) {
        return null;
      }

      final resized = _fit(decoded);
      await target.create(recursive: true);
      await target.writeAsBytes(img.encodeJpg(resized, quality: quality));
      _ready[coverPath] = target.path;
      logger.output(
        '[media] art ${resized.width}x${resized.height} '
        '${await target.length()}B for $coverPath',
      );
      return target.path;
    } catch (e) {
      logger.output('[media] art downscale failed for $coverPath: $e');
      return null;
    } finally {
      _pending.remove(coverPath);
    }
  }

  img.Image _fit(img.Image decoded) {
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest <= maxSide) {
      return decoded;
    }
    final scale = maxSide / longest;
    return img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  /// Kept beside the covers, under the cover's own file name, so clearing the
/// picture cache removes these too and the two can be matched up again.
  String _targetPath(String coverPath) {
    final name = coverPath.substring(coverPath.lastIndexOf('/') + 1);
    return '${getPicturesPath(sourceType)}/media/$name';
  }

  void clear() {
    _ready.clear();
    _pending.clear();
  }
}