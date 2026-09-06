import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/quoridor_logic.dart';
import '../../models/user_model.dart';

const Color kBoardFrameSide = Color(0xFF43301F);
const Color kBoardFrameTop = Color(0xFF6A4830);
const Color kTileLight = Color(0xFFEBD1A6);
const Color kTileDark = Color(0xFFDCBD8B);
const Color kWallWood = Color(0xFF965F31);
const Color kMoveAccent = Color(0xFF2FBE8C);
const Color kInvalidAccent = Color(0xFFDF5B4F);
const Color kP1Color = Color(0xFFF7E9C8);
const Color kP2Color = Color(0xFF2F4A5C);
const Color kP3Color = Color(0xFFC45C26);
const Color kP4Color = Color(0xFF16705B);
const List<Color> kPawnColors = [kP1Color, kP2Color, kP3Color, kP4Color];

/// Fixed three-quarter camera that maps board coordinates to the screen.
///
/// Board space uses cell units: `x` and `y` run 0..9 across the grid and `z`
/// points up out of the floor. The yaw is what makes walls read as solid
/// boxes; a straight forward tilt leaves their end caps edge-on and invisible.
class BoardProjection {
  static const double span = 9.0;
  static const double wallThickness = 0.17;
  static const double wallHeight = 0.52;
  static const double wallInset = 0.03;
  static const double frameMargin = 0.42;
  static const double frameDepth = 0.28;

  static const double _elevation = 0.94;
  static const double _yaw = 0.30;
  static const double _camDistance = 24.0;

  final double focal;
  final Offset origin;
  final int rotation;

  bool get flipped => rotation == 2;

  const BoardProjection({
    required this.focal,
    required this.origin,
    this.rotation = 0,
  });

  /// Scales and centres the camera so the whole board fits inside [size].
  factory BoardProjection.fit(
    Size size, {
    bool flipped = false,
    int? rotation,
  }) {
    final rot = rotation ?? (flipped ? 2 : 0);
    final probe = BoardProjection(focal: 1, origin: Offset.zero, rotation: rot);
    const m = frameMargin;
    const heads = wallHeight + 0.85;

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final x in const [-m, span + m]) {
      for (final y in const [-m, span + m]) {
        for (final z in const [-frameDepth, heads]) {
          final p = probe.project(x, y, z);
          minX = math.min(minX, p.dx);
          maxX = math.max(maxX, p.dx);
          minY = math.min(minY, p.dy);
          maxY = math.max(maxY, p.dy);
        }
      }
    }

    const pad = 8.0;
    final available = Size(
      math.max(size.width - pad * 2, 1),
      math.max(size.height - pad * 2, 1),
    );
    final focal = math.min(
      available.width / (maxX - minX),
      available.height / (maxY - minY),
    );

    return BoardProjection(
      focal: focal,
      origin: Offset(
        size.width / 2 - (minX + maxX) / 2 * focal,
        size.height / 2 - (minY + maxY) / 2 * focal,
      ),
      rotation: rot,
    );
  }

  /// Rotate in the board plane so a given seat sits nearest the camera.
  static List<double> _rotate(double cx, double cy, int steps) {
    var x = cx;
    var y = cy;
    final n = ((steps % 4) + 4) % 4;
    for (var i = 0; i < n; i++) {
      final t = x;
      x = y;
      y = -t;
    }
    return [x, y];
  }

  Offset project(double x, double y, double z) {
    final c = _camera(x, y, z);
    return origin + Offset(c.x / c.z, -c.y / c.z) * focal;
  }

  /// Distance from the camera, used to sort what gets painted first.
  double depthAt(double x, double y, double z) => _camera(x, y, z).z;

  /// Screen pixels per cell unit at the given board location.
  double scaleAt(double x, double y, [double z = 0]) =>
      focal / _camera(x, y, z).z;

  /// Maps a screen point back onto the floor plane, in cell units.
  Offset? unproject(Offset screen) {
    final n = (screen - origin) / focal;
    final sinE = math.sin(_elevation);
    final cosE = math.cos(_elevation);

    final denom = n.dy * cosE + sinE;
    if (denom.abs() < 1e-6) return null;

    final ry = -n.dy * _camDistance / denom;
    final camZ = ry * cosE + _camDistance;
    if (camZ <= 0.01) return null;

    final rx = n.dx * camZ;
    final cosY = math.cos(_yaw);
    final sinY = math.sin(_yaw);
    var cx = rx * cosY + ry * sinY;
    var cy = -rx * sinY + ry * cosY;
    final inv = _rotate(cx, cy, (4 - rotation) % 4);
    return Offset(inv[0] + span / 2, inv[1] + span / 2);
  }

  _CameraPoint _camera(double x, double y, double z) {
    var cx = x - span / 2;
    var cy = y - span / 2;
    final rot = _rotate(cx, cy, rotation);
    cx = rot[0];
    cy = rot[1];

    final cosY = math.cos(_yaw);
    final sinY = math.sin(_yaw);
    final rx = cx * cosY - cy * sinY;
    final ry = cx * sinY + cy * cosY;

    final sinE = math.sin(_elevation);
    final cosE = math.cos(_elevation);
    return _CameraPoint(
      rx,
      ry * sinE + z * cosE,
      ry * cosE - z * sinE + _camDistance,
    );
  }
}

