import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math' as math;
import '../../models/game_model.dart';
import '../../models/quoridor_logic.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../widgets/user_profile_dialog.dart';
import 'game_result_screen.dart';

class GameScreen extends StatelessWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final currentUser = context.watch<AppUser?>();

    return StreamBuilder<GameModel?>(
      stream: db.streamGame(gameId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final game = snapshot.data!;
        
        return _GameScreenContent(game: game, currentUser: currentUser);
      },
    );
  }
}

class _GameScreenContent extends StatelessWidget {
  final GameModel game;
  final AppUser? currentUser;

  const _GameScreenContent({required this.game, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    
    // Find opponent ID
    final p1Id = game.playerIds.isNotEmpty ? game.playerIds[0] : '';
    final p2Id = game.playerIds.length > 1 ? game.playerIds[1] : '';
    
    // We want to resolve both users. 
    // We can wrap GameBoard in StreamBuilders.
    
    return StreamBuilder<AppUser?>(
      stream: p1Id.isNotEmpty ? db.streamUser(p1Id) : Stream.value(null),
      builder: (context, p1Snap) {
        return StreamBuilder<AppUser?>(
          stream: p2Id.isNotEmpty ? db.streamUser(p2Id) : Stream.value(null),
          builder: (context, p2Snap) {
             final p1User = p1Snap.data;
             final p2User = p2Snap.data;
             
             return Scaffold(
              appBar: AppBar(
                title: Text('Game: ${game.id.substring(0, 4)}...'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      Share.share('Join my Quoridor game! Code: ${game.id}');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: game.id));
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
                        _buildPlayerInfo(p1User, game.gameState['p1WallsLeft'] ?? 10, 1),
                        const Text("vs"),
                        _buildPlayerInfo(p2User, game.gameState['p2WallsLeft'] ?? 10, 2),
                      ],
                    ),
                  ),
                  if (game.status == 'waiting')
                    const Expanded(child: Center(child: Text("Waiting for opponent... Share the code!"))),
                  if (game.status == 'playing' || game.status == 'finished')
                    Expanded(
                      child: Stack(
                        children: [
                          GameBoard(
                            game: game, 
                            userId: currentUser?.id ?? '',
                            p1User: p1User,
                            p2User: p2User,
                          ),
                          if (game.status == 'finished')
                            GameResultScreen(game: game, currentUserId: currentUser?.id ?? ''),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildPlayerInfo(AppUser? user, int walls, int pNum) {
    return Column(
      children: [
        Text(user?.username ?? "Player $pNum", style: const TextStyle(fontWeight: FontWeight.bold)),
        Text("Walls: $walls"),
      ],
    );
  }
}

class GameBoard extends StatefulWidget {
  final GameModel game;
  final String userId;
  final AppUser? p1User;
  final AppUser? p2User;

  const GameBoard({
    super.key, 
    required this.game, 
    required this.userId,
    this.p1User,
    this.p2User,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  Wall? _draggedWall;
  bool _isValidPlacement = false;
  
  // Perspective Constants
  final double _perspectiveValue = 0.001;
  final double _tiltAngle = 0.6; // Radians ~ 34 degrees
  
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

    // Rotation Logic:
    // P1 (myIndex == 0) starts at y=0 (Top). To view from Bottom, Rotate 180.
    // P2 (myIndex == 1) starts at y=8 (Bottom). Already at Bottom. No Rotation.
    final bool shouldRotate = myIndex == 0;
    final double rotationAngle = shouldRotate ? math.pi : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        // Adjust square size to fit in the tilted view (needs some padding)
        final squareSize = size / 11; // Slightly smaller to fit with tilt
        final boardWidth = squareSize * 9;
        final boardHeight = squareSize * 9;

        return Center(
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, _perspectiveValue)
                ..rotateX(-_tiltAngle),
              child: Transform.rotate(
                angle: rotationAngle,
                child: SizedBox(
                  width: boardWidth,
                  height: boardHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Floor Grid (Base)
                      _buildGrid(squareSize, validMoves, isMyTurn, walls, p1Pos, p2Pos),

                      // 2. Render Objects (Players and Walls sorted by depth)
                      ..._buildSortedObjects(p1Pos, p2Pos, walls, squareSize, isRotated: shouldRotate),
                      
                      // 3. Dragged Wall (Ghost)
                      if (_draggedWall != null)
                         _buildWall(_draggedWall!, squareSize, 
                           _isValidPlacement ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.7),
                           isGhost: true
                         ),

                      // 4. Touch Handling Layer (Invisible, on top of everything for drag)
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(double squareSize, List<Position> validMoves, bool isMyTurn, List<Wall> walls, Position p1, Position p2) {
    return Stack(
      children: [
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
                   margin: const EdgeInsets.all(1),
                   decoration: BoxDecoration(
                     color: validMoves.contains(Position(x, y)) 
                       ? Colors.green.withOpacity(0.3) 
                       : Colors.brown[200], // Floor color
                     borderRadius: BorderRadius.circular(2),
                     boxShadow: [
                        BoxShadow(color: Colors.black12, offset: Offset(1, 1))
                     ]
                   ),
                 ),
               ),
             ),
      ],
    );
  }

  List<Widget> _buildSortedObjects(Position p1Pos, Position p2Pos, List<Wall> walls, double squareSize, {required bool isRotated}) {
    // Create a list of renderable items with a Z-index (sort key)
    final items = <_RenderItem>[];

    // Add Players
    // Player Z is simply their Y position (row index)
    items.add(_RenderItem(
      z: p1Pos.y.toDouble(),
      widget: _buildPlayer(p1Pos, Colors.white, squareSize, widget.p1User, isRotated: isRotated),
    ));
    items.add(_RenderItem(
      z: p2Pos.y.toDouble(),
      widget: _buildPlayer(p2Pos, Colors.black, squareSize, widget.p2User, isRotated: isRotated),
    ));

    // Add Walls
    for (final wall in walls) {
      double z;
      if (wall.orientation == 0) {
        z = wall.y + 0.8; 
      } else {
        z = wall.y + 1.8; // Vertical wall ends at grid line y+2.
      }
      
      items.add(_RenderItem(
        z: z,
        widget: _buildWall(wall, squareSize, Colors.brown[800]!),
      ));
    }

    // Sort
    if (isRotated) {
      // Descending Y (Far Y=8 to Near Y=0)
      items.sort((a, b) => b.z.compareTo(a.z));
    } else {
      // Ascending Y (Far Y=0 to Near Y=8)
      items.sort((a, b) => a.z.compareTo(b.z));
    }

    return items.map((i) => i.widget).toList();
  }

  Widget _buildPlayer(Position pos, Color color, double size, AppUser? user, {required bool isRotated}) {
    // To make it "stand up", we need to counter-rotate.
    // The board is rotated X by _tiltAngle.
    // We rotate X by -_tiltAngle.
    // We also need to position it correctly.
    
    // If Board is Rotated 180, we need to correct the player facing.
    // Otherwise they will be upside down / facing away? 
    // Board Rotation Z(180) -> Rotates Local Y to -Y.
    // Player stands in Local Z.
    // So Player facing is rotated 180.
    // We need to rotate Z(180) to correct it.
    
    return Positioned(
      left: pos.x * size,
      top: pos.y * size - (size * 0.5), // Shift up slightly to stand on tile
      width: size,
      height: size * 1.5, // Taller container for standing character
      child: GestureDetector(
        onTap: () {
          if (user != null) {
            UserProfileDialog.show(context, user.id, widget.userId);
          }
        },
        child: Transform(
          transform: Matrix4.identity()
            ..translate(0.0, size * 0.5) // Pivot correction
            ..rotateZ(isRotated ? math.pi : 0) // Correct Rotation
            ..rotateX(_tiltAngle) // Counter tilt to stand up
            ..translate(0.0, -size * 0.5),
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Character Avatar
              Container(
                width: size * 0.8,
                height: size * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                  image: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                    ? DecorationImage(image: NetworkImage(user.photoUrl!), fit: BoxFit.cover)
                    : null,
                  color: user?.photoUrl == null ? color : Colors.grey[300],
                ),
                child: user?.photoUrl == null 
                  ? Icon(Icons.person, color: color == Colors.white ? Colors.black : Colors.white) 
                  : null,
              ),
              // Small shadow/base
              Container(
                 width: size * 0.6,
                 height: size * 0.2,
                 decoration: BoxDecoration(
                   color: Colors.black26,
                   borderRadius: BorderRadius.all(Radius.elliptical(size * 0.6, size * 0.2)),
                 ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWall(Wall wall, double gridSize, Color color, {bool isGhost = false}) {
    double top, left, width, height;
    final thickness = gridSize * 0.2;  
    final length = gridSize * 2 + gridSize * 0.1;

    // For 3D effect, we draw a container that looks like a block
    // We can use a stack of faces or just a styled container
    
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

    // If ghost, just flat
    if (isGhost) {
      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }

    // 3D Wall
    // We want it to have height (Z-axis). 
    
    final wallHeight = gridSize * 0.6; // How tall the wall stands up

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height, // Base footprint
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Shadow/Base
          Container(
            width: width,
            height: height,
            color: Colors.black26,
          ),
          // The Wall Body (Standing up)
          Transform(
            transform: Matrix4.identity()
              ..translate(0.0, height) // Move to bottom of footprint
              ..rotateX(-math.pi / 2) // Rotate 90 deg to stand up
              ..translate(0.0, -wallHeight), // Move up by height
            alignment: Alignment.bottomCenter, // Pivot at bottom
            child: Container(
               width: width,
               height: wallHeight,
               decoration: BoxDecoration(
                 color: color, // Front face
                 border: Border.all(color: Colors.black54, width: 0.5),
                 gradient: LinearGradient(
                   begin: Alignment.topCenter,
                   end: Alignment.bottomCenter,
                   colors: [color.withOpacity(0.8), color],
                 )
               ),
               // Add Top Face visual hack?
               child: Stack(
                 clipBehavior: Clip.none,
                 children: [
                   // Top Cap
                   Positioned(
                     top: -height/2, // This is approximate
                     left: 0,
                     right: 0,
                     height: height, // depth of wall
                     child: Transform(
                        transform: Matrix4.identity()..rotateX(math.pi / 2),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          color: Color.lerp(color, Colors.white, 0.2),
                        ),
                     )
                   )
                 ],
               ),
            ),
          ),
        ],
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
    
    // Logic: Find nearest integer.
    int nearestX = rawX.round();
    int nearestY = rawY.round();
    
    // Determine orientation based on which grid line we are closer to
    double distToX = (rawX - nearestX).abs();
    double distToY = (rawY - nearestY).abs();
    
    int orientation = (distToX < distToY) ? 1 : 0; // 1=Vertical (closer to X line), 0=Horizontal (closer to Y line)
    
    // Map to valid wall indices (0..7)
    int wallX = nearestX - 1;
    int wallY = nearestY - 1;
    
    if (orientation == 0) {
      wallX = rawX.floor();
      wallY = nearestY - 1;
    } else {
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
    // Note: We await this to ensure stats are updated.
    // The UI will react to the stream update.
    if (myIndex == 0 && newPos.y == 8) {
      await db.setWinner(widget.game.id, widget.userId);
    }
    if (myIndex == 1 && newPos.y == 0) {
      await db.setWinner(widget.game.id, widget.userId);
    }
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

class _RenderItem {
  final double z;
  final Widget widget;
  
  _RenderItem({required this.z, required this.widget});
}
