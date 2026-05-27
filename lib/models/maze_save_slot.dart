import 'maze_save_data.dart';

class MazeSaveSlot {
  final String name;
  final MazeSaveData data;

  const MazeSaveSlot({
    required this.name,
    required this.data,
  });

  factory MazeSaveSlot.fromJson(Map<String, dynamic> json) {
    return MazeSaveSlot(
      name: json['name'] as String? ?? '',
      data: MazeSaveData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'data': data.toJson(),
    };
  }
}
