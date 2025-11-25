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
              'v1.0.1',
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
            // Search Users Button (Temporary until better UI)
            OutlinedButton.icon(
              onPressed: () => _showUserSearch(context, user?.id ?? ''),
              icon: const Icon(Icons.person_search),
              label: const Text("Find Friends"),
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

  void _showUserSearch(BuildContext context, String currentUserId) {
    showDialog(
      context: context,
      builder: (context) => _UserSearchDialog(currentUserId: currentUserId),
    );
  }
}

class _UserSearchDialog extends StatefulWidget {
  final String currentUserId;
  const _UserSearchDialog({required this.currentUserId});

  @override
  State<_UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<_UserSearchDialog> {
  final _searchController = TextEditingController();
  List<AppUser> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;
    setState(() => _loading = true);
    final db = context.read<DatabaseService>();
    final results = await db.searchUsers(_searchController.text);
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Find Friends", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Search username...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _search, icon: const Icon(Icons.search)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              width: double.maxFinite,
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                          child: user.photoUrl == null ? Text(user.username[0].toUpperCase()) : null,
                        ),
                        title: Text(user.username),
                        onTap: () => UserProfileDialog.show(context, user.id, widget.currentUserId),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
