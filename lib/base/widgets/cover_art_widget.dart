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

  /// Whether this cover goes to the front of the load queue (page headers,
  /// the now-playing artwork) instead of lining up behind list thumbnails.
  final bool priorityLoad;

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
    this.priorityLoad = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      // The cover's identity is part of the key: when the slot shows a
      // different picture (a sort change picks another first song, a resync
      // replaces the list) the state below must start over instead of reusing
      // the previous picture's one-shot flags.
      key: ValueKey('${picture?.id ?? picturePath}#${picture?.changeNotifier.value}'),
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
      priorityLoad: priorityLoad,
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

  /// Whether the load goes to the front of the scheduler's queue.
  final bool priorityLoad;

  const _FuturePicture({
    required this.picture,
    required this.size,
    required this.imageWidget,
    required this.fallback,
    this.loading,
    this.priorityLoad = false,
  });
  @override
  State<StatefulWidget> createState() => _FuturePictureState();
}

class _FuturePictureState extends State<_FuturePicture> {
  late final int widgetId;
  bool _recheckDone = false;

  /// The load this state is showing, and the picture it belongs to. Created
  /// once per picture instead of on every rebuild: the old code asked the
  /// scheduler again for every parent rebuild (a lyric tick, a background
  /// colour change), which piled up tasks for one id.
  late Future<void> _future;
  late String _futureKey;

  @override
  void initState() {
    super.initState();
    widgetId = _widgetId++;
    _startLoad();
  }

  @override
  void didUpdateWidget(_FuturePicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_keyOf(widget.picture) != _futureKey) {
      _startLoad();
      _recheckDone = false;
    }
  }

  String _keyOf(MyPicture picture) => '${picture.id}|${picture.path}';

  void _startLoad() {
    _futureKey = _keyOf(widget.picture);
    _future = loadPictureSafe(
      widget.picture,
      widgetId: widgetId,
      priority: widget.priorityLoad,
    );
  }

  @override
  void dispose() {
    pictureLoadScheduler.cancel(widgetId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
          return widget.loading ??
              SizedBox(width: widget.size, height: widget.size);
        }

        // A load that produced no file is the same as a missing image: the
        // album cover replaces it instead of a music note. The file may have
        // landed on disk after this instance was built (another view loaded the
        // same cover), so the disk is asked once more before giving up - that
        // is what kept a re-entered page's cover blank until an app restart.
        if (asyncSnapshot.hasError || !widget.picture.isExist) {
          _recheckDisk();
          return widget.fallback();
        }
        return widget.imageWidget(widget.picture.path);
      },
    );
  }

  /// One-shot disk re-check; if the image appeared, [setState] shows it.
  ///
  /// When it did not, one bounded retry is scheduled: a cover fetch that failed
  /// on a flaky link stays blank otherwise, and this screen never asks again
  /// until it is re-entered.
  void _recheckDisk() {
    if (_recheckDone || widget.picture.id.isEmpty) {
      return;
    }
    _recheckDone = true;
    File(widget.picture.path).exists().then((exists) {
      if (!mounted) {
        return;
      }
      if (exists) {
        setState(() {
          widget.picture.isExist = true;
          widget.picture.isLoaded = true;
        });
        return;
      }
      _scheduleRetry();
    });
  }

  int _retries = 0;

  void _scheduleRetry() {
    if (_retries >= 2) {
      return;
    }
    _retries++;
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted || widget.picture.isExist) {
        return;
      }
      setState(() {
        _recheckDone = false;
        _startLoad();
      });
    });
  }
}
