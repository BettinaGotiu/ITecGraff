import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int calculateLevel(int xp) {
    return (xp / 1000).floor() + 1;
  }

  Future<void> updateGameResult(
    String userId,
    String userTeamId,
    Map<String, dynamic> gameResultData,
  ) async {
    final String winnerTeam = gameResultData['winnerTeam'];
    final Map<String, dynamic> xpMap = gameResultData['xp'];
    final int receivedXP = xpMap[userId] ?? 0;

    final userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      int currentXp = snapshot.get('xp') ?? 0;
      int newXp = currentXp + receivedXP;
      int newLevel = calculateLevel(newXp);
      bool isWinner = (userTeamId == winnerTeam);

      Map<String, dynamic> updates = {
        'xp': FieldValue.increment(receivedXP),
        'gamesPlayed': FieldValue.increment(1),
        'level': newLevel,
      };

      if (isWinner) {
        updates['wins'] = FieldValue.increment(1);
      }

      transaction.update(userRef, updates);
    });
  }
}
