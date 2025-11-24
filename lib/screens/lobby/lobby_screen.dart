import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../models/game_model.dart';
import '../../services/database_service.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _joinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createGame() async {
    final settings = await showDialog<GameSettings>(
      context: context,
      builder: (context) => const CreateGameDialog(),
    );

    if (settings != null) {
      setState(() => _isLoading = true);
      try {
        final user = context.read<AppUser?>();
        if (user == null) return;
        final db = context.read<DatabaseService>();
        final gameId = await db.createGame(user.id, settings);
        if (mounted) context.push('/game/$gameId');
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _joinGame() async {
    final code = _joinController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = context.read<AppUser?>();
      if (user == null) return;
      final db = context.read<DatabaseService>();
      await db.joinGame(code, user.id);
      if (mounted) context.push('/game/$code');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             Card(
               child: Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Column(
                   children: [
                     const Text("Join Game", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 16),
                     TextField(
                       controller: _joinController,
                       decoration: const InputDecoration(
                         labelText: 'Enter Game Code',
                         border: OutlineInputBorder(),
                       ),
                     ),
                     const SizedBox(height: 16),
                     SizedBox(
                       width: double.infinity,
                       child: FilledButton(
                         onPressed: _isLoading ? null : _joinGame,
                         child: const Text("Join"),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
             const SizedBox(height: 32),
             const Text("Or", textAlign: TextAlign.center),
             const SizedBox(height: 32),
             SizedBox(
               height: 50,
               child: ElevatedButton.icon(
                 onPressed: _isLoading ? null : _createGame,
                 icon: const Icon(Icons.add),
                 label: const Text("Create New Game"),
               ),
             ),
          ],
        ),
      ),
    );
  }
}

class CreateGameDialog extends StatefulWidget {
  const CreateGameDialog({super.key});

  @override
  State<CreateGameDialog> createState() => _CreateGameDialogState();
}

class _CreateGameDialogState extends State<CreateGameDialog> {
  int _timeLimit = 60;
  bool _isPrivate = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Game Settings"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text("Time Limit: "),
              DropdownButton<int>(
                value: _timeLimit,
                items: const [
                   DropdownMenuItem(value: 30, child: Text("30s")),
                   DropdownMenuItem(value: 60, child: Text("60s")),
                   DropdownMenuItem(value: 300, child: Text("5m")),
                   DropdownMenuItem(value: 0, child: Text("No Limit")),
                ],
                onChanged: (v) => setState(() => _timeLimit = v!),
              ),
            ],
          ),
          CheckboxListTile(
            title: const Text("Private Game"),
            value: _isPrivate,
            onChanged: (v) => setState(() => _isPrivate = v!),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        FilledButton(
          onPressed: () => Navigator.pop(context, GameSettings(timeLimitSeconds: _timeLimit, isPrivate: _isPrivate)),
          child: const Text("Create"),
        ),
      ],
    );
  }
}
