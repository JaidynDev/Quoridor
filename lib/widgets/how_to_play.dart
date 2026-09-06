import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HowToPlaySheet extends StatelessWidget {
  const HowToPlaySheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const HowToPlaySheet(),
    );
  }

  static const _rules = [
    (
      Icons.flag_outlined,
      'Win the race',
      'Walk your pawn to any square on the far side of the board. First one across wins.',
    ),
    (
      Icons.swap_horiz,
      'One action a turn',
      'Either step one square up, down, left or right, or place one of your walls.',
    ),
    (
      Icons.fence_outlined,
      'Walls are the real weapon',
      'A wall spans two squares. You get ten in a duel, six with three players, five when four play.',
    ),
    (
      Icons.route_outlined,
      'Never seal anyone in',
      'You can slow a player down, but a wall is illegal if it leaves them no path at all to their goal.',
    ),
    (
      Icons.groups_outlined,
      'Two, three or four',
      'Three players sit south, east and north, with west empty. Four fill every side. First pawn to the far side still wins.',
    ),
    (
      Icons.keyboard_double_arrow_up,
      'Hop the standoff',
      'When pawns meet face to face, jump straight over — or step diagonal if that landing is blocked.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How to play Quoridor', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'A race across a 9x9 board where the walls are the real weapon.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.inkSoft,
                ),
              ),
              const SizedBox(height: 20),
              for (final (icon, title, body) in _rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              body,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppPalette.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
