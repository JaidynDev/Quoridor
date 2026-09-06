import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workspace/models/quoridor_logic.dart';
import 'package:workspace/screens/game/board_3d.dart';

void main() {
  group('BoardProjection', () {
    const size = Size(600, 800);

    test('unproject inverts project on the floor plane', () {
      for (final flipped in [false, true]) {
        final proj = BoardProjection.fit(size, flipped: flipped);

        for (double y = 0.5; y < BoardProjection.span; y += 1) {
          for (double x = 0.5; x < BoardProjection.span; x += 1) {
            final screen = proj.project(x, y, 0);
            final back = proj.unproject(screen);

            expect(back, isNotNull, reason: 'flipped=$flipped at ($x, $y)');
            expect(back!.dx, closeTo(x, 0.001),
                reason: 'flipped=$flipped at ($x, $y)');
            expect(back.dy, closeTo(y, 0.001),
                reason: 'flipped=$flipped at ($x, $y)');
          }
        }
      }
    });

    test('a tapped cell centre maps back to that cell', () {
      for (final flipped in [false, true]) {
        final proj = BoardProjection.fit(size, flipped: flipped);

        for (int cellY = 0; cellY < 9; cellY++) {
          for (int cellX = 0; cellX < 9; cellX++) {
            final screen = proj.project(cellX + 0.5, cellY + 0.5, 0);
            final board = proj.unproject(screen)!;

            expect(board.dx.floor(), cellX, reason: 'flipped=$flipped');
            expect(board.dy.floor(), cellY, reason: 'flipped=$flipped');
          }
        }
      }
    });

    test('flipping turns the board a half turn rather than mirroring it', () {
      final normal = BoardProjection.fit(size, flipped: false);
      final flipped = BoardProjection.fit(size, flipped: true);

      // The cell player 1 starts on should land where player 2's start sits in
      // the opposite view.
      final p1Start = normal.project(4.5, 0.5, 0);
      final p2StartFlipped = flipped.project(4.5, 8.5, 0);

      expect(p1Start.dx, closeTo(p2StartFlipped.dx, 0.001));
      expect(p1Start.dy, closeTo(p2StartFlipped.dy, 0.001));
    });

    test('quarter turns still invert on the floor plane', () {
      for (final rotation in [0, 1, 2, 3]) {
        final proj = BoardProjection.fit(size, rotation: rotation);

        for (double y = 0.5; y < BoardProjection.span; y += 1) {
          for (double x = 0.5; x < BoardProjection.span; x += 1) {
            final screen = proj.project(x, y, 0);
            final back = proj.unproject(screen);

            expect(back, isNotNull, reason: 'rotation=$rotation at ($x, $y)');
            expect(back!.dx, closeTo(x, 0.001),
                reason: 'rotation=$rotation at ($x, $y)');
            expect(back.dy, closeTo(y, 0.001),
                reason: 'rotation=$rotation at ($x, $y)');
          }
        }
      }
    });

    test('east seat sits at the near edge of the camera', () {
      final south = BoardProjection.fit(size, rotation: 0);
      final east = BoardProjection.fit(size, rotation: 1);

      final southStart = south.project(4.5, 0.5, 0);
      final eastStart = east.project(8.5, 4.5, 0);

      expect(southStart.dx, closeTo(eastStart.dx, 0.001));
      expect(southStart.dy, closeTo(eastStart.dy, 0.001));
    });

    test('nearer cells project larger than far cells', () {
      final proj = BoardProjection.fit(size, flipped: false);
      expect(proj.scaleAt(4.5, 0.5), greaterThan(proj.scaleAt(4.5, 8.5)));
    });

    test('board fits inside the given size', () {
      final proj = BoardProjection.fit(size, flipped: false);
      for (final x in [0.0, BoardProjection.span]) {
        for (final y in [0.0, BoardProjection.span]) {
          final p = proj.project(x, y, 0);
          expect(p.dx, inInclusiveRange(0, size.width));
          expect(p.dy, inInclusiveRange(0, size.height));
        }
      }
    });
  });

  group('wallFootprint', () {
    test('horizontal walls straddle the line below their row', () {
      final r = wallFootprint(const Wall(3, 4, 0));
      expect(r.center.dy, closeTo(5.0, 0.0001));
      expect(r.left, greaterThanOrEqualTo(3.0));
      expect(r.right, lessThanOrEqualTo(5.0));
      expect(r.width, greaterThan(r.height));
    });

    test('vertical walls straddle the line right of their column', () {
      final r = wallFootprint(const Wall(3, 4, 1));
      expect(r.center.dx, closeTo(4.0, 0.0001));
      expect(r.top, greaterThanOrEqualTo(4.0));
      expect(r.bottom, lessThanOrEqualTo(6.0));
      expect(r.height, greaterThan(r.width));
    });
  });
}
