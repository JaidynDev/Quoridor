import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/how_to_play.dart';
import '../../widgets/user_profile_dialog.dart';
import '../auth/auth_screen.dart';

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
    if (user == null) return;
    context
        .read<DatabaseService>()
        .updateLastActive(user.id)
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppUser?>();
    final db = context.read<DatabaseService>();

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (user != null && user.friends.isNotEmpty)
            StreamBuilder<List<AppUser>>(
              stream: db.streamUsersByIds(user.friends),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final online =
                    snapshot.data!.where((f) => _isOnline(f.lastActive)).toList();

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: online.take(4).map((friend) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () => UserProfileDialog.show(context, friend.id, user.id),
                        child: Stack(
                          children: [
                            _Avatar(user: friend, radius: 16),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2FBE8C),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppPalette.parchment,
                                    width: 1.5,
                                  ),
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
              padding: const EdgeInsets.only(right: 16.0, left: 4),
              child: Tooltip(
                message: user.isGuest ? 'Sign in' : 'Your profile',
                child: GestureDetector(
                  onTap: () => UserProfileDialog.show(context, user.id, user.id),
                  child: _Avatar(user: user, radius: 20),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 16),
                  if (user?.isGuest == true) ...[
                    _GuestBanner(name: user?.username ?? 'Guest'),
                    const SizedBox(height: 16),
                  ],
                  _MenuTile(
                    icon: Icons.play_arrow_rounded,
                    title: 'Play a match',
                    subtitle: 'Start a table or join a friend with their code',
                    highlighted: true,
                    onTap: () => context.push('/lobby'),
                  ),
                  const SizedBox(height: 12),
                  _MenuTile(
                    icon: Icons.people_alt_outlined,
                    title: 'Friends',
                    subtitle: 'See who is online, add rivals and send invites',
                    onTap: () => context.push('/friends'),
                  ),
                  const SizedBox(height: 12),
                  _MenuTile(
                    icon: Icons.view_in_ar_outlined,
                    title: 'Board preview',
                    subtitle: 'Look over the 3D board from either side',
                    onTap: () => context.push('/preview'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Quoridor v1.1.1',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.inkSoft,
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

  bool _isOnline(DateTime? lastActive) {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive).inMinutes < 5;
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.slateDeep, AppPalette.pineDark, AppPalette.pine],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STRATEGY BOARD GAME',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quoridor',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Race your pawn to the opposite side of the board. '
                  'Two or four players. Walls to slow a rival down, but you '
                  'can never block them off completely.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => HowToPlaySheet.show(context),
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('How to play'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint board grid behind the hero text.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    const divisions = 9;
    final step = size.height / divisions;
    for (var i = 1; i < divisions; i++) {
      final y = step * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GuestBanner extends StatelessWidget {
  final String name;

  const _GuestBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person_outline,
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Playing as $name', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Sign in to keep friends, stats and invites.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () => AuthScreen.show(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: highlighted ? scheme.primary : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: highlighted ? scheme.primary : AppPalette.hairline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.18)
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: highlighted ? Colors.white : scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: highlighted ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: highlighted
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppPalette.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: highlighted ? Colors.white70 : AppPalette.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final AppUser user;
  final double radius;

  const _Avatar({required this.user, required this.radius});

  @override
  Widget build(BuildContext context) {
    final initial =
        (user.username.isNotEmpty ? user.username[0] : 'G').toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppPalette.slate,
      foregroundColor: Colors.white,
      backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
      child: user.photoUrl == null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
