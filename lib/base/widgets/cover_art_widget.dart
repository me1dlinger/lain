import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/asset_images.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:lain/base/services/picture_load_scheduler.dart';
import 'package:lain/base/services/picture_service.dart';

class CoverArtWidget extends StatelessWidget {
  final double? size;
  final double borderRadius;
  final MyPicture? picture;

  /// Shown when [picture] has nothing to display (an artist without an image
  /// uses an album cover). A music note is only used when this is null too.
  final MyPicture? fallbackPicture;

  final String? picturePath;
  final double elevation;
  final Color? color;
  final bool useResize;

  const CoverArtWidget({
    super.key,
    this.size,
    this.borderRadius = 0,
    this.picture,
    this.fallbackPicture,
    this.picturePath,
    this.elevation = 0,
    this.color,
    this.useResize = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey(picture?.changeNotifier.value),
      elevation: elevation,
      color: color ?? Colors.transparent,
      shape: SmoothRectangleBorder(
        smoothness: 1,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: .antiAlias,
      child: content(context),
    );
  }

  Widget content(BuildContext context) {
    if (picturePath != null) {
      return imageWidget(picturePath!);
    }
    if (picture == null) {
      return fallbackContent();
    }

    if (picture!.isLoaded) {
      return picture!.isExist ? imageWidget(picture!.path) : fallbackContent();
    }
    return _FuturePicture(
      picture: picture!,
      size: size,
      imageWidget: imageWidget,
      fallback: fallbackContent,
      // An artist image can take a while (an external URL); show the album
      // cover in the meantime instead of an empty hole.
      loading: fallbackPicture == null ? null : fallbackContent(),
    );
  }

  /// The album cover to use when the requested picture is missing. A picture
  /// that is itself the fallback (or no fallback at all) shows the note.
  Widget fallbackContent() {
    final fallback = fallbackPicture;
    if (fallback == null || fallback.id == picture?.id) {
      return musicNote();
    }
    return CoverArtWidget(
      size: size,
      borderRadius: borderRadius,
      picture: fallback,
      useResize: useResize,
    );
  }

  Widget imageWidget(String path) {
    final ImageProvider imageProvider = size != null && useResize
        ? ResizeImage(FileImage(File(path)), width: (size! * 4).toInt())
        : FileImage(File(path));

    return Image(
      image: imageProvider,
      width: size,
      height: size,
      fit: size != null ? .contain : .cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return fallbackContent();
      },
    );
  }

  Widget musicNote() {
    return ImageIcon(musicNoteImage, size: size);
  }
}

int _widgetId = 0;

class _FuturePicture extends StatefulWidget {
  final MyPicture picture;
  final double? size;
  final Widget Function(String) imageWidget;
  final Widget Function() fallback;

  /// Shown while the load is in progress, when there is something better than
  /// empty space to show (an album cover for an artist image).
  final Widget? loading;

  const _FuturePicture({
    required this.picture,
    required this.size,
    required this.imageWidget,
    required this.fallback,
    this.loading,
  });
  @override
  State<StatefulWidget> createState() => _FuturePictureState();
}

class _FuturePictureState extends State<_FuturePicture> {
  late final int widgetId;
  @override
  void initState() {
    super.initState();
    widgetId = _widgetId++;
  }

  @override
  void dispose() {
    pictureLoadScheduler.cancel(widgetId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: loadPictureSafe(widget.picture, widgetId: widgetId),
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
          return widget.loading ??
              SizedBox(width: widget.size, height: widget.size);
        }

        // A load that produced no file is the same as a missing image: the
        // album cover replaces it instead of a music note.
        if (asyncSnapshot.hasError || !widget.picture.isExist) {
          return widget.fallback();
        }
        return widget.imageWidget(widget.picture.path);
      },
    );
  }
}
