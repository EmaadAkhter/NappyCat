import 'package:flutter/material.dart';
import '../theme/cozy_colors.dart';

/// Comic-book speech bubble: rounded cloud with a little tail pointing at
/// whoever is talking — here, always the cat.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.child,
    this.tail = BubbleTail.up,
  });

  final Widget child;
  final BubbleTail tail;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(tail: tail),
      child: Padding(
        // Extra headroom on the tail side so text never sits inside the tail.
        padding: EdgeInsets.fromLTRB(
          tail == BubbleTail.left ? 26 : 16,
          tail == BubbleTail.up ? 24 : 14,
          16,
          tail == BubbleTail.down ? 24 : 14,
        ),
        child: child,
      ),
    );
  }
}

enum BubbleTail { up, left, down }

class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.tail});

  final BubbleTail tail;

  static const _radius = 18.0;
  static const _tailSize = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = CozyColors.cardSecondary;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = CozyColors.sageGreen.withValues(alpha: 0.5);

    final body = switch (tail) {
      BubbleTail.up =>
        Rect.fromLTWH(0, _tailSize, size.width, size.height - _tailSize),
      BubbleTail.down =>
        Rect.fromLTWH(0, 0, size.width, size.height - _tailSize),
      BubbleTail.left =>
        Rect.fromLTWH(_tailSize, 0, size.width - _tailSize, size.height),
    };

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(_radius)));

    // The tail: a soft triangle poking out toward the speaker.
    switch (tail) {
      case BubbleTail.up:
        final cx = size.width * 0.3;
        path
          ..moveTo(cx - _tailSize, _tailSize + 1)
          ..lineTo(cx, 0)
          ..lineTo(cx + _tailSize, _tailSize + 1)
          ..close();
      case BubbleTail.down:
        final cx = size.width * 0.3;
        final base = size.height - _tailSize - 1;
        path
          ..moveTo(cx - _tailSize, base)
          ..lineTo(cx, size.height)
          ..lineTo(cx + _tailSize, base)
          ..close();
      case BubbleTail.left:
        final cy = size.height * 0.45;
        path
          ..moveTo(_tailSize + 1, cy - _tailSize)
          ..lineTo(0, cy)
          ..lineTo(_tailSize + 1, cy + _tailSize)
          ..close();
    }

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.tail != tail;
}
