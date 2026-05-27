// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

class MazeLocalSaveStorage {
  static const _storageKey = 'trying_flutter_maze_saves';

  String? load() {
    return html.window.localStorage[_storageKey];
  }

  void save(String value) {
    html.window.localStorage[_storageKey] = value;
  }

  void clear() {
    html.window.localStorage.remove(_storageKey);
  }
}
