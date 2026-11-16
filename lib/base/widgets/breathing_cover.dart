import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/ui_motion_settings.dart';

/// A very slow breathing scale for cover art. It is subtle on purpose: the
/// page is a reading surface, and a cover that visibly pumps is distracting.
class BreathingCover extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;

  const BreathingCover({
    super.key,
    required this.child,
    this.amplitude = 0.018,
    this.period = const Duration(seconds: 7),
  });

  @override
  State<BreathingCover> createState() => _BreathingCoverState();
}

class _BreathingCoverState extends State<BreathingCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..value = 0.5;
    isPlayingNotifier.addListener(_syncPlayback);
    lyricsCoverMotionNotifier.addListener(_syncPlayback);
    _syncPlayback();
  }

  void _syncPlayback() {
    if (lyricsCoverMotionNotifier.value && isPlayingNotifier.value) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      // Settle at the neutral value, not at the edge of the swing.
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    isPlayingNotifier.removeListener(_syncPlayback);
    lyricsCoverMotionNotifier.removeListener(_syncPlayback);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale =
            1 + widget.amplitude * math.sin(_controller.value * 2 * math.pi);
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}
