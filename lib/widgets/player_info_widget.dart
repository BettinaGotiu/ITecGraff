import 'package:flutter/material.dart';
import '../services/friends_service.dart';

class PlayerInfoWidget extends StatelessWidget {
  final List<Map<String, dynamic>> activePlayers;

  const PlayerInfoWidget({Key? key, required this.activePlayers})
    : super(key: key);

  void _showPlayersDialog(BuildContext context) {
    final FriendsService _friendsService = FriendsService();
    String? myId = _friendsService.currentUserId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Jucători în cameră'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: activePlayers.length,
              itemBuilder: (context, index) {
                final player = activePlayers[index];
                bool isMe = player['userId'] == myId;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: player['teamId'] == 'pink'
                        ? Colors.pinkAccent
                        : Colors.blueAccent,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(player['username'] ?? 'Unknown'),
                  subtitle: Text("Team: ${player['teamId']}"),
                  trailing: isMe
                      ? const Text(
                          "Tu",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.person_add,
                            color: Colors.deepPurple,
                          ),
                          onPressed: () {
                            _friendsService.sendFriendRequest(player['userId']);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Cerere trimisă lui ${player['username']}',
                                ),
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Închide'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPlayersDialog(context),
      child: Container(
        margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueAccent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people, size: 16, color: Colors.blueAccent),
            const SizedBox(width: 6),
            Text(
              "${activePlayers.length}",
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
