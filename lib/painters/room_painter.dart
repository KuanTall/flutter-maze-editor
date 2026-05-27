import 'package:flutter/material.dart';

class RoomPainter extends CustomPainter {
  final Color? fillColor;

  RoomPainter({this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (fillColor != null) {
      final fill = Paint()
        ..color = fillColor!
        ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fill);
    }

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final gap = w * 0.4;

    canvas.drawLine(Offset(0, 0), Offset((w - gap) / 2, 0), paint);
    canvas.drawLine(Offset((w + gap) / 2, 0), Offset(w, 0), paint);

    canvas.drawLine(Offset(0, h), Offset((w - gap) / 2, h), paint);
    canvas.drawLine(Offset((w + gap) / 2, h), Offset(w, h), paint);

    canvas.drawLine(Offset(0, 0), Offset(0, (h - gap) / 2), paint);
    canvas.drawLine(Offset(0, (h + gap) / 2), Offset(0, h), paint);

    canvas.drawLine(Offset(w, 0), Offset(w, (h - gap) / 2), paint);
    canvas.drawLine(Offset(w, (h + gap) / 2), Offset(w, h), paint);
  }

  @override
  bool shouldRepaint(covariant RoomPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor;
  }
}
