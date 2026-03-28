import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/neon_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  String _currentProfilePic = 'assets/profile_pics/avatar1.png';

  final List<String> _profilePics = [
    'assets/profile_pics/pic1.png',
    'assets/profile_pics/pic2.png',
    'assets/profile_pics/pic3.png',
    'assets/profile_pics/pic4.png',
  ];

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _emailCtrl.text = user.email ?? '';
    _usernameCtrl.text = user.displayName ?? '';

    // Încărcăm datele din noua colecție principală 'users'
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .get();
    if (snap.exists && mounted) {
      final data = snap.data()!;
      _usernameCtrl.text = (data['username'] as String?) ?? _usernameCtrl.text;
      _emailCtrl.text = (data['email'] as String?) ?? _emailCtrl.text;

      setState(() {
        _currentProfilePic =
            data['profilePic'] ?? 'assets/profile_pics/pic1.png';
      });
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final username = _usernameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;

      // Update in Authentication
      if (username.isNotEmpty && username != user.displayName) {
        await user.updateDisplayName(username);
      }

      if (email.isNotEmpty && email != user.email) {
        await user.verifyBeforeUpdateEmail(email);
      }

      if (password.isNotEmpty) {
        await user.updatePassword(password);
      }

      // Update in Firestore
      final payload = {
        'uid': user.uid,
        'username': username.isNotEmpty ? username : user.email?.split('@')[0],
        'email': email,
        'profilePic': _currentProfilePic,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Actualizăm ambele colecții pentru consistență
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('user_index')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contul și poza au fost actualizate!')),
      );

      // Golim parola din câmp pentru siguranță
      _passwordCtrl.clear();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'A apărut o eroare la salvare.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('Această acțiune este permanentă.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Stergem utilizatorul din ambele colectii
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await FirebaseFirestore.instance
          .collection('user_index')
          .doc(user.uid)
          .delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Delete failed, please re-login and retry.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Setări Cont',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Zona pentru Poza de profil (Stilul Scan Pop-up)
                  const Text(
                    "Alege o poză de profil:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _profilePics.length,
                      itemBuilder: (context, index) {
                        String pic = _profilePics[index];
                        bool isSelected = pic == _currentProfilePic;

                        return GestureDetector(
                          onTap: () => setState(() => _currentProfilePic = pic),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? Colors.deepPurpleAccent
                                    : Colors.transparent,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(
                                12,
                              ), // Borderul la fel ca in ClipRRect
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                pic,
                                height: 90,
                                width: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.image_not_supported,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 30),

                  // Campurile Originale
                  AppTextField(
                    controller: _usernameCtrl,
                    label: 'Nume Utilizator',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.alternate_email,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _passwordCtrl,
                    label: 'Parolă nouă (opțional)',
                    obscureText: true,
                    prefixIcon: Icons.password_outlined,
                  ),
                  const SizedBox(height: 24),

                  // Butoanele Originale
                  AppButton(
                    label: 'Salvează modificările',
                    onPressed: _save,
                    loading: _loading,
                    icon: Icons.save_outlined,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Deconectare',
                    onPressed: FirebaseAuth.instance.signOut,
                    icon: Icons.logout,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Șterge contul',
                    onPressed: _deleteAccount,
                    icon: Icons.delete_outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
