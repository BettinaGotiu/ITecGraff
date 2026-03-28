import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Send request
  Future<void> sendFriendRequest(String targetUserId) async {
    if (currentUserId == null || currentUserId == targetUserId) return;

    // Scrie in colectia corecta 'users' (NU 'user_data')
    final targetUserRef = _firestore.collection('users').doc(targetUserId);

    // Folosim set cu merge: true pentru a preveni erorile daca field-ul nu exista
    await targetUserRef.set({
      'friendRequests': FieldValue.arrayUnion([currentUserId]),
    }, SetOptions(merge: true));
  }

  // Accept request
  Future<void> acceptFriendRequest(String senderId) async {
    if (currentUserId == null) return;
    final myRef = _firestore.collection('users').doc(currentUserId);
    final senderRef = _firestore.collection('users').doc(senderId);

    WriteBatch batch = _firestore.batch();
    batch.set(myRef, {
      'friendRequests': FieldValue.arrayRemove([senderId]),
      'friends': FieldValue.arrayUnion([senderId]),
    }, SetOptions(merge: true));

    batch.set(senderRef, {
      'friends': FieldValue.arrayUnion([currentUserId]),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // Decline request
  Future<void> declineFriendRequest(String senderId) async {
    if (currentUserId == null) return;
    await _firestore.collection('users').doc(currentUserId).update({
      'friendRequests': FieldValue.arrayRemove([senderId]),
    });
  }

  Stream<DocumentSnapshot> getUserData(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
