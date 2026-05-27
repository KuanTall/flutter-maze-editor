import 'package:flutter/material.dart';

import '../models/direction.dart';

class DirectionTrianglePainter extends CustomPainter {
  final Direction direction;

  DirectionTrianglePainter(this.direction);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

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

    canvas.drawLine(left, tip, paint);
    canvas.drawLine(right, tip, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