class _CameraPoint {
  final double x;
  final double y;
  final double z;
  const _CameraPoint(this.x, this.y, this.z);
}

/// Bounds of a wall's footprint in cell units.
Rect wallFootprint(Wall wall) {
  const t = BoardProjection.wallThickness;
  const inset = BoardProjection.wallInset;
  if (wall.orientation == 0) {
    final line = wall.y + 1.0;
    return Rect.fromLTRB(
      wall.x + inset,
      line - t / 2,
      wall.x + 2.0 - inset,
      line + t / 2,
    );
  }
  final line = wall.x + 1.0;
  return Rect.fromLTRB(
    line - t / 2,
    wall.y + inset,
    line + t / 2,
    wall.y + 2.0 - inset,
  );
}

class _Face {
  final List<Offset> points;
  final List<double> normal;
  final double depth;
  const _Face(this.points, this.normal, this.depth);
}

class BoardPainter extends CustomPainter {
  final BoardProjection proj;
  final List<Wall> walls;
  final Set<Position> validMoves;
  final Wall? ghostWall;
  final bool ghostValid;
  final double pulse;

  BoardPainter({
    required this.proj,
    required this.walls,
    required this.validMoves,
    required this.pulse,
    this.ghostWall,
    this.ghostValid = true,
  });

  // Direction towards the light, used to shade every box face.
  static const List<double> _light = [-0.42, -0.32, 0.85];

  @override
  void paint(Canvas canvas, Size size) {
    _paintCastShadow(canvas);
    _paintFrame(canvas);
    _paintGoalInlays(canvas);
    _paintTiles(canvas);
    _paintMoveHints(canvas);
    _paintWalls(canvas);
  }

