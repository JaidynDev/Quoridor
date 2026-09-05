import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/game_model.dart';
import '../../models/quoridor_logic.dart';
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
    final db = context.read<DatabaseService>();
    return StreamBuilder<List<AppUser>>(
      key: ValueKey(_statsEpoch),
      stream: db.streamUsersByIds(widget.game.playerIds),
      builder: (context, snapshot) {
        final byId = <String, AppUser>{
          for (final user in snapshot.data ?? const <AppUser>[]) user.id: user,
        };
        return GameResultPanel(
          headline: _headline,
          game: widget.game,
          currentUserId: widget.currentUserId,
          playersById: byId,
          onRematch: () => db.requestRematch(widget.game.id, widget.currentUserId),
          onBackToMenu: () => context.go('/'),
          seriesBuilder: (playerId) => db.streamSeriesStats(
            widget.currentUserId,
            playerId,
          ),
        );
      },
    );
  }

  String _randomWinMessage() {
    const messages = [
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
    const messages = [
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

class GameResultPanel extends StatelessWidget {
  final String headline;
  final GameModel game;
  final String currentUserId;
  final Map<String, AppUser> playersById;
  final Future<void> Function()? onRematch;
  final VoidCallback? onBackToMenu;
  final Stream<Map<String, dynamic>?> Function(String playerId)? seriesBuilder;
  final Map<String, HeadToHead> vsYou;

  const GameResultPanel({
    super.key,
    required this.headline,
    required this.game,
    required this.currentUserId,
    required this.playersById,
    this.onRematch,
    this.onBackToMenu,
    this.seriesBuilder,
    this.vsYou = const {},
  });

  @override
  Widget build(BuildContext context) {
    final waiting = game.rematchRequests.contains(currentUserId);
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
                  headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final seats = game.playerIds.length;
                    const gap = 12.0;
                    final columns = constraints.maxWidth >= 680
                        ? seats.clamp(1, 4)
                        : (seats <= 2 ? seats.clamp(1, 2) : 2);
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
                            width: width.clamp(130.0, 300.0),
                            child: _PlayerResultCard(
                              game: game,
                              seatIndex: i,
                              playerId: game.playerIds[i],
                              user: playersById[game.playerIds[i]],
                              currentUserId: currentUserId,
                              vsYou: vsYou[game.playerIds[i]],
                              seriesStream:
                                  game.playerIds[i] == currentUserId
                                      ? null
                                      : seriesBuilder?.call(game.playerIds[i]),
                            ),
                          ),
                      ],
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
                    onPressed: onRematch,
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
                  onPressed: onBackToMenu,
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
}

class _PlayerResultCard extends StatelessWidget {

  final GameModel game;
  final int seatIndex;
  final String playerId;
  final AppUser? user;
  final String currentUserId;
  final HeadToHead? vsYou;
  final Stream<Map<String, dynamic>?>? seriesStream;

  const _PlayerResultCard({
    required this.game,
    required this.seatIndex,
    required this.playerId,
    required this.user,
    required this.currentUserId,
    this.vsYou,
    this.seriesStream,
  });

  bool get isYou => playerId == currentUserId;

  @override
  Widget build(BuildContext context) {
    final won = game.winnerId == playerId;
    final color = kPawnColors[seatIndex % kPawnColors.length];
    final side = QuoridorLogic.sideLabel(seatIndex, game.settings.seats);
    final name = afterActionPlayerName(user?.username, isYou: isYou);
    final sessionW = game.sessionWinsFor(playerId);
    final sessionL = game.sessionLossesFor(playerId);
    final career = _canShowCareer() ? _careerRecord() : null;

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
          if (!isYou) _vsYouLine(),
        ],
      ),
    );
  }

  Widget _vsYouLine() {
    if (vsYou != null) {
      return _StatLine(label: 'You vs', value: vsYou!.scoreLabel);
    }
    final stream = seriesStream;
    if (stream == null) {
      return const _StatLine(label: 'You vs', value: '0–0');
    }
    return StreamBuilder<Map<String, dynamic>?>(
      stream: stream,
      builder: (context, snapshot) {
        final vs = HeadToHead.fromSeries(snapshot.data, currentUserId);
        return _StatLine(label: 'You vs', value: vs.scoreLabel);
      },
    );
  }

  bool _canShowCareer() {
    if (user == null) return false;
    if (user!.id.startsWith('guest_') && !isYou) return false;
    return true;
  }

  (int, int) _careerRecord() {
    var wins = user?.wins ?? 0;
    var losses = user?.losses ?? 0;
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
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
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
