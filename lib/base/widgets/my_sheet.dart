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

  /// Size the sheet to its content, up to [maxHeightFactor], instead of always
  /// filling that share. Action menus look wrong with a large empty bottom.
  final bool wrapContent;

  const MySheet(
    this.child, {
    super.key,
    this.height,
    this.maxHeightFactor = 0.6,
    this.wrapContent = false,
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
          child: _SheetSize(
            height: height,
            maxHeightFactor: maxHeightFactor,
            wrapContent: wrapContent,
            child: child,
          ),
        );
      },
    );
  }
}


class _SheetSize extends StatelessWidget {
  final Widget child;
  final double? height;
  final double maxHeightFactor;
  final bool wrapContent;

  const _SheetSize({
    required this.child,
    required this.height,
    required this.maxHeightFactor,
    required this.wrapContent,
  });

  @override
  Widget build(BuildContext context) {
    final content = MediaQuery.removePadding(
      context: context,
      removeLeft: true,
      removeRight: true,
      removeBottom: true,
      removeTop: true,
      child: child,
    );
    final maxHeight = MediaQuery.heightOf(context) * maxHeightFactor;
    if (wrapContent) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: content,
      );
    }
    return SizedBox(
      height: min(height ?? 500, maxHeight),
      child: content,
    );
  }
}
