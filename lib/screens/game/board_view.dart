import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/game_model.dart';
import '../../models/quoridor_logic.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../widgets/user_profile_dialog.dart';
import 'board_3d.dart';

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

class _GameBoardState extends State<GameBoard>
    with SingleTickerProviderStateMixin {
  Wall? _draggedWall;
  bool _isValidPlacement = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.game.gameState;
    final p1Pos = Position(state['p1']['x'], state['p1']['y']);
    final p2Pos = Position(state['p2']['x'], state['p2']['y']);
    final walls = (state['walls'] as List)
        .map((w) => Wall(w['x'], w['y'], w['orientation']))
        .toList();

    final myIndex = widget.game.playerIds.indexOf(widget.userId);
    final isMyTurn = widget.game.currentTurnIndex == myIndex;
    final int wallsLeft =
        (myIndex == 0 ? state['p1WallsLeft'] : state['p2WallsLeft']) ?? 10;

    // Each player sits at their own end of the board. Player 2 starts on the
    // far row, so their camera is the one that gets turned around.
    final flipped = myIndex == 1;

    final validMoves = <Position>{};
    if (isMyTurn && myIndex >= 0) {
      final myPos = myIndex == 0 ? p1Pos : p2Pos;
      final otherPos = myIndex == 0 ? p2Pos : p1Pos;
      validMoves.addAll(QuoridorLogic.getValidMoves(myPos, walls, [otherPos]));
    }

    final canPlaceWall = isMyTurn && wallsLeft > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final proj = BoardProjection.fit(constraints.biggest, flipped: flipped);

        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final pulse = Curves.easeInOut.transform(_pulse.value);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) =>
                  _handleTap(details.localPosition, proj, validMoves),
              onPanStart: canPlaceWall
                  ? (details) => _updateGhostWall(
                      details.localPosition, proj, walls, p1Pos, p2Pos)
                  : null,
              onPanUpdate: canPlaceWall
                  ? (details) => _updateGhostWall(
                      details.localPosition, proj, walls, p1Pos, p2Pos)
                  : null,
              onPanEnd: canPlaceWall ? (_) => _finalizeWallPlacement() : null,
              onPanCancel: canPlaceWall ? _clearGhostWall : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BoardPainter(
                        proj: proj,
                        walls: walls,
                        validMoves: validMoves,
                        ghostWall: _draggedWall,
                        ghostValid: _isValidPlacement,
                        pulse: pulse,
                      ),
                    ),
                  ),
                  ..._buildPieces(proj, p1Pos, p2Pos, pulse),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildPieces(
    BoardProjection proj,
    Position p1Pos,
    Position p2Pos,
    double pulse,
  ) {
    final playing = widget.game.status == 'playing';
    final pieces = <_PieceSpec>[
      _PieceSpec(
        pos: p1Pos,
        user: widget.p1User,
        color: kP1Color,
        isActive: playing && widget.game.currentTurnIndex == 0,
      ),
      _PieceSpec(
        pos: p2Pos,
        user: widget.p2User,
        color: kP2Color,
        isActive: playing && widget.game.currentTurnIndex == 1,
      ),
    ];

    // Painter's order: whichever pawn is further from the camera goes down
    // first so a nearer pawn overlaps it rather than the other way around.
    pieces.sort((a, b) => _pieceDepth(proj, b).compareTo(_pieceDepth(proj, a)));

    return pieces.map((piece) {
      final cx = piece.pos.x + 0.5;
      final cy = piece.pos.y + 0.5;
      final base = proj.project(cx, cy, 0);
      final diameter = proj.scaleAt(cx, cy) * 0.62;
      final box = BoardPiece.boxFor(diameter);
      final anchor = BoardPiece.anchorFor(diameter);
      final user = piece.user;

      return Positioned(
        left: base.dx - anchor.dx,
        top: base.dy - anchor.dy,
        width: box.width,
        height: box.height,
        child: BoardPiece(
          user: user,
          color: piece.color,
          diameter: diameter,
          isActive: piece.isActive,
          pulse: pulse,
          onTap: user == null
              ? null
              : () => UserProfileDialog.show(context, user.id, widget.userId),
        ),
      );
    }).toList();
  }

  double _pieceDepth(BoardProjection proj, _PieceSpec piece) =>
      proj.depthAt(piece.pos.x + 0.5, piece.pos.y + 0.5, 0);

  void _handleTap(
    Offset local,
    BoardProjection proj,
    Set<Position> validMoves,
  ) {
    if (_draggedWall != null) {
      _clearGhostWall();
      return;
    }

    final board = proj.unproject(local);
    if (board == null) return;

    final target = Position(board.dx.floor(), board.dy.floor());
    if (!validMoves.contains(target)) return;
    _makeMove(target);
  }

  void _updateGhostWall(
    Offset local,
    BoardProjection proj,
    List<Wall> walls,
    Position p1,
    Position p2,
  ) {
    // Aim above the finger so the wall being placed is not hidden by it.
    final lift = proj.scaleAt(
          BoardProjection.span / 2,
          BoardProjection.span / 2,
        ) *
        0.55;
    final board = proj.unproject(local - Offset(0, lift));
    if (board == null) return;

    final rawX = board.dx;
    final rawY = board.dy;
    final nearestX = rawX.round();
    final nearestY = rawY.round();

    // Snap to whichever grid line the touch is closest to, then centre the
    // two-cell span on the touch instead of hanging it off to one side.
    final orientation =
        (rawX - nearestX).abs() < (rawY - nearestY).abs() ? 1 : 0;

    final int wallX;
    final int wallY;
    if (orientation == 0) {
      wallX = _clampSlot((rawX - 1).round());
      wallY = _clampSlot(nearestY - 1);
    } else {
      wallX = _clampSlot(nearestX - 1);
      wallY = _clampSlot((rawY - 1).round());
    }

    final candidate = Wall(wallX, wallY, orientation);
    final valid = QuoridorLogic.isValidWall(candidate, walls, p1, p2);
    if (candidate == _draggedWall && valid == _isValidPlacement) return;

    setState(() {
      _draggedWall = candidate;
      _isValidPlacement = valid;
    });
  }

  static int _clampSlot(int value) {
    if (value < 0) return 0;
    if (value > QuoridorLogic.boardSize - 2) {
      return QuoridorLogic.boardSize - 2;
    }
    return value;
  }

  void _clearGhostWall() {
    if (_draggedWall == null) return;
    setState(() {
      _draggedWall = null;
      _isValidPlacement = false;
    });
  }

  Future<void> _finalizeWallPlacement() async {
    final wall = _draggedWall;
    final wasValid = _isValidPlacement;
    _clearGhostWall();
    if (wall != null && wasValid) {
      await _placeWall(wall);
    }
  }

  Future<void> _makeMove(Position newPos) async {
    final db = context.read<DatabaseService>();
    final myIndex = widget.game.playerIds.indexOf(widget.userId);
    final newState = Map<String, dynamic>.from(widget.game.gameState);

    if (myIndex == 0) {
      newState['p1'] = {'x': newPos.x, 'y': newPos.y};
    } else {
      newState['p2'] = {'x': newPos.x, 'y': newPos.y};
    }

    final logEntry = {
      'playerId': widget.userId,
      'type': 'move',
      'to': {'x': newPos.x, 'y': newPos.y},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final nextTurn = (widget.game.currentTurnIndex + 1) % 2;
    await db.updateGameState(widget.game.id, newState, nextTurn,
        logEntry: logEntry);

    bool won = false;
    if (myIndex == 0 && newPos.y == 8) won = true;
    if (myIndex == 1 && newPos.y == 0) won = true;

    if (won) {
      await db.setWinner(widget.game.id, widget.userId);
    }
  }

  Future<void> _placeWall(Wall wall) async {
    final db = context.read<DatabaseService>();
    final myIndex = widget.game.playerIds.indexOf(widget.userId);
    final newState = Map<String, dynamic>.from(widget.game.gameState);

    final wallsList = List<Map<String, dynamic>>.from(newState['walls'] ?? []);
    wallsList.add({'x': wall.x, 'y': wall.y, 'orientation': wall.orientation});
    newState['walls'] = wallsList;

    if (myIndex == 0) {
      newState['p1WallsLeft'] = (newState['p1WallsLeft'] ?? 10) - 1;
    } else {
      newState['p2WallsLeft'] = (newState['p2WallsLeft'] ?? 10) - 1;
    }

    final logEntry = {
      'playerId': widget.userId,
      'type': 'wall',
      'wall': {'x': wall.x, 'y': wall.y, 'o': wall.orientation},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final nextTurn = (widget.game.currentTurnIndex + 1) % 2;
    await db.updateGameState(widget.game.id, newState, nextTurn,
        logEntry: logEntry);
  }
}

class _PieceSpec {
  final Position pos;
  final AppUser? user;
  final Color color;
  final bool isActive;

  const _PieceSpec({
    required this.pos,
    required this.user,
    required this.color,
    required this.isActive,
  });
}
