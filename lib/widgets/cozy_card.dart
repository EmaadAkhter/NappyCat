import 'package:flutter/material.dart';
import '../theme/cozy_colors.dart';

/// Port of `.cozyCard(padding:cornerRadius:)`. Defaults match the Swift
/// modifier's 20 / 24.
class CozyCard extends StatelessWidget {
  const CozyCard({
    super.key,
    required this.child,
    this.padding = 20,
    this.radius = 24,
  });

  final Widget child;
  final double padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: CozyColors.cardBackground,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: cozyShadow(),
        ),
        child: child,
      );
}

/// Port of `.dashedCard(...)`: a soft-cream fill with a 6-on/4-off dashed
/// border. Flutter has no dashed border, so the stroke is painted by walking the
/// rounded-rect path.
class DashedCard extends StatelessWidget {
  const DashedCard({
    super.key,
    required this.child,
    this.padding = 16,
    this.radius = 20,
    this.strokeColor = CozyColors.sageGreen,
  });

  final Widget child;
  final double padding;
  final double radius;
  final Color strokeColor;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedBorderPainter(
          radius: radius,
          color: strokeColor.withValues(alpha: 0.6),
        ),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: CozyColors.cardSecondary,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      );
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  static const _on = 6.0;
  static const _off = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _on).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _off;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.radius != radius || old.color != color;
}
