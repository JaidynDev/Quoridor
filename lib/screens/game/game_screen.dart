import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/game_model.dart';
import '../../models/move_clock.dart';
import '../../models/quoridor_logic.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_sheet.dart';
import 'board_3d.dart';
import 'board_view.dart';
import 'game_result_screen.dart';

class GameScreen extends StatelessWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final currentUser = context.watch<AppUser?>();

    return StreamBuilder<GameModel?>(
      stream: db.streamGame(gameId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final game = snapshot.data!;
        return _GameScreenContent(game: game, currentUser: currentUser);
      },
    );
  }
}

class _GameScreenContent extends StatelessWidget {
  final GameModel game;
  final AppUser? currentUser;

  const _GameScreenContent({required this.game, required this.currentUser});

  bool get _canResign {
    final id = currentUser?.id;
    if (id == null || id.isEmpty) return false;
    if (game.status == 'finished') return false;
    return game.playerIds.contains(id) && !game.hasResigned(id);
  }

  void _onMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'share':
        Share.share('Join my Quoridor game! Code: ${game.id}');
      case 'copy':
        Clipboard.setData(ClipboardData(text: game.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code copied!')),
        );
      case 'resign':
        _confirmResign(context);
    }
  }

  Future<void> _confirmResign(BuildContext context) async {
    final db = context.read<DatabaseService>();
    final id = currentUser?.id ?? '';
    final onePlayerLeft = game.activePlayerIds.length <= 2;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resign this match?'),
        content: Text(
          onePlayerLeft
              ? 'Your opponent takes the win and it goes on both your records.'
              : 'You leave the table and the others play on. Your pawn stays '
                  'put as a wall of its own.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Resign'),
          ),
        ],
      ),
    );

    if (confirmed == true && id.isNotEmpty) {
      await db.resign(game.id, id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();

    return StreamBuilder<List<AppUser>>(
      stream: db.streamUsersByIds(game.playerIds),
      builder: (context, snap) {
        final byId = <String, AppUser>{
          for (final u in snap.data ?? const <AppUser>[]) u.id: u,
        };
        final players = [
          for (final id in game.playerIds) byId[id],
        ];

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(game.settings.displayName),
                Text(
                  '${game.settings.seatsLabel} · ${game.settings.clockLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => SettingsSheet.show(context),
              ),
              PopupMenuButton<String>(
                tooltip: 'Match options',
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _onMenuSelected(context, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.share, size: 20),
                      title: Text('Share code'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.copy, size: 20),
                      title: Text('Copy code'),
                    ),
                  ),
                  if (_canResign)
                    const PopupMenuItem(
                      value: 'resign',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.flag_outlined, size: 20),
                        title: Text('Resign match'),
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _PlayerStrip(game: game, players: players),
              if (game.status == 'waiting')
                Expanded(
                  child: _WaitingRoom(game: game),
                ),
              if (game.status == 'playing' || game.status == 'finished')
                Expanded(
                  child: Stack(
                    children: [
                      GameBoard(
                        game: game,
                        userId: currentUser?.id ?? '',
                        players: players,
                      ),
                      if (game.status == 'finished')
                        GameResultScreen(
                          game: game,
                          currentUserId: currentUser?.id ?? '',
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerStrip extends StatelessWidget {
  final GameModel game;
  final List<AppUser?> players;

  const _PlayerStrip({required this.game, required this.players});

  @override
  Widget build(BuildContext context) {
    final seats = game.settings.seats;
    final defaults = QuoridorLogic.wallsEach(seats);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < seats; i++)
            _SeatChip(
              index: i,
              side: QuoridorLogic.sideLabel(i, seats),
              user: i < players.length ? players[i] : null,
              walls: game.gameState[QuoridorLogic.wallsKey(i)] ?? defaults,
              isTurn: game.status == 'playing' && game.currentTurnIndex == i,
              hasResigned: i < game.playerIds.length &&
                  game.hasResigned(game.playerIds[i]),
              game: game,
            ),
        ],
      ),
    );
  }
}

class _SeatChip extends StatelessWidget {
  final int index;
  final String side;
  final AppUser? user;
  final dynamic walls;
  final bool isTurn;
  final bool hasResigned;
  final GameModel game;

  const _SeatChip({
    required this.index,
    required this.side,
    required this.user,
    required this.walls,
    required this.isTurn,
    required this.hasResigned,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final color = kPawnColors[index % kPawnColors.length];
    final name = user?.username ?? 'Empty seat';
    final highlight = isTurn && !hasResigned;

    return Opacity(
      opacity: hasResigned ? 0.55 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? color.withValues(alpha: 0.22) : AppPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight ? color : AppPalette.hairline,
            width: highlight ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: color,
              backgroundImage:
                  user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    decoration:
                        hasResigned ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  hasResigned ? '$side · resigned' : '$side · $walls walls',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.inkSoft,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
            if (highlight) TurnClock(game: game),
          ],
        ),
      ),
    );
  }
}

/// Counts down the per-move limit for whoever is on turn.
class TurnClock extends StatefulWidget {
  final GameModel game;

  /// Overridable so tests can drive the countdown without waiting it out.
  final DateTime Function() now;

  const TurnClock({super.key, required this.game, this.now = DateTime.now});

  @override
  State<TurnClock> createState() => _TurnClockState();
}

class _TurnClockState extends State<TurnClock> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = MoveClock.remaining(widget.game, now: widget.now());
    if (left == null) return const SizedBox.shrink();

    final seconds = left.inSeconds;
    final color = seconds <= 5
        ? const Color(0xFFC0392B)
        : seconds <= 15
            ? const Color(0xFFB9770E)
            : AppPalette.inkSoft;

    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            MoveClock.label(left),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingRoom extends StatelessWidget {
  final GameModel game;

  const _WaitingRoom({required this.game});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final need = game.settings.seats - game.playerIds.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                need == 1
                    ? 'Waiting for 1 more player'
                    : 'Waiting for $need more players',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Share the code so friends can sit down. The match starts when every seat is filled.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.inkSoft,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SelectableText(
                game.id,
                style: theme.textTheme.titleMedium?.copyWith(
                  letterSpacing: 0.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
