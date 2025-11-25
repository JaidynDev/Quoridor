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

    // 1. Update Game Status (Priority)
    await _firestore.runTransaction((transaction) async {
      final gameSnapshot = await transaction.get(gameRef);
      if (!gameSnapshot.exists) throw Exception("Game not found");

      final gameData = gameSnapshot.data()!;
      if (gameData['status'] == 'finished') return; // Already finished

      transaction.update(gameRef, {
        'status': 'finished',
        'winnerId': winnerId,
      });
    });

    // 2. Update User Stats (Best Effort)
    // We do this outside the game transaction so a permission error here doesn't stop the game from ending.
    try {
      final gameSnapshot = await gameRef.get();
      final gameData = gameSnapshot.data()!;
      final playerIds = List<String>.from(gameData['playerIds']);
      
      String? loserId;
      if (playerIds.contains(winnerId)) {
        loserId = playerIds.firstWhere((id) => id != winnerId, orElse: () => '');
      }

      // Update Winner Stats
      await _firestore.collection('users').doc(winnerId).set({
        'wins': FieldValue.increment(1),
      }, SetOptions(merge: true)).catchError((e) => print("Error updating winner stats: $e"));

      // Update Loser Stats (Only if permissions allow, otherwise this might fail silently on client)
      if (loserId != null && loserId.isNotEmpty) {
        await _firestore.collection('users').doc(loserId).set({
          'losses': FieldValue.increment(1),
        }, SetOptions(merge: true)).catchError((e) => print("Error updating loser stats: $e"));

        // Update Series Stats (Shared document, usually allowed if public/shared)
        final p1 = winnerId.compareTo(loserId) < 0 ? winnerId : loserId;
        final p2 = winnerId.compareTo(loserId) < 0 ? loserId : winnerId;
        final seriesId = '${p1}_${p2}';
        final seriesRef = _firestore.collection('series').doc(seriesId);

        await _firestore.runTransaction((t) async {
           final sSnap = await t.get(seriesRef);
           if (!sSnap.exists) {
             t.set(seriesRef, {
               'player1Id': p1,
               'player2Id': p2,
               'p1Wins': winnerId == p1 ? 1 : 0,
               'p2Wins': winnerId == p2 ? 1 : 0,
             });
           } else {
             t.update(seriesRef, {
               winnerId == p1 ? 'p1Wins' : 'p2Wins': FieldValue.increment(1),
             });
           }
        }).catchError((e) => print("Error updating series stats: $e"));
      }
    } catch (e) {
      print("Error in stats update: $e");
    }
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

  Future<void> sendFriendRequest(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) return;
    
    // Check if already friends or requested
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    
    await _firestore.runTransaction((transaction) async {
       final targetSnap = await transaction.get(targetUserRef);
       if (!targetSnap.exists) throw Exception("User not found");
       
       final targetData = targetSnap.data()!;
       final friends = List<String>.from(targetData['friends'] ?? []);
       if (friends.contains(currentUserId)) return; // Already friends

       // Create request
       final requestRef = _firestore.collection('users').doc(targetUserId).collection('friend_requests').doc(currentUserId);
       transaction.set(requestRef, {
         'fromId': currentUserId,
         'timestamp': FieldValue.serverTimestamp(),
       });
    });
  }

  Future<void> acceptFriendRequest(String currentUserId, String fromUserId) async {
    final myRef = _firestore.collection('users').doc(currentUserId);
    final fromRef = _firestore.collection('users').doc(fromUserId);
    final requestRef = myRef.collection('friend_requests').doc(fromUserId);

    await _firestore.runTransaction((transaction) async {
      // Get current data
      final mySnap = await transaction.get(myRef);
      final fromSnap = await transaction.get(fromRef);
      
      if (!mySnap.exists || !fromSnap.exists) return;

      // Add to friends list for BOTH
      transaction.update(myRef, {
        'friends': FieldValue.arrayUnion([fromUserId])
      });
      transaction.update(fromRef, {
        'friends': FieldValue.arrayUnion([currentUserId])
      });
      
      // Delete request
      transaction.delete(requestRef);
    });
  }

  Future<void> declineFriendRequest(String currentUserId, String fromUserId) async {
    await _firestore.collection('users').doc(currentUserId).collection('friend_requests').doc(fromUserId).delete();
  }

  Future<void> removeFriend(String currentUserId, String friendId) async {
    final myRef = _firestore.collection('users').doc(currentUserId);
    final friendRef = _firestore.collection('users').doc(friendId);

    await _firestore.runTransaction((transaction) async {
      transaction.update(myRef, {
        'friends': FieldValue.arrayRemove([friendId])
      });
      transaction.update(friendRef, {
        'friends': FieldValue.arrayRemove([currentUserId])
      });
    });
  }

  Stream<List<String>> streamFriendRequests(String userId) {
    return _firestore.collection('users').doc(userId).collection('friend_requests')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
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
