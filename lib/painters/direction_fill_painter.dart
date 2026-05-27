import 'package:flutter/material.dart';

import '../models/direction.dart';

class DirectionFillPainter extends CustomPainter {
  final Direction direction;
  final Color color;

  DirectionFillPainter({
    required this.direction,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final span = w * 0.4;
    final depth = h * 0.4;

    late Offset c;
    late Offset left;
    late Offset right;
    late Offset tip;

    switch (direction) {
      case Direction.east:
        c = Offset(0, (h / 2) - 1);
        left = Offset(c.dx, c.dy - span);
        right = Offset(c.dx, c.dy + span);
        tip = Offset(c.dx + span, c.dy);
        break;
      case Direction.west:
        c = Offset(w, (h / 2) - 1);
        left = Offset(c.dx, c.dy - span);
        right = Offset(c.dx, c.dy + span);
        tip = Offset(c.dx - span, c.dy);
        break;
      case Direction.north:
        c = Offset((w / 2) - 1, h);
        left = Offset(c.dx - depth, c.dy);
        right = Offset(c.dx + depth, c.dy);
        tip = Offset(c.dx, c.dy - depth);
        break;
      case Direction.south:
        c = Offset((w / 2) - 1, 0);
        left = Offset(c.dx - depth, c.dy);
        right = Offset(c.dx + depth, c.dy);
        tip = Offset(c.dx, c.dy + depth);
        break;
    }

    final path = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DirectionFillPainter oldDelegate) {
    return oldDelegate.direction != direction || oldDelegate.color != color;
  }
}
