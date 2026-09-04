class GameSettings {
  final int timeLimitSeconds; // 0 for no limit
  final bool isPrivate;

  /// Optional label so players can tell one match from another.
  final String? name;

  GameSettings({
    this.timeLimitSeconds = 60,
    this.isPrivate = false,
    this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'timeLimitSeconds': timeLimitSeconds,
      'isPrivate': isPrivate,
      if (name != null) 'name': name,
    };
  }

  factory GameSettings.fromMap(Map<String, dynamic> map) {
    return GameSettings(
      timeLimitSeconds: map['timeLimitSeconds'] ?? 60,
      isPrivate: map['isPrivate'] ?? false,
      name: map['name'],
    );
  }

  String get displayName => name?.isNotEmpty == true ? name! : 'Quoridor match';

  String get clockLabel {
    if (timeLimitSeconds == 0) return 'No time limit';
    if (timeLimitSeconds % 60 == 0) return '${timeLimitSeconds ~/ 60} min per move';
    return '${timeLimitSeconds}s per move';
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
  final int currentTurnIndex; // 0 or 1
  // Game State
  final Map<String, dynamic> gameState; 
  final List<Map<String, dynamic>> moveLog;
  final List<String> rematchRequests;

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
    );
  }
}
