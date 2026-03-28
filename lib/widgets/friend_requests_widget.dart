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
          title: const Text('Cereri de prietenie'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: requestIds.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Nu ai nicio cerere nouă de prietenie."),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: requestIds.length,
                    itemBuilder: (context, index) {
                      String senderId = requestIds[index];

                      // Fetch datele utilizatorului care a trimis cererea
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(senderId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const ListTile(title: Text("Se încarcă..."));
                          }

                          var data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          String username =
                              data?['username'] ?? 'Utilizator Necunoscut';

                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(username),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Buton Decline (X Roșu)
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await friendsService.declineFriendRequest(
                                      senderId,
                                    );
                                    // Închidem pop-up-ul ca să facă refresh streamul
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                ),
                                // Buton Accept (V Verde)
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
              child: const Text('Închide'),
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
      // Ascultăm schimbările documentului tău din Firestore
      stream: friendsService.getUserData(currentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
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
                color: requests.isNotEmpty ? Colors.blueAccent : Colors.black,
              ),
              onPressed: () => _showRequestsDialog(context, requests),
            ),
            // Bulină Roșie cu numărul de cereri
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
