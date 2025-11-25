import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/game_model.dart';
import '../../models/quoridor_logic.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';

class GameScreen extends StatelessWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final user = context.watch<AppUser?>();

    return StreamBuilder<GameModel?>(
      stream: db.streamGame(gameId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final game = snapshot.data!;
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Game: ${gameId.substring(0, 4)}...'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  Share.share('Join my Quoridor game! Code: $gameId');
                },
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: gameId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!')));
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text("Status: ${game.status}"),
                    Text("P1 Walls: ${game.gameState['p1WallsLeft'] ?? 10}"),
                    Text("P2 Walls: ${game.gameState['p2WallsLeft'] ?? 10}"),
                  ],
                ),
              ),
              if (game.status == 'waiting')
                const Expanded(child: Center(child: Text("Waiting for opponent... Share the code!"))),
              if (game.status == 'playing' || game.status == 'finished')
                Expanded(
                  child: GameBoard(game: game, userId: user?.id ?? ''),
                ),
            ],
          ),
        );
      },
    );
  }
}

class GameBoard extends StatefulWidget {
  final GameModel game;
  final String userId;

  const GameBoard({super.key, required this.game, required this.userId});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  Wall? _draggedWall;
  bool _isValidPlacement = false;
  
  // Cache for path checking optimization if needed, though BFS is fast enough for 9x9
  
