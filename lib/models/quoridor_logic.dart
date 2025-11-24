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

class QuoridorLogic {
  static const int boardSize = 9;

  static bool isValidWall(Wall newWall, List<Wall> existingWalls, Position p1, Position p2) {
    // Check bounds
    if (newWall.x < 0 || newWall.x >= boardSize - 1 || newWall.y < 0 || newWall.y >= boardSize - 1) return false;

    // Check overlap/intersect
    for (final w in existingWalls) {
      if (w.x == newWall.x && w.y == newWall.y) return false; // Same center
      if (w.orientation == newWall.orientation) {
         // Overlap if horizontal and same y, and x diff <= 1
         // Or vertical and same x, and y diff <= 1
         if (newWall.orientation == 0) { // Horizontal
            if (w.y == newWall.y && (w.x - newWall.x).abs() <= 1) return false; // Overlap
         } else { // Vertical
            if (w.x == newWall.x && (w.y - newWall.y).abs() <= 1) return false; // Overlap
         }
      }
      // Note: Crossing walls (H and V at same center) is allowed in some rules?
      // Standard rules: Walls cannot cross.
      // If different orientation and same center, they cross.
      if (w.x == newWall.x && w.y == newWall.y) return false; 
    }

    // Check paths
    // Temporarily add wall
    final updatedWalls = [...existingWalls, newWall];
    if (!hasPath(p1, 8, updatedWalls)) return false; // P1 goal y=8
    if (!hasPath(p2, 0, updatedWalls)) return false; // P2 goal y=0

    return true;
  }

  static bool hasPath(Position start, int goalY, List<Wall> walls) {
    final queue = Queue<Position>();
    queue.add(start);
    final visited = <Position>{start};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.y == goalY) return true;

      for (final neighbor in getValidMoves(current, walls, [], ignoreOtherPlayers: true)) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add(neighbor);
        }
      }
    }
    return false;
  }

  static List<Position> getValidMoves(Position current, List<Wall> walls, List<Position> otherPlayers, {bool ignoreOtherPlayers = false}) {
    final moves = <Position>[];
    final dirs = [
      const Position(0, 1), // Down
      const Position(0, -1), // Up
      const Position(1, 0), // Right
      const Position(-1, 0), // Left
    ];

    for (final dir in dirs) {
      final next = Position(current.x + dir.x, current.y + dir.y);
      
      // Check bounds
      if (next.x < 0 || next.x >= boardSize || next.y < 0 || next.y >= boardSize) continue;

      // Check walls
      if (isBlocked(current, next, walls)) continue;

      // Check opponent
      if (!ignoreOtherPlayers) {
         bool occupied = false;
         for (final p in otherPlayers) {
           if (p == next) occupied = true;
         }
         
         if (occupied) {
           // Jump
           final jump = Position(next.x + dir.x, next.y + dir.y);
           bool canJumpStraight = true;
           
           // Check bounds for jump
           if (jump.x < 0 || jump.x >= boardSize || jump.y < 0 || jump.y >= boardSize) canJumpStraight = false;
           // Check wall behind opponent
           if (canJumpStraight && isBlocked(next, jump, walls)) canJumpStraight = false;
           // Check if jump position occupied (rare in 4p, impossible in 2p)
           
           if (canJumpStraight) {
             moves.add(jump);
           } else {
             // Diagonal jumps
             // If blocked straight, can move diagonal relative to opponent
             // Left/Right relative to direction
             final diagonals = <Position>[];
             if (dir.x == 0) { // Moving vertical
               diagonals.add(Position(next.x - 1, next.y));
               diagonals.add(Position(next.x + 1, next.y));
             } else { // Moving horizontal
               diagonals.add(Position(next.x, next.y - 1));
               diagonals.add(Position(next.x, next.y + 1));
             }
             
             for (final diag in diagonals) {
               if (diag.x >= 0 && diag.x < boardSize && diag.y >= 0 && diag.y < boardSize) {
                 if (!isBlocked(next, diag, walls)) { // Check wall between opponent and diag
                   // Also check if diag is occupied
                   bool diagOccupied = false;
                   for (final p in otherPlayers) {
                     if (p == diag) diagOccupied = true;
                   }
                   if (!diagOccupied) moves.add(diag);
                 }
               }
             }
           }
           continue; // Handled jump
         }
      }

      moves.add(next);
    }

    return moves;
  }

  static bool isBlocked(Position from, Position to, List<Wall> walls) {
    for (final wall in walls) {
      // Horizontal wall (orientation 0) blocks vertical movement
      if (wall.orientation == 0) {
        // Blocks (x, y) <-> (x, y+1) and (x+1, y) <-> (x+1, y+1)
        // Wall at (wx, wy) blocks crossing from y=wy to y=wy+1 or vice versa
        // at x=wx or x=wx+1
        if (from.x == to.x && (from.x == wall.x || from.x == wall.x + 1)) {
          if ((from.y == wall.y && to.y == wall.y + 1) || (from.y == wall.y + 1 && to.y == wall.y)) {
            return true;
          }
        }
      }
      // Vertical wall (orientation 1) blocks horizontal movement
      else {
         // Blocks (x, y) <-> (x+1, y) and (x, y+1) <-> (x+1, y+1)
         // Wall at (wx, wy) blocks crossing from x=wx to x=wx+1
         // at y=wy or y=wy+1
         if (from.y == to.y && (from.y == wall.y || from.y == wall.y + 1)) {
           if ((from.x == wall.x && to.x == wall.x + 1) || (from.x == wall.x + 1 && to.x == wall.x)) {
             return true;
           }
         }
      }
    }
    return false;
  }
}
