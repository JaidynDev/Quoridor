import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workspace/models/game_model.dart';
import 'package:workspace/models/quoridor_logic.dart';
import 'package:workspace/screens/game/board_view.dart';
import 'package:workspace/services/database_service.dart';
import 'package:workspace/services/settings_service.dart';

class _RecordingDatabase extends DatabaseService {
  final states = <Map<String, dynamic>>[];
  final logs = <Map<String, dynamic>>[];
  final turns = <int>[];
  String? winner;

  @override
  Future<void> updateGameState(
    String gameId,
    Map<String, dynamic> newState,
    int nextTurn, {
    Map<String, dynamic>? logEntry,
  }) async {
    states.add(newState);
    turns.add(nextTurn);
    if (logEntry != null) logs.add(logEntry);
  }

  @override
  Future<void> setWinner(String gameId, String winnerId) async {
    winner = winnerId;
  }
}

GameModel _game({
  int turnIndex = 0,
  int limitSeconds = 60,
  required int startedSecondsAgo,
  int seats = 2,
  List<String> resignedIds = const [],
}) {
  return GameModel(
    id: 'game',
    hostId: 'host',
    playerIds: ['host', 'rival', 'third', 'fourth'].take(seats).toList(),
    status: 'playing',
    settings: GameSettings(timeLimitSeconds: limitSeconds, playerCount: seats),
    currentTurnIndex: turnIndex,
    gameState: QuoridorLogic.initialState(seats),
    turnStartedAt:
        DateTime.now().subtract(Duration(seconds: startedSecondsAgo)),
    resignedIds: resignedIds,
  );
}

Future<_RecordingDatabase> _pumpBoard(
  WidgetTester tester, {
  required GameModel game,
  required String userId,
}) async {
  SharedPreferences.setMockInitialValues({
    SettingsService.hapticsKey: false,
  });
  final settings = SettingsService();
  await settings.load();
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
              width: 500,
              height: 500,
              child: GameBoard(game: game, userId: userId),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return db;
}

void main() {
  testWidgets('an expired clock steps the pawn on turn forward', (tester) async {
    final db = await _pumpBoard(
      tester,
      game: _game(startedSecondsAgo: 61),
      userId: 'host',
    );

    expect(db.states, isEmpty, reason: 'nothing until the ticker runs');

    await tester.pump(const Duration(seconds: 1));

    expect(db.states, hasLength(1));
    expect(db.logs.single['type'], 'timeout');
    expect(db.logs.single['playerId'], 'host');
    expect(db.states.single['p1'], {'x': 4, 'y': 1});
    expect(db.turns.single, 1);
    expect(db.winner, isNull);

    // The board should not keep firing while it waits for the write to land.
    await tester.pump(const Duration(seconds: 3));
    expect(db.states, hasLength(1));
  });

  testWidgets('a clock with time left is left alone', (tester) async {
    final db = await _pumpBoard(
      tester,
      game: _game(startedSecondsAgo: 10),
      userId: 'host',
    );

    await tester.pump(const Duration(seconds: 3));

    expect(db.states, isEmpty);
  });

  testWidgets('a match with no limit never times out', (tester) async {
    final db = await _pumpBoard(
      tester,
      game: _game(limitSeconds: 0, startedSecondsAgo: 600),
      userId: 'host',
    );

    await tester.pump(const Duration(seconds: 3));

    expect(db.states, isEmpty);
  });

  testWidgets('a bystander does not touch someone else\'s turn',
      (tester) async {
    final db = await _pumpBoard(
      tester,
      game: _game(seats: 4, turnIndex: 0, startedSecondsAgo: 120),
      userId: 'third',
    );

    await tester.pump(const Duration(seconds: 3));

    expect(db.states, isEmpty, reason: 'only the host may force a turn along');
  });

  testWidgets('the host forces an abandoned turn along', (tester) async {
    final db = await _pumpBoard(
      tester,
      game: _game(turnIndex: 1, startedSecondsAgo: 120),
      userId: 'host',
    );

    await tester.pump(const Duration(seconds: 1));

    expect(db.states, hasLength(1));
    expect(db.logs.single['playerId'], 'rival');
    expect(db.states.single['p2'], {'x': 4, 'y': 7},
        reason: 'the north pawn runs towards row 0');
    expect(db.turns.single, 0);
  });

  testWidgets('the host waits out the grace period before stepping in',
      (tester) async {
    final db = await _pumpBoard(
      tester,
      game: _game(turnIndex: 1, startedSecondsAgo: 61),
      userId: 'host',
    );

    await tester.pump(const Duration(seconds: 1));

    expect(db.states, isEmpty, reason: 'the rival still gets a few seconds');
  });

  testWidgets('a forced turn skips seats that resigned', (tester) async {
    final db = await _pumpBoard(
      tester,
      game: _game(
        seats: 4,
        turnIndex: 0,
        startedSecondsAgo: 120,
        resignedIds: const ['rival'],
      ),
      userId: 'host',
    );

    await tester.pump(const Duration(seconds: 1));

    expect(db.turns.single, 2, reason: 'seat 1 resigned, so it is skipped');
  });
}
