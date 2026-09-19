import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/game_model.dart';
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
              IconButton(
                tooltip: 'Share code',
                icon: const Icon(Icons.share),
                onPressed: () {
                  Share.share('Join my Quoridor game! Code: ${game.id}');
                },
              ),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: game.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!')),
                  );
                },
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

  const _SeatChip({
    required this.index,
    required this.side,
    required this.user,
    required this.walls,
    required this.isTurn,
  });

  @override
  Widget build(BuildContext context) {
    final color = kPawnColors[index % kPawnColors.length];
    final name = user?.username ?? 'Empty seat';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isTurn ? color.withValues(alpha: 0.22) : AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTurn ? color : AppPalette.hairline,
          width: isTurn ? 2 : 1,
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
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                '$side · $walls walls',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.inkSoft,
                      fontSize: 11,
                    ),
              ),
            ],
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
