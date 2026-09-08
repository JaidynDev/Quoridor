import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import '../models/match_flow.dart';
import '../models/quoridor_logic.dart';
import '../models/user_model.dart';
import 'guest_service.dart';

class DatabaseService {
  // Resolved on first use so widget tests can subclass this without a live
  // Firebase app in the background.
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createGame(
    String hostId,
    GameSettings settings, {
    String? invitedUserId,
  }) async {
    final docRef = _firestore.collection('games').doc();
    final game = GameModel(
      id: docRef.id,
      hostId: hostId,
      invitedUserId: invitedUserId,
      playerIds: [hostId],
      status: 'waiting',
      settings: settings,
      gameState: QuoridorLogic.initialState(settings.seats),
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
      if (game.playerIds.length >= game.settings.seats) {
        throw Exception("Game is full");
      }

      final nextIds = [...game.playerIds, userId];
      final starting = nextIds.length >= game.settings.seats;
      transaction.update(docRef, {
        'playerIds': FieldValue.arrayUnion([userId]),
        'status': starting ? 'playing' : 'waiting',
        // The first clock only starts once every seat is filled.
        if (starting) 'turnStartedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<GameModel>> streamIncomingInvites(String userId) {
    return _firestore
        .collection('games')
        .where('invitedUserId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GameModel.fromMap(d.data(), d.id))
            .where((g) => g.status == 'waiting')
            .toList());
  }

  Future<void> declineGameInvite(String gameId) async {
    await _firestore.collection('games').doc(gameId).update({
      'invitedUserId': FieldValue.delete(),
    });
  }

  Stream<GameModel?> streamGame(String gameId) {
    return _firestore.collection('games').doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GameModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> updateGameState(String gameId, Map<String, dynamic> newState, int nextTurn, {Map<String, dynamic>? logEntry}) async {
    final updates = <String, dynamic>{
      'gameState': newState,
      'currentTurnIndex': nextTurn,
      'turnStartedAt': FieldValue.serverTimestamp(),
    };
    
    if (logEntry != null) {
      updates['moveLog'] = FieldValue.arrayUnion([logEntry]);
    }

    await _firestore.collection('games').doc(gameId).update(updates);
  }
  
  /// Takes a player out of the running. The others play on, unless only one
  /// of them is left, in which case they take the win.
  Future<void> resign(String gameId, String userId) async {
    if (userId.isEmpty) return;
    final gameRef = _firestore.collection('games').doc(gameId);

    final outcome = await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      if (!snapshot.exists) return ResignationOutcome.noop;

      final data = snapshot.data()!;
      if (data['status'] == 'finished') return ResignationOutcome.noop;

      final result = resolveResignation(
        playerIds: List<String>.from(data['playerIds'] ?? []),
        resignedIds: List<String>.from(data['resignedIds'] ?? []),
        resignerId: userId,
        currentTurnIndex: data['currentTurnIndex'] ?? 0,
      );
      if (!result.changed) return result;

      transaction.update(gameRef, {
        'resignedIds': result.resignedIds,
        'currentTurnIndex': result.nextTurnIndex,
        'turnStartedAt': FieldValue.serverTimestamp(),
        'moveLog': FieldValue.arrayUnion([
          {
            'playerId': userId,
            'type': 'resign',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }
        ]),
      });
      return result;
    });

    final winnerId = outcome.winnerId;
    if (outcome.changed && winnerId != null) {
      await setWinner(gameId, winnerId);
    }
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
        'sessionWins.$winnerId': FieldValue.increment(1),
        'recordedBy': [],
      });
    });

    // Lifetime head-to-head: this winner beat each other player at the table.
    try {
      final gameSnapshot = await gameRef.get();
      final gameData = gameSnapshot.data()!;
      final playerIds = List<String>.from(gameData['playerIds']);
      final losers = playerIds.where((id) => id != winnerId);

      for (final loserId in losers) {
        await _bumpSeries(winnerId, loserId);
      }
    } catch (e) {
      print("Error in stats update: $e");
    }
  }

  Future<void> _bumpSeries(String winnerId, String loserId) async {
    final p1 = winnerId.compareTo(loserId) < 0 ? winnerId : loserId;
    final p2 = winnerId.compareTo(loserId) < 0 ? loserId : winnerId;
    final seriesRef = _firestore.collection('series').doc('${p1}_$p2');

    await _firestore.runTransaction((t) async {
      final snap = await t.get(seriesRef);
      if (!snap.exists) {
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
    });
  }

  /// Each player applies their own career W/L so Firestore user rules hold.
  Future<void> recordPersonalResult(String gameId, String userId) async {
    if (userId.isEmpty) return;
    final gameRef = _firestore.collection('games').doc(gameId);

    final shouldWrite = await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(gameRef);
      if (!snap.exists) return false;
      final data = snap.data()!;
      if (data['status'] != 'finished') return false;
      final recorded = List<String>.from(data['recordedBy'] ?? []);
      if (recorded.contains(userId)) return false;
      transaction.update(gameRef, {
        'recordedBy': FieldValue.arrayUnion([userId]),
      });
      return true;
    });

    if (shouldWrite != true) return;

    final gameSnap = await gameRef.get();
    final winnerId = gameSnap.data()?['winnerId'] as String?;
    final won = winnerId == userId;

    if (userId.startsWith('guest_')) {
      final prefs = await SharedPreferences.getInstance();
      final key = won ? GuestService.guestWinsKey : GuestService.guestLossesKey;
      await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
      return;
    }

    await _firestore.collection('users').doc(userId).set({
      won ? 'wins' : 'losses': FieldValue.increment(1),
    }, SetOptions(merge: true));
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

  Stream<AppUser?> streamUser(String userId) async* {
    if (userId.startsWith('guest_')) {
      yield await _localGuestProfile(userId);
      return;
    }
    
    // For authenticated users, fetch from Firestore
    yield* _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> sendFriendRequest(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) return;
    if (currentUserId.startsWith('guest_')) {
      throw Exception('Sign in to send friend requests.');
    }
    
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

  Stream<List<AppUser>> streamUsersByIds(List<String> userIds) async* {
    if (userIds.isEmpty) {
      yield [];
      return;
    }
    
    // Separate guest users from authenticated users
    final guestIds = userIds.where((id) => id.startsWith('guest_')).toList();
    final authIds = userIds.where((id) => !id.startsWith('guest_')).toList();
    
    final users = <AppUser>[];
    
    if (guestIds.isNotEmpty) {
      for (final guestId in guestIds) {
        users.add(await _localGuestProfile(guestId));
      }
    }
    
    // Fetch authenticated users from Firestore
    if (authIds.isNotEmpty) {
      // Chunking for whereIn limit of 10
      final chunks = <List<String>>[];
      for (var i = 0; i < authIds.length; i += 10) {
        chunks.add(authIds.sublist(i, i + 10 > authIds.length ? authIds.length : i + 10));
      }
      
      // For now, just return the first 10 authenticated users
      if (chunks.isNotEmpty) {
        await for (final snap in _firestore.collection('users')
            .where(FieldPath.documentId, whereIn: chunks.first)
            .snapshots()) {
          final authUsers = snap.docs.map((d) => AppUser.fromMap(d.data(), d.id)).toList();
          yield [...users, ...authUsers];
        }
      } else {
        yield users;
      }
    } else {
      yield users;
    }
  }
  
  Future<void> requestRematch(String gameId, String userId) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      if (!snapshot.exists) return;
      
      final data = snapshot.data()!;
      final playerIds = List<String>.from(data['playerIds'] ?? []);
      final rematchRequests = List<String>.from(data['rematchRequests'] ?? []);
      
      if (!rematchRequests.contains(userId)) {
        rematchRequests.add(userId);
      }
      
      // Check if all players requested
      bool allRequested = playerIds.isNotEmpty && playerIds.every((id) => rematchRequests.contains(id));
      
      if (allRequested) {
        final settings = GameSettings.fromMap(
          Map<String, dynamic>.from(data['settings'] ?? {}),
        );
        transaction.update(gameRef, {
          'status': 'playing',
          'winnerId': null,
          'currentTurnIndex': 0,
          'gameState': QuoridorLogic.initialState(settings.seats),
          'rematchRequests': [],
          'moveLog': [],
          'recordedBy': [],
          'resignedIds': [],
          'turnStartedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Just update requests
        transaction.update(gameRef, {
          'rematchRequests': rematchRequests,
        });
      }
    });
  }

  Future<List<AppUser>> searchUsers(String usernameQuery) async {
    // Simple prefix search
    if (usernameQuery.isEmpty) return [];
    
    final snapshot = await _firestore.collection('users')
        .where('username', isGreaterThanOrEqualTo: usernameQuery)
        .where('username', isLessThan: '${usernameQuery}z')
        .limit(20)
        .get();
        
    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .where((user) => !user.isGuest)
        .toList();
  }

  /// Device-local `guest_*` ids only carry stats for *this* browser.
  /// Other guests at the table stay anonymous placeholders.
  Future<AppUser> _localGuestProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final isLocal = prefs.getString('guest_id') == userId;
    return AppUser(
      id: userId,
      email: '',
      username: isLocal ? (prefs.getString('guest_username') ?? 'Guest') : 'Guest',
      photoUrl: isLocal ? prefs.getString('guest_photo_url') : null,
      wins: isLocal ? (prefs.getInt(GuestService.guestWinsKey) ?? 0) : 0,
      losses: isLocal ? (prefs.getInt(GuestService.guestLossesKey) ?? 0) : 0,
      isGuest: true,
    );
  }
}
