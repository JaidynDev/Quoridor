import 'dart:collection';

class Position {
  final int x;
  final int y;
  const Position(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is Position && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  Map<String, int> toMap() => {'x': x, 'y': y};

  factory Position.fromMap(Map<String, dynamic> map) =>
      Position(map['x'] as int, map['y'] as int);
}

class Wall {
  final int x; // 0..7
  final int y; // 0..7
  final int orientation; // 0: Horizontal, 1: Vertical

  const Wall(this.x, this.y, this.orientation);

  @override
  bool operator ==(Object other) =>
      other is Wall && other.x == x && other.y == y && other.orientation == orientation;

  @override
  int get hashCode => Object.hash(x, y, orientation);
}

/// One seat around the table. Index 0 sits south and looks up the board.
class PlayerSeat {
  final Position start;
  final bool goalIsY;
  final int goalValue;
  final String side;

  /// Quarter-turns so this player's own edge sits nearest the camera.
  final int cameraRotation;

  const PlayerSeat({
    required this.start,
    required this.goalIsY,
    required this.goalValue,
    required this.side,
    required this.cameraRotation,
  });

  bool reachedGoal(Position pawn) =>
      goalIsY ? pawn.y == goalValue : pawn.x == goalValue;
}

class QuoridorLogic {
  static const int boardSize = 9;

  static const List<PlayerSeat> twoPlayerSeats = [
    PlayerSeat(
      start: Position(4, 0),
      goalIsY: true,
      goalValue: 8,
      side: 'South',
      cameraRotation: 0,
    ),
    PlayerSeat(
      start: Position(4, 8),
      goalIsY: true,
      goalValue: 0,
      side: 'North',
      cameraRotation: 2,
    ),
  ];

  /// South, east, north, west — clockwise around the table.
  static const List<PlayerSeat> fourPlayerSeats = [
    PlayerSeat(
      start: Position(4, 0),
      goalIsY: true,
      goalValue: 8,
      side: 'South',
      cameraRotation: 0,
    ),
    PlayerSeat(
      start: Position(8, 4),
      goalIsY: false,
      goalValue: 0,
      side: 'East',
      cameraRotation: 1,
    ),
    PlayerSeat(
      start: Position(4, 8),
      goalIsY: true,
      goalValue: 0,
      side: 'North',
      cameraRotation: 2,
    ),
    PlayerSeat(
      start: Position(0, 4),
      goalIsY: false,
      goalValue: 8,
      side: 'West',
      cameraRotation: 3,
    ),
  ];

  /// South, east, north — west stays empty, matching the usual 3-player layout.
  static List<PlayerSeat> get threePlayerSeats =>
      fourPlayerSeats.sublist(0, 3);

  static List<PlayerSeat> seatsFor(int playerCount) {
    switch (playerCount) {
      case 4:
        return fourPlayerSeats;
      case 3:
        return threePlayerSeats;
      default:
        return twoPlayerSeats;
    }
  }

  static int wallsEach(int playerCount) {
    switch (playerCount) {
      case 4:
        return 5;
      case 3:
        return 6;
      default:
        return 10;
    }
  }

  static String sideLabel(int seatIndex, int playerCount) {
    final seats = seatsFor(playerCount);
    if (seatIndex < 0 || seatIndex >= seats.length) return 'Seat';
    return seats[seatIndex].side;
  }

  static String pawnKey(int index) => 'p${index + 1}';
  static String wallsKey(int index) => 'p${index + 1}WallsLeft';

  static Map<String, dynamic> initialState(int playerCount) {
    final seats = seatsFor(playerCount);
    final walls = wallsEach(playerCount);
    final state = <String, dynamic>{'walls': []};
    for (var i = 0; i < seats.length; i++) {
      state[pawnKey(i)] = seats[i].start.toMap();
      state[wallsKey(i)] = walls;
    }
    return state;
  }

  static Position pawnAt(Map<String, dynamic> state, int index) {
    final raw = state[pawnKey(index)];
    if (raw is Map) {
      return Position.fromMap(Map<String, dynamic>.from(raw));
    }
    final seats = seatsFor(index >= 3 ? 4 : (index >= 2 ? 3 : 2));
    return seats[index.clamp(0, seats.length - 1)].start;
  }

  static List<Position> pawnsFromState(Map<String, dynamic> state, int playerCount) {
    return [
      for (var i = 0; i < playerCount; i++) pawnAt(state, i),
    ];
  }

  /// Next seat that is still playing, skipping anyone who walked away.
  /// Falls back to [from] when nobody else is left.
  static int nextActiveSeat(int from, int seats, {Set<int> out = const {}}) {
    if (seats <= 0) return from;
    for (var step = 1; step <= seats; step++) {
      final candidate = (from + step) % seats;
      if (!out.contains(candidate)) return candidate;
    }
    return from;
  }

