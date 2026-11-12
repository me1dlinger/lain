import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lain/portrait_view/portrait_view.dart';

/// How many pages this helper has pushed onto the settings navigator and that
/// are still open.
int _settingsPushedRoutes = 0;

/// Whether a settings sub-page is open.
///
/// This cannot be answered with `Navigator.canPop()`: the layer navigators
/// carry an extra blank Android page, so they always report that something can
/// be popped. Popping on that basis removed the settings page itself and left
/// a blank screen behind.
bool get hasSettingsPushedPage => _settingsPushedRoutes > 0;

/// Pushes [route] on the nearest navigator and keeps [hasSettingsPushedPage]
/// correct, whether the page is closed by its back button, the system gesture
/// or a programmatic pop.
Future<T?> pushSettingsPage<T>(BuildContext context, Route<T> route) async {
  _settingsPushedRoutes++;
  try {
    return await Navigator.of(context).push(route);
  } finally {
    _settingsPushedRoutes--;
  }
}

/// A settings sub-page transition that matches the root drawer: the same
/// direction and curve, at the app's standard page-transition length.
///
/// iOS keeps MaterialPageRoute so its edge-swipe back gesture keeps working;
/// that route already slides in from the side there.
Route<T> settingsPageRoute<T>(Widget Function() builder) {
  if (Platform.isIOS) {
    return MaterialPageRoute<T>(builder: (_) => builder());
  }
  return PageRouteBuilder<T>(
    opaque: true,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => builder(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Forward: the page slides in. Back: the same page slides out, driven by
      // a reversed animation with the same curve as the root drawer's back
      // move. Using the forward curve on a reverse animation made the exit
      // feel much slower than leaving the settings root.
      final sign = endDrawerNotifier.value ? 1.0 : -1.0;
      final forward = CurvedAnimation(
        parent: animation,
        curve: Curves.linearToEaseOut,
      );
      final back = CurvedAnimation(
        parent: ReverseAnimation(animation),
        curve: Curves.linearToEaseOut,
      );
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final reversing = animation.status == AnimationStatus.reverse;
          final t = reversing ? back.value : forward.value;
          final offset = reversing
              ? Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset(sign, 0.0),
                ).transform(t)
              : Tween<Offset>(
                  begin: Offset(sign, 0.0),
                  end: Offset.zero,
                ).transform(t);
          return FractionalTranslation(translation: offset, child: child);
        },
        child: child,
      );
    },
  );
}
