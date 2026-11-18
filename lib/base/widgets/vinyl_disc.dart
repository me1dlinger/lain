import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';

/// The angle is shared by every disc instance. A route transition can build a
/// shuttle copy and then the settled page's own disc; keeping the phase here
/// means the second instance continues from the first instead of snapping
/// back to zero.
double _vinylPhase = 0;

/// The now-playing artwork as a vinyl record: a black disc with fine grooves,
/// the cover as its centre label, and a spindle. The disc turns while music
/// plays and keeps its angle when paused.
class VinylDisc extends StatefulWidget {
  final MyPicture? picture;
  final double size;

  const VinylDisc({super.key, required this.picture, required this.size});

  @override
  State<VinylDisc> createState() => _VinylDiscState();
}

class _VinylDiscState extends State<VinylDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;
  Animation<double>? _routeAnimation;
  bool _routeReady = false;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..value = _vinylPhase;
    _rotation.addListener(_rememberPhase);
    isPlayingNotifier.addListener(_syncRotation);
    // Opening the player is a route transition. Starting here would turn the
    // record for those few hundred milliseconds and then visibly snap back
    // when the settled page builds its own disc; wait until the transition is
    // over.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final animation = ModalRoute.of(context)?.animation;
      _routeAnimation = animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        _routeReady = true;
        _syncRotation();
      } else {
        animation.addStatusListener(_onRouteStatus);
      }
    });
  }

  void _rememberPhase() {
    _vinylPhase = _rotation.value;
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    _routeReady = true;
    _syncRotation();
  }

  void _syncRotation() {
    if (!_routeReady) {
      return;
    }
    if (isPlayingNotifier.value) {
      if (!_rotation.isAnimating) {
        _rotation.repeat();
      }
    } else {
      _rotation.stop();
    }
  }

  @override
  void dispose() {
    isPlayingNotifier.removeListener(_syncRotation);
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _vinylPhase = _rotation.value;
    _rotation.removeListener(_rememberPhase);
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final labelSize = size * 0.56;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _rotation,
            // The rotation samples the rendered disc every frame. The default
            // low filter makes the cover's pixels crawl at shallow angles.
            filterQuality: FilterQuality.high,
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.square(size),
                painter: _VinylPainter(),
                child: Center(
                  child: ClipOval(
                    child: CoverArtWidget(
                      size: labelSize,
                      picture: widget.picture,
                      useResize: false,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // A still tonearm at the top right, for the record-player silhouette.
          Positioned(
            top: size * 0.015,
            right: size * 0.085,
            child: Transform.rotate(
              angle: 0.38,
              alignment: Alignment.topCenter,
              child: Container(
                width: size * 0.018,
                height: size * 0.42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  color: const Color(0xFFC9C4B8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);

    final disc = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF202020), Color(0xFF080808)],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, disc);

    // Grooves: many thin rings, brightest near the outer edge.
    for (var ring = 0.60; ring < 0.99; ring += 0.018) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring % 0.09 < 0.02 ? 1.2 : 0.55
        ..color = Colors.white.withValues(
          alpha: (0.085 - ring * 0.045).clamp(0.02, 0.08),
        );
      canvas.drawCircle(center, radius * ring, paint);
    }

    // A soft highlight arc so the disc reads as a physical surface.
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.085
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.085),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.79),
      math.pi * 1.08,
      math.pi * 0.44,
      false,
      highlight,
    );

    // The rim.
    canvas.drawCircle(
      center,
      radius - 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.06),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
