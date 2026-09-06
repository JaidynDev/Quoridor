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
  final List<AppUser?> players;

  const GameBoard({
    super.key,
    required this.game,
    required this.userId,
    this.players = const [],
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard>
    with SingleTickerProviderStateMixin {
  Wall? _draggedWall;
  bool _isValidPlacement = false;
  late final AnimationController _pulse;

  int get _seats => widget.game.settings.seats;
  List<PlayerSeat> get _seatsInfo => QuoridorLogic.seatsFor(_seats);

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

  AppUser? _userFor(int index) {
    if (index < widget.players.length) return widget.players[index];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.game.gameState;
    final pawns = QuoridorLogic.pawnsFromState(state, _seats);
    final walls = (state['walls'] as List? ?? [])
        .map((w) => Wall(w['x'], w['y'], w['orientation']))
        .toList();

    final myIndex = widget.game.playerIds.indexOf(widget.userId);
    final isMyTurn = widget.game.currentTurnIndex == myIndex && myIndex >= 0;
    final wallsLeft = myIndex >= 0
        ? (state[QuoridorLogic.wallsKey(myIndex)] ??
            QuoridorLogic.wallsEach(_seats)) as int
        : 0;

    final rotation =
        myIndex >= 0 ? _seatsInfo[myIndex].cameraRotation : 0;

    final validMoves = <Position>{};
    if (isMyTurn) {
      final myPos = pawns[myIndex];
      final others = [
        for (var i = 0; i < pawns.length; i++)
          if (i != myIndex) pawns[i],
      ];
      validMoves.addAll(QuoridorLogic.getValidMoves(myPos, walls, others));
    }

    final canPlaceWall = isMyTurn && wallsLeft > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final proj =
            BoardProjection.fit(constraints.biggest, rotation: rotation);

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
                      details.localPosition, proj, walls, pawns)
                  : null,
              onPanUpdate: canPlaceWall
                  ? (details) => _updateGhostWall(
                      details.localPosition, proj, walls, pawns)
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
                  ..._buildPieces(proj, pawns, pulse),
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
    List<Position> pawns,
    double pulse,
  ) {
    final playing = widget.game.status == 'playing';
    final pieces = <_PieceSpec>[
      for (var i = 0; i < pawns.length; i++)
        _PieceSpec(
          pos: pawns[i],
          user: _userFor(i),
          color: kPawnColors[i % kPawnColors.length],
          isActive: playing && widget.game.currentTurnIndex == i,
        ),
    ];

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
    List<Position> pawns,
  ) {
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
    final valid =
        QuoridorLogic.isValidWall(candidate, walls, pawns, _seatsInfo);
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
    if (myIndex < 0) return;
    final newState = Map<String, dynamic>.from(widget.game.gameState);
    newState[QuoridorLogic.pawnKey(myIndex)] = newPos.toMap();

    final logEntry = {
      'playerId': widget.userId,
      'type': 'move',
      'to': newPos.toMap(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final nextTurn = (widget.game.currentTurnIndex + 1) % _seats;
    await db.updateGameState(widget.game.id, newState, nextTurn,
        logEntry: logEntry);

    if (_seatsInfo[myIndex].reachedGoal(newPos)) {
      await db.setWinner(widget.game.id, widget.userId);
    }
  }

  Future<void> _placeWall(Wall wall) async {
    final db = context.read<DatabaseService>();
    final myIndex = widget.game.playerIds.indexOf(widget.userId);
    if (myIndex < 0) return;
    final newState = Map<String, dynamic>.from(widget.game.gameState);

    final wallsList = List<Map<String, dynamic>>.from(newState['walls'] ?? []);
    wallsList.add({'x': wall.x, 'y': wall.y, 'orientation': wall.orientation});
    newState['walls'] = wallsList;

    final key = QuoridorLogic.wallsKey(myIndex);
    newState[key] = ((newState[key] ?? QuoridorLogic.wallsEach(_seats)) as int) - 1;

    final logEntry = {
      'playerId': widget.userId,
      'type': 'wall',
      'wall': {'x': wall.x, 'y': wall.y, 'o': wall.orientation},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final nextTurn = (widget.game.currentTurnIndex + 1) % _seats;
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
