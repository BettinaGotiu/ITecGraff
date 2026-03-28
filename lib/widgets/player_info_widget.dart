import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
          title: const Text('Players in Room'),
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
                final userId = player['userId'];
                bool isMe = userId == myId;

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ListTile(title: Text("Loading..."));
                    }

                    var dbData = snapshot.data!.data() as Map<String, dynamic>?;

                    String username =
                        dbData?['username'] ?? player['username'] ?? 'Unknown';
                    String email = dbData?['email'] ?? 'No email';
                    String? photoUrl =
                        dbData?['profilePhoto'] ?? dbData?['photoUrl'];

                    // Extragem culoarea echipei (dacă nu are, fallback la gri)
                    String hexColor = dbData?['teamColor'] ?? '#9E9E9E';
                    Color teamColor = Color(
                      int.parse("0xFF${hexColor.replaceAll('#', '')}"),
                    );

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: teamColor,
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null || photoUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: const TextStyle(fontSize: 12)),
                          Text("Team: ${dbData?['teamId'] ?? 'None'}"),
                        ],
                      ),
                      trailing: isMe
                          ? const Text(
                              "You",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.person_add,
                                color: Colors.deepPurpleAccent,
                              ),
                              onPressed: () {
                                _friendsService.sendFriendRequest(userId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Friend request sent to $username',
                                    ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
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
