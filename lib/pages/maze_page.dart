import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/direction.dart';
import '../models/grid_pos.dart';
import '../models/maze_save_collection.dart';
import '../models/maze_save_data.dart';
import '../models/maze_save_slot.dart';
import '../models/room.dart';
import '../painters/direction_triangle_painter.dart';
import '../painters/room_painter.dart';
import '../painters/wall_painter.dart';
import '../storage/maze_cookie_storage.dart';
import '../storage/maze_local_save_storage.dart';

class MazePage extends StatefulWidget {
  const MazePage({super.key});

  @override
  State<MazePage> createState() => _MazePageState();
}

class _MazePageState extends State<MazePage> {
  final List<Room> rooms = [Room(x: 0, y: 0)];
  final MazeCookieStorage _storage = MazeCookieStorage();
  final MazeLocalSaveStorage _saveStorage = MazeLocalSaveStorage();

  static const int maxCookieSaveLength = 3800;
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

  final List<MazeSaveData> _undoStack = [];
  final List<MazeSaveData> _redoStack = [];
  MazeSaveData? _markerDragStartSnapshot;

  bool draggingStart = false;
  bool draggingGoal = false;
  bool isLoadPanelOpen = false;
  int? deleteVisibleSaveIndex;

  Room? activeDrawRoom;

  static const double canvasSize = 4000;
  static const double canvasCenter = canvasSize / 2;

  final TransformationController _controller = TransformationController();
  final GlobalKey _canvasKey = GlobalKey();
  Timer? _autosaveTimer;

  Offset get defaultStartMarker => Offset(
        canvasCenter + roomSize / 2,
        canvasCenter + roomSize / 2,
      );

  Offset get defaultGoalMarker => Offset(
        canvasCenter + spacing + roomSize / 2,
        canvasCenter + roomSize / 2,
      );

  MazeSaveData snapshotMaze() {
    return MazeSaveData(
      rooms: rooms.map((room) => Room.fromJson(room.toJson())).toList(),
      startMarker: startMarker,
      goalMarker: goalMarker,
    );
  }

  void applyMazeSnapshot(MazeSaveData saveData) {
    rooms
      ..clear()
      ..addAll(
        saveData.rooms.isEmpty
            ? [Room(x: 0, y: 0)]
            : saveData.rooms.map((room) => Room.fromJson(room.toJson())),
      );
    startMarker = saveData.startMarker;
    goalMarker = saveData.goalMarker;
    startPoint = null;
    endPoint = null;
    dragPath = [];
    draggingStart = false;
    draggingGoal = false;
    activeDrawRoom = null;
    _markerDragStartSnapshot = null;
  }

