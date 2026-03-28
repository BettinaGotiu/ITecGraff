import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final usernameQuery = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    return usernameQuery.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  Future<void> sendFriendRequest(String targetUserId) async {
    if (currentUserId == null || currentUserId == targetUserId) return;
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    await targetUserRef.update({
      'friendRequests': FieldValue.arrayUnion([currentUserId]),
    });
  }

  Future<void> acceptFriendRequest(String senderId) async {
    if (currentUserId == null) return;
    final myRef = _firestore.collection('users').doc(currentUserId);
    final senderRef = _firestore.collection('users').doc(senderId);

    WriteBatch batch = _firestore.batch();
    batch.update(myRef, {
      'friendRequests': FieldValue.arrayRemove([senderId]),
      'friends': FieldValue.arrayUnion([senderId]),
    });
    batch.update(senderRef, {
      'friends': FieldValue.arrayUnion([currentUserId]),
    });
    await batch.commit();
  }

  Future<void> declineFriendRequest(String senderId) async {
    if (currentUserId == null) return;
    final myRef = _firestore.collection('users').doc(currentUserId);
    await myRef.update({
      'friendRequests': FieldValue.arrayRemove([senderId]),
    });
  }

  Stream<DocumentSnapshot> getUserData(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
