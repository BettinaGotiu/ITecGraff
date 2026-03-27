class UserModel {
  final String uid;
  final String email;
  final String team;
  final int level;

  UserModel({
    required this.uid,
    required this.email,
    required this.team,
    this.level = 1,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      email: data['email'] ?? '',
      team: data['team'] ?? 'Red',
      level: data['level'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'team': team,
      'level': level,
    };
  }
}
