import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:lain/base/app.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/picture_load_scheduler.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/services/webdav_client.dart';
import 'package:lain/base/utils/path.dart';

List<MyPicture> globalPictureList = [];

/// One picture object per id for the whole process.
///
/// A cover is shown in several places (the home card, the page header, the
/// media session), and each place used to build its own [MyPicture] for the
/// same id. The objects then disagreed: one had `isLoaded`/`isExist` set from
/// the load it ran, while the others kept their placeholder state and asked the
/// scheduler for the same image again - which is how a header ended up blank
/// after the home card had already shown the cover. Sharing the object means a
/// cover loaded once is a cover known everywhere.
final Map<String, MyPicture> _pictureRegistry = {};

/// Below this many bytes a server "artist image" is the placeholder star, not
/// a real picture.
const _artistPlaceholderMinBytes = 2048;

class MyPicture {
  String id;
  bool isLoaded = false;
  bool isExist = false;
  String path = '';
  Color? color;
  Color? lowerLuminance;

  /// The one source of this picture's bytes when it is set. An artist image
  /// needs this: the server answers the cover-art endpoint with a placeholder
  /// (a star) for an artist it has no image for, so the generic fallbacks must
  /// not run for it. The bytes still land in the same on-disk cache as every
  /// other cover.
  Future<Uint8List?> Function()? remoteResolver;

  final changeNotifier = ValueNotifier(0);

  MyPicture(this.id, {String? md5Hash, String? explicitPath}) {
    if (id.isEmpty) {
      isExist = false;
      isLoaded = true;
      color = Colors.grey;
      return;
    }
    md5Hash ??= md5.convert(utf8.encode(id)).toString();
    path = explicitPath ?? '${getPicturesPath(sourceType)}/$md5Hash';
    if (_hasImageFile(path)) {
      isLoaded = true;
      isExist = true;
    } else {
      isExist = false;
    }
  }

  /// Whether an artist image is already on disk. Used before deciding to fall
  /// back to an album cover: a cached image wins even when the server's current
  /// metadata does not mention one.
  static bool artistExists(String name) => File(artistPath(name)).existsSync();

  /// Where [MyPicture.artist] keeps its file, keyed by the artist's name so a
  /// local library can reuse what Navidrome fetched for the same artist.
  static String artistPath(String name) {
    final key = name.trim().toLowerCase();
    final hash = md5.convert(utf8.encode(key)).toString();
    return '${appSupportDir.path}/artist_images/$hash';
  }

  /// An artist's picture, cached in one place for every source.
  ///
  /// The server's own image ([allowServerCover]) is tried first: it lives on
  /// the server, is fast, and `hasImage` guarantees the cover-art endpoint has
  /// real bytes. [imageUrl] is the external image used when the server has
  /// none; an `imageAbsent` artist must never hit the cover-art endpoint,
  /// because that answers with a star placeholder.
  factory MyPicture.artist(
    String name, {
    String? artistId,
    String? imageUrl,
    bool allowServerCover = false,
  }) {
    final key = name.trim().toLowerCase();
    final cached = _pictureRegistry['artist:$key'];
    if (cached != null) {
      return cached;
    }
    final picture = MyPicture(
      'artist:$key',
      explicitPath: artistPath(name),
    );
    picture.remoteResolver = () async {
      if (!isStreamSource) {
        return null;
      }
      if (allowServerCover && artistId != null) {
        final bytes = await streamClient?.getPictureBytes(artistId, size: 400);
        // Navidrome answers an artist without a local image with a tiny star
        // placeholder (a few hundred bytes). Treat anything that small as "no
        // image" instead of caching it as the avatar.
        if (bytes != null && bytes.length >= _artistPlaceholderMinBytes) {
          return bytes;
        }
      }
      if (imageUrl != null && imageUrl.isNotEmpty) {
        return fetchRemoteImageBytes(imageUrl);
      }
      return null;
    };
    _pictureRegistry[picture.id] = picture;
    globalPictureList.add(picture);
    return picture;
  }

  factory MyPicture.form(String id) {
    final cached = _pictureRegistry[id];
    if (cached != null) {
      return cached;
    }
    final md5Hash = md5.convert(utf8.encode(id)).toString();
    final picture = MyPicture(id, md5Hash: md5Hash);
    _pictureRegistry[id] = picture;
    globalPictureList.add(picture);
    return picture;
  }

