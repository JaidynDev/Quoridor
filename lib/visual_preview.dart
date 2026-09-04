import 'package:flutter/material.dart';
import 'screens/game/board_preview_screen.dart';

/// Local visual harness for inspecting the 3D board without Firebase.
/// Run with: flutter run -t lib/visual_preview.dart -d chrome
void main() {
  runApp(const VisualPreviewApp());
}

class VisualPreviewApp extends StatelessWidget {
  const VisualPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quoridor Visual Preview',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.brown),
      home: const BoardPreviewScreen(),
    );
  }
}
