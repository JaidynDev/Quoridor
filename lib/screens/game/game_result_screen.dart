import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/game_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';

class GameResultScreen extends StatelessWidget {
  final GameModel game;
  final String currentUserId;

  const GameResultScreen({
    super.key, 
    required this.game, 
    required this.currentUserId
  });

  @override
  Widget build(BuildContext context) {
    final isWinner = game.winnerId == currentUserId;
    final opponentId = game.playerIds.firstWhere((id) => id != currentUserId, orElse: () => '');
    final db = context.read<DatabaseService>();

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Funny Message
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  isWinner ? _getRandomWinMessage() : _getRandomLossMessage(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Stats
              if (opponentId.isNotEmpty)
                _buildStats(context, db, currentUserId, opponentId),
              
              const SizedBox(height: 40),
              
              if (game.rematchRequests.contains(currentUserId))
                ElevatedButton(
                  onPressed: null, // Disabled
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    disabledBackgroundColor: Colors.grey,
                    disabledForegroundColor: Colors.white,
                  ),
                  child: const Text("Waiting for opponent...", style: TextStyle(color: Colors.white)),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    await db.requestRematch(game.id, currentUserId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text("Rematch", style: TextStyle(color: Colors.white)),
                ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close result screen
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  side: const BorderSide(color: Colors.white),
                ),
                child: const Text("Back to Menu", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, DatabaseService db, String myId, String oppId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // My Stats
        Expanded(child: _buildUserStats(db, myId, "You")),
        
        // Series Stats
        Expanded(child: _buildSeriesStats(db, myId, oppId)),
        
        // Opponent Stats
        Expanded(child: _buildUserStats(db, oppId, "Opponent")),
      ],
    );
  }

  Widget _buildUserStats(DatabaseService db, String userId, String label) {
    return StreamBuilder<AppUser?>(
      stream: db.streamUser(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final user = snapshot.data!;
        return Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            Text(user.username.isEmpty ? 'Player' : user.username, style: const TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 8),
            Text("W: ${user.wins}  L: ${user.losses}", style: const TextStyle(color: Colors.white70)),
          ],
        );
      },
    );
  }

  Widget _buildSeriesStats(DatabaseService db, String myId, String oppId) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: db.streamSeriesStats(myId, oppId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final data = snapshot.data!;
        // Determine which wins are whose based on stored IDs
        final p1 = data['player1Id'];
        final p1Wins = data['p1Wins'] ?? 0;
        final p2Wins = data['p2Wins'] ?? 0;
        
        final myWins = myId == p1 ? p1Wins : p2Wins;
        final oppWins = myId == p1 ? p2Wins : p1Wins;

        return Column(
          children: [
            const Text("Series", style: TextStyle(color: Colors.amber, fontSize: 16)),
            const SizedBox(height: 8),
            const Text("VS", style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("$myWins - $oppWins", style: const TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }

  String _getRandomWinMessage() {
    final messages = [
      "Did you cheat? Just kidding, nice job!",
      "Quoridor master in the house!",
      "Your wall placement was legendary.",
      "The opponent never saw it coming.",
      "Easy peasy lemon squeezy.",
      "Winner winner chicken dinner!",
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _getRandomLossMessage() {
    final messages = [
      "Walls are hard, aren't they?",
      "Maybe try Checkers?",
      "Oof, blocked at the finish line.",
      "Don't worry, my grandma plays like that too.",
      "Better luck next time!",
      "You were so close... kinda.",
    ];
    return messages[Random().nextInt(messages.length)];
  }
}