  void reset() {
    isLoaded = false;
    isExist = false;
    color = null;
    lowerLuminance = null;
    pictureLoadScheduler.resetPicture(this);
  }
}

/// Some image CDNs (NetEase among them) answer Dart's default User-Agent with
/// 403 and only serve a real image to a browser-like one.
const _imageRequestUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

/// Fetches an absolute image URL, used for an artist's external
/// `largeImageUrl` when the server itself has no artist image.
Future<Uint8List?> fetchRemoteImageBytes(String url) async {
  try {
    var target = Uri.parse(url);
    // NetEase image URLs carry their size in a `param` query. The server hands
    // out 1200x1200 (~900 KB), which is far more than an avatar needs and can
    // take longer than the timeout on a slow phone link; 600x600 is ample.
    if (target.queryParameters.containsKey('param')) {
      target = target.replace(
        queryParameters: {...target.queryParameters, 'param': '600y600'},
      );
    }
    final headers = <String, String>{'User-Agent': _imageRequestUserAgent};
    if (target.host.endsWith('music.126.net') ||
        target.host.endsWith('music.163.com')) {
      headers['Referer'] = 'https://music.163.com/';
    }
    final response = await http
        .get(target, headers: headers)
        // An image that takes longer than this is not worth holding the row
        // blank for; the album cover is shown instead and a long-press retries.
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      return response.bodyBytes;
    }
    logger.output('image $target: HTTP ${response.statusCode}');
  } catch (e) {
    logger.output('image $url: $e');
  }
  return null;
}

Future<void> loadPictureSafe(
  MyPicture picture, {
  int? widgetId,
  bool priority = false,
}) async {
  if (picture.id.isEmpty) {
    return;
  }
  // Only a load that ended with an image sets isLoaded (see [_loadPicture]),
  // and the file is checked rather than trusted: a cache directory the OS
  // cleared leaves the flags saying "loaded" for a file that is gone, which
  // used to mean a blank cover for the rest of the session.
  if (picture.isLoaded && picture.isExist && _hasImageFile(picture.path)) {
    return;
  }
  return pictureLoadScheduler.load(
    picture.id,
    () async {
      await _loadPicture(picture);
      return picture.isLoaded && picture.isExist;
    },
    widgetId,
    priority: priority,
  );
}

Future<void> _loadPicture(MyPicture picture) async {
  // Disk first: the image may already be there - from another instance of the
  // same id, or from a previous run - and re-downloading what is cached is what
  // makes re-entering a page slow.
  try {
    final file = File(picture.path);
    if (await file.exists() && await file.length() > 0) {
      picture.isExist = true;
      picture.isLoaded = true;
      return;
    }
  } catch (_) {}

  Uint8List? bytes;

  final resolver = picture.remoteResolver;
  if (resolver != null) {
    // An artist image decides its own source. Running the generic fallbacks as
    // well called the resolver twice (a long blank while the external URL
    // timed out) and let the cover-art endpoint cache its star placeholder.
    try {
      bytes = await resolver();
    } catch (e) {
      logger.output(e.toString());
    }
  } else {
    try {
      switch (sourceType) {
        case .local:
          bytes = await readPictureAsync(picture.id);
          break;
        case .webdav:
          final tmpPath = await covertToRedirectPathIfNeed(picture.id);
          if (tmpPath == null) {
            bytes = await readPictureAsync(
              picture.id,
              headers: webdavClient?.headers,
            );
          } else {
            bytes = await readPictureAsync(tmpPath);
          }
          break;
        default:
          bytes = await streamClient?.getPictureBytes(picture.id);
          break;
      }
    } catch (e) {
      // A server that has no image for this id may answer with an error; that
      // is not a reason to fail the picture load.
      logger.output(e.toString());
    }
  }

  if (bytes != null && bytes.isNotEmpty) {
    try {
      File pictureFile = File(picture.path);
      if (!await pictureFile.exists()) {
        await pictureFile.create(recursive: true);
      }
      await pictureFile.writeAsBytes(bytes);
      picture.isExist = true;
    } catch (e) {
      logger.output(e.toString());
    }
  }
  // A load that produced nothing stays retryable: `isLoaded` means "an image
  // is available", and setting it on a failed fetch is what made a cover blank
  // forever - the media session's artwork path already had to work around it by
  // asking the file directly.
  picture.isLoaded = picture.isExist;
  if (picture.isLoaded) {
    // Every view showing this cover rebuilds from the file now; it does not
    // have to wait for its own (shared) future to be observed.
    picture.changeNotifier.value++;
  }
}

