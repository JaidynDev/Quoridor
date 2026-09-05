import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workspace/models/game_model.dart';
import 'package:workspace/models/user_model.dart';
import 'package:workspace/screens/game/game_result_screen.dart';

GameModel _fourPlayerGame() {
  return GameModel(
    id: 'table',
    hostId: 'south',
    playerIds: const ['south', 'east', 'north', 'west'],
    status: 'finished',
    settings: GameSettings(playerCount: 4),
    winnerId: 'east',
    gameState: const {},
    sessionWins: const {
      'south': 1,
      'east': 2,
      'north': 0,
      'west': 0,
    },
    recordedBy: const ['south'],
  );
}

void main() {
  testWidgets('four-player report lists every seat with session and vs-you', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: GameResultPanel(
          headline: 'Walls are hard, aren\'t they?',
          game: _fourPlayerGame(),
          currentUserId: 'south',
          playersById: {
            'south': AppUser(
              id: 'south',
              email: '',
              username: 'Guest',
              wins: 4,
              losses: 3,
            ),
            'east': AppUser(
              id: 'east',
              email: '',
              username: 'Alex',
              wins: 8,
              losses: 1,
            ),
            'north': AppUser(
              id: 'north',
              email: '',
              username: 'Sam',
              wins: 2,
              losses: 5,
            ),
            'west': AppUser(
              id: 'west',
              email: '',
              username: 'Riley',
              wins: 0,
              losses: 9,
            ),
          },
          vsYou: const {
            'east': HeadToHead(myWins: 3, theirWins: 5),
            'north': HeadToHead(myWins: 1, theirWins: 0),
            'west': HeadToHead(myWins: 2, theirWins: 2),
          },
          onRematch: () async {},
          onBackToMenu: () {},
        ),
      ),
    );

    expect(find.text('Guest (You)'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Riley'), findsOneWidget);
    expect(find.text('Winner'), findsOneWidget);
    expect(find.text('South'), findsOneWidget);
    expect(find.text('East'), findsOneWidget);
    expect(find.text('North'), findsOneWidget);
    expect(find.text('West'), findsOneWidget);

    expect(find.text('Session'), findsNWidgets(4));
    expect(find.text('Lifetime'), findsNWidgets(4));
    expect(find.text('You vs'), findsNWidgets(3));
    expect(find.text('(You)'), findsNothing);

    expect(find.text('1–2'), findsOneWidget); // south session
    expect(find.text('2–1'), findsOneWidget); // east session
    expect(find.text('0–3'), findsNWidgets(2)); // north and west session
    expect(find.text('4–3'), findsOneWidget); // south lifetime
    expect(find.text('3–5'), findsOneWidget); // vs Alex
    expect(find.text('Rematch'), findsOneWidget);
    expect(find.text('Back to Menu'), findsOneWidget);
  });

  testWidgets('two-player report still names you on the local seat', (
    tester,
  ) async {
    final game = GameModel(
      id: 'duel',
      hostId: 'me',
      playerIds: const ['me', 'them'],
      status: 'finished',
      settings: GameSettings(),
      winnerId: 'me',
      gameState: const {},
      sessionWins: const {'me': 1, 'them': 0},
      recordedBy: const ['me'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameResultPanel(
          headline: 'Nice job!',
          game: game,
          currentUserId: 'me',
          playersById: {
            'me': AppUser(id: 'me', email: '', username: 'Pat', wins: 1, losses: 0),
            'them': AppUser(
              id: 'them',
              email: '',
              username: 'Kim',
              wins: 4,
              losses: 6,
            ),
          },
          vsYou: const {'them': HeadToHead(myWins: 1, theirWins: 4)},
          onRematch: () async {},
          onBackToMenu: () {},
        ),
      ),
    );

    expect(find.text('Pat (You)'), findsOneWidget);
    expect(find.text('Kim'), findsOneWidget);
    expect(find.text('You vs'), findsOneWidget);
    expect(find.text('1–4'), findsOneWidget);
    expect(find.text('Waiting for opponent...'), findsNothing);
  });
}