  @override
  Widget build(BuildContext context) {
    // Parse state
    final p1Pos = Position(widget.game.gameState['p1']['x'], widget.game.gameState['p1']['y']);
    final p2Pos = Position(widget.game.gameState['p2']['x'], widget.game.gameState['p2']['y']);
    final walls = (widget.game.gameState['walls'] as List).map((w) => Wall(w['x'], w['y'], w['orientation'])).toList();

    final myIndex = widget.game.playerIds.indexOf(widget.userId);
    final isMyTurn = widget.game.currentTurnIndex == myIndex;
    
    final myWallsLeft = myIndex == 0 
        ? (widget.game.gameState['p1WallsLeft'] ?? 10) 
        : (widget.game.gameState['p2WallsLeft'] ?? 10);

    // Determine valid moves if my turn
    List<Position> validMoves = [];
    if (isMyTurn) {
      final myPos = myIndex == 0 ? p1Pos : p2Pos;
      final otherPos = myIndex == 0 ? p2Pos : p1Pos;
      validMoves = QuoridorLogic.getValidMoves(myPos, walls, [otherPos]);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final squareSize = size / 9;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Grid
                for (int y = 0; y < 9; y++)
                  for (int x = 0; x < 9; x++)
                    Positioned(
                      left: x * squareSize,
                      top: y * squareSize,
                      width: squareSize,
                      height: squareSize,
                      child: GestureDetector(
                        onTap: () {
                          if (!isMyTurn) return;
                          // If we were dragging a wall, don't move
                          if (_draggedWall != null) {
                            setState(() => _draggedWall = null);
                            return;
                          }
                          
                          final target = Position(x, y);
                          if (validMoves.contains(target)) {
                            _makeMove(target, walls);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: validMoves.contains(Position(x, y)) 
                              ? Colors.green.withOpacity(0.3) 
                              : Colors.brown[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                // Players
                _buildPlayer(p1Pos, Colors.white, squareSize),
                _buildPlayer(p2Pos, Colors.black, squareSize),

                // Existing Walls
                for (final wall in walls)
                   _buildWall(wall, squareSize, Colors.brown[800]!),
                   
                // Dragged Wall (Ghost)
                if (_draggedWall != null)
                   _buildWall(_draggedWall!, squareSize, 
                     _isValidPlacement ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.7)
                   ),

                // Wall Placement Interaction (Full board drag)
                if (isMyTurn && myWallsLeft > 0)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (details) => _handleWallDrag(details.localPosition, squareSize, walls, p1Pos, p2Pos),
                      onPanUpdate: (details) => _handleWallDrag(details.localPosition, squareSize, walls, p1Pos, p2Pos),
                      onPanEnd: (details) => _finalizeWallPlacement(walls),
                      onPanCancel: () => setState(() => _draggedWall = null),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayer(Position pos, Color color, double size) {
    return Positioned(
      left: pos.x * size,
      top: pos.y * size,
      width: size,
      height: size,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: size * 0.6,
            height: size * 0.6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey, width: 2),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2,2))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWall(Wall wall, double gridSize, Color color) {
    double top, left, width, height;
    final thickness = gridSize * 0.15; // Thicker walls for visibility
    final length = gridSize * 2 + gridSize * 0.05; // Slightly longer to bridge gap visually

    if (wall.orientation == 0) { // Horizontal
      left = wall.x * gridSize; // Aligned with cell start
      top = (wall.y + 1) * gridSize - (thickness / 2);
      width = length;
      height = thickness;
    } else { // Vertical
      left = (wall.x + 1) * gridSize - (thickness / 2);
      top = wall.y * gridSize;
      width = thickness;
      height = length;
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(thickness/2),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
        ),
      ),
    );
  }

  void _handleWallDrag(Offset localPos, double squareSize, List<Wall> currentWalls, Position p1, Position p2) {
    // Convert localPos to grid coordinates
    // Note: User touch should be near the wall "center"
    // Add offset so the wall appears above the finger (y-axis offset)
    final touchPos = localPos - const Offset(0, 50); 
    
    double rawX = touchPos.dx / squareSize;
    double rawY = touchPos.dy / squareSize;

    // Identify nearest gap
    // Gap x is between col x and x+1 (vertical wall)
    // Gap y is between row y and y+1 (horizontal wall)
    
    // Logic: Find nearest integer.
    int nearestX = rawX.round();
    int nearestY = rawY.round();
    
    // Determine orientation based on which grid line we are closer to
    double distToX = (rawX - nearestX).abs();
    double distToY = (rawY - nearestY).abs();
    
    int orientation = (distToX < distToY) ? 1 : 0; // 1=Vertical (closer to X line), 0=Horizontal (closer to Y line)
    
    // Map to valid wall indices (0..7)
    // Vertical wall at x=0 is between col 0 and 1. NearestX should be 1.
    // So wallX = nearestX - 1.
    
    int wallX = nearestX - 1;
    int wallY = nearestY - 1;
    
    if (orientation == 0) {
      // Horizontal: snapped to Y line. 
      // wallY is index of row *above* the wall? No, gap index.
      // Wall(x, y, 0) is between row y and y+1.
      // NearestY corresponds to the line index. Line 1 is between row 0 and 1.
      // So wallY = nearestY - 1 is correct.
      // But horizontal wall needs to be aligned with a column start?
      // Yes, wall.x determines start column.
      // We should round rawX to nearest integer? No, floor rawX?
      // Horizontal wall spans 2 cells.
      // Center of wall is at rawX. Start is rawX - 1?
      // Let's snap x to nearest cell index.
      wallX = rawX.floor();
      wallY = nearestY - 1;
    } else {
      // Vertical: snapped to X line.
      // wallX = nearestX - 1.
      // wallY needs to be snapped to nearest cell index (start row).
      wallX = nearestX - 1;
      wallY = rawY.floor();
    }

    // Clamp
    if (wallX < 0) wallX = 0;
    if (wallX > 7) wallX = 7;
    if (wallY < 0) wallY = 0;
    if (wallY > 7) wallY = 7;

    final potentialWall = Wall(wallX, wallY, orientation);
    final isValid = QuoridorLogic.isValidWall(potentialWall, currentWalls, p1, p2);

    setState(() {
      _draggedWall = potentialWall;
      _isValidPlacement = isValid;
    });
  }

  Future<void> _finalizeWallPlacement(List<Wall> walls) async {
    if (_draggedWall != null && _isValidPlacement) {
      await _placeWall(_draggedWall!);
    }
    setState(() {
      _draggedWall = null;
      _isValidPlacement = false;
    });
  }

  Future<void> _makeMove(Position newPos, List<Wall> walls) async {
    final db = context.read<DatabaseService>();
    final myIndex = widget.game.playerIds.indexOf(widget.userId);
    final newState = Map<String, dynamic>.from(widget.game.gameState);
    
    if (myIndex == 0) {
      newState['p1'] = {'x': newPos.x, 'y': newPos.y};
    } else {
      newState['p2'] = {'x': newPos.x, 'y': newPos.y};
    }
    
    final nextTurn = (widget.game.currentTurnIndex + 1) % 2;
    await db.updateGameState(widget.game.id, newState, nextTurn);
    
    // Check Win
    if (myIndex == 0 && newPos.y == 8) db.setWinner(widget.game.id, widget.userId);
    if (myIndex == 1 && newPos.y == 0) db.setWinner(widget.game.id, widget.userId);
  }
  
  Future<void> _placeWall(Wall wall) async {
    final db = context.read<DatabaseService>();
    final myIndex = widget.game.playerIds.indexOf(widget.userId);
    final newState = Map<String, dynamic>.from(widget.game.gameState);
    
    // Add wall
    final wallsList = List<Map<String, dynamic>>.from(newState['walls'] ?? []);
    wallsList.add({'x': wall.x, 'y': wall.y, 'orientation': wall.orientation});
    newState['walls'] = wallsList;
    
    // Decrement counter
    if (myIndex == 0) {
       newState['p1WallsLeft'] = (newState['p1WallsLeft'] ?? 10) - 1;
    } else {
       newState['p2WallsLeft'] = (newState['p2WallsLeft'] ?? 10) - 1;
    }
    
    final nextTurn = (widget.game.currentTurnIndex + 1) % 2;
    await db.updateGameState(widget.game.id, newState, nextTurn);
  }
}
