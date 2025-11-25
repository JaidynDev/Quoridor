import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class UserProfileDialog extends StatelessWidget {
  final String userId;
  final String currentUserId;

  const UserProfileDialog({
    super.key,
    required this.userId,
    required this.currentUserId,
  });

  static void show(BuildContext context, String userId, String currentUserId) {
    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(userId: userId, currentUserId: currentUserId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();

    return StreamBuilder<AppUser?>(
      stream: db.streamUser(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final user = snapshot.data!;

        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 40,
                  backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null ? Text(user.username[0].toUpperCase(), style: const TextStyle(fontSize: 32)) : null,
                ),
                const SizedBox(height: 16),
                Text(user.username, style: Theme.of(context).textTheme.headlineSmall),
                
                // Online Status
                if (_isOnline(user.lastActive))
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 12, color: Colors.green),
                        SizedBox(width: 4),
                        Text("Online", style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
                
                // Global Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatBox("Wins", user.wins.toString()),
                    _StatBox("Losses", user.losses.toString()),
                  ],
                ),
                
                const Divider(height: 32),
                
                // Series Stats
                if (userId != currentUserId)
                  StreamBuilder<Map<String, dynamic>?>(
                    stream: db.streamSeriesStats(currentUserId, userId),
                    builder: (context, seriesSnap) {
                      final data = seriesSnap.data;
                      int myWins = 0;
                      int theirWins = 0;
                      
                      if (data != null) {
                        final p1 = data['player1Id'];
                        if (p1 == currentUserId) {
                          myWins = data['p1Wins'] ?? 0;
                          theirWins = data['p2Wins'] ?? 0;
                        } else {
                          myWins = data['p2Wins'] ?? 0;
                          theirWins = data['p1Wins'] ?? 0;
                        }
                      }

                      return Column(
                        children: [
                          Text("VS YOU", style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          Text("$myWins - $theirWins", style: Theme.of(context).textTheme.headlineMedium),
                        ],
                      );
                    }
                  ),

                const SizedBox(height: 24),
                
                // Actions
                if (userId != currentUserId)
                  Wrap(
                    spacing: 8,
                    children: [
                      // Friend Button
                      StreamBuilder<AppUser?>(
                        stream: db.streamUser(currentUserId),
                        builder: (context, mySnap) {
                          final me = mySnap.data;
                          final isFriend = me?.friends.contains(userId) ?? false;
                          
                          return FilledButton.tonalIcon(
                            onPressed: () => db.toggleFriend(currentUserId, userId),
                            icon: Icon(isFriend ? Icons.person_remove : Icons.person_add),
                            label: Text(isFriend ? "Remove Friend" : "Add Friend"),
                          );
                        }
                      ),
                      
                      // Invite Button (Placeholder for now, could link to create game)
                      // Only if online or friend?
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Initiate Game with specific user
                          // For now, just close, or maybe navigate to lobby with pre-fill?
                          // Simple v1: Go to lobby
                          // context.push('/lobby');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Invitation feature coming soon! Create a game and share code."))
                          );
                        },
                        icon: const Icon(Icons.gamepad),
                        label: const Text("Invite"),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isOnline(DateTime? lastActive) {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive).inMinutes < 5;
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  
  const _StatBox(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

