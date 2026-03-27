import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/friend.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/neon_card.dart';

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
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final fromDoc = await FirebaseFirestore.instance.collection('user_data').doc(me.uid).get();
    final fromData = fromDoc.data() ?? <String, dynamic>{};

    await FirebaseFirestore.instance
        .collection('user_data')
        .doc(target.uid)
        .collection('friend_requests')
        .doc(me.uid)
        .set({
      'fromUid': me.uid,
      'fromUsername': fromData['username'] ?? me.displayName ?? 'Unknown',
      'fromEmail': me.email ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Friend request sent to ${target.username}')),
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
                NeonCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Find friends', style: Theme.of(context).textTheme.titleLarge),
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
                      Text('Your friends', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Friend>>(
                        stream: _friendsStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final friends = snapshot.data!;
                          if (friends.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('No friends yet.'),
                            );
                          }

                          return Column(
                            children: friends
                                .map(
                                  (friend) => ListTile(
                                    leading: const Icon(Icons.group_outlined),
                                    title: Text(friend.username),
                                    subtitle: Text(friend.email),
                                  ),
                                )
                                .toList(),
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
