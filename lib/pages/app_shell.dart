import 'package:flutter/material.dart';
import 'canvas_screen.dart';
import 'home_screen.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  String? _lastPosterId;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onPosterSelected: (id) => setState(() => _lastPosterId = id)),
      CanvasScreen(initialPosterId: _lastPosterId),
      const FriendsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.brush_outlined),
            label: 'Canvas',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            label: 'Friends',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
