import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/user_profile_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _startHeartbeat();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  void _startHeartbeat() {
    // Update immediately then every 2 minutes
    _updatePresence();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) => _updatePresence());
  }

  void _updatePresence() {
    final user = context.read<AppUser?>();
    if (user != null) {
      context.read<DatabaseService>().updateLastActive(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppUser?>();
    final db = context.read<DatabaseService>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('Quoridor'),
            const SizedBox(width: 8),
            Text(
              'v1.0.9',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          // Online Friends
          if (user != null && user.friends.isNotEmpty)
            StreamBuilder<List<AppUser>>(
              stream: db.streamUsersByIds(user.friends),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                
                final friends = snapshot.data!;
                final onlineFriends = friends.where((f) => _isOnline(f.lastActive)).toList();

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: onlineFriends.map((friend) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () => UserProfileDialog.show(context, friend.id, user.id),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                              child: friend.photoUrl == null ? Text(friend.username[0].toUpperCase(), style: const TextStyle(fontSize: 12)) : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () => UserProfileDialog.show(context, user.id, user.id),
                child: CircleAvatar(
                  backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null ? Text(user.username[0].toUpperCase()) : null,
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Hello, ${user?.username ?? 'Guest'}!"),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/lobby'),
              icon: const Icon(Icons.play_arrow),
              label: const Text("Play Game"),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/friends'),
              icon: const Icon(Icons.people),
              label: const Text("Friends"),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.read<AuthService>().signOut(),
              child: const Text("Sign Out"),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOnline(DateTime? lastActive) {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive).inMinutes < 5;
  }
}

