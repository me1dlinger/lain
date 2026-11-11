import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/widgets/song_list.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/portrait_view/play_bar.dart';

/// Opens a full-screen page as a route that still looks like the rest of the
/// app: it is wrapped the same way a root layer is, so it gets the theme's
/// backdrop (the blurred cover on a vivid theme, the themed colour otherwise),
/// and on a phone the play bar is drawn over it, since the root route covers
/// the one in the portrait view.
Route<T> themedRoute<T>(
  WidgetBuilder builder, {
  MyPicture? picture,
}) {
  return PageRouteBuilder<T>(
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      final child = builder(context);
      // createPage keys its styling on this exact widget instance, so it is
      // registered before wrapping and styled from the page's own picture.
      final themed = layersManager.createPage(child);
      unawaited(layersManager.styleRouteLayer(child, picture));
      if (!isTooNarrow(context)) {
        return themed;
      }
      return Stack(
        children: [
          Positioned.fill(child: themed),
          const Positioned(left: 20, right: 20, bottom: 40, child: PlayBar()),
        ],
      );
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
