import 'package:flutter/material.dart';

import 'canvas_screen.dart';
import 'friends_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    CanvasScreen(),
    ScanScreen(),
    CanvasScreen(),
    FriendsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.brush_outlined), label: 'Canvas'),
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.layers_outlined), label: 'Rooms'),
          NavigationDestination(icon: Icon(Icons.group_outlined), label: 'Friends'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