  void _paintCastShadow(Canvas canvas) {
    const m = BoardProjection.frameMargin;
    final path = _poly([
      proj.project(-m, -m, -BoardProjection.frameDepth),
      proj.project(BoardProjection.span + m, -m, -BoardProjection.frameDepth),
      proj.project(
          BoardProjection.span + m, BoardProjection.span + m, -BoardProjection.frameDepth),
      proj.project(-m, BoardProjection.span + m, -BoardProjection.frameDepth),
    ]).shift(const Offset(6, 14));

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _paintFrame(Canvas canvas) {
    const m = BoardProjection.frameMargin;
    final faces = _boxFaces(
      -m,
      -m,
      BoardProjection.span + m,
      BoardProjection.span + m,
      -BoardProjection.frameDepth,
      0,
    )..sort((a, b) => b.depth.compareTo(a.depth));

    for (final face in faces) {
      final isTop = face.normal[2] > 0.5;
      _fillFace(canvas, face, isTop ? kBoardFrameTop : kBoardFrameSide);
    }

    final rim = _poly([
      proj.project(-m, -m, 0),
      proj.project(BoardProjection.span + m, -m, 0),
      proj.project(BoardProjection.span + m, BoardProjection.span + m, 0),
      proj.project(-m, BoardProjection.span + m, 0),
    ]);
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.10),
    );
  }

  /// Coloured inlays on the frame marking the row each player is running for.
  void _paintGoalInlays(Canvas canvas) {
    const span = BoardProjection.span;
    void inlay(double y0, double y1, Color color) {
      final path = _poly([
        proj.project(0, y0, 0),
        proj.project(span, y0, 0),
        proj.project(span, y1, 0),
        proj.project(0, y1, 0),
      ]);
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(color, kBoardFrameSide, 0.32)!
              .withValues(alpha: 0.75),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = Colors.black.withValues(alpha: 0.22),
      );
    }

    inlay(-0.28, -0.13, kP2Color);
    inlay(span + 0.13, span + 0.28, kP1Color);
  }

  void _paintTiles(Canvas canvas) {
    const g = 0.035;
    const span = BoardProjection.span;

    // Tiles further from the camera settle into the frame's shadow, which is
    // what sells the depth. Measured per tile so it follows the yaw.
    final dA = proj.depthAt(span / 2, 0.5, 0);
    final dB = proj.depthAt(span / 2, span - 0.5, 0);
    final near = math.min(dA, dB);
    final far = math.max(dA, dB);

    for (int y = 0; y < span; y++) {
      for (int x = 0; x < span; x++) {
        final base = (x + y).isEven ? kTileLight : kTileDark;
        final t = far - near < 1e-6
            ? 0.0
            : ((proj.depthAt(x + 0.5, y + 0.5, 0) - near) / (far - near))
                .clamp(0.0, 1.0);
        final color = Color.lerp(base, kBoardFrameSide, t * 0.26)!;

        canvas.drawPath(
          _poly([
            proj.project(x + g, y + g, 0),
            proj.project(x + 1 - g, y + g, 0),
            proj.project(x + 1 - g, y + 1 - g, 0),
            proj.project(x + g, y + 1 - g, 0),
          ]),
          Paint()
            ..color = color
            ..isAntiAlias = true,
        );
      }
    }
  }

  void _paintMoveHints(Canvas canvas) {
    if (validMoves.isEmpty) return;
    const g = 0.06;
    final glow = 0.55 + 0.45 * pulse;

    for (final move in validMoves) {
      final tile = _poly([
        proj.project(move.x + g, move.y + g, 0),
        proj.project(move.x + 1 - g, move.y + g, 0),
        proj.project(move.x + 1 - g, move.y + 1 - g, 0),
        proj.project(move.x + g, move.y + 1 - g, 0),
      ]);

      canvas.drawPath(
        tile,
        Paint()..color = kMoveAccent.withValues(alpha: 0.20 * glow),
      );
      canvas.drawPath(
        tile,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = kMoveAccent.withValues(alpha: 0.75 * glow),
      );

      final centre = proj.project(move.x + 0.5, move.y + 0.5, 0);
      final r = proj.scaleAt(move.x + 0.5, move.y + 0.5) * 0.10;
      canvas.drawCircle(
        centre,
        r * (0.85 + 0.15 * pulse),
        Paint()
          ..color = kMoveAccent.withValues(alpha: 0.9)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
      );
      canvas.drawCircle(centre, r * 0.55, Paint()..color = Colors.white70);
    }
  }

  void _paintWalls(Canvas canvas) {
    final ordered = [...walls]
      ..sort((a, b) => _wallDepth(b).compareTo(_wallDepth(a)));
    for (final wall in ordered) {
      _paintWall(canvas, wall, kWallWood, 1.0);
    }

    if (ghostWall != null) {
      _paintWall(
        canvas,
        ghostWall!,
        ghostValid ? kMoveAccent : kInvalidAccent,
        0.52 + 0.18 * pulse,
      );
    }
  }

  double _wallDepth(Wall wall) {
    final r = wallFootprint(wall);
    return proj.depthAt(r.center.dx, r.center.dy, BoardProjection.wallHeight / 2);
  }

  void _paintWall(Canvas canvas, Wall wall, Color wood, double alpha) {
    final r = wallFootprint(wall);
    const h = BoardProjection.wallHeight;

    final shadowShift = Offset(-_light[0], -_light[1]) * (h * 0.5);
    canvas.drawPath(
      _poly([
        proj.project(r.left + shadowShift.dx, r.top + shadowShift.dy, 0),
        proj.project(r.right + shadowShift.dx, r.top + shadowShift.dy, 0),
        proj.project(r.right + shadowShift.dx, r.bottom + shadowShift.dy, 0),
        proj.project(r.left + shadowShift.dx, r.bottom + shadowShift.dy, 0),
      ]),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.26 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final faces = _boxFaces(r.left, r.top, r.right, r.bottom, 0, h)
      ..sort((a, b) => b.depth.compareTo(a.depth));
    if (faces.isEmpty) return;

    for (final face in faces) {
      _fillFace(canvas, face, wood, alpha: alpha);
      canvas.drawPath(
        _poly(face.points),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = _scaleRgb(wood, _brightness(face.normal) * 0.6)
              .withValues(alpha: 0.55 * alpha),
      );
    }

    final top = faces.firstWhere(
      (f) => f.normal[2] > 0.5,
      orElse: () => faces.first,
    );
    canvas.drawPath(
      _poly(top.points),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = Colors.white.withValues(alpha: 0.22 * alpha),
    );
  }

  /// Front-facing quads of an axis-aligned box, already projected.
  ///
  /// Corners of each face are wound counter-clockwise about the outward
  /// normal, so a projected face that winds the other way is pointing away
  /// from the camera and gets dropped.
  List<_Face> _boxFaces(
    double x0,
    double y0,
    double x1,
    double y1,
    double z0,
    double z1,
  ) {
    final faces = <_Face>[];

    void add(List<List<double>> corners, List<double> normal) {
      final points = corners.map((c) => proj.project(c[0], c[1], c[2])).toList();
      if (_signedArea(points) >= 0) return;
      var depth = 0.0;
      for (final c in corners) {
        depth += proj.depthAt(c[0], c[1], c[2]);
      }
      faces.add(_Face(points, normal, depth / corners.length));
    }

    add([
      [x0, y0, z1],
      [x1, y0, z1],
      [x1, y1, z1],
      [x0, y1, z1],
    ], const [0.0, 0.0, 1.0]);
    add([
      [x0, y0, z0],
      [x1, y0, z0],
      [x1, y0, z1],
      [x0, y0, z1],
    ], const [0.0, -1.0, 0.0]);
    add([
      [x0, y1, z0],
      [x0, y1, z1],
      [x1, y1, z1],
      [x1, y1, z0],
    ], const [0.0, 1.0, 0.0]);
    add([
      [x0, y0, z0],
      [x0, y0, z1],
      [x0, y1, z1],
      [x0, y1, z0],
    ], const [-1.0, 0.0, 0.0]);
    add([
      [x1, y0, z0],
      [x1, y1, z0],
      [x1, y1, z1],
      [x1, y0, z1],
    ], const [1.0, 0.0, 0.0]);

    return faces;
  }

  void _fillFace(Canvas canvas, _Face face, Color base, {double alpha = 1.0}) {
    final b = _brightness(face.normal);
    final path = _poly(face.points);
    final bounds = path.getBounds().inflate(0.5);

    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _scaleRgb(base, b * 1.10).withValues(alpha: alpha),
            _scaleRgb(base, b * 0.88).withValues(alpha: alpha),
          ],
        ).createShader(bounds),
    );
  }

  double _brightness(List<double> n) {
    final dot = n[0] * _light[0] + n[1] * _light[1] + n[2] * _light[2];
    return 0.38 + 0.72 * math.max(0.0, dot);
  }

  static Color _scaleRgb(Color c, double f) => Color.from(
        alpha: c.a,
        red: (c.r * f).clamp(0.0, 1.0),
        green: (c.g * f).clamp(0.0, 1.0),
        blue: (c.b * f).clamp(0.0, 1.0),
      );

  static Path _poly(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static double _signedArea(List<Offset> pts) {
    var sum = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum / 2;
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.proj.focal != proj.focal ||
      old.proj.origin != proj.origin ||
      old.proj.rotation != proj.rotation ||
      old.pulse != pulse ||
      old.ghostWall != ghostWall ||
      old.ghostValid != ghostValid ||
      old.walls.length != walls.length ||
      !setEquals(old.validMoves, validMoves);
}

/// An upright pawn: a wooden base with the player's avatar as its head.
///
/// The piece is drawn as a screen-space billboard so it never inherits the
/// board's tilt, which is what used to stretch the avatars.
class BoardPiece extends StatelessWidget {
  final AppUser? user;
  final Color color;
  final double diameter;
  final bool isActive;
  final double pulse;
  final VoidCallback? onTap;

  const BoardPiece({
    super.key,
    required this.user,
    required this.color,
    required this.diameter,
    required this.isActive,
    required this.pulse,
    this.onTap,
  });

  static Size boxFor(double diameter) =>
      Size(diameter * 1.34, diameter * 1.46);

  /// Where the piece meets the floor, relative to its box.
  static Offset anchorFor(double diameter) =>
      Offset(diameter * 0.67, diameter * 1.28);

  @override
  Widget build(BuildContext context) {
    final d = diameter;
    final box = boxFor(d);
    final light = color.computeLuminance() > 0.5;
    final iconColor = light ? const Color(0xFF4A3520) : Colors.white;

    return SizedBox(
      width: box.width,
      height: box.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PawnStandPainter(diameter: d, color: color),
            ),
          ),
          Positioned(
            left: (box.width - d) / 2,
            top: 0,
            width: d,
            height: d,
            child: GestureDetector(
              onTap: onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      BoardPainter._scaleRgb(color, 1.12),
                      BoardPainter._scaleRgb(color, 0.82),
                    ],
                  ),
                  border: Border.all(
                    color: isActive
                        ? kMoveAccent.withValues(alpha: 0.75 + 0.25 * pulse)
                        : Colors.white.withValues(alpha: 0.85),
                    width: d * 0.06,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: d * 0.16,
                      offset: Offset(0, d * 0.07),
                    ),
                    if (isActive)
                      BoxShadow(
                        color: kMoveAccent
                            .withValues(alpha: 0.30 + 0.30 * pulse),
                        blurRadius: d * 0.42,
                        spreadRadius: d * 0.04,
                      ),
                  ],
                  image: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(user!.photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                    ? null
                    : Center(
                        child: Icon(
                          Icons.person,
                          size: d * 0.52,
                          color: iconColor,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The turned base the avatar sits on: contact shadow, tapered stem, foot.
class _PawnStandPainter extends CustomPainter {
  final double diameter;
  final Color color;

  const _PawnStandPainter({required this.diameter, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final d = diameter;
    final cx = size.width / 2;
    final footY = d * 1.28;

    // Turned-wood tone, so a pale player colour still reads against the tiles.
    final tone = Color.lerp(color, const Color(0xFF3B2718), 0.42)!;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = d * 0.028
      ..color = BoardPainter._scaleRgb(tone, 0.42).withValues(alpha: 0.8);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + d * 0.06, footY + d * 0.04),
        width: d * 1.08,
        height: d * 0.38,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d * 0.07),
    );

    final stem = Path()
      ..moveTo(cx - d * 0.21, d * 0.76)
      ..lineTo(cx + d * 0.21, d * 0.76)
      ..lineTo(cx + d * 0.34, footY)
      ..lineTo(cx - d * 0.34, footY)
      ..close();
    canvas.drawPath(
      stem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BoardPainter._scaleRgb(tone, 1.0),
            BoardPainter._scaleRgb(tone, 0.52),
          ],
        ).createShader(
            Rect.fromLTWH(cx - d * 0.34, d * 0.76, d * 0.68, d * 0.52)),
    );
    canvas.drawPath(stem, edge);

    final foot = Rect.fromCenter(
      center: Offset(cx, footY),
      width: d * 0.88,
      height: d * 0.29,
    );
    canvas.drawOval(
      foot,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BoardPainter._scaleRgb(tone, 1.15),
            BoardPainter._scaleRgb(tone, 0.55),
          ],
        ).createShader(foot),
    );
    canvas.drawOval(foot, edge);
    canvas.drawOval(
      foot.deflate(d * 0.03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = d * 0.02
        ..color = Colors.white.withValues(alpha: 0.20),
    );
  }

  @override
  bool shouldRepaint(_PawnStandPainter old) =>
      old.diameter != diameter || old.color != color;
}
