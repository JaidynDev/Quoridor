import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Friends"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Friends"),
              Tab(text: "Requests"),
              Tab(text: "Add Friend"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FriendsListTab(),
            FriendRequestsTab(),
            AddFriendTab(),
          ],
        ),
      ),
    );
  }
}

class FriendsListTab extends StatelessWidget {
  const FriendsListTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppUser?>();
    final db = context.read<DatabaseService>();

    if (user == null) return const SizedBox();

    if (user.friends.isEmpty) {
      return const Center(child: Text("No friends yet. Add some!"));
    }

    return StreamBuilder<List<AppUser>>(
      stream: db.streamUsersByIds(user.friends),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final friends = snapshot.data!;
        if (friends.isEmpty) return const Center(child: Text("No friends found (ids might be invalid)."));

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                child: friend.photoUrl == null ? Text(friend.username[0].toUpperCase()) : null,
              ),
              title: Text(friend.username),
              subtitle: Text("Wins: ${friend.wins} | Losses: ${friend.losses}"),
              trailing: IconButton(
                icon: const Icon(Icons.person_remove, color: Colors.red),
                onPressed: () {
                  _showRemoveConfirmation(context, db, user.id, friend);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showRemoveConfirmation(BuildContext context, DatabaseService db, String myId, AppUser friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Remove ${friend.username}?"),
        content: const Text("Are you sure you want to remove this friend?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await db.removeFriend(myId, friend.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }
}

class FriendRequestsTab extends StatelessWidget {
  const FriendRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppUser?>();
    final db = context.read<DatabaseService>();

    if (user == null) return const SizedBox();

    return StreamBuilder<List<String>>(
      stream: db.streamFriendRequests(user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final requestIds = snapshot.data!;
        if (requestIds.isEmpty) return const Center(child: Text("No pending requests."));

        return StreamBuilder<List<AppUser>>(
          stream: db.streamUsersByIds(requestIds),
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
            
            final requesters = userSnap.data!;
            
            return ListView.builder(
              itemCount: requesters.length,
              itemBuilder: (context, index) {
                final requester = requesters[index];
                return ListTile(
                  leading: CircleAvatar(
                     backgroundImage: requester.photoUrl != null ? NetworkImage(requester.photoUrl!) : null,
                     child: requester.photoUrl == null ? Text(requester.username[0].toUpperCase()) : null,
                  ),
                  title: Text(requester.username),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => db.acceptFriendRequest(user.id, requester.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => db.declineFriendRequest(user.id, requester.id),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class AddFriendTab extends StatefulWidget {
  const AddFriendTab({super.key});

  @override
  State<AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends State<AddFriendTab> {
  final _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _searching = false;

  Future<void> _search() async {
    if (_searchController.text.trim().isEmpty) return;
    
    setState(() => _searching = true);
    final db = context.read<DatabaseService>();
    try {
      final results = await db.searchUsers(_searchController.text.trim());
      setState(() => _searchResults = results);
    } finally {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppUser?>();
    final db = context.read<DatabaseService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: "Search Username",
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        if (_searching) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              if (user.id == currentUser?.id) return const SizedBox(); // Don't show self

              final isFriend = currentUser?.friends.contains(user.id) ?? false;

              return ListTile(
                leading: CircleAvatar(
                   backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                   child: user.photoUrl == null ? Text(user.username[0].toUpperCase()) : null,
                ),
                title: Text(user.username),
                subtitle: Text("Wins: ${user.wins}"),
                trailing: isFriend 
                  ? const Icon(Icons.check, color: Colors.green)
                  : IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: () async {
                        await db.sendFriendRequest(currentUser!.id, user.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Request sent to ${user.username}")),
                          );
                        }
                      },
                    ),
              );
            },
          ),
        ),
      ],
    );
  }
}

