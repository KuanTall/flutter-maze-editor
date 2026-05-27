import 'package:flutter/material.dart';

import 'pages/maze_page.dart';

void main() {
  runApp(const MazeApp());
}

class MazeApp extends StatelessWidget {
  const MazeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MazePage(),
    );
  }
}
