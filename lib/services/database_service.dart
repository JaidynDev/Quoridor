import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createGame(String hostId, GameSettings settings) async {
    final docRef = _firestore.collection('games').doc();
    final game = GameModel(
      id: docRef.id,
      hostId: hostId,
      playerIds: [hostId],
      status: 'waiting',
      settings: settings,
      gameState: {
        // Initial Quoridor state
        'p1': {'x': 4, 'y': 0}, // Top (or bottom) center
        'p2': {'x': 4, 'y': 8}, // Bottom (or top) center
        'walls': [], // List of {x, y, orientation, owner}
      },
    );
    await docRef.set(game.toMap());
    return docRef.id;
  }

  Future<void> joinGame(String gameId, String userId) async {
    final docRef = _firestore.collection('games').doc(gameId);
    
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Game not found");
      
      final game = GameModel.fromMap(snapshot.data()!, gameId);
      
      if (game.status != 'waiting') throw Exception("Game already started");
      if (game.playerIds.contains(userId)) return; // Already joined
      if (game.playerIds.length >= 2) throw Exception("Game is full");

      transaction.update(docRef, {
        'playerIds': FieldValue.arrayUnion([userId]),
        'status': 'playing', // Start immediately when 2nd player joins for 2p
      });
    });
  }

  Stream<GameModel?> streamGame(String gameId) {
    return _firestore.collection('games').doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GameModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> updateGameState(String gameId, Map<String, dynamic> newState, int nextTurn) async {
    await _firestore.collection('games').doc(gameId).update({
      'gameState': newState,
      'currentTurnIndex': nextTurn,
    });
  }
  
  Future<void> setWinner(String gameId, String winnerId) async {
    await _firestore.collection('games').doc(gameId).update({
      'status': 'finished',
      'winnerId': winnerId,
    });
  }
}
