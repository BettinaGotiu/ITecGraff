import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/friends_service.dart';

class FriendRequestsWidget extends StatelessWidget {
  const FriendRequestsWidget({Key? key}) : super(key: key);

  void _showRequestsDialog(BuildContext context, List<dynamic> requestIds) {
    final friendsService = FriendsService();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Friend Requests'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: requestIds.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("You have no new friend requests."),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: requestIds.length,
                    itemBuilder: (context, index) {
                      String senderId = requestIds[index];

                      // Extragem documentul cu informatiile utilizatorului din Firestore
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(senderId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const ListTile(title: Text("Loading..."));
                          }

                          var data =
                              snapshot.data!.data() as Map<String, dynamic>?;

                          // Extragem valorile cu fallback-uri in caz ca nu exista
                          String username = data?['username'] ?? 'Unknown User';
                          String email = data?['email'] ?? 'No email';
                          String? photoUrl =
                              data?['profilePhoto'] ?? data?['photoUrl'];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              backgroundImage:
                                  photoUrl != null && photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null || photoUrl.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            title: Text(
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              email,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Decline Button
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await friendsService.declineFriendRequest(
                                      senderId,
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                ),
                                // Accept Button
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  onPressed: () async {
                                    await friendsService.acceptFriendRequest(
                                      senderId,
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                ),
                              ],
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
    final friendsService = FriendsService();
    String? currentId = friendsService.currentUserId;

    if (currentId == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: friendsService.getUserData(currentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () => _showRequestsDialog(context, []),
          );
        }

        var data = snapshot.data!.data() as Map<String, dynamic>?;
        List<dynamic> requests = data?['friendRequests'] ?? [];

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                requests.isNotEmpty
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => _showRequestsDialog(context, requests),
            ),
            if (requests.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${requests.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
