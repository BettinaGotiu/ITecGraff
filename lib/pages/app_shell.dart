import 'package:flutter/material.dart';
import 'ar_canvas_screen.dart'; // Folosim noul ecran AR
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
    // Aici se inițializează ecranele
    final pages = [
      HomeScreen(
        onPosterSelected: (id) {
          setState(() {
            _lastPosterId = id;
            _index = 1; // Trecem automat la tab-ul de Canvas după ce a dat Join
          });
        },
      ),
      // Dacă avem un poster ID, deschidem AR, altfel arătăm un mesaj
      _lastPosterId != null
          ? ARCanvasScreen(roomId: _lastPosterId!)
          : const Center(
              child: Text("Scanează un poster prima dată din Home."),
            ),
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
            label: 'AR Canvas',
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
