import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/workspace_screen.dart';

void main() {
  runApp(const ProviderScope(child: MayariApp()));
}

class MayariApp extends StatelessWidget {
  const MayariApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isMacOS = !kIsWeb && Platform.isMacOS;

    return MaterialApp(
      title: 'Mayari',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        platform: isMacOS ? TargetPlatform.macOS : null,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        platform: isMacOS ? TargetPlatform.macOS : null,
      ),
      themeMode: ThemeMode.system,
      home: const WorkspaceScreen(),
    );
  }
}
