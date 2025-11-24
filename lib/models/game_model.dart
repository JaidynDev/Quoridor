class GameSettings {
  final int timeLimitSeconds; // 0 for no limit
  final bool isPrivate;

  GameSettings({this.timeLimitSeconds = 60, this.isPrivate = false});

  Map<String, dynamic> toMap() {
    return {
      'timeLimitSeconds': timeLimitSeconds,
      'isPrivate': isPrivate,
    };
  }

  factory GameSettings.fromMap(Map<String, dynamic> map) {
    return GameSettings(
      timeLimitSeconds: map['timeLimitSeconds'] ?? 60,
      isPrivate: map['isPrivate'] ?? false,
    );
  }
}

class GameModel {
  final String id;
  final String hostId;
  final List<String> playerIds; // UIDs
  final String status; // 'waiting', 'playing', 'finished'
  final GameSettings settings;
  final String? winnerId;
  final int currentTurnIndex; // 0 or 1
  // Game State
  // For simplicity, we'll store the last move or full state. 
  // In Quoridor: Player positions, Wall positions.
  final Map<String, dynamic> gameState; 

  GameModel({
    required this.id,
    required this.hostId,
    required this.playerIds,
    required this.status,
    required this.settings,
    this.winnerId,
    this.currentTurnIndex = 0,
    required this.gameState,
  });

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'playerIds': playerIds,
      'status': status,
      'settings': settings.toMap(),
      'winnerId': winnerId,
      'currentTurnIndex': currentTurnIndex,
      'gameState': gameState,
    };
  }

  factory GameModel.fromMap(Map<String, dynamic> map, String id) {
    return GameModel(
      id: id,
      hostId: map['hostId'] ?? '',
      playerIds: List<String>.from(map['playerIds'] ?? []),
      status: map['status'] ?? 'waiting',
      settings: GameSettings.fromMap(map['settings'] ?? {}),
      winnerId: map['winnerId'],
      currentTurnIndex: map['currentTurnIndex'] ?? 0,
      gameState: map['gameState'] ?? {},
    );
  }
}