  /// The step a shortest route to this seat's goal would take, used when a
  /// player's clock runs out. Null only if every neighbour is unreachable.
  static Position? stepTowardGoal(
    Position from,
    List<Wall> walls,
    List<Position> others,
    PlayerSeat seat,
  ) {
    final legal = getValidMoves(from, walls, others);
    if (legal.isEmpty) return null;

    final distances = _goalDistances(seat, walls);
    Position? best;
    int? bestDistance;

    for (final move in legal) {
      final distance = distances[move];
      if (distance == null) continue;
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        best = move;
      }
    }

    // Every legal step walled off from the goal should be impossible, but
    // moving beats stalling the table if it ever happens.
    return best ?? legal.first;
  }

  /// Breadth-first sweep out from the goal row, ignoring pawns.
  static Map<Position, int> _goalDistances(PlayerSeat seat, List<Wall> walls) {
    final distances = <Position, int>{};
    final queue = Queue<Position>();

    for (var i = 0; i < boardSize; i++) {
      final cell = seat.goalIsY
          ? Position(i, seat.goalValue)
          : Position(seat.goalValue, i);
      distances[cell] = 0;
      queue.add(cell);
    }

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final next = distances[current]! + 1;
      for (final neighbor in getValidMoves(current, walls, const [],
          ignoreOtherPlayers: true)) {
        if (distances.containsKey(neighbor)) continue;
        distances[neighbor] = next;
        queue.add(neighbor);
      }
    }

    return distances;
  }

  static bool isValidWall(
    Wall newWall,
    List<Wall> existingWalls,
    List<Position> pawns,
    List<PlayerSeat> seats,
  ) {
    if (newWall.x < 0 ||
        newWall.x >= boardSize - 1 ||
        newWall.y < 0 ||
        newWall.y >= boardSize - 1) {
      return false;
    }

    for (final w in existingWalls) {
      if (w.x == newWall.x && w.y == newWall.y) return false;
      if (w.orientation == newWall.orientation) {
        if (newWall.orientation == 0) {
          if (w.y == newWall.y && (w.x - newWall.x).abs() <= 1) return false;
        } else {
          if (w.x == newWall.x && (w.y - newWall.y).abs() <= 1) return false;
        }
      }
    }

    final updatedWalls = [...existingWalls, newWall];
    for (var i = 0; i < pawns.length && i < seats.length; i++) {
      if (!hasPath(pawns[i], seats[i], updatedWalls)) return false;
    }
    return true;
  }

  static bool hasPath(Position start, PlayerSeat seat, List<Wall> walls) {
    final queue = Queue<Position>();
    queue.add(start);
    final visited = <Position>{start};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (seat.reachedGoal(current)) return true;

      for (final neighbor in getValidMoves(current, walls, const [],
          ignoreOtherPlayers: true)) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add(neighbor);
        }
      }
    }
    return false;
  }

  static List<Position> getValidMoves(
    Position current,
    List<Wall> walls,
    List<Position> otherPlayers, {
    bool ignoreOtherPlayers = false,
  }) {
    final moves = <Position>[];
    final dirs = [
      const Position(0, 1),
      const Position(0, -1),
      const Position(1, 0),
      const Position(-1, 0),
    ];

    bool occupied(Position p) => otherPlayers.any((o) => o == p);

    for (final dir in dirs) {
      final next = Position(current.x + dir.x, current.y + dir.y);

      if (next.x < 0 || next.x >= boardSize || next.y < 0 || next.y >= boardSize) {
        continue;
      }
      if (isBlocked(current, next, walls)) continue;

      if (!ignoreOtherPlayers && occupied(next)) {
        final jump = Position(next.x + dir.x, next.y + dir.y);
        var canJumpStraight = jump.x >= 0 &&
            jump.x < boardSize &&
            jump.y >= 0 &&
            jump.y < boardSize &&
            !isBlocked(next, jump, walls) &&
            !occupied(jump);

        if (canJumpStraight) {
          moves.add(jump);
        } else {
          final diagonals = dir.x == 0
              ? [Position(next.x - 1, next.y), Position(next.x + 1, next.y)]
              : [Position(next.x, next.y - 1), Position(next.x, next.y + 1)];

          for (final diag in diagonals) {
            if (diag.x < 0 ||
                diag.x >= boardSize ||
                diag.y < 0 ||
                diag.y >= boardSize) {
              continue;
            }
            if (isBlocked(next, diag, walls)) continue;
            if (occupied(diag)) continue;
            moves.add(diag);
          }
        }
        continue;
      }

      moves.add(next);
    }

    return moves;
  }

  static bool isBlocked(Position from, Position to, List<Wall> walls) {
    for (final wall in walls) {
      if (wall.orientation == 0) {
        if (from.x == to.x && (from.x == wall.x || from.x == wall.x + 1)) {
          if ((from.y == wall.y && to.y == wall.y + 1) ||
              (from.y == wall.y + 1 && to.y == wall.y)) {
            return true;
          }
        }
      } else {
        if (from.y == to.y && (from.y == wall.y || from.y == wall.y + 1)) {
          if ((from.x == wall.x && to.x == wall.x + 1) ||
              (from.x == wall.x + 1 && to.x == wall.x)) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
