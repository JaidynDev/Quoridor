import 'package:flutter/material.dart';
import '../../models/game_model.dart';
import '../../models/user_model.dart';
import 'board_view.dart';

/// Sample board used to inspect the 3D camera without a live match.
class BoardPreviewScreen extends StatelessWidget {
  const BoardPreviewScreen({super.key});

  GameModel _sampleGame() {
    return GameModel(
      id: 'preview',
      hostId: 'host',
      playerIds: const ['host', 'guest'],
      status: 'playing',
      settings: GameSettings(),
      currentTurnIndex: 0,
      gameState: {
        'p1': {'x': 4, 'y': 2},
        'p2': {'x': 4, 'y': 6},
        'p1WallsLeft': 7,
        'p2WallsLeft': 8,
        'walls': [
          {'x': 1, 'y': 1, 'orientation': 0},
          {'x': 4, 'y': 2, 'orientation': 1},
          {'x': 6, 'y': 3, 'orientation': 0},
          {'x': 2, 'y': 4, 'orientation': 1},
          {'x': 5, 'y': 5, 'orientation': 0},
          {'x': 0, 'y': 6, 'orientation': 1},
        ],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _sampleGame();
    final p1 = AppUser(id: 'host', email: '', username: 'Host');
    final p2 = AppUser(id: 'guest', email: '', username: 'Guest');

    return Scaffold(
      backgroundColor: const Color(0xFF241610),
      appBar: AppBar(
        title: const Text('Board visual preview'),
        backgroundColor: const Color(0xFF3E2723),
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final hostBoard = _labeledBoard(
            label: 'Host view (player 1)',
            child: GameBoard(game: game, userId: 'host', p1User: p1, p2User: p2),
          );
          final guestBoard = _labeledBoard(
            label: 'Guest view (player 2)',
            child: GameBoard(game: game, userId: 'guest', p1User: p1, p2User: p2),
          );

          if (constraints.maxWidth > 900) {
            return Row(
              children: [
                Expanded(child: hostBoard),
                Expanded(child: guestBoard),
              ],
            );
          }

          return ListView(
            children: [
              SizedBox(height: constraints.maxHeight * 0.9, child: hostBoard),
              SizedBox(height: constraints.maxHeight * 0.9, child: guestBoard),
            ],
          );
        },
      ),
    );
  }

  Widget _labeledBoard({required String label, required Widget child}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
