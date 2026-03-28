import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:itec/services/teams_service.dart';
import '../services/friends_service.dart';

class TeamDetailsScreen extends StatefulWidget {
  final String teamId;
  const TeamDetailsScreen({super.key, required this.teamId});

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  final TeamService _teamService = TeamService();
  final FriendsService _friendsService = FriendsService();

  // Memoram prietenii userului curent ca sa stim daca sa-i aratam butonul de "Add friend"
  List<dynamic> myFriends = [];

  @override
  void initState() {
    super.initState();
    _fetchMyFriends();
  }

  Future<void> _fetchMyFriends() async {
    final myId = _friendsService.currentUserId;
    if (myId == null) return;

    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(myId)
        .get();
    if (myDoc.exists && mounted) {
      setState(() {
        myFriends = myDoc.data()?['friends'] ?? [];
      });
    }
  }

  void _handleJoinTeam() async {
    final error = await _teamService.joinTeam(widget.teamId);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  void _showInviteFriendsDialog(
    BuildContext context,
    List<dynamic> currentMembers,
  ) async {
    if (myFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You don't have any friends to invite.")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Invite Friends",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: myFriends.length,
                  itemBuilder: (context, index) {
                    String friendId = myFriends[index];

                    // Don't show friends already in the team
                    if (currentMembers.contains(friendId))
                      return const SizedBox();

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(friendId)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const ListTile(title: Text("Loading..."));
                        var friendData =
                            snapshot.data!.data() as Map<String, dynamic>? ??
                            {};

                        String username =
                            friendData['username'] ??
                            friendData['email']?.split('@')[0] ??
                            'Player';

                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(username),
                          trailing: ElevatedButton(
                            onPressed: () {
                              _teamService.inviteFriendToTeam(
                                friendId,
                                widget.teamId,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Invite sent to $username"),
                                ),
                              );
                              Navigator.pop(context);
                            },
                            child: const Text("Invite"),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String? currentUserId = _teamService.currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Team Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _teamService.getTeamDetails(widget.teamId),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists)
            return const Center(child: Text("Team no longer exists."));

          var teamData = snapshot.data!.data() as Map<String, dynamic>;
          List<dynamic> members = teamData['members'] ?? [];
          bool isMember = members.contains(currentUserId);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage(
                    teamData['icon'] ?? 'assets/teams/icon1.png',
                  ),
                  onBackgroundImageError: (_, __) {},
                ),
                const SizedBox(height: 16),
                Text(
                  teamData['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Total XP: ${teamData['totalXp'] ?? 0}",
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.deepPurpleAccent,
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!isMember)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text("Join Team"),
                        onPressed: _handleJoinTeam,
                      )
                    else ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add),
                        label: const Text("Invite Friends"),
                        onPressed: () =>
                            _showInviteFriendsDialog(context, members),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.exit_to_app, color: Colors.red),
                        label: const Text(
                          "Leave",
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () => _teamService.leaveTeam(widget.teamId),
                      ),
                    ],
                  ],
                ),

                const Divider(height: 40),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Members",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      String memberId = members[index];
                      bool isMe = memberId == currentUserId;

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(memberId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const ListTile(
                              title: Text("Loading member..."),
                            );

                          var userData =
                              snapshot.data!.data() as Map<String, dynamic>? ??
                              {};
                          String username =
                              userData['username'] ??
                              userData['email']?.split('@')[0] ??
                              'Player';
                          String profilePic =
                              userData['profilePic'] ??
                              'assets/profile_pics/avatar1.png';

                          // Verificam daca e deja prieten
                          bool isFriend = myFriends.contains(memberId);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: AssetImage(profilePic),
                              onBackgroundImageError: (_, __) {},
                            ),
                            title: Text(username),
                            subtitle: Text("Level ${userData['level'] ?? 1}"),
                            trailing: isMe
                                ? const Text(
                                    "You",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : isFriend
                                ? const Icon(
                                    Icons.group,
                                    color: Colors.grey,
                                  ) // E deja prieten, aratam un grup icon gri
                                : IconButton(
                                    // Nu e prieten, aratam butonul de add
                                    icon: const Icon(
                                      Icons.person_add,
                                      color: Colors.deepPurpleAccent,
                                    ),
                                    onPressed: () {
                                      _friendsService.sendFriendRequest(
                                        memberId,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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
              ],
            ),
          );
        },
      ),
    );
  }
}
