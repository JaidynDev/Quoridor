import 'package:flutter_test/flutter_test.dart';
import 'package:workspace/models/game_model.dart';
import 'package:workspace/models/move_clock.dart';
import 'package:workspace/models/quoridor_logic.dart';

GameModel _game({
  int limitSeconds = 60,
  String status = 'playing',
  DateTime? turnStartedAt,
}) {
  return GameModel(
    id: 'game',
    hostId: 'host',
    playerIds: const ['host', 'rival'],
    status: status,
    settings: GameSettings(timeLimitSeconds: limitSeconds),
    gameState: QuoridorLogic.initialState(2),
    turnStartedAt: turnStartedAt,
  );
}

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);

  test('counts down from the agreed limit', () {
    final game = _game(turnStartedAt: start);

    expect(
      MoveClock.remaining(game, now: start.add(const Duration(seconds: 20))),
      const Duration(seconds: 40),
    );
    expect(MoveClock.hasExpired(game, now: start), isFalse);
  });

  test('stops at zero and reports the overrun', () {
    final game = _game(turnStartedAt: start);
    final late = start.add(const Duration(seconds: 68));

    expect(MoveClock.remaining(game, now: late), Duration.zero);
    expect(MoveClock.overrun(game, now: late), const Duration(seconds: 8));
    expect(MoveClock.hasExpired(game, now: late), isTrue);
  });

  test('a turn is only abandoned once the grace period passes', () {
    final game = _game(turnStartedAt: start);

    expect(
      MoveClock.isAbandoned(game, now: start.add(const Duration(seconds: 62))),
      isFalse,
    );
    expect(
      MoveClock.isAbandoned(game, now: start.add(const Duration(seconds: 66))),
      isTrue,
    );
  });

  test('no clock runs without a limit, a start time or a live match', () {
    expect(
      MoveClock.remaining(_game(limitSeconds: 0, turnStartedAt: start)),
      isNull,
    );
    expect(MoveClock.remaining(_game()), isNull);
    expect(
      MoveClock.remaining(_game(status: 'waiting', turnStartedAt: start)),
      isNull,
    );
    expect(
      MoveClock.hasExpired(_game(limitSeconds: 0, turnStartedAt: start)),
      isFalse,
    );
  });

  test('reads a Firestore timestamp without importing the plugin', () {
    final game = GameModel.fromMap({
      'hostId': 'host',
      'playerIds': ['host', 'rival'],
      'status': 'playing',
      'settings': {'timeLimitSeconds': 60},
      'gameState': QuoridorLogic.initialState(2),
      'turnStartedAt': _FakeTimestamp(start),
      'resignedIds': ['rival'],
    }, 'game');

    expect(game.turnStartedAt, start);
    expect(game.hasResigned('rival'), isTrue);
    expect(game.activePlayerIds, ['host']);
    expect(game.resignedSeats, {1});
  });

  test('labels short and long clocks differently', () {
    expect(MoveClock.label(const Duration(seconds: 9)), '9s');
    expect(MoveClock.label(const Duration(seconds: 75)), '1:15');
    expect(MoveClock.label(const Duration(minutes: 5)), '5:00');
  });
}

/// Stands in for `cloud_firestore`'s Timestamp, which exposes `toDate()`.
class _FakeTimestamp {
  final DateTime value;
  const _FakeTimestamp(this.value);
  DateTime toDate() => value;
}
