import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/game_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
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
        if (snapshot.hasError) return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
    
    // Find opponent ID
    final p1Id = game.playerIds.isNotEmpty ? game.playerIds[0] : '';
    final p2Id = game.playerIds.length > 1 ? game.playerIds[1] : '';
    
    // We want to resolve both users. 
    // We can wrap GameBoard in StreamBuilders.
    
    return StreamBuilder<AppUser?>(
      stream: p1Id.isNotEmpty ? db.streamUser(p1Id) : Stream.value(null),
      builder: (context, p1Snap) {
        return StreamBuilder<AppUser?>(
          stream: p2Id.isNotEmpty ? db.streamUser(p2Id) : Stream.value(null),
          builder: (context, p2Snap) {
             final p1User = p1Snap.data;
             final p2User = p2Snap.data;
             
             return Scaffold(
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(game.settings.displayName),
                    Text(
                      game.settings.clockLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                actions: [
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!')));
                    },
                  ),
                ],
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPlayerInfo(p1User, game.gameState['p1WallsLeft'] ?? 10, 1),
                        const Text("vs"),
                        _buildPlayerInfo(p2User, game.gameState['p2WallsLeft'] ?? 10, 2),
                      ],
                    ),
                  ),
                  if (game.status == 'waiting')
                    const Expanded(child: Center(child: Text("Waiting for opponent... Share the code!"))),
                  if (game.status == 'playing' || game.status == 'finished')
                    Expanded(
                      child: Stack(
                        children: [
                          GameBoard(
                            game: game, 
                            userId: currentUser?.id ?? '',
                            p1User: p1User,
                            p2User: p2User,
                          ),
                          if (game.status == 'finished')
                            GameResultScreen(game: game, currentUserId: currentUser?.id ?? ''),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildPlayerInfo(AppUser? user, int walls, int pNum) {
    return Column(
      children: [
        Text(user?.username ?? "Player $pNum", style: const TextStyle(fontWeight: FontWeight.bold)),
        Text("Walls: $walls"),
      ],
    );
  }
}
