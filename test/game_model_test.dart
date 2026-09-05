import 'package:flutter_test/flutter_test.dart';
import 'package:workspace/models/game_model.dart';

void main() {
  test('invite fields round-trip through GameModel', () {
    final game = GameModel(
      id: 'abc123',
      hostId: 'host',
      invitedUserId: 'friend',
      playerIds: const ['host'],
      status: 'waiting',
      settings: GameSettings(isPrivate: true, timeLimitSeconds: 60),
      gameState: const {},
    );

    final copy = GameModel.fromMap(game.toMap(), game.id);

    expect(copy.invitedUserId, 'friend');
    expect(copy.settings.isPrivate, isTrue);
    expect(copy.hostId, 'host');
  });

  test('match name and clock label describe the game', () {
    final named = GameSettings(name: 'Friday rematch', timeLimitSeconds: 300);
    expect(named.displayName, 'Friday rematch');
    expect(named.clockLabel, '5 min per move');

    final unnamed = GameSettings(timeLimitSeconds: 0);
    expect(unnamed.displayName, 'Quoridor match');
    expect(unnamed.clockLabel, 'No time limit');

    expect(GameSettings(timeLimitSeconds: 30).clockLabel, '30s per move');
    expect(GameSettings(playerCount: 4).seatsLabel, '4 players');
    expect(GameSettings.fromMap({'playerCount': 4}).seats, 4);
    expect(GameSettings.fromMap({}).seats, 2);
    expect(
      GameSettings.fromMap(named.toMap()).name,
      'Friday rematch',
    );
  });

  test('omits invitedUserId when the game is open', () {
    final game = GameModel(
      id: 'open',
      hostId: 'host',
      playerIds: const ['host'],
      status: 'waiting',
      settings: GameSettings(),
      gameState: const {},
    );

    expect(game.toMap().containsKey('invitedUserId'), isFalse);
  });

  test('session W/L counts rematch wins at this table', () {
    final game = GameModel(
      id: 'table',
      hostId: 'south',
      playerIds: const ['south', 'east', 'north', 'west'],
      status: 'finished',
      settings: GameSettings(playerCount: 4),
      winnerId: 'south',
      gameState: const {},
      sessionWins: const {
        'south': 2,
        'east': 1,
        'north': 0,
        'west': 0,
      },
    );

    expect(game.sessionGames, 3);
    expect(game.sessionWinsFor('south'), 2);
    expect(game.sessionLossesFor('south'), 1);
    expect(game.sessionWinsFor('east'), 1);
    expect(game.sessionLossesFor('east'), 2);
    expect(game.sessionWinsFor('west'), 0);
    expect(game.sessionLossesFor('west'), 3);

    final copy = GameModel.fromMap(game.toMap(), game.id);
    expect(copy.sessionWinsFor('south'), 2);
    expect(copy.recordedBy, isEmpty);
  });

  test('head-to-head maps series docs onto the local player', () {
    const data = {
      'player1Id': 'a',
      'player2Id': 'b',
      'p1Wins': 4,
      'p2Wins': 1,
    };
    expect(HeadToHead.fromSeries(data, 'a').scoreLabel, '4–1');
    expect(HeadToHead.fromSeries(data, 'b').scoreLabel, '1–4');
    expect(HeadToHead.fromSeries(null, 'a').scoreLabel, '0–0');
  });
}
