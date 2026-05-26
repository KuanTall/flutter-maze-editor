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

enum Direction { north, east, south, west }

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

class GridPos {
  final int x;
  final int y;

  const GridPos(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is GridPos && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

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
        c = Offset(0, (h / 2) - 1);

        left = Offset(c.dx, c.dy - span);
        right = Offset(c.dx, c.dy + span);
        tip = Offset(c.dx + span, c.dy);
        break;

      // ================= WEST（左牆）
      case Direction.west:
        c = Offset(w, (h / 2) - 1);

        left = Offset(c.dx, c.dy - span);
        right = Offset(c.dx, c.dy + span);
        tip = Offset(c.dx - span, c.dy);
        break;

      // ================= NORTH（上牆）
      case Direction.north:
        c = Offset((w / 2) - 1, h);

        left = Offset(c.dx - depth, c.dy);
        right = Offset(c.dx + depth, c.dy);
        tip = Offset(c.dx, c.dy - depth);
        break;

      // ================= SOUTH（下牆）
      case Direction.south:
        c = Offset((w / 2) - 1, 0);

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
  final List<Room> rooms = [Room(x: 0, y: 0)];
  static const double roomSize = 50;
  static const double spacing = 48;

  static const double markerSize = 28;

  Offset? startPoint;
  Offset? endPoint;

  List<GridPos> dragPath = [];

  double lastDx = 0;
  double lastDy = 0;

  Offset? startMarker;
  Offset? goalMarker;

  bool draggingStart = false;
  bool draggingGoal = false;

  Room? activeDrawRoom;

  static const double canvasSize = 4000;
  static const double canvasCenter = canvasSize / 2;

  final TransformationController _controller = TransformationController();
  final GlobalKey _canvasKey = GlobalKey();

  Widget buildMarker({required Offset? position, required Color color}) {
    final pos =
        position ??
        Offset(canvasCenter + roomSize / 2, canvasCenter + roomSize / 2);

    final room = findRoomUnderPoint(pos);

    final isDragging =
        (color == Colors.green && draggingStart) ||
        (color == Colors.red && draggingGoal);

    if (room != null && !isDragging) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: pos.dx - markerSize / 2,
      top: pos.dy - markerSize / 2,
      child: Draggable<Color>(
        data: color,

        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: markerSize,
            height: markerSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black),
            ),
          ),
        ),

        childWhenDragging: Container(
          width: markerSize,
          height: markerSize,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),

        child: Container(
          width: markerSize,
          height: markerSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black),
          ),
        ),
      ),
    );
  }

  Room? findRoomUnderPoint(Offset point) {
    for (final room in rooms) {
      final left = canvasCenter + room.x * spacing;
      final top = canvasCenter + room.y * spacing;
      final right = left + roomSize;
      final bottom = top + roomSize;

      if (point.dx >= left &&
          point.dx <= right &&
          point.dy >= top &&
          point.dy <= bottom) {
        return room;
      }
    }

    return null;
  }

  GridPos? markerRoom(Offset? marker) {
    if (marker == null) return null;

    final room = findRoomUnderPoint(marker);
    if (room == null) return null;

    return GridPos(room.x, room.y);
  }

  GridPos? getDragGridPos(Room startRoom, Offset localPosition) {
    if (startPoint == null || dragPath.isEmpty) return null;

    final last = dragPath.last;

    final lastCenter = Offset(
      startPoint!.dx + (last.x - startRoom.x) * spacing,
      startPoint!.dy + (last.y - startRoom.y) * spacing,
    );

    final dx = localPosition.dx - lastCenter.dx;
    final dy = localPosition.dy - lastCenter.dy;

    const threshold = 0.65;

    if (dx > spacing * threshold) {
      return GridPos(last.x + 1, last.y);
    }

    if (dx < -spacing * threshold) {
      return GridPos(last.x - 1, last.y);
    }

    if (dy > spacing * threshold) {
      return GridPos(last.x, last.y + 1);
    }

    if (dy < -spacing * threshold) {
      return GridPos(last.x, last.y - 1);
    }

    return last;
  }

  bool isNeighbor(GridPos a, GridPos b) {
    final dx = (a.x - b.x).abs();
    final dy = (a.y - b.y).abs();
    return dx + dy == 1;
  }

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
  void initState() {
    super.initState();

    startMarker = Offset(
      canvasCenter + roomSize / 2,
      canvasCenter + roomSize / 2,
    );

    goalMarker = Offset(
      canvasCenter + spacing + roomSize / 2,
      canvasCenter + roomSize / 2,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screen = MediaQuery.of(context).size;

      _controller.value = Matrix4.identity()
        ..translate(
          screen.width / 2 - canvasCenter - roomSize / 2,
          screen.height / 2 - canvasCenter - roomSize / 2,
        );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: InteractiveViewer(
        transformationController: _controller,
        constrained: false,
        minScale: 0.2,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(2000),
        child: SizedBox(
          key: _canvasKey,
          width: canvasSize,
          height: canvasSize,
          child: DragTarget<Color>(
            onAcceptWithDetails: (details) {
              final box =
                  _canvasKey.currentContext!.findRenderObject() as RenderBox;

              final localTopLeft = box.globalToLocal(details.offset);
              Offset markerCenter =
                  localTopLeft + const Offset(markerSize / 2, markerSize / 2);

              final room = findRoomUnderPoint(markerCenter);

              if (room != null) {
                markerCenter = Offset(
                  canvasCenter + room.x * spacing + (roomSize - 2) / 2,
                  canvasCenter + room.y * spacing + (roomSize - 2) / 2,
                );
              }

              setState(() {
                if (details.data == Colors.green) {
                  startMarker = markerCenter;
                } else {
                  goalMarker = markerCenter;
                }
              });
            },

            builder: (context, candidateData, rejectedData) {
              return Stack(
                children: [
                  ...rooms.map((room) {
                    final neighborE = getRoom(room.x + 1, room.y);
                    final neighborW = getRoom(room.x - 1, room.y);
                    final neighborN = getRoom(room.x, room.y - 1);
                    final neighborS = getRoom(room.x, room.y + 1);

                    final showEast = room.east && !(neighborE?.west ?? false);
                    final wallEast = !room.east && !(neighborE?.west ?? false);

                    final showWest = room.west && !(neighborW?.east ?? false);
                    final wallWest = !room.west && !(neighborW?.east ?? false);

                    final showNorth =
                        room.north && !(neighborN?.south ?? false);
                    final wallNorth =
                        !room.north && !(neighborN?.south ?? false);

                    final showSouth =
                        room.south && !(neighborS?.north ?? false);
                    final wallSouth =
                        !room.south && !(neighborS?.north ?? false);

                    final startRoom = draggingStart
                        ? null
                        : markerRoom(startMarker);

                    final goalRoom = draggingGoal
                        ? null
                        : markerRoom(goalMarker);

                    Color? roomFillColor;

                    if (startRoom == GridPos(room.x, room.y)) {
                      roomFillColor = Colors.green;
                    }

                    if (goalRoom == GridPos(room.x, room.y)) {
                      roomFillColor = Colors.red;
                    }

                    final isStartRoom = startRoom == GridPos(room.x, room.y);
                    final isGoalRoom = goalRoom == GridPos(room.x, room.y);

                    return Positioned(
                      left: canvasCenter + room.x * spacing,
                      top: canvasCenter + room.y * spacing,
                      child: GestureDetector(
                        onDoubleTapDown: (details) {
                          setState(() {
                            activeDrawRoom = room;
                            startPoint = details.localPosition;
                            dragPath = [GridPos(room.x, room.y)];
                          });
                        },
                        onPanStart: (details) {
                          final roomCenter = Offset(
                            canvasCenter +
                                room.x * spacing +
                                (roomSize - 2) / 2,
                            canvasCenter +
                                room.y * spacing +
                                (roomSize - 2) / 2,
                          );

                          if (isStartRoom) {
                            setState(() {
                              draggingStart = true;
                              startMarker = roomCenter;
                            });
                            return;
                          }

                          if (isGoalRoom) {
                            setState(() {
                              draggingGoal = true;
                              goalMarker = roomCenter;
                            });
                            return;
                          }

                          if (activeDrawRoom == room) return;

                          startPoint ??= details.localPosition;
                          dragPath = [GridPos(room.x, room.y)];
                        },
                        onPanUpdate: (details) {
                          if (draggingStart || draggingGoal) {
                            final local = Offset(
                              canvasCenter +
                                  room.x * spacing +
                                  details.localPosition.dx,
                              canvasCenter +
                                  room.y * spacing +
                                  details.localPosition.dy,
                            );

                            setState(() {
                              if (draggingStart) {
                                startMarker = local;
                              } else {
                                goalMarker = local;
                              }
                            });

                            return;
                          }
                          if (activeDrawRoom != room) return;

                          endPoint = details.localPosition;

                          final next = getDragGridPos(
                            room,
                            details.localPosition,
                          );
                          if (next == null) return;

                          final last = dragPath.last;

                          if (next == last) return;

                          // 回頭：滑回倒數第二格，取消最後一格
                          if (dragPath.length >= 2 &&
                              next == dragPath[dragPath.length - 2]) {
                            setState(() {
                              dragPath.removeLast();
                            });
                            return;
                          }

                          // 正常往相鄰格前進
                          if (isNeighbor(last, next)) {
                            setState(() {
                              dragPath.add(next);
                            });
                          }
                        },
                        onPanEnd: (_) {
                          if (draggingStart || draggingGoal) {
                            final marker = draggingStart
                                ? startMarker
                                : goalMarker;
                            if (marker == null) return;

                            Offset finalMarker = marker;
                            final roomUnder = findRoomUnderPoint(marker);

                            if (roomUnder != null) {
                              finalMarker = Offset(
                                canvasCenter +
                                    roomUnder.x * spacing +
                                    (roomSize - 2) / 2,
                                canvasCenter +
                                    roomUnder.y * spacing +
                                    (roomSize - 2) / 2,
                              );
                            }

                            setState(() {
                              if (draggingStart) {
                                startMarker = finalMarker;
                                draggingStart = false;
                              } else {
                                goalMarker = finalMarker;
                                draggingGoal = false;
                              }
                            });

                            return;
                          }
                          if (activeDrawRoom != room) return;

                          if (dragPath.length < 2) {
                            setState(() {
                              startPoint = null;
                              endPoint = null;
                              dragPath = [];
                            });
                            return;
                          }

                          setState(() {
                            for (int i = 0; i < dragPath.length - 1; i++) {
                              final from = dragPath[i];
                              final to = dragPath[i + 1];

                              Room? fromRoom = getRoom(from.x, from.y);
                              fromRoom ??= Room(x: from.x, y: from.y);
                              if (!rooms.contains(fromRoom)) {
                                rooms.add(fromRoom);
                              }

                              Room? toRoom = getRoom(to.x, to.y);
                              if (toRoom == null) {
                                toRoom = Room(x: to.x, y: to.y);
                                rooms.add(toRoom);
                              }

                              final dxDir = to.x - from.x;
                              final dyDir = to.y - from.y;

                              final currentOpen = isCurrentOpen(
                                fromRoom,
                                dxDir,
                                dyDir,
                              );
                              final oppositeOpen = isOppositeOpen(
                                toRoom,
                                dxDir,
                                dyDir,
                              );

                              if (dragPath.length == 2 &&
                                  currentOpen &&
                                  oppositeOpen) {
                                closeBothDoors(fromRoom, toRoom, dxDir, dyDir);
                              } else {
                                connectRoom(fromRoom, dxDir, dyDir);
                              }
                            }

                            startPoint = null;
                            endPoint = null;
                            dragPath = [];
                            activeDrawRoom = null;
                          });
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CustomPaint(
                              size: Size(roomSize - 2, roomSize - 2),
                              painter: RoomPainter(fillColor: roomFillColor),
                            ),

                            if (showEast)
                              Positioned(
                                right: -roomSize / 2,
                                top: 0,
                                child: SizedBox(
                                  width: roomSize / 2,
                                  height: roomSize,
                                  child: CustomPaint(
                                    painter: DirectionTrianglePainter(
                                      Direction.east,
                                    ),
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

                            if (showWest)
                              Positioned(
                                left: -roomSize / 2,
                                top: 0,
                                child: SizedBox(
                                  width: roomSize / 2,
                                  height: roomSize,
                                  child: CustomPaint(
                                    painter: DirectionTrianglePainter(
                                      Direction.west,
                                    ),
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

                            if (showSouth)
                              Positioned(
                                bottom: -roomSize / 2,
                                left: 0,
                                child: SizedBox(
                                  width: roomSize,
                                  height: roomSize / 2,
                                  child: CustomPaint(
                                    painter: DirectionTrianglePainter(
                                      Direction.south,
                                    ),
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

                            if (showNorth)
                              Positioned(
                                top: -roomSize / 2,
                                left: 0,
                                child: SizedBox(
                                  width: roomSize,
                                  height: roomSize / 2,
                                  child: CustomPaint(
                                    painter: DirectionTrianglePainter(
                                      Direction.north,
                                    ),
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

                  ...dragPath.skip(1).map((pos) {
                    return Positioned(
                      left: canvasCenter + pos.x * spacing,
                      top: canvasCenter + pos.y * spacing,
                      child: Container(
                        width: roomSize,
                        height: roomSize,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          border: Border.all(color: Colors.grey, width: 2),
                        ),
                      ),
                    );
                  }),
                  buildMarker(position: startMarker, color: Colors.green),

                  buildMarker(position: goalMarker, color: Colors.red),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
