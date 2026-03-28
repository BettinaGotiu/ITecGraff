import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Create team
  Future<String?> createTeam(String teamName, String iconPath) async {
    final user = _auth.currentUser;
    if (user == null) return "User not logged in";

    final formattedName = teamName.trim();
    if (formattedName.isEmpty) return "Team name cannot be empty";

    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data()!.containsKey('teamId')) {
      return "You are already in a team! Leave it first.";
    }

    final teamRef = _db.collection('teams').doc(formattedName);
    final teamDoc = await teamRef.get();
    if (teamDoc.exists) return "A team with this name already exists!";

    WriteBatch batch = _db.batch();

    batch.set(teamRef, {
      'name': formattedName,
      'icon': iconPath,
      'totalXp': 0,
      'members': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    String fallbackUsername = user.email?.split('@')[0] ?? "Player";
    batch.set(_db.collection('users').doc(user.uid), {
      'teamId': formattedName,
      'username': user.displayName?.isNotEmpty == true
          ? user.displayName!
          : fallbackUsername,
      'email': user.email ?? '',
    }, SetOptions(merge: true));

    await batch.commit();
    return null;
  }

  // Join Team
  Future<String?> joinTeam(String teamId) async {
    final user = _auth.currentUser;
    if (user == null) return "User not logged in";

    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data()!.containsKey('teamId')) {
      return "You are already in a team! Leave it first.";
    }

    WriteBatch batch = _db.batch();

    batch.set(_db.collection('teams').doc(teamId), {
      'members': FieldValue.arrayUnion([user.uid]),
    }, SetOptions(merge: true));

    String fallbackUsername = user.email?.split('@')[0] ?? "Player";
    batch.set(_db.collection('users').doc(user.uid), {
      'teamId': teamId,
      'username': user.displayName?.isNotEmpty == true
          ? user.displayName!
          : fallbackUsername,
      'email': user.email ?? '',
      // Sterge invitatia daca se alatura cu succes
      'teamInvites': FieldValue.arrayRemove([teamId]),
    }, SetOptions(merge: true));

    await batch.commit();
    return null;
  }

  // Leave Team
  Future<void> leaveTeam(String teamId) async {
    if (currentUserId == null) return;
    WriteBatch batch = _db.batch();

    batch.set(_db.collection('teams').doc(teamId), {
      'members': FieldValue.arrayRemove([currentUserId]),
    }, SetOptions(merge: true));

    batch.update(_db.collection('users').doc(currentUserId), {
      'teamId': FieldValue.delete(),
    });

    await batch.commit();
  }

  // Invită un prieten
  Future<void> inviteFriendToTeam(String friendUid, String teamId) async {
    await _db.collection('users').doc(friendUid).set({
      'teamInvites': FieldValue.arrayUnion([teamId]),
    }, SetOptions(merge: true));
  }

  // Refuză Invitația
  Future<void> declineTeamInvite(String teamId) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).update({
      'teamInvites': FieldValue.arrayRemove([teamId]),
    });
  }

  Stream<QuerySnapshot> getAllTeams() {
    return _db.collection('teams').snapshots();
  }

  Stream<DocumentSnapshot> getTeamDetails(String teamId) {
    return _db.collection('teams').doc(teamId).snapshots();
  }

  // Obține datele live ale user-ului curent pentru a citi invitatiile
  Stream<DocumentSnapshot> getCurrentUserStream() {
    return _db.collection('users').doc(currentUserId).snapshots();
  }
}
