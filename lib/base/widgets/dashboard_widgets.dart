import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/services/color_manager.dart';

class RingSegment {
  final String label;
  final double value;
  final Color color;

  const RingSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// A donut that sweeps in on first build. Segments keep their proportion and
/// the centre can hold any summary.
class AnimatedRing extends StatelessWidget {
  final List<RingSegment> segments;
  final double size;
  final double strokeWidth;
  final Widget? center;

  const AnimatedRing({
    super.key,
    required this.segments,
    this.size = 168,
    this.strokeWidth = 16,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              segments: segments,
              progress: value,
              strokeWidth: strokeWidth,
            ),
            child: Center(child: center),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final List<RingSegment> segments;
  final double progress;
  final double strokeWidth;

  const _RingPainter({
    required this.segments,
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.shortestSide - strokeWidth) / 2,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = colorManager.getSpecificTextColor().withAlpha(24);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final total = segments.fold<double>(0, (sum, item) => sum + item.value);
    if (total <= 0) {
      return;
    }
    var start = -math.pi / 2;
    const gap = 0.035;
    for (final segment in segments) {
      if (segment.value <= 0) {
        continue;
      }
      final sweep = (segment.value / total) * math.pi * 2 * progress;
      if (sweep <= gap) {
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = segment.color;
      canvas.drawArc(rect, start + gap / 2, sweep - gap, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.segments != segments;
}

/// A labelled bar that grows from zero, used for quality tiers and file kinds.
class AnimatedMetricBar extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final Color color;

  const AnimatedMetricBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14, color: textColor),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withAlpha(160),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  backgroundColor: textColor.withAlpha(18),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A rounded surface matching the rest of the app, with a little breathing
/// room around it.
class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: padding,
      decoration: BoxDecoration(
        color: textColor.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

String dashboardSize(int bytes) {
  if (bytes <= 0) {
    return '0 MB';
  }
  final gb = bytes / (1024 * 1024 * 1024);
  if (gb >= 1) {
    return '${gb.toStringAsFixed(gb >= 10 ? 1 : 2)} GB';
  }
  final mb = bytes / (1024 * 1024);
  if (mb >= 1) {
    return '${mb.toStringAsFixed(mb >= 10 ? 1 : 1)} MB';
  }
  return '${(bytes / 1024).round()} KB';
}

String dashboardDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours > 0) {
    return '$hours h $minutes m';
  }
  return '${duration.inMinutes} m';
}
