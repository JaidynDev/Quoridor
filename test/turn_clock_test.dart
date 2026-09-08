import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workspace/models/game_model.dart';
import 'package:workspace/models/quoridor_logic.dart';
import 'package:workspace/screens/game/game_screen.dart';

final _turnStart = DateTime.utc(2026, 1, 1, 12);

GameModel _game({int limitSeconds = 60}) {
  return GameModel(
    id: 'game',
    hostId: 'host',
    playerIds: const ['host', 'rival'],
    status: 'playing',
    settings: GameSettings(timeLimitSeconds: limitSeconds),
    gameState: QuoridorLogic.initialState(2),
    turnStartedAt: _turnStart,
  );
}

Future<void> _pump(
  WidgetTester tester,
  GameModel game,
  DateTime Function() now,
) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: TurnClock(game: game, now: now))),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the time left on the current turn', (tester) async {
    await _pump(
      tester,
      _game(),
      () => _turnStart.add(const Duration(seconds: 15)),
    );

    expect(find.text('45s'), findsOneWidget);
  });

  testWidgets('ticks down once a second', (tester) async {
    var now = _turnStart.add(const Duration(seconds: 15));
    await _pump(tester, _game(), () => now);

    expect(find.text('45s'), findsOneWidget);

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('45s'), findsNothing);
    expect(find.text('43s'), findsOneWidget);
  });

  testWidgets('uses minutes on a longer clock', (tester) async {
    await _pump(
      tester,
      _game(limitSeconds: 300),
      () => _turnStart.add(const Duration(seconds: 45)),
    );

    expect(find.text('4:15'), findsOneWidget);
  });

  testWidgets('bottoms out at zero rather than going negative',
      (tester) async {
    await _pump(
      tester,
      _game(),
      () => _turnStart.add(const Duration(seconds: 90)),
    );

    expect(find.text('0s'), findsOneWidget);
  });

  testWidgets('shows nothing when the match has no clock', (tester) async {
    await _pump(
      tester,
      _game(limitSeconds: 0),
      () => _turnStart.add(const Duration(seconds: 10)),
    );

    expect(find.byType(Text), findsNothing);
  });
}
