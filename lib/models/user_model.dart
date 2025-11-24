class AppUser {
  final String id;
  final String email;
  final String username;
  final String? photoUrl;

  AppUser({
    required this.id,
    required this.email,
    required this.username,
    this.photoUrl,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'photoUrl': photoUrl,
    };
  }
}
