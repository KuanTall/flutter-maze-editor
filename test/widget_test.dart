import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trying_flutter/main.dart';

void main() {
  testWidgets('Maze app renders the interactive canvas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MazeApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Draggable<Color>), findsWidgets);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.folder_open));
    await tester.pumpAndSettle();

    expect(find.text('Map saves'), findsOneWidget);
    expect(find.text('Autosave'), findsOneWidget);
    expect(find.text('Create new save'), findsOneWidget);
  });
}
