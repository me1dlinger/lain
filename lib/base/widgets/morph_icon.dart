import 'package:material_ui/material_ui.dart';

/// Play and pause as one button whose icon changes shape, not just image:
/// the outgoing icon shrinks and turns away while the incoming one pops in
/// with a small overshoot.
class MorphPlayPauseIcon extends StatelessWidget {
  final bool playing;
  final double size;
  final Color? color;

  const MorphPlayPauseIcon({
    super.key,
    required this.playing,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 230),
      reverseDuration: const Duration(milliseconds: 160),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .62, end: 1).animate(curved),
            child: RotationTransition(
              turns: Tween<double>(begin: .88, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
      child: Icon(
        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        key: ValueKey(playing),
        size: size,
        color: color,
      ),
    );
  }
}

/// A heart that fills in with a short spring when it is switched on, and
/// empties the same way. The colour animates with the shape instead of
/// snapping from grey to red.
class MorphFavoriteIcon extends StatelessWidget {
  final bool active;
  final double size;
  final Color activeColor;
  final Color? inactiveColor;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const MorphFavoriteIcon({
    super.key,
    required this.active,
    required this.size,
    this.activeColor = Colors.red,
    this.inactiveColor,
    this.activeIcon = Icons.favorite_rounded,
    this.inactiveIcon = Icons.favorite_border_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(active),
      tween: Tween(begin: active ? .72 : .84, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Icon(
        active ? activeIcon : inactiveIcon,
        size: size,
        color: active ? activeColor : inactiveColor,
      ),
    );
  }
}
