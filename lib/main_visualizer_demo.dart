import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/visualizer/screens/visualizer_screen.dart';

// Small test app: opens only the visualizer. No login or Firebase needed.
// Run with: flutter run -t lib/main_visualizer_demo.dart -d chrome
void main() {
  runApp(const ProviderScope(child: _DemoApp()));
}

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Visualizer Demo',
      themeMode: ThemeMode.dark,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const VisualizerScreen(),
    );
  }
}