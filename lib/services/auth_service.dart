import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email & password and create Firestore document
  Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
    String username,
    String teamId,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        // Create user document with required schema
        await _firestore.collection('users').doc(user.uid).set({
          'username': username,
          'teamId': teamId,
          'xp': 0,
          'level': 1,
          'gamesPlayed': 0,
          'wins': 0,
          'friends': [],
          'invitations': [],
        });
      }

      return userCredential;
    } catch (e) {
      print("Sign Up Error: $e");
      return null;
    }
  }

  // Sign in with email & password
  Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print("Sign In Error: $e");
      return null;
    }
  }
}
