import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workspace/models/game_model.dart';
import 'package:workspace/models/quoridor_logic.dart';
import 'package:workspace/screens/game/board_3d.dart';
import 'package:workspace/screens/game/board_view.dart';
import 'package:workspace/services/database_service.dart';
import 'package:workspace/services/settings_service.dart';

class _RecordingDatabase extends DatabaseService {
  int stateUpdates = 0;

  @override
  Future<void> updateGameState(
    String gameId,
    Map<String, dynamic> newState,
    int nextTurn, {
    Map<String, dynamic>? logEntry,
  }) async {
    stateUpdates++;
  }

  @override
  Future<void> setWinner(String gameId, String winnerId) async {}
}

GameModel _game() {
  return GameModel(
    id: 'game',
    hostId: 'host',
    playerIds: const ['host', 'rival'],
    status: 'playing',
    settings: GameSettings(),
    currentTurnIndex: 0,
    gameState: QuoridorLogic.initialState(2),
  );
}

Future<_RecordingDatabase> _pumpBoard(
  WidgetTester tester,
  SettingsService settings,
) async {
  final db = _RecordingDatabase();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: db),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: 600,
              child: GameBoard(
                game: _game(),
                userId: 'host',
                players: const [null, null],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return db;
}

/// Drags across the middle of the board the way a player aims a wall.
Future<void> _dragWall(WidgetTester tester) async {
  final centre = tester.getCenter(find.byType(GameBoard));
  final gesture = await tester.startGesture(centre);
  await tester.pump();
  await gesture.moveBy(const Offset(0, -40));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<SettingsService> _settings({
  required bool confirmWalls,
  bool confirmMoves = false,
}) async {
  SharedPreferences.setMockInitialValues({
    SettingsService.confirmWallsKey: confirmWalls,
    SettingsService.confirmMovesKey: confirmMoves,
    SettingsService.hapticsKey: false,
  });
  final settings = SettingsService();
  await settings.load();
  return settings;
}

void main() {
  testWidgets('with confirmation on, a wall drag waits for the button',
      (tester) async {
    final db = await _pumpBoard(
      tester,
      await _settings(confirmWalls: true),
    );

    await _dragWall(tester);

    expect(find.text('Place wall'), findsOneWidget);
    expect(db.stateUpdates, 0, reason: 'nothing should commit before confirm');

    await tester.tap(find.text('Place wall'));
    await tester.pump();

    expect(db.stateUpdates, 1);
    expect(find.text('Place wall'), findsNothing);
  });

  testWidgets('cancelling a pending wall leaves the board untouched',
      (tester) async {
    final db = await _pumpBoard(
      tester,
      await _settings(confirmWalls: true),
    );

    await _dragWall(tester);
    expect(find.text('Place wall'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(find.text('Place wall'), findsNothing);
    expect(db.stateUpdates, 0);
  });

  testWidgets('with confirmation off, releasing the drag places the wall',
      (tester) async {
    final db = await _pumpBoard(
      tester,
      await _settings(confirmWalls: false),
    );

    await _dragWall(tester);

    expect(find.text('Place wall'), findsNothing);
    expect(db.stateUpdates, 1);
  });

  testWidgets('with move confirmation on, a tapped square waits for the button',
      (tester) async {
    final db = await _pumpBoard(
      tester,
      await _settings(confirmWalls: true, confirmMoves: true),
    );

    await _tapStepForward(tester);

    expect(find.text('Move here'), findsOneWidget);
    expect(db.stateUpdates, 0);

    await tester.tap(find.text('Move here'));
    await tester.pump();

    expect(db.stateUpdates, 1);
    expect(find.text('Move here'), findsNothing);
  });

  testWidgets('with move confirmation off, a tapped square moves at once',
      (tester) async {
    final db = await _pumpBoard(
      tester,
      await _settings(confirmWalls: true),
    );

    await _tapStepForward(tester);

    expect(find.text('Move here'), findsNothing);
    expect(db.stateUpdates, 1);
  });
}

/// Taps the square the south pawn can step into on its first turn.
Future<void> _tapStepForward(WidgetTester tester) async {
  final seat = QuoridorLogic.seatsFor(2).first;
  final start = QuoridorLogic.pawnsFromState(QuoridorLogic.initialState(2), 2)
      .first;
  final step = Position(start.x, start.y + (seat.goalValue > start.y ? 1 : -1));

  final proj = BoardProjection.fit(
    const Size(600, 600),
    rotation: seat.cameraRotation,
  );
  final origin = tester.getTopLeft(find.byType(GameBoard));

  await tester.tapAt(origin + proj.project(step.x + 0.5, step.y + 0.5, 0));
  await tester.pump();
}