  void rememberForUndo({MazeSaveData? snapshot}) {
    _undoStack.add(snapshot ?? snapshotMaze());
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void undoMazeChange() {
    if (_undoStack.isEmpty) return;

    final current = snapshotMaze();
    final previous = _undoStack.removeLast();

    setState(() {
      _redoStack.add(current);
      applyMazeSnapshot(previous);
    });
    scheduleAutosave();
  }

  void redoMazeChange() {
    if (_redoStack.isEmpty) return;

    final current = snapshotMaze();
    final next = _redoStack.removeLast();

    setState(() {
      _undoStack.add(current);
      applyMazeSnapshot(next);
    });
    scheduleAutosave();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void saveMaze({bool showFeedback = true}) {
    final autosave = snapshotMaze();

    final encoded = jsonEncode(autosave.toJson());
    if (encoded.length > maxCookieSaveLength) {
      if (showFeedback) showMessage('Maze is too large for cookie storage');
      return;
    }

    _storage.save(encoded);
    if (showFeedback) showMessage('Maze saved to cookie');
  }

  MazeSaveData? readAutosave() {
    final saved = _storage.load();
    if (saved == null || saved.isEmpty) return null;

    try {
      final decoded = jsonDecode(saved) as Map<String, dynamic>;
      if (decoded.containsKey('rooms')) {
        return MazeSaveData.fromJson(decoded);
      }
      return MazeSaveCollection.fromJson(decoded).autosave;
    } catch (_) {
      return null;
    }
  }

  List<MazeSaveSlot> readManualSaves() {
    final saved = _saveStorage.load();
    if (saved != null && saved.isNotEmpty) {
      try {
        return (jsonDecode(saved) as List<dynamic>)
            .map((save) => MazeSaveSlot.fromJson(save as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return const [];
      }
    }

    final oldCookieData = _storage.load();
    if (oldCookieData == null || oldCookieData.isEmpty) return const [];

    try {
      final oldCollection = MazeSaveCollection.fromJson(
        jsonDecode(oldCookieData) as Map<String, dynamic>,
      );
      return oldCollection.saves;
    } catch (_) {
      return const [];
    }
  }

  bool writeManualSaves(List<MazeSaveSlot> saves) {
    try {
      _saveStorage.save(
        jsonEncode(saves.map((save) => save.toJson()).toList()),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void migrateLegacyCookieSaves() {
    final saved = _saveStorage.load();
    if (saved != null && saved.isNotEmpty) return;

    final oldCookieData = _storage.load();
    if (oldCookieData == null || oldCookieData.isEmpty) return;

    try {
      final oldCollection = MazeSaveCollection.fromJson(
        jsonDecode(oldCookieData) as Map<String, dynamic>,
      );
      if (oldCollection.saves.isNotEmpty) {
        writeManualSaves(oldCollection.saves);
      }
    } catch (_) {
      return;
    }
  }

  String nextDefaultSaveName(List<MazeSaveSlot> saves) {
    final defaultNamePattern = RegExp(r'^地圖(\d+)$');
    var highestIndex = 0;

    for (final save in saves) {
      final match = defaultNamePattern.firstMatch(save.name);
      if (match == null) continue;

      final index = int.tryParse(match.group(1) ?? '');
      if (index != null && index > highestIndex) {
        highestIndex = index;
      }
    }

    return '地圖${highestIndex + 1}';
  }

  String uniqueSaveName(String desiredName, List<MazeSaveSlot> saves) {
    if (!saves.any((save) => save.name == desiredName)) {
      return desiredName;
    }

    var index = 2;
    while (saves.any((save) => save.name == '$desiredName ($index)')) {
      index++;
    }
    return '$desiredName ($index)';
  }

  Future<void> createNamedSave() async {
    final collection = readSaveCollection();
    final controller = TextEditingController();
    var hasSubmitted = false;

    final enteredName = await showDialog<String>(
      context: context,
      builder: (context) {
        void submit(String? value) {
          if (hasSubmitted) return;
          hasSubmitted = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: const Text('New map save'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Save name'),
            textInputAction: TextInputAction.done,
            onSubmitted: submit,
          ),
          actions: [
            TextButton(
              onPressed: () => submit(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => submit(controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (enteredName == null) return;

    final trimmedName = enteredName.trim();
    final desiredName = trimmedName.isEmpty
        ? nextDefaultSaveName(collection.saves)
        : trimmedName;
    final saveName = uniqueSaveName(desiredName, collection.saves);

    final nextCollection = collection.copyWith(
      saves: [
        ...collection.saves,
        MazeSaveSlot(name: saveName, data: snapshotMaze()),
      ],
    );

    if (!writeManualSaves(nextCollection.saves)) {
      showMessage('Save list could not be saved to localStorage');
      return;
    }

    setState(() {
      deleteVisibleSaveIndex = null;
    });
    showMessage('Map saved');
  }

  void loadSaveSlot(MazeSaveData saveData) {
    setState(() {
      applyMazeSnapshot(saveData);
      _undoStack.clear();
      _redoStack.clear();
      isLoadPanelOpen = false;
      deleteVisibleSaveIndex = null;
    });
    scheduleAutosave();
    showMessage('Map loaded');
  }

  void deleteSaveSlot(int index) {
    final collection = readSaveCollection();
    if (index < 0 || index >= collection.saves.length) return;

    final nextSaves = [...collection.saves]..removeAt(index);

    if (!writeManualSaves(nextSaves)) {
      showMessage('Save list could not be updated');
      return;
    }

    setState(() {
      deleteVisibleSaveIndex = null;
    });
    showMessage('Map save deleted');
  }

  void scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 500), () {
      saveMaze(showFeedback: false);
    });
  }

  void loadMaze({bool showFeedback = true}) {
    final saveData = readAutosave();
    if (saveData == null) {
      if (showFeedback) showMessage('No saved maze found');
      return;
    }

    setState(() {
      applyMazeSnapshot(saveData);
      _undoStack.clear();
      _redoStack.clear();
    });

    if (showFeedback) showMessage('Maze loaded from cookie');
  }

  void clearCanvas() {
    rememberForUndo();
    setState(() {
      applyMazeSnapshot(
        MazeSaveData(
          rooms: [Room(x: 0, y: 0)],
          startMarker: defaultStartMarker,
          goalMarker: defaultGoalMarker,
        ),
      );
      isLoadPanelOpen = false;
    });
    scheduleAutosave();
    showMessage('Canvas cleared');
  }

  MazeSaveCollection readSaveCollection() {
    return MazeSaveCollection(
      autosave: readAutosave(),
      saves: readManualSaves(),
    );
  }

  Widget buildLoadPanel() {
    final collection = readSaveCollection();
    final autosave = collection.autosave;

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isLoadPanelOpen ? 280 : 0,
          curve: Curves.easeOut,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Colors.black12)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 16,
                offset: Offset(-4, 0),
              ),
            ],
          ),
          child: isLoadPanelOpen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Map saves',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                isLoadPanelOpen = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (autosave == null)
                      const ListTile(
                        leading: Icon(Icons.history),
                        title: Text('Autosave'),
                        subtitle: Text('No autosave yet'),
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('Autosave'),
                        subtitle: Text('${autosave.rooms.length} rooms'),
                        onTap: () {
                          loadMaze(showFeedback: true);
                          setState(() {
                            isLoadPanelOpen = false;
                            deleteVisibleSaveIndex = null;
                          });
                        },
                      ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Create new save'),
                      onTap: createNamedSave,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: collection.saves.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No map saves'),
                            )
                          : ListView.builder(
                              itemCount: collection.saves.length,
                              itemBuilder: (context, index) {
                                final save = collection.saves[index];
                                final showDelete =
                                    deleteVisibleSaveIndex == index;

                                return ListTile(
                                  leading: const Icon(Icons.map_outlined),
                                  title: Text(save.name),
                                  subtitle:
                                      Text('${save.data.rooms.length} rooms'),
                                  trailing: showDelete
                                      ? IconButton(
                                          tooltip: 'Delete',
                                          icon: const Icon(Icons.delete),
                                          onPressed: () =>
                                              deleteSaveSlot(index),
                                        )
                                      : null,
                                  onTap: () => loadSaveSlot(save.data),
                                  onLongPress: () {
                                    setState(() {
                                      deleteVisibleSaveIndex = index;
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

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
          decoration: BoxDecoration(shape: BoxShape.circle),
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

  Room? getRoom(int x, int y) {
    try {
      return rooms.firstWhere((r) => r.x == x && r.y == y);
    } catch (_) {
      return null;
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

    migrateLegacyCookieSaves();

    startMarker = defaultStartMarker;
    goalMarker = defaultGoalMarker;

    loadMaze(showFeedback: false);

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
    _autosaveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          InteractiveViewer(
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
                  rememberForUndo();
                  final box =
                      _canvasKey.currentContext!.findRenderObject()
                          as RenderBox;

                  final localTopLeft = box.globalToLocal(details.offset);
                  Offset markerCenter =
                      localTopLeft +
                      const Offset(markerSize / 2, markerSize / 2);

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
                  scheduleAutosave();
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
                              _markerDragStartSnapshot = snapshotMaze();
                              draggingStart = true;
                              startMarker = roomCenter;
                            });
                            return;
                          }

                          if (isGoalRoom) {
                            setState(() {
                              _markerDragStartSnapshot = snapshotMaze();
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

                          if (dragPath.length >= 2 &&
                              next == dragPath[dragPath.length - 2]) {
                            setState(() {
                              dragPath.removeLast();
                            });
                            return;
                          }

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
                              rememberForUndo(
                                snapshot: _markerDragStartSnapshot,
                              );
                              if (draggingStart) {
                                startMarker = finalMarker;
                                draggingStart = false;
                              } else {
                                goalMarker = finalMarker;
                                draggingGoal = false;
                              }
                              _markerDragStartSnapshot = null;
                            });
                            scheduleAutosave();

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
                            rememberForUndo();
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
                          scheduleAutosave();
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
                          color: Colors.grey.withValues(alpha: 0.3),
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
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo),
                      onPressed: _undoStack.isEmpty ? null : undoMazeChange,
                    ),
                    IconButton(
                      tooltip: 'Redo',
                      icon: const Icon(Icons.redo),
                      onPressed: _redoStack.isEmpty ? null : redoMazeChange,
                    ),
                    IconButton(
                      tooltip: 'Open map saves',
                      icon: const Icon(Icons.folder_open),
                      onPressed: () {
                        setState(() {
                          isLoadPanelOpen = !isLoadPanelOpen;
                          deleteVisibleSaveIndex = null;
                        });
                      },
                    ),
                    IconButton(
                      tooltip: 'Clear canvas',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: clearCanvas,
                    ),
                  ],
                ),
              ),
            ),
          ),
          buildLoadPanel(),
        ],
      ),
    );
  }
}
