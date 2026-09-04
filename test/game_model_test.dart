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
