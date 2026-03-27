class Friend {
  const Friend({
    required this.uid,
    required this.username,
    required this.email,
  });

  final String uid;
  final String username;
  final String email;

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        uid: json['uid'] as String,
        username: (json['username'] as String?) ?? 'Unknown',
        email: (json['email'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'username': username,
        'email': email,
      };
}
