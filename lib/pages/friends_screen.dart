import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itec/services/friends_service.dart';

import '../models/friend.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/neon_card.dart';
import '../widgets/friend_requests_widget.dart'; // NOU: am importat widget-ul

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  List<Friend> _results = const [];

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<List<Friend>> _friendsStream() {
    return FirebaseFirestore.instance
        .collection('user_data')
        .doc(_uid)
        .collection('friends')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Friend.fromJson({'uid': doc.id, ...doc.data()}))
              .toList(),
        );
  }

  Future<void> _searchUsers() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _results = const []);
      return;
    }

    setState(() => _searching = true);

    try {
      final byEmail = await FirebaseFirestore.instance
          .collection('user_index')
          .where('email', isEqualTo: q)
          .limit(10)
          .get();

      final byUsername = await FirebaseFirestore.instance
          .collection('user_index')
          .where('username', isEqualTo: q)
          .limit(10)
          .get();

      final docs = [...byEmail.docs, ...byUsername.docs];
      final seen = <String>{};
      final users = <Friend>[];

      for (final doc in docs) {
        if (doc.id == _uid || seen.contains(doc.id)) continue;
        seen.add(doc.id);
        users.add(Friend.fromJson({'uid': doc.id, ...doc.data()}));
      }

      if (mounted) {
        setState(() => _results = users);
      }
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _sendRequest(Friend target) async {
    final friendsService = FriendsService();
    await friendsService.sendFriendRequest(target.uid);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Friend request sent to ${target.username}!')),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                // NOU: Header care conține Titlul Paginei și Clopoțelul de Cereri
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prieteni',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const FriendRequestsWidget(), // Widget-ul este plasat aici
                  ],
                ),
                const SizedBox(height: 16),

                NeonCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Find friends',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _searchCtrl,
                        label: 'Email or exact username',
                        prefixIcon: Icons.search,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Search',
                        onPressed: _searchUsers,
                        loading: _searching,
                        icon: Icons.person_search,
                      ),
                      if (_results.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._results.map(
                          (f) => ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(f.username),
                            subtitle: Text(f.email),
                            trailing: IconButton(
                              icon: const Icon(Icons.person_add_alt_1),
                              onPressed: () => _sendRequest(f),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                NeonCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Your friends',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Friend>>(
                        stream: _friendsStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final friends = snapshot.data!;
                          if (friends.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('No friends yet.'),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: friends.length,
                            itemBuilder: (_, i) {
                              final f = friends[i];
                              return ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(f.username),
                                subtitle: Text(f.email),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
