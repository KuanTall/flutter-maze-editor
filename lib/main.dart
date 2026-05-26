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

    final w = size.width;
    final h = size.height;

    // 中間缺口大小
    final gap = w * 0.4;

    // =====================
    // 北邊
    // =====================
    canvas.drawLine(
      Offset(0, 0),
      Offset((w - gap) / 2, 0),
      paint,
    );

    canvas.drawLine(
      Offset((w + gap) / 2, 0),
      Offset(w, 0),
      paint,
    );

    // =====================
    // 南邊
    // =====================
    canvas.drawLine(
      Offset(0, h),
      Offset((w - gap) / 2, h),
      paint,
    );

    canvas.drawLine(
      Offset((w + gap) / 2, h),
      Offset(w, h),
      paint,
    );

    // =====================
    // 西邊
    // =====================
    canvas.drawLine(
      Offset(0, 0),
      Offset(0, (h - gap) / 2),
      paint,
    );

    canvas.drawLine(
      Offset(0, (h + gap) / 2),
      Offset(0, h),
      paint,
    );

    // =====================
    // 東邊
    // =====================
    canvas.drawLine(
      Offset(w, 0),
      Offset(w, (h - gap) / 2),
      paint,
    );

    canvas.drawLine(
      Offset(w, (h + gap) / 2),
      Offset(w, h),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
        canvas.drawLine(
          Offset(0, 0),
          Offset(0, size.height),
          paint,
        );
        break;

      case Direction.west:
        canvas.drawLine(
          Offset(size.width, 0),
          Offset(size.width, size.height),
          paint,
        );
        break;

      case Direction.north:
        canvas.drawLine(
          Offset(0, size.height),
          Offset(size.width, size.height),
          paint,
        );
        break;

      case Direction.south:
        canvas.drawLine(
          Offset(0, 0),
          Offset(size.width, 0),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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

    // ===== 幾何參數 =====
    final span = w * 0.4; // 牆上左右展開
    final depth = h * 0.4; // 往房間內縮

    late Offset c; // 牆中心
    late Offset left;
    late Offset right;
    late Offset tip;

    switch (direction) {
      // ================= EAST（右牆）
      case Direction.east:
        c = Offset(0, h / 2);

        left = Offset(c.dx, c.dy - span);
        right = Offset(c.dx, c.dy + span);
        tip = Offset(c.dx + span, c.dy);
        break;

      // ================= WEST（左牆）
      case Direction.west:
        c = Offset(w, h / 2);

        left = Offset(c.dx, c.dy - span);
        right = Offset(c.dx, c.dy + span);
        tip = Offset(c.dx - span, c.dy);
        break;

      // ================= NORTH（上牆）
      case Direction.north:
        c = Offset(w / 2, h);

        left = Offset(c.dx - depth, c.dy);
        right = Offset(c.dx + depth, c.dy);
        tip = Offset(c.dx, c.dy - depth);
        break;

      // ================= SOUTH（下牆）
      case Direction.south:
        c = Offset(w / 2, 0);

        left = Offset(c.dx - depth, c.dy);
        right = Offset(c.dx + depth, c.dy);
        tip = Offset(c.dx, c.dy + depth);
        break;
    }

    // ===== 畫兩條線 =====
    canvas.drawLine(left, tip, paint);
    canvas.drawLine(right, tip, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  Room? getRoom(int x, int y) {
    try {
      return rooms.firstWhere((r) => r.x == x && r.y == y);
    } catch (_) {
      return null;
    }
  }
  
  Direction opposite(Direction d) {
    switch (d) {
      case Direction.north:
        return Direction.south;
      case Direction.south:
        return Direction.north;
      case Direction.east:
        return Direction.west;
      case Direction.west:
        return Direction.east;
    }
  }

  bool isOppositeOpen(Room target, int dx, int dy) {
    if (dx == 1) return target.west;
    if (dx == -1) return target.east;
    if (dy == 1) return target.north;
    if (dy == -1) return target.south;
    return false;
  }

  bool isCurrentOpen(Room room, int dx, int dy) {
    if (dx == 1) return room.east;
    if (dx == -1) return room.west;
    if (dy == 1) return room.south;
    if (dy == -1) return room.north;
    return false;
  }
  
  void closeBothDoors(Room a, Room b, int dx, int dy) {
    if (dx == 1) {
      a.east = false;
      b.west = false;
    } else if (dx == -1) {
      a.west = false;
      b.east = false;
    } else if (dy == 1) {
      a.south = false;
      b.north = false;
    } else if (dy == -1) {
      a.north = false;
      b.south = false;
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
              final neighborE = getRoom(room.x + 1, room.y);
              final neighborW = getRoom(room.x - 1, room.y);
              final neighborN = getRoom(room.x, room.y - 1);
              final neighborS = getRoom(room.x, room.y + 1);
              // EAST
              final showEast = room.east && !(neighborE?.west ?? false);
              final wallEast =!room.east && !(neighborE?.west ?? false);
              // WEST
              final showWest = room.west && !(neighborW?.east ?? false);
              final wallWest =!room.west && !(neighborW?.east ?? false);
              // NORTH
              final showNorth = room.north && !(neighborN?.south ?? false);
              final wallNorth =!room.north && !(neighborN?.south ?? false);
              // SOUTH
              final showSouth = room.south && !(neighborS?.north ?? false);
              final wallSouth =!room.south && !(neighborS?.north ?? false);

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
                    final targetRoom = getRoom(newX, newY);

                    setState(() {
                      final currentOpen = isCurrentOpen(room, dxDir, dyDir);
                      final oppositeOpen =
                          targetRoom != null && isOppositeOpen(targetRoom, dxDir, dyDir);

                      if (targetRoom != null && currentOpen && oppositeOpen) {
                        closeBothDoors(room, targetRoom, dxDir, dyDir);
                      } else {
                        connectRoom(room, dxDir, dyDir);
                    
                        if (!exists) {
                          rooms.add(Room(x: newX, y: newY));
                        }
                      }
                    
                      startPoint = null;
                      endPoint = null;
                      previewX = null;
                      previewY = null;
                    });
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: Size(roomSize-2, roomSize-2),
                        painter: RoomPainter(),
                      ),
                      // 東邊箭頭
                      if (showEast)
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
                      if (wallEast)
                        Positioned(
                          right: -roomSize / 2,
                          top: 0,
                          child: SizedBox(
                            width: roomSize / 2,
                            height: roomSize,
                            child: CustomPaint(
                              painter: WallPainter(Direction.east),
                            ),
                          ),
                        ),
                      // 西邊箭頭
                      if (showWest)
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
                      if (wallWest)
                        Positioned(
                          left: -roomSize / 2,
                          top: 0,
                          child: SizedBox(
                            width: roomSize / 2,
                            height: roomSize,
                            child: CustomPaint(
                              painter: WallPainter(Direction.west),
                            ),
                          ),
                        ),
                      // 南邊箭頭
                      if (showSouth)
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
                      if (wallSouth)
                        Positioned(
                          bottom: -roomSize / 2,
                          left: 0,
                          child: SizedBox(
                            width: roomSize,
                            height: roomSize / 2,
                            child: CustomPaint(
                              painter: WallPainter(Direction.south),
                            ),
                          ),
                        ),
                      // 北邊箭頭
                      if (showNorth)
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
                      if (wallNorth)
                        Positioned(
                          top: -roomSize / 2,
                          left: 0,
                          child: SizedBox(
                            width: roomSize,
                            height: roomSize / 2,
                            child: CustomPaint(
                              painter: WallPainter(Direction.north),
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