import 'package:flutter/material.dart';

import 'room.dart';

class MazeSaveData {
  final List<Room> rooms;
  final Offset? startMarker;
  final Offset? goalMarker;

  const MazeSaveData({
    required this.rooms,
    required this.startMarker,
    required this.goalMarker,
  });

  factory MazeSaveData.fromJson(Map<String, dynamic> json) {
    return MazeSaveData(
      rooms: (json['rooms'] as List<dynamic>? ?? [])
          .map((room) => Room.fromJson(room as Map<String, dynamic>))
          .toList(),
      startMarker: _offsetFromJson(json['startMarker']),
      goalMarker: _offsetFromJson(json['goalMarker']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rooms': rooms.map((room) => room.toJson()).toList(),
      'startMarker': _offsetToJson(startMarker),
      'goalMarker': _offsetToJson(goalMarker),
    };
  }

  static Offset? _offsetFromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;

    final dx = value['dx'];
    final dy = value['dy'];

    if (dx is! num || dy is! num) return null;

    return Offset(dx.toDouble(), dy.toDouble());
  }

  static Map<String, double>? _offsetToJson(Offset? offset) {
    if (offset == null) return null;

    return {
      'dx': offset.dx,
      'dy': offset.dy,
    };
  }
}
