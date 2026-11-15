import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/learning/engine/bubble_sort_tracer.dart';
import 'features/learning/screens/dry_run_screen.dart';

// Small test app: opens only the dry run screen.
// No login or Firebase needed.
// Run with: flutter run -t lib/main_demo.dart -d chrome
void main() {
  // ProviderScope is needed for Riverpod.
  runApp(const ProviderScope(child: DemoApp()));
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dry Run Demo',
      themeMode: ThemeMode.dark,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
      ),
      home: DryRunScreen(tracer: BubbleSortTracer()),
    );
  }
}