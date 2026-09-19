class GameSettings {
  final int timeLimitSeconds; // 0 for no limit
  final bool isPrivate;
  final int playerCount;

  /// Optional label so players can tell one match from another.
  final String? name;

  GameSettings({
    this.timeLimitSeconds = 60,
    this.isPrivate = false,
    this.playerCount = 2,
    this.name,
  });

  int get seats {
    if (playerCount == 4) return 4;
    if (playerCount == 3) return 3;
    return 2;
  }

  Map<String, dynamic> toMap() {
    return {
      'timeLimitSeconds': timeLimitSeconds,
      'isPrivate': isPrivate,
      'playerCount': seats,
      if (name != null) 'name': name,
    };
  }

  factory GameSettings.fromMap(Map<String, dynamic> map) {
    final raw = map['playerCount'] ?? 2;
    final count = raw is int ? raw : int.tryParse('$raw') ?? 2;
    return GameSettings(
      timeLimitSeconds: map['timeLimitSeconds'] ?? 60,
      isPrivate: map['isPrivate'] ?? false,
      playerCount: (count == 3 || count == 4) ? count : 2,
      name: map['name'],
    );
  }

  String get displayName => name?.isNotEmpty == true ? name! : 'Quoridor match';

  String get clockLabel {
    if (timeLimitSeconds == 0) return 'No time limit';
    if (timeLimitSeconds % 60 == 0) return '${timeLimitSeconds ~/ 60} min per move';
    return '${timeLimitSeconds}s per move';
  }

  String get seatsLabel {
    switch (seats) {
      case 4:
        return '4 players';
      case 3:
        return '3 players';
      default:
        return '2 players';
    }
  }
}

class GameModel {
  final String id;
  final String hostId;
  final String? invitedUserId;
  final List<String> playerIds; // UIDs
  final String status; // 'waiting', 'playing', 'finished'
  final GameSettings settings;
  final String? winnerId;
  final int currentTurnIndex;
  // Game State
  final Map<String, dynamic> gameState; 
  final List<Map<String, dynamic>> moveLog;
  final List<String> rematchRequests;

  /// Wins at this table across rematches. Survives a rematch reset.
  final Map<String, int> sessionWins;
  final List<String> recordedBy;

  /// Server time the current turn began, used to run the per-move clock.
  final DateTime? turnStartedAt;

  /// Players who walked away. They keep their pawn on the board as an
  /// obstacle but are skipped in the turn order.
  final List<String> resignedIds;

  GameModel({
    required this.id,
    required this.hostId,
    this.invitedUserId,
    required this.playerIds,
    required this.status,
    required this.settings,
    this.winnerId,
    this.currentTurnIndex = 0,
    required this.gameState,
    this.moveLog = const [],
    this.rematchRequests = const [],
    this.sessionWins = const {},
    this.recordedBy = const [],
    this.turnStartedAt,
    this.resignedIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      if (invitedUserId != null) 'invitedUserId': invitedUserId,
      'playerIds': playerIds,
      'status': status,
      'settings': settings.toMap(),
      'winnerId': winnerId,
      'currentTurnIndex': currentTurnIndex,
      'gameState': gameState,
      'moveLog': moveLog,
      'rematchRequests': rematchRequests,
      'sessionWins': sessionWins,
      'recordedBy': recordedBy,
      'resignedIds': resignedIds,
    };
  }

  factory GameModel.fromMap(Map<String, dynamic> map, String id) {
    return GameModel(
      id: id,
      hostId: map['hostId'] ?? '',
      invitedUserId: map['invitedUserId'],
      playerIds: List<String>.from(map['playerIds'] ?? []),
      status: map['status'] ?? 'waiting',
      settings: GameSettings.fromMap(map['settings'] ?? {}),
      winnerId: map['winnerId'],
      currentTurnIndex: map['currentTurnIndex'] ?? 0,
      gameState: map['gameState'] ?? {},
      moveLog: List<Map<String, dynamic>>.from(map['moveLog'] ?? []),
      rematchRequests: List<String>.from(map['rematchRequests'] ?? []),
      sessionWins: _intMap(map['sessionWins']),
      recordedBy: List<String>.from(map['recordedBy'] ?? []),
      turnStartedAt: _dateTime(map['turnStartedAt']),
      resignedIds: List<String>.from(map['resignedIds'] ?? []),
    );
  }

  int get sessionGames =>
      sessionWins.values.fold<int>(0, (sum, n) => sum + n);

  int sessionWinsFor(String playerId) => sessionWins[playerId] ?? 0;

  int sessionLossesFor(String playerId) =>
      (sessionGames - sessionWinsFor(playerId)).clamp(0, sessionGames);

  bool hasResigned(String playerId) => resignedIds.contains(playerId);

  /// Seats to skip in the turn order.
  Set<int> get resignedSeats => {
        for (var i = 0; i < playerIds.length; i++)
          if (resignedIds.contains(playerIds[i])) i,
      };

  List<String> get activePlayerIds =>
      [for (final id in playerIds) if (!resignedIds.contains(id)) id];
}

/// Lifetime head-to-head pulled from a `series/{id1_id2}` document.
class HeadToHead {
  final int myWins;
  final int theirWins;

  const HeadToHead({this.myWins = 0, this.theirWins = 0});

  factory HeadToHead.fromSeries(Map<String, dynamic>? data, String myId) {
    if (data == null) return const HeadToHead();
    final p1 = data['player1Id'];
    final p1Wins = (data['p1Wins'] as num?)?.toInt() ?? 0;
    final p2Wins = (data['p2Wins'] as num?)?.toInt() ?? 0;
    if (myId == p1) {
      return HeadToHead(myWins: p1Wins, theirWins: p2Wins);
    }
    return HeadToHead(myWins: p2Wins, theirWins: p1Wins);
  }

  String get scoreLabel => '$myWins–$theirWins';
}

String afterActionPlayerName(String? username, {required bool isYou}) {
  final base =
      (username != null && username.trim().isNotEmpty) ? username.trim() : 'Guest';
  return isYou ? '$base (You)' : base;
}

/// Accepts a Firestore `Timestamp` without dragging the plugin into the
/// models, so this layer stays testable on the Dart VM.
DateTime? _dateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  try {
    final converted = (raw as dynamic).toDate();
    return converted is DateTime ? converted : null;
  } catch (_) {
    return null;
  }
}

Map<String, int> _intMap(dynamic raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
  };
}
