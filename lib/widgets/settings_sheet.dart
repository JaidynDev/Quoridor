import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'how_to_play.dart';

/// Play preferences, reachable from the menu and from inside a match.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsService>();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      'These apply to this device, so they follow you from match to match.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppPalette.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingSwitch(
                icon: Icons.fence_outlined,
                title: 'Confirm wall placement',
                subtitle:
                    'Drag a wall where you want it, then tap Place wall. Nothing commits until you do.',
                value: settings.confirmWalls,
                onChanged: settings.setConfirmWalls,
              ),
              _SettingSwitch(
                icon: Icons.directions_walk,
                title: 'Confirm pawn moves',
                subtitle:
                    'Tap a square to pick it, then tap Move here to take the step.',
                value: settings.confirmMoves,
                onChanged: settings.setConfirmMoves,
              ),
              _SettingSwitch(
                icon: Icons.lightbulb_outline,
                title: 'Show move hints',
                subtitle: 'Glow the squares your pawn can reach on your turn.',
                value: settings.moveHints,
                onChanged: settings.setMoveHints,
              ),
              _SettingSwitch(
                icon: Icons.vibration,
                title: 'Haptic feedback',
                subtitle: 'A short buzz when your move or wall is committed.',
                value: settings.haptics,
                onChanged: settings.setHaptics,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  HowToPlaySheet.show(context);
                },
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('How to play'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        secondary: Container(
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
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.inkSoft),
        ),
      ),
    );
  }
}
