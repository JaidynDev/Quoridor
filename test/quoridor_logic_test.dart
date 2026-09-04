import 'package:flutter_test/flutter_test.dart';
import 'package:workspace/models/quoridor_logic.dart';

void main() {
  group('four-player setup', () {
    test('starts one pawn on each edge with five walls', () {
      final state = QuoridorLogic.initialState(4);
      expect(state['p1'], {'x': 4, 'y': 0});
      expect(state['p2'], {'x': 8, 'y': 4});
      expect(state['p3'], {'x': 4, 'y': 8});
      expect(state['p4'], {'x': 0, 'y': 4});
      expect(state['p1WallsLeft'], 5);
      expect(state['p4WallsLeft'], 5);
      expect(QuoridorLogic.wallsEach(2), 10);
    });

    test('east player wins on the west edge', () {
      final east = QuoridorLogic.fourPlayerSeats[1];
      expect(east.reachedGoal(const Position(0, 4)), isTrue);
      expect(east.reachedGoal(const Position(0, 7)), isTrue);
      expect(east.reachedGoal(const Position(1, 4)), isFalse);
    });

    test('a wall is illegal if it seals any of the four paths', () {
      final pawns = QuoridorLogic.pawnsFromState(
        QuoridorLogic.initialState(4),
        4,
      );
      final seats = QuoridorLogic.fourPlayerSeats;

      // A vertical stack that would close the west player's only eastbound
      // corridor along row 4 is still legal as long as they can go around.
      expect(
        QuoridorLogic.isValidWall(const Wall(3, 3, 1), const [], pawns, seats),
        isTrue,
      );
    });
  });

  group('two-player paths still hold', () {
    test('p1 cannot be walled off from y=8', () {
      final pawns = [const Position(4, 0), const Position(4, 8)];
      final seats = QuoridorLogic.twoPlayerSeats;
      expect(
        QuoridorLogic.isValidWall(const Wall(3, 0, 0), const [], pawns, seats),
        isTrue,
      );
    });
  });

  group('jumps', () {
    test('cannot land on a third pawn, so the jump fans out', () {
      const me = Position(4, 4);
      const blocker = Position(4, 5);
      const behind = Position(4, 6);
      final moves = QuoridorLogic.getValidMoves(me, const [], [blocker, behind]);
      expect(moves.contains(behind), isFalse);
      expect(moves.contains(const Position(3, 5)), isTrue);
      expect(moves.contains(const Position(5, 5)), isTrue);
    });
  });
}
