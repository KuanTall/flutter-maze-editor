import 'package:flutter/material.dart';

import '../models/direction.dart';

class WallPainter extends CustomPainter {
  final Direction direction;

  WallPainter(this.direction);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    switch (direction) {
      case Direction.east:
        canvas.drawLine(Offset(0, 0), Offset(0, size.height - 1), paint);
        break;
      case Direction.west:
        canvas.drawLine(
          Offset(size.width, 0),
          Offset(size.width, size.height - 1),
          paint,
        );
        break;
      case Direction.north:
        canvas.drawLine(
          Offset(-1, size.height),
          Offset(size.width - 1, size.height),
          paint,
        );
        break;
      case Direction.south:
        canvas.drawLine(Offset(0, 0), Offset(size.width - 1, 0), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
