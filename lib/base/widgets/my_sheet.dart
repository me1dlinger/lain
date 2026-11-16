import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:smooth_corner/smooth_corner.dart';

class MySheet extends StatelessWidget {
  final Widget child;
  final double? height;

  /// The share of the screen the sheet may take at most. Action menus need
  /// more room than the small lyric sheets.
  final double maxHeightFactor;

  const MySheet(
    this.child, {
    super.key,
    this.height,
    this.maxHeightFactor = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (context, _, _) {
        return Material(
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          color: Color.alphaBlend(
            colorManager.getSpecificBgColor(),
            colorManager.getSpecificBgBaseColor(),
          ),
          clipBehavior: .antiAlias,
          child: SizedBox(
            height: min(
              height ?? 500,
              MediaQuery.heightOf(context) * maxHeightFactor,
            ),
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true, // for mobile
              removeRight: true,
              removeBottom: true,
              removeTop: true,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
