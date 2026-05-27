import 'maze_save_data.dart';
import 'maze_save_slot.dart';

class MazeSaveCollection {
  final MazeSaveData? autosave;
  final List<MazeSaveSlot> saves;

  const MazeSaveCollection({
    required this.autosave,
    required this.saves,
  });

  factory MazeSaveCollection.empty() {
    return const MazeSaveCollection(autosave: null, saves: []);
  }

  factory MazeSaveCollection.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('rooms')) {
      return MazeSaveCollection(
        autosave: MazeSaveData.fromJson(json),
        saves: const [],
      );
    }

    return MazeSaveCollection(
      autosave: json['autosave'] == null
          ? null
          : MazeSaveData.fromJson(json['autosave'] as Map<String, dynamic>),
      saves: (json['saves'] as List<dynamic>? ?? [])
          .map((save) => MazeSaveSlot.fromJson(save as Map<String, dynamic>))
          .toList(),
    );
  }

  MazeSaveCollection copyWith({
    MazeSaveData? autosave,
    List<MazeSaveSlot>? saves,
  }) {
    return MazeSaveCollection(
      autosave: autosave ?? this.autosave,
      saves: saves ?? this.saves,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autosave': autosave?.toJson(),
      'saves': saves.map((save) => save.toJson()).toList(),
    };
  }
}
