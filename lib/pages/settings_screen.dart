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

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    _emailCtrl.text = user?.email ?? '';
    _usernameCtrl.text = user?.displayName ?? '';

    final snap = await FirebaseFirestore.instance
        .collection('user_data')
        .doc(_uid)
        .get();
    final data = snap.data();
    if (data != null && mounted) {
      _usernameCtrl.text = (data['username'] as String?) ?? _usernameCtrl.text;
      _emailCtrl.text = (data['email'] as String?) ?? _emailCtrl.text;
      setState(() {});
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

      if (username.isNotEmpty && username != user.displayName) {
        await user.updateDisplayName(username);
      }

      if (email.isNotEmpty && email != user.email) {
        await user.verifyBeforeUpdateEmail(email);
      }

      if (password.isNotEmpty) {
        await user.updatePassword(password);
      }

      final payload = {
        'uid': user.uid,
        'username': username,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('user_data')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('user_index')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings updated')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to update account')),
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
        content: const Text('This action is permanent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('user_data')
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
                    'Account settings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _usernameCtrl,
                    label: 'Username',
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
                    label: 'New password',
                    obscureText: true,
                    prefixIcon: Icons.password_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Save changes',
                    onPressed: _save,
                    loading: _loading,
                    icon: Icons.save_outlined,
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Logout',
                    onPressed: FirebaseAuth.instance.signOut,
                    icon: Icons.logout,
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Delete account',
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
