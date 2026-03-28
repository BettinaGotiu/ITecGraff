import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:itec/services/teams_service.dart';
import 'team_detail_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TeamService _teamService = TeamService();
  final TextEditingController _nameController = TextEditingController();

  final List<String> _availableIcons = [
    'assets/teams/icon1.png',
    'assets/teams/icon2.png',
    'assets/teams/icon3.png',
    'assets/teams/icon4.png',
  ];
  String _selectedIcon = 'assets/teams/icon1.png';

  void _showCreateTeamDialog() {
    setState(() => _selectedIcon = _availableIcons.first);
    _nameController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Create a New Team"),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Team Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Select Team Icon",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      width: double.maxFinite,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableIcons.length,
                        itemBuilder: (context, index) {
                          final iconPath = _availableIcons[index];
                          final isSelected = _selectedIcon == iconPath;
                          return GestureDetector(
                            onTap: () =>
                                setStateDialog(() => _selectedIcon = iconPath),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.deepPurpleAccent
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: AssetImage(iconPath),
                                onBackgroundImageError: (_, __) {},
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.deepPurpleAccent,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final error = await _teamService.createTeam(
                      _nameController.text,
                      _selectedIcon,
                    );
                    if (error != null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Graffiti Teams')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTeamDialog,
        icon: const Icon(Icons.add),
        label: const Text("Create Team"),
      ),
      body: Column(
        children: [
          // ZONA DE INVITATII (Apare doar daca ai cel putin o invitatie)
          StreamBuilder<DocumentSnapshot>(
            stream: _teamService.getCurrentUserStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists)
                return const SizedBox();

              var userData = snapshot.data!.data() as Map<String, dynamic>;
              List<dynamic> invites = userData['teamInvites'] ?? [];

              if (invites.isEmpty) return const SizedBox();

              return Container(
                color: Colors.deepPurpleAccent.withOpacity(0.1),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: invites.map((teamId) {
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      color: Colors
                          .deepPurple[900], // Fundal intunecat pentru contrast
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.mail_outline,
                            color: Colors.deepPurple,
                          ),
                        ),
                        title: const Text(
                          "You are invited!",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          "Join team: $teamId",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // X - Refuza
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.redAccent,
                              ),
                              onPressed: () =>
                                  _teamService.declineTeamInvite(teamId),
                            ),
                            // V - Accepta
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.greenAccent,
                              ),
                              onPressed: () async {
                                final error = await _teamService.joinTeam(
                                  teamId,
                                );
                                if (error != null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(error),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    // Te duce automat pe pagina echipei cand dai Join!
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TeamDetailsScreen(teamId: teamId),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          // ZONA CU LISTA DE ECHIPE GLOBALE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _teamService.getAllTeams(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final teams = snapshot.data!.docs;
                if (teams.isEmpty)
                  return const Center(
                    child: Text("No teams available. Create one!"),
                  );

                return ListView.builder(
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    var team = teams[index];
                    var data = team.data() as Map<String, dynamic>;
                    List members = data['members'] ?? [];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: AssetImage(
                            data['icon'] ?? 'assets/teams/icon1.png',
                          ),
                          onBackgroundImageError: (_, __) {},
                        ),
                        title: Text(
                          data['name'] ?? 'Unknown Team',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${members.length} Members • ${data['totalXp'] ?? 0} XP",
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TeamDetailsScreen(teamId: team.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
