import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/game_model.dart';
import '../../models/move_clock.dart';
import '../../models/quoridor_logic.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/game_link.dart';
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
          return _MatchProblem(
            title: 'Could not open that match',
            detail: '${snapshot.error}',
          );
        }

        // Waiting is the connecting state. A null value once connected means
        // the document is not there, which is a dead link rather than a wait.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _MatchLoading();
        }

        final game = snapshot.data;
        if (game == null) {
          return _MatchProblem(
            title: 'That match is not here',
            detail: 'The link may be out of date, or the table was cleared '
                'away. Code: $gameId',
          );
        }

        return _GameScreenContent(game: game, currentUser: currentUser);
      },
    );
  }
}

/// Loading a match, with a way out if the connection never lands so nobody
/// is left staring at a spinner.
class _MatchLoading extends StatefulWidget {
  const _MatchLoading();

  @override
  State<_MatchLoading> createState() => _MatchLoadingState();
}

class _MatchLoadingState extends State<_MatchLoading> {
  static const _patience = Duration(seconds: 8);

  Timer? _slow;
  bool _takingTooLong = false;

  @override
  void initState() {
    super.initState();
    _slow = Timer(_patience, () {
      if (mounted) setState(() => _takingTooLong = true);
    });
  }

  @override
  void dispose() {
    _slow?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _takingTooLong ? 'Still reaching the table' : 'Opening match',
                style: theme.textTheme.titleMedium,
              ),
              if (_takingTooLong) ...[
                const SizedBox(height: 8),
                Text(
                  'This is taking longer than it should. Check your connection, '
                  'or head back and open the match from the menu.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppPalette.inkSoft),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to menu'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A dead link or a failed read, explained rather than left spinning.
class _MatchProblem extends StatelessWidget {
  final String title;
  final String detail;

  const _MatchProblem({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 40, color: AppPalette.inkSoft),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppPalette.inkSoft),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to menu'),
                ),
              ],
            ),
          ),
        ),
      ),
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
      case 'shareLink':
        SharePlus.instance.share(
          ShareParams(
            subject: 'Quoridor match',
            text: 'Join my Quoridor match: ${buildGameLink(game.id)}',
          ),
        );
      case 'copyLink':
        _copy(context, buildGameLink(game.id), 'Link copied!');
      case 'copyCode':
        _copy(context, game.id, 'Code copied!');
      case 'resign':
        _confirmResign(context);
    }
  }

  void _copy(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                    value: 'shareLink',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.share, size: 20),
                      title: Text('Share link'),
                      subtitle: Text('Opens straight into this match'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copyLink',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.link, size: 20),
                      title: Text('Copy link'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copyCode',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.tag, size: 20),
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
              _AutoSeat(game: game, userId: currentUser?.id),
              if (currentUser != null &&
                  !game.playerIds.contains(currentUser!.id))
                _OnlookerNotice(game: game),
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

/// Seats whoever opened a share link, so the link on its own is enough to
/// join. Renders nothing; it only watches for a free seat.
class _AutoSeat extends StatefulWidget {
  final GameModel game;
  final String? userId;

  const _AutoSeat({required this.game, required this.userId});

  @override
  State<_AutoSeat> createState() => _AutoSeatState();
}

class _AutoSeatState extends State<_AutoSeat> {
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTakeSeat());
  }

  @override
  void didUpdateWidget(_AutoSeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The guest session usually lands a beat after the first build.
    _maybeTakeSeat();
  }

  void _maybeTakeSeat() {
    if (_attempted || !mounted) return;

    final id = widget.userId;
    final game = widget.game;
    if (id == null || id.isEmpty) return;
    if (game.playerIds.contains(id)) return;
    if (game.status != 'waiting') return;
    if (game.playerIds.length >= game.settings.seats) return;

    _attempted = true;
    _takeSeat(id);
  }

  Future<void> _takeSeat(String id) async {
    final db = context.read<DatabaseService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await db.joinGame(widget.game.id, id);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not take a seat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Explains why someone looking at the board cannot play on it.
class _OnlookerNotice extends StatelessWidget {
  final GameModel game;

  const _OnlookerNotice({required this.game});

  @override
  Widget build(BuildContext context) {
    final seatsFull = game.playerIds.length >= game.settings.seats;
    final String message;
    if (game.status == 'waiting' && !seatsFull) {
      message = 'Taking your seat...';
    } else if (game.status == 'finished') {
      message = 'You are looking in on a finished match.';
    } else {
      message = 'This table is full, so you are watching this one.';
    }

    return Container(
      width: double.infinity,
      color: AppPalette.parchment,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.visibility_outlined,
              size: 16, color: AppPalette.inkSoft),
          const SizedBox(width: 8),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.inkSoft),
          ),
        ],
      ),
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

/// The join link, spelled out so a host can read it back or copy it.
class _InviteLink extends StatelessWidget {
  final String gameId;

  const _InviteLink({required this.gameId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = buildGameLink(gameId);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.hairline),
          ),
          child: SelectableText(
            link,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  subject: 'Quoridor match',
                  text: 'Join my Quoridor match: $link',
                ),
              ),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share link'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied!')),
                );
              },
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Copy link'),
            ),
          ],
        ),
      ],
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
        child: SingleChildScrollView(
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
                'Send the link and whoever opens it drops straight into this match. The game starts when every seat is filled.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.inkSoft,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _InviteLink(gameId: game.id),
              const SizedBox(height: 16),
              Text(
                'Or hand over the code',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppPalette.inkSoft,
                ),
              ),
              const SizedBox(height: 4),
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
