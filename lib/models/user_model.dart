class AppUser {
  final String id;
  final String email;
  final String username;
  final String? photoUrl;
  final int wins;
  final int losses;

  AppUser({
    required this.id,
    required this.email,
    required this.username,
    this.photoUrl,
    this.wins = 0,
    this.losses = 0,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      photoUrl: data['photoUrl'],
      wins: data['wins'] ?? 0,
      losses: data['losses'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'photoUrl': photoUrl,
      'wins': wins,
      'losses': losses,
    };
  }
}
