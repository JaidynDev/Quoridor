import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/game_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'board_3d.dart';

class GameResultScreen extends StatefulWidget {
  final GameModel game;
  final String currentUserId;

  const GameResultScreen({
    super.key,
    required this.game,
    required this.currentUserId,
  });

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen> {
  int _statsEpoch = 0;
  late final String _headline;

  @override
  void initState() {
    super.initState();
    final isWinner = widget.game.winnerId == widget.currentUserId;
    _headline = isWinner ? _randomWinMessage() : _randomLossMessage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordResult());
  }

  Future<void> _recordResult() async {
    if (!mounted) return;
    await context.read<DatabaseService>().recordPersonalResult(
          widget.game.id,
          widget.currentUserId,
        );
    if (mounted) setState(() => _statsEpoch++);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final db = context.read<DatabaseService>();
    final waiting = game.rematchRequests.contains(widget.currentUserId);
    final waitingLabel = game.playerIds.length > 2
        ? 'Waiting for others...'
        : 'Waiting for opponent...';

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                StreamBuilder<List<AppUser>>(
                  key: ValueKey(_statsEpoch),
                  stream: db.streamUsersByIds(game.playerIds),
                  builder: (context, snapshot) {
                    final byId = <String, AppUser>{
                      for (final user in snapshot.data ?? const <AppUser>[])
                        user.id: user,
                    };
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final seats = game.playerIds.length;
                        const gap = 12.0;
                        final columns = seats <= 2
                            ? seats.clamp(1, 2)
                            : (constraints.maxWidth >= 560 ? 4 : 2);
                        final width = seats == 0
                            ? constraints.maxWidth
                            : (constraints.maxWidth - gap * (columns - 1)) /
                                columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          alignment: WrapAlignment.center,
                          children: [
                            for (var i = 0; i < game.playerIds.length; i++)
                              SizedBox(
                                width: width.clamp(148.0, 300.0),
                                child: _PlayerResultCard(
                                  game: game,
                                  seatIndex: i,
                                  playerId: game.playerIds[i],
                                  user: byId[game.playerIds[i]],
                                  currentUserId: widget.currentUserId,
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
                if (waiting)
                  FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white24,
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: Text(waitingLabel),
                  )
                else
                  FilledButton(
                    onPressed: () async {
                      await db.requestRematch(game.id, widget.currentUserId);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.pine,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Rematch'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    side: const BorderSide(color: Colors.white),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Back to Menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _randomWinMessage() {
    final messages = [
      'Did you cheat? Just kidding, nice job!',
      'Quoridor master in the house!',
      'Your wall placement was legendary.',
      'The opponent never saw it coming.',
      'Easy peasy lemon squeezy.',
      'Winner winner chicken dinner!',
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _randomLossMessage() {
    final messages = [
      "Walls are hard, aren't they?",
      'Maybe try Checkers?',
      'Oof, blocked at the finish line.',
      "Don't worry, my grandma plays like that too.",
      'Better luck next time!',
      'You were so close... kinda.',
    ];
    return messages[Random().nextInt(messages.length)];
  }
}

class _PlayerResultCard extends StatelessWidget {
  static const _sides4 = ['South', 'East', 'North', 'West'];

  final GameModel game;
  final int seatIndex;
  final String playerId;
  final AppUser? user;
  final String currentUserId;

  const _PlayerResultCard({
    required this.game,
    required this.seatIndex,
    required this.playerId,
    required this.user,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final isYou = playerId == currentUserId;
    final won = game.winnerId == playerId;
    final color = kPawnColors[seatIndex % kPawnColors.length];
    final seats = game.playerIds.length;
    final side = seats == 4
        ? _sides4[seatIndex % 4]
        : (seatIndex == 0 ? 'South' : 'North');
    final baseName =
        (user != null && user!.username.trim().isNotEmpty) ? user!.username : 'Guest';
    final name = isYou ? '$baseName (You)' : baseName;
    final sessionW = game.sessionWinsFor(playerId);
    final sessionL = game.sessionLossesFor(playerId);
    final showCareer = _canShowCareer();
    final career = showCareer ? _careerRecord() : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: won
            ? const Color(0xFF3A2F14)
            : Colors.white.withValues(alpha: isYou ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: won
              ? const Color(0xFFE4C36A)
              : (isYou ? Colors.white70 : Colors.white24),
          width: won || isYou ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color,
            backgroundImage:
                user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            side,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (won) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE4C36A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Winner',
                style: TextStyle(
                  color: Color(0xFF3A2F14),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _StatLine(label: 'Session', value: '$sessionW–$sessionL'),
          _StatLine(
            label: 'Lifetime',
            value: career == null ? '—' : '${career.$1}–${career.$2}',
          ),
          if (!isYou)
            StreamBuilder<Map<String, dynamic>?>(
              stream: db.streamSeriesStats(currentUserId, playerId),
              builder: (context, snapshot) {
                final vs = HeadToHead.fromSeries(snapshot.data, currentUserId);
                return _StatLine(label: 'You vs', value: vs.scoreLabel);
              },
            ),
        ],
      ),
    );
  }

  bool _canShowCareer() {
    if (user == null) return false;
    // Other browsers' device-local guests don't share career stats.
    if (user!.id.startsWith('guest_') && !isYou) return false;
    return true;
  }

  bool get isYou => playerId == currentUserId;

  (int, int) _careerRecord() {
    var wins = user?.wins ?? 0;
    var losses = user?.losses ?? 0;
    // The local player already wrote their own career row. Other seats may
    // not have applied it yet, so fold this game into the number we show.
    if (isYou) return (wins, losses);
    if (!game.recordedBy.contains(playerId) && game.winnerId != null) {
      if (game.winnerId == playerId) {
        wins += 1;
      } else {
        losses += 1;
      }
    }
    return (wins, losses);
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;

  const _StatLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
