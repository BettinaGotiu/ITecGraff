class Friend {
  final String uid;
  final String username;
  final String email;
  final String profilePic;

  Friend({
    required this.uid,
    required this.username,
    required this.email,
    this.profilePic = 'assets/profile_pics/avatar1.png',
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      uid: json['uid'] ?? '',
      username: json['username'] ?? 'Unknown',
      email: json['email'] ?? '',
      profilePic: json['profilePic'] ?? 'assets/profile_pics/avatar1.png',
    );
  }
}
