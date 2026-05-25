import 'package:flutter/material.dart';

void main() {
  runApp(const MazeApp());
}

class MazeApp extends StatelessWidget {
  const MazeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MazePage(),
    );
  }
}

enum Direction {
  north,
  east,
  south,
  west,
}

class Room {
  final int x;
  final int y;

  bool north;
  bool east;
  bool south;
  bool west;

  Room({
    required this.x,
    required this.y,
    this.north = false,
    this.east = false,
    this.south = false,
    this.west = false,
  });
}

class RoomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DirectionTrianglePainter extends CustomPainter {
  final Direction direction;

  DirectionTrianglePainter(this.direction);

  @override
  void paint(Canvas canvas, Size size) {
    Path getPath() {
      final path = Path();

      switch (direction) {
        case Direction.east: {
          final w = size.width * 0.4;
          final h = size.height * 0.4;
          final cy = size.height / 2;
          final overlap = 2.0;
          
          path.moveTo(-overlap, cy - h / 2);
          path.lineTo(-overlap, cy + h / 2);
          path.lineTo(w, cy);
          path.close();
          break;
        }

        case Direction.west: {
          final w = size.width * 0.35;
          final h = size.height * 0.35;
          final cy = size.height / 2;

          path.moveTo(size.width, cy - h / 2);
          path.lineTo(size.width, cy + h / 2);
          path.lineTo(size.width - w, cy);
          break;
        }

        case Direction.north: {
          final w = size.width * 0.35;
          final h = size.height * 0.35;
          final cx = size.width / 2;

          path.moveTo(cx - w / 2, size.height);
          path.lineTo(cx + w / 2, size.height);
          path.lineTo(cx, size.height - h);
          break;
        }

        case Direction.south: {
          final w = size.width * 0.35;
          final h = size.height * 0.35;
          final cx = size.width / 2;

          path.moveTo(cx - w / 2, 0);
          path.lineTo(cx + w / 2, 0);
          path.lineTo(cx, h);
          break;
        }
      }

      path.close();
      return path;
    }

    final path = getPath();

    // ✔ 1. 黑色邊框
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // ✔ 2. 白色填充
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, stroke);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MazePage extends StatefulWidget {
  const MazePage({super.key});

  @override
  State<MazePage> createState() => _MazePageState();
}

class _MazePageState extends State<MazePage> {
  final List<Room> rooms = [
    Room(x: 0, y: 0),
  ];
  static const double roomSize = 50;
  static const double spacing = 48;

  Offset? startPoint;
  Offset? endPoint;

  int? previewX;
  int? previewY;

  double lastDx = 0;
  double lastDy = 0;

  void addRoom(Room room, Offset velocity) {
    setState(() {
      lastDx = velocity.dx.abs();
      lastDy = velocity.dy.abs();
    });
    int newX = room.x;
    int newY = room.y;

    // 判斷拖曳方向
    
    if (velocity.dx.abs() > velocity.dy.abs()) {
      // 左右
      if (velocity.dx > 0) {
        newX += 1;
      } else {
        newX -= 1;
      }
    } else {
      // 上下
      if (velocity.dy > 0) {
        newY += 1;
      } else {
        newY -= 1;
      }
    }

    // 避免重複房間
    bool exists = rooms.any((r) => r.x == newX && r.y == newY);

    if (!exists) {
      setState(() {
        rooms.add(Room(x: newX, y: newY));
      });
    }
    
  }

  void connectRoom(Room room, int dx, int dy) {
    if (dx == 1) {
      room.east = true;
    } else if (dx == -1) {
      room.west = true;
    } else if (dy == 1) {
      room.south = true;
    } else if (dy == -1) {
      room.north = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: InteractiveViewer(
        child: Stack(
          children: [
            ...rooms.map((room) {
              return Positioned(
                left: room.x * spacing,
                top: room.y * spacing,
                child: GestureDetector(
                  onPanStart: (details) {
                    startPoint = details.localPosition;
                  },
                  onPanUpdate: (details) {
                    endPoint = details.localPosition;
                    final dx = details.localPosition.dx - (startPoint?.dx ?? 0);
                    final dy = details.localPosition.dy - (startPoint?.dy ?? 0);
                    if (dx.abs() < 10 && dy.abs() < 10) {
                      previewX = null;
                      previewY = null;
                      setState(() {});
                      return;
                    }
                    previewX = room.x;
                    previewY = room.y;
                    if (dx.abs() > dy.abs()) {
                      if (dx > 0) {
                        previewX = room.x + 1;
                      } else {
                        previewX = room.x - 1;
                      }
                    } else {
                      if (dy > 0) {
                        previewY = room.y + 1;
                      } else {
                        previewY = room.y - 1;
                      }
                    }
                    setState(() {});
                  },
                  onPanEnd: (_) {
                    if (startPoint == null || endPoint == null) return;
                    final dx = endPoint!.dx - startPoint!.dx;
                    final dy = endPoint!.dy - startPoint!.dy;
                    int newX = room.x;
                    int newY = room.y;
                    if (dx.abs() > dy.abs()) {
                      dx > 0 ? newX++ : newX--;
                    } else {
                      dy > 0 ? newY++ : newY--;
                    }
                    final exists = rooms.any((r) => r.x == newX && r.y == newY);
                    final dxDir = newX - room.x;
                    final dyDir = newY - room.y;
                    connectRoom(room, dxDir, dyDir);
                    if (!exists) {
                      setState(() {
                        rooms.add(Room(x: newX, y: newY));
                      });
                    }
                    startPoint = null;
                    endPoint = null;
                    setState(() {
                      previewX = null;
                      previewY = null;
                    });
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: Size(roomSize, roomSize),
                        painter: RoomPainter(),
                      ),
                      // 東邊箭頭
                      if (room.east)
                        Positioned(
                          right: -roomSize / 2,
                          top: 0,
                          child: SizedBox(
                            width: roomSize / 2,
                            height: roomSize,
                            child: CustomPaint(
                              painter: DirectionTrianglePainter(Direction.east),
                            ),
                          ),
                        ),
                      // 西邊箭頭
                      if (room.west)
                        Positioned(
                          left: -roomSize / 2,
                          top: 0,
                          child: SizedBox(
                            width: roomSize / 2,
                            height: roomSize,
                            child: CustomPaint(
                              painter: DirectionTrianglePainter(Direction.west),
                            ),
                          ),
                        ),
                      // 南邊箭頭
                      if (room.south)
                        Positioned(
                          bottom: -roomSize / 2,
                          left: 0,
                          child: SizedBox(
                            width: roomSize,
                            height: roomSize / 2,
                            child: CustomPaint(
                              painter: DirectionTrianglePainter(Direction.south),
                            ),
                          ),
                        ),
                      // 北邊箭頭
                      if (room.north)
                        Positioned(
                          top: -roomSize / 2,
                          left: 0,
                          child: SizedBox(
                            width: roomSize,
                            height: roomSize / 2,
                            child: CustomPaint(
                              painter: DirectionTrianglePainter(Direction.north),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            if (previewX != null && previewY != null)
              Positioned(
                left: previewX! * spacing,
                top: previewY! * spacing,
                child: Container(
                  width: roomSize,
                  height: roomSize,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    border: Border.all(
                      color: Colors.grey,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}