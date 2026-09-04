import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../models/game_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/how_to_play.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _joinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  Future<void> _createGame() async {
    final settings = await showDialog<GameSettings>(
      context: context,
      builder: (context) => const CreateGameDialog(),
    );
    if (settings == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final user = context.read<AppUser?>();
      if (user == null) return;
      final db = context.read<DatabaseService>();
      final gameId = await db.createGame(user.id, settings);
      if (mounted) context.push('/game/$gameId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Play a match')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Two players, one board. Host a table and pass the code '
                    'around, or drop into a game someone already opened.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppPalette.inkSoft,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CardHeading(
                            icon: Icons.add_circle_outline,
                            title: 'Host a new match',
                            subtitle:
                                'Name the table, pick a clock, then share the code.',
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _createGame,
                            icon: const Icon(Icons.add),
                            label: const Text('Create match'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CardHeading(
                            icon: Icons.login,
                            title: 'Join with a code',
                            subtitle:
                                'Paste the code your opponent sent you to sit down.',
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _joinController,
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) => _joinGame(),
                            decoration: const InputDecoration(
                              labelText: 'Game code',
                              prefixIcon: Icon(Icons.tag),
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: _isLoading ? null : _joinGame,
                            child: const Text('Join match'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => HowToPlaySheet.show(context),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('New here? Read the rules'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CardHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppPalette.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CreateGameDialog extends StatefulWidget {
  const CreateGameDialog({super.key});

  @override
  State<CreateGameDialog> createState() => _CreateGameDialogState();
}

class _CreateGameDialogState extends State<CreateGameDialog> {
  final _nameController = TextEditingController();
  int _timeLimit = 60;
  bool _isPrivate = false;

  static const _clocks = [
    (30, '30 seconds', 'Blitz. Move fast or lose the turn.'),
    (60, '1 minute', 'The standard pace for a friendly game.'),
    (300, '5 minutes', 'Room to plan a proper wall trap.'),
    (0, 'No limit', 'Take as long as you like on every move.'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('New match'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Match name (optional)',
                  hintText: 'Friday rematch',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Shown to your opponent so they know which game they are joining.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppPalette.inkSoft),
              ),
              const SizedBox(height: 20),
              Text('Time per move', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              RadioGroup<int>(
                groupValue: _timeLimit,
                onChanged: (v) => setState(() => _timeLimit = v!),
                child: Column(
                  children: [
                    for (final (value, label, blurb) in _clocks)
                      RadioListTile<int>(
                        value: value,
                        contentPadding: EdgeInsets.zero,
                        title: Text(label),
                        subtitle: Text(
                          blurb,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppPalette.inkSoft),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              SwitchListTile(
                value: _isPrivate,
                onChanged: (v) => setState(() => _isPrivate = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Private match'),
                subtitle: Text(
                  'Only people with the code can join.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppPalette.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            Navigator.pop(
              context,
              GameSettings(
                timeLimitSeconds: _timeLimit,
                isPrivate: _isPrivate,
                name: name.isEmpty ? null : name,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
