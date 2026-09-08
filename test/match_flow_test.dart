import 'package:flutter_test/flutter_test.dart';
import 'package:workspace/models/match_flow.dart';
import 'package:workspace/models/quoridor_logic.dart';

void main() {
  group('resignation', () {
    test('in a two-player match the other player wins', () {
      final outcome = resolveResignation(
        playerIds: const ['host', 'rival'],
        resignedIds: const [],
        resignerId: 'host',
        currentTurnIndex: 0,
      );

      expect(outcome.changed, isTrue);
      expect(outcome.winnerId, 'rival');
      expect(outcome.resignedIds, ['host']);
    });

    test('with four at the table the rest play on', () {
      final outcome = resolveResignation(
        playerIds: const ['a', 'b', 'c', 'd'],
        resignedIds: const [],
        resignerId: 'b',
        currentTurnIndex: 1,
      );

      expect(outcome.winnerId, isNull);
      expect(outcome.resignedIds, ['b']);
      expect(outcome.nextTurnIndex, 2, reason: 'turn passes on from seat b');
    });

    test('someone leaving out of turn does not steal the turn', () {
      final outcome = resolveResignation(
        playerIds: const ['a', 'b', 'c'],
        resignedIds: const [],
        resignerId: 'c',
        currentTurnIndex: 0,
      );

      expect(outcome.nextTurnIndex, 0);
    });

    test('the last player standing wins after the others drop out', () {
      final outcome = resolveResignation(
        playerIds: const ['a', 'b', 'c'],
        resignedIds: const ['b'],
        resignerId: 'c',
        currentTurnIndex: 2,
      );

      expect(outcome.winnerId, 'a');
      expect(outcome.resignedIds, ['b', 'c']);
    });

    test('resigning twice, or as a spectator, changes nothing', () {
      expect(
        resolveResignation(
          playerIds: const ['a', 'b'],
          resignedIds: const ['a'],
          resignerId: 'a',
          currentTurnIndex: 0,
        ).changed,
        isFalse,
      );
      expect(
        resolveResignation(
          playerIds: const ['a', 'b'],
          resignedIds: const [],
          resignerId: 'stranger',
          currentTurnIndex: 0,
        ).changed,
        isFalse,
      );
    });
  });

  group('turn order', () {
    test('skips seats that have dropped out', () {
      expect(QuoridorLogic.nextActiveSeat(0, 4, out: const {1}), 2);
      expect(QuoridorLogic.nextActiveSeat(0, 4, out: const {1, 2}), 3);
      expect(QuoridorLogic.nextActiveSeat(3, 4, out: const {0}), 1);
    });

    test('stays put when everyone else has dropped out', () {
      expect(QuoridorLogic.nextActiveSeat(2, 4, out: const {0, 1, 3}), 2);
    });
  });

  group('timeout step', () {
    test('walks the pawn towards its own goal row', () {
      final south = QuoridorLogic.twoPlayerSeats[0];
      final step = QuoridorLogic.stepTowardGoal(
        const Position(4, 0),
        const [],
        const [Position(4, 8)],
        south,
      );

      expect(step, const Position(4, 1), reason: 'straight down the board');
    });

    test('routes around a wall instead of butting into it', () {
      final south = QuoridorLogic.twoPlayerSeats[0];
      final walls = [const Wall(3, 0, 0), const Wall(5, 0, 0)];

      final step = QuoridorLogic.stepTowardGoal(
        const Position(4, 0),
        walls,
        const [Position(4, 8)],
        south,
      );

      expect(step, isNotNull);
      expect(step!.y, 0, reason: 'the way down is walled off, so step aside');
      expect([3, 5], contains(step.x));
    });

    test('the north seat heads the other way', () {
      final north = QuoridorLogic.twoPlayerSeats[1];
      final step = QuoridorLogic.stepTowardGoal(
        const Position(4, 8),
        const [],
        const [Position(4, 0)],
        north,
      );

      expect(step, const Position(4, 7));
    });

    test('the east seat runs across the board', () {
      final east = QuoridorLogic.fourPlayerSeats[1];
      final step = QuoridorLogic.stepTowardGoal(
        const Position(8, 4),
        const [],
        const [],
        east,
      );

      expect(step, const Position(7, 4));
    });
  });
}
