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

  int get seats => playerCount == 4 ? 4 : 2;

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
    return GameSettings(
      timeLimitSeconds: map['timeLimitSeconds'] ?? 60,
      isPrivate: map['isPrivate'] ?? false,
      playerCount: raw == 4 ? 4 : 2,
      name: map['name'],
    );
  }

  String get displayName => name?.isNotEmpty == true ? name! : 'Quoridor match';

  String get clockLabel {
    if (timeLimitSeconds == 0) return 'No time limit';
    if (timeLimitSeconds % 60 == 0) return '${timeLimitSeconds ~/ 60} min per move';
    return '${timeLimitSeconds}s per move';
  }

  String get seatsLabel => seats == 4 ? '4 players' : '2 players';
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
    );
  }

  int get sessionGames =>
      sessionWins.values.fold<int>(0, (sum, n) => sum + n);

  int sessionWinsFor(String playerId) => sessionWins[playerId] ?? 0;

  int sessionLossesFor(String playerId) =>
      (sessionGames - sessionWinsFor(playerId)).clamp(0, sessionGames);
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

Map<String, int> _intMap(dynamic raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
  };
}
