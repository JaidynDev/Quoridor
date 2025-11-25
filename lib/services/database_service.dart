import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_model.dart';
import '../models/user_model.dart';

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
        'p1WallsLeft': 10,
        'p2WallsLeft': 10,
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
    final gameRef = _firestore.collection('games').doc(gameId);

    await _firestore.runTransaction((transaction) async {
      final gameSnapshot = await transaction.get(gameRef);
      if (!gameSnapshot.exists) throw Exception("Game not found");

      final gameData = gameSnapshot.data()!;
      if (gameData['status'] == 'finished') return; // Already finished

      final playerIds = List<String>.from(gameData['playerIds']);
      String? loserId;
      if (playerIds.contains(winnerId)) {
        loserId = playerIds.firstWhere((id) => id != winnerId, orElse: () => '');
      }

      // Update Game
      transaction.update(gameRef, {
        'status': 'finished',
        'winnerId': winnerId,
      });

      // Update User Stats
      final winnerRef = _firestore.collection('users').doc(winnerId);
      // Use set with merge to create if not exists (though users should exist)
      transaction.set(winnerRef, {
        'wins': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (loserId != null && loserId.isNotEmpty) {
        final loserRef = _firestore.collection('users').doc(loserId);
        transaction.set(loserRef, {
          'losses': FieldValue.increment(1),
        }, SetOptions(merge: true));

        // Update Series Stats
        final p1 = winnerId.compareTo(loserId) < 0 ? winnerId : loserId;
        final p2 = winnerId.compareTo(loserId) < 0 ? loserId : winnerId;
        final seriesId = '${p1}_${p2}';
        final seriesRef = _firestore.collection('series').doc(seriesId);

        final seriesSnapshot = await transaction.get(seriesRef);
        if (!seriesSnapshot.exists) {
          transaction.set(seriesRef, {
            'player1Id': p1,
            'player2Id': p2,
            'p1Wins': winnerId == p1 ? 1 : 0,
            'p2Wins': winnerId == p2 ? 1 : 0,
          });
        } else {
          transaction.update(seriesRef, {
            winnerId == p1 ? 'p1Wins' : 'p2Wins': FieldValue.increment(1),
          });
        }
      }
    });
  }

  Stream<Map<String, dynamic>?> streamSeriesStats(String p1, String p2) {
    final id1 = p1.compareTo(p2) < 0 ? p1 : p2;
    final id2 = p1.compareTo(p2) < 0 ? p2 : p1;
    final seriesId = '${id1}_${id2}';

    return _firestore.collection('series').doc(seriesId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }

  Stream<AppUser?> streamUser(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> toggleFriend(String myId, String friendId) async {
    final myRef = _firestore.collection('users').doc(myId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(myRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final friends = List<String>.from(data['friends'] ?? []);
      
      if (friends.contains(friendId)) {
        friends.remove(friendId);
      } else {
        friends.add(friendId);
      }
      
      transaction.update(myRef, {'friends': friends});
    });
  }

  Future<void> updateLastActive(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppUser>> streamUsersByIds(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);
    // Chunking for whereIn limit of 10
    final chunks = <List<String>>[];
    for (var i = 0; i < userIds.length; i += 10) {
      chunks.add(userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10));
    }
    
    // Combine streams (simple implementation for first chunk only for now to avoid complexity without rxdart)
    // Real production app would use Rx.combineLatest or similar.
    // For now, we just return the first 10 friends.
    return _firestore.collection('users')
        .where(FieldPath.documentId, whereIn: chunks.first)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AppUser.fromMap(d.data(), d.id)).toList());
  }
  
  Future<List<AppUser>> searchUsers(String usernameQuery) async {
    // Simple prefix search
    if (usernameQuery.isEmpty) return [];
    
    final snapshot = await _firestore.collection('users')
        .where('username', isGreaterThanOrEqualTo: usernameQuery)
        .where('username', isLessThan: '${usernameQuery}z')
        .limit(20)
        .get();
        
    return snapshot.docs.map((doc) => AppUser.fromMap(doc.data(), doc.id)).toList();
  }
}