/// Whether [path] is an image file that is actually there (a zero-byte file is
/// what a failed response leaves behind, and it decodes to nothing).
bool _hasImageFile(String path) {
  if (path.isEmpty) {
    return false;
  }
  try {
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 0;
  } catch (_) {
    return false;
  }
}

/// Drops a cover file that could not be decoded and makes every view ask for it
/// again. Called from the image widget's error builder: without this, a bad
/// cached file stays a blank (or note-only) cover until the app is restarted.
void invalidateCoverFile(MyPicture picture) {
  try {
    final file = File(picture.path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  } catch (e) {
    logger.output('cover file could not be dropped: $e');
  }
  picture.isExist = false;
  picture.isLoaded = false;
  pictureLoadScheduler.resetPicture(picture);
  picture.changeNotifier.value++;
}

Future<Color> computeColor(MyPicture? picture) async {
  if (picture?.color != null) {
    return picture!.color!;
  }
  Uint8List? bytes;
  if (picture != null) {
    await loadPictureSafe(picture);
  }

  if (picture?.isExist == true) {
    File pictureFile = File(picture!.path);
    if (await pictureFile.exists()) {
      bytes = await pictureFile.readAsBytes();
    }
  }

  if (bytes == null) {
    picture?.color = Colors.grey;
    return Colors.grey;
  }

  final color = await _calculateAverageColor(bytes);
  picture!.color = color;

  double r = color.r;
  double g = color.g;
  double b = color.b;
  final luminance = 0.299 * r + 0.587 * g + 0.114 * b;

  const maxLuminance = 200 / 255.0;

  if (luminance > maxLuminance) {
    final factor = maxLuminance / luminance;

    picture.lowerLuminance = Color.from(
      alpha: color.a,
      red: r * factor,
      green: g * factor,
      blue: b * factor,
    );
  }

  return color;
}

Future<Color> _calculateAverageColor(Uint8List bytes) async {
  final state = WidgetsBinding.instance.lifecycleState;

  if (Platform.isIOS && state != AppLifecycleState.resumed) {
    return _calculateWithImagePackage(bytes);
  }

  Uint8List buffer = Uint8List(0);
  ui.Codec? codec;
  try {
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 20,
      targetHeight: 20,
    );
    final frameInfo = await codec.getNextFrame();
    final image = frameInfo.image;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    image.dispose();

    if (byteData == null) {
      return Colors.grey;
    }

    buffer = byteData.buffer.asUint8List();
  } catch (e) {
    logger.output(e.toString());
    return Colors.grey;
  } finally {
    codec?.dispose();
  }

  double r = 0;
  double g = 0;
  double b = 0;
  int count = 0;

  for (int i = 0; i < buffer.length; i += 4) {
    final red = buffer[i];
    final green = buffer[i + 1];
    final blue = buffer[i + 2];
    final alpha = buffer[i + 3];

    if (alpha == 0) {
      r += 128;
      g += 128;
      b += 128;
    } else {
      r += red;
      g += green;
      b += blue;
    }

    count++;
  }

  if (count == 0) {
    return Colors.grey;
  }
  return Color.fromARGB(
    255,
    (r / count).round(),
    (g / count).round(),
    (b / count).round(),
  );
}

Color _calculateWithImagePackage(Uint8List bytes) {
  final image = img.decodeImage(bytes);

  if (image == null) {
    return Colors.grey;
  }

  final thumb = img.copyResize(
    image,
    width: 20,
    height: 20,
    interpolation: img.Interpolation.average,
  );

  double r = 0;
  double g = 0;
  double b = 0;
  int count = 0;

  for (final pixel in thumb) {
    if (pixel.a == 0) {
      r += 128;
      g += 128;
      b += 128;
    } else {
      r += pixel.r;
      g += pixel.g;
      b += pixel.b;
    }

    count++;
  }

  if (count == 0) {
    return Colors.grey;
  }

  return Color.fromARGB(
    255,
    (r / count).round(),
    (g / count).round(),
    (b / count).round(),
  );
}
