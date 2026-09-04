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
}
