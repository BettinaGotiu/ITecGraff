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

  // Stream care citește array-ul 'friends' din documentul tău din 'users'
  Stream<List<Friend>> _friendsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists) return [];

          final data = doc.data() as Map<String, dynamic>;

          // Extragem lista de ID-uri de prieteni
          final List<dynamic> friendIds = data['friends'] ?? [];
          if (friendIds.isEmpty) return [];

          List<Friend> friendsList = [];

          // Facem fetch la documentul FIECĂRUI prieten pentru a-i lua datele (nume, poza)
          for (String id in friendIds) {
            final fDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(id)
                .get();
            if (fDoc.exists) {
              final fData = fDoc.data()!;
              friendsList.add(
                Friend.fromJson({
                  'uid': id,
                  'username':
                      fData['username'] ??
                      fData['email']?.split('@')[0] ??
                      'Unknown Player',
                  'email': fData['email'] ?? '',
                  'profilePic':
                      fData['profilePic'] ?? 'assets/profile_pics/avatar1.png',
                }),
              );
            }
          }
          return friendsList;
        });
  }

  // Caută utilizatori noi în baza de date
  Future<void> _searchUsers() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _results = const []);
      return;
    }

    setState(() => _searching = true);

    try {
      // Căutăm direct în colecția principală 'users'
      final byEmail = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: q)
          .limit(10)
          .get();

      final byUsername = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: q)
          .limit(10)
          .get();

      final docs = [...byEmail.docs, ...byUsername.docs];
      final seen = <String>{};
      final users = <Friend>[];

      for (final doc in docs) {
        if (doc.id == _uid || seen.contains(doc.id)) continue;
        seen.add(doc.id);

        final dData = doc.data();
        users.add(
          Friend.fromJson({
            'uid': doc.id,
            'username':
                dData['username'] ?? dData['email']?.split('@')[0] ?? 'Unknown',
            'email': dData['email'] ?? '',
            'profilePic':
                dData['profilePic'] ?? 'assets/profile_pics/avatar1.png',
          }),
        );
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

  // Trimite cererea de prietenie folosind FriendsService-ul existent
  Future<void> _sendRequest(Friend target) async {
    final friendsService = FriendsService();
    await friendsService.sendFriendRequest(target.uid);

    if (!mounted) return;

    // Stergem manual utilizatorul din lista de căutare pt feedback vizual bun
    setState(() {
      _results.removeWhere((f) => f.uid == target.uid);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cerere de prietenie trimisă lui ${target.username}!'),
      ),
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
                // Header cu Titlu + Clopoțelul de notificări pentru cereri
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
                    const FriendRequestsWidget(), // Widget-ul pentru acceptat cereri
                  ],
                ),
                const SizedBox(height: 16),

                // Zona de căutare
                NeonCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Caută Prieteni Noi',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _searchCtrl,
                        label: 'Introdu email sau username exact',
                        prefixIcon: Icons.search,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Caută',
                        onPressed: _searchUsers,
                        loading: _searching,
                        icon: Icons.person_search,
                      ),
                      if (_results.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        ..._results.map(
                          (f) => ListTile(
                            leading: CircleAvatar(
                              backgroundImage: AssetImage(f.profilePic),
                              onBackgroundImageError: (_, __) {},
                              backgroundColor: Colors.grey[800],
                            ),
                            title: Text(
                              f.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              f.email,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.person_add_alt_1,
                                color: Colors.deepPurpleAccent,
                              ),
                              onPressed: () => _sendRequest(f),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Lista de Prieteni Curenți
                NeonCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Prietenii Tăi',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Friend>>(
                        stream: _friendsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('Eroare la încărcarea prietenilor.'),
                            );
                          }

                          final friends = snapshot.data ?? [];

                          if (friends.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Nu ai adăugat niciun prieten încă.',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: friends.length,
                            itemBuilder: (_, i) {
                              final f = friends[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: AssetImage(f.profilePic),
                                  onBackgroundImageError: (_, __) {},
                                  backgroundColor: Colors.grey[800],
                                ),
                                title: Text(
                                  f.username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(f.email),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.message,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Chat-ul cu ${f.username} va fi disponibil curând!',
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
