import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';
import 'teams_screen.dart'; // IMPORT NOU
import 'game_room_screen.dart'; // IMPORT NOU

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onPosterSelected: (id) {
          // Deschidem Canvas-ul peste navbar, ca o pagină nouă
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameRoomScreen(
                posterId: id,
                imagePath: "assets/poster.jpg",
              ), // Adaugă calea corectă pt imaginea ta
            ),
          );
        },
      ),
      const TeamsScreen(), // ÎNLOCUIT AR CANVAS CU TEAMS SCREEN
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
            icon: Icon(Icons.group_work),
            label: 'Echipe',
          ), // MODIFICAT
          NavigationDestination(icon: Icon(Icons.person), label: 'Prieteni'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Setări'),
        ],
      ),
    );
  }
}
