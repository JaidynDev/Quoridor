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
                child: Text("Status: ${game.status}"),
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

  @override
  Widget build(BuildContext context) {
    // Parse state
    final p1Pos = Position(widget.game.gameState['p1']['x'], widget.game.gameState['p1']['y']);
    final p2Pos = Position(widget.game.gameState['p2']['x'], widget.game.gameState['p2']['y']);
    final walls = (widget.game.gameState['walls'] as List).map((w) => Wall(w['x'], w['y'], w['orientation'])).toList();

    final myIndex = widget.game.playerIds.indexOf(widget.userId);
    final isMyTurn = widget.game.currentTurnIndex == myIndex;
    
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
                          final target = Position(x, y);
                          if (validMoves.contains(target)) {
                            _makeMove(target, walls);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          color: validMoves.contains(Position(x, y)) 
                            ? Colors.green.withOpacity(0.3) 
                            : Colors.brown[200],
                          child: Center(
                             // Debug coords
                             // child: Text("$x,$y", style: TextStyle(fontSize: 8)),
                          ),
                        ),
                      ),
                    ),

                // Players
                _buildPlayer(p1Pos, Colors.white, squareSize),
                _buildPlayer(p2Pos, Colors.black, squareSize),

                // Walls
                for (final wall in walls)
                   _buildWall(wall, squareSize, Colors.brown[800]!),
                   
                // Wall Placement Interaction (Clicking gaps)
                if (isMyTurn)
                  for (int y = 0; y < 8; y++)
                    for (int x = 0; x < 8; x++)
                      Positioned(
                        left: x * squareSize + squareSize - 10,
                        top: y * squareSize + squareSize - 10,
                        width: 20,
                        height: 20,
                        child: GestureDetector(
                           onTap: () => _showWallPlacementDialog(x, y, walls, p1Pos, p2Pos),
                           child: Container(
                             color: Colors.transparent, // Hit test area
                           ),
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
              border: Border.all(color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWall(Wall wall, double gridSize, Color color) {
    // Visual adjustments
    // Wall is 2 squares long + gap.
    // Vertical: placed at right of x, top of y.
    // Horizontal: placed at bottom of y, left of x.
    
    double top, left, width, height;
    final thickness = 8.0;
    final length = gridSize * 2;

    if (wall.orientation == 0) { // Horizontal
      left = wall.x * gridSize;
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
      child: Container(color: color),
    );
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
    final newState = Map<String, dynamic>.from(widget.game.gameState);
    final wallsList = List<Map<String, dynamic>>.from(newState['walls'] ?? []);
    wallsList.add({'x': wall.x, 'y': wall.y, 'orientation': wall.orientation});
    newState['walls'] = wallsList;
    
    final nextTurn = (widget.game.currentTurnIndex + 1) % 2;
    await db.updateGameState(widget.game.id, newState, nextTurn);
  }
  
  void _showWallPlacementDialog(int x, int y, List<Wall> currentWalls, Position p1, Position p2) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Place Wall"),
        children: [
          SimpleDialogOption(
            child: const Text("Horizontal"),
            onPressed: () {
              Navigator.pop(context);
              final wall = Wall(x, y, 0);
              if (QuoridorLogic.isValidWall(wall, currentWalls, p1, p2)) {
                _placeWall(wall);
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Wall Position")));
              }
            },
          ),
          SimpleDialogOption(
            child: const Text("Vertical"),
            onPressed: () {
               Navigator.pop(context);
               final wall = Wall(x, y, 1);
               if (QuoridorLogic.isValidWall(wall, currentWalls, p1, p2)) {
                 _placeWall(wall);
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Wall Position")));
               }
            },
          ),
        ],
      ),
    );
  }
}
