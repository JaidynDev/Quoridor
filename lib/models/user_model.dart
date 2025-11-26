import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String username;
  final String? photoUrl;
  final int wins;
  final int losses;
  final List<String> friends;
  final DateTime? lastActive;
  final bool isGuest;

  AppUser({
    required this.id,
    required this.email,
    required this.username,
    this.photoUrl,
    this.wins = 0,
    this.losses = 0,
    this.friends = const [],
    this.lastActive,
    this.isGuest = false,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      photoUrl: data['photoUrl'],
      wins: data['wins'] ?? 0,
      losses: data['losses'] ?? 0,
      friends: List<String>.from(data['friends'] ?? []),
      lastActive: data['lastActive'] != null 
        ? (data['lastActive'] as Timestamp).toDate() 
        : null,
      isGuest: data['isGuest'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'photoUrl': photoUrl,
      'wins': wins,
      'losses': losses,
      'friends': friends,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'isGuest': isGuest,
    };
  }
}
