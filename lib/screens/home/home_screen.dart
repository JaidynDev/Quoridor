import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppUser?>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quoridor PWA'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null ? Text(user.username[0].toUpperCase()) : null,
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
            OutlinedButton(
              onPressed: () => context.read<AuthService>().signOut(),
              child: const Text("Sign Out"),
            ),
          ],
        ),
      ),
    );
  }
}
