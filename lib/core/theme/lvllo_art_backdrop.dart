import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The visual language of LVL LOOL's approved vertical entry artwork.
/// It is deliberately drawn in Flutter so the same art direction can be
/// reused at every resolution without adding a large raster asset.
class LvlloArtBackdrop extends StatelessWidget {
  const LvlloArtBackdrop({
    super.key,
    required this.child,
    this.showDevil = true,
    this.showGrid = true,
    this.showPlatform = false,
  });

  final Widget child;
  final bool showDevil;
  final bool showGrid;
  final bool showPlatform;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF07123A),
            Color(0xFF090E2B),
            Color(0xFF050716),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _LvlloArtPainter(
              showDevil: showDevil,
              showGrid: showGrid,
              showPlatform: showPlatform,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _LvlloArtPainter extends CustomPainter {
  _LvlloArtPainter({required this.showDevil, required this.showGrid, required this.showPlatform});

  final bool showDevil;
  final bool showGrid;
  final bool showPlatform;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bg = Paint()..style = PaintingStyle.fill;

    // Deep blue/purple light field.
    bg.shader = RadialGradient(
      center: const Alignment(-.12, -.18),
      radius: 1.05,
      colors: const [
        Color(0xFF183D96),
        Color(0xFF101B52),
        Color(0x00070A20),
      ],
      stops: const [0, .42, 1],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    if (showGrid) {
      final grid = Paint()
        ..color = const Color(0x183B5BC6)
        ..strokeWidth = 1;
      for (double x = 0; x <= w; x += 34) {
        canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
      }
      for (double y = 0; y <= h; y += 34) {
        canvas.drawLine(Offset(0, y), Offset(w, y), grid);
      }
    }

    // Angular shards — the distinctive LVL LOOL mountain/portal language.
    _poly(canvas, [
      Offset(0, h * .14), Offset(w * .18, h * .04), Offset(w * .32, h * .19),
      Offset(w * .19, h * .32), Offset(0, h * .25),
    ], const Color(0xFF0A1B55));
    _poly(canvas, [
      Offset(w * .08, h * .24), Offset(w * .28, h * .07), Offset(w * .43, h * .26),
      Offset(w * .31, h * .38), Offset(w * .16, h * .34),
    ], const Color(0xFF123D9A));
    _poly(canvas, [
      Offset(w * .34, h * .23), Offset(w * .55, h * .02), Offset(w * .73, h * .20),
      Offset(w * .59, h * .37), Offset(w * .43, h * .31),
    ], const Color(0xFF101C55));
    _poly(canvas, [
      Offset(w * .48, h * .15), Offset(w * .62, 0), Offset(w * .78, h * .18),
      Offset(w * .66, h * .30),
    ], const Color(0xFF172D86));
    _poly(canvas, [
      Offset(w * .67, h * .11), Offset(w * .86, h * .03), Offset(w, h * .23),
      Offset(w * .89, h * .34), Offset(w * .72, h * .26),
    ], const Color(0xFF10164A));

    // Cyan/purple shards.
    _poly(canvas, [
      Offset(w * .16, h * .16), Offset(w * .27, h * .10), Offset(w * .23, h * .23),
    ], const Color(0xFF00DDF5));
    _poly(canvas, [
      Offset(w * .26, h * .18), Offset(w * .38, h * .12), Offset(w * .32, h * .28),
    ], const Color(0xFF2D74FF));
    _poly(canvas, [
      Offset(w * .73, h * .13), Offset(w * .83, h * .08), Offset(w * .79, h * .21),
    ], const Color(0xFF7C31FF));
    _poly(canvas, [
      Offset(w * .88, h * .25), Offset(w, h * .20), Offset(w * .94, h * .32),
    ], const Color(0xFF00BDEB));

    if (showDevil) {
      final center = Offset(w * .5, h * .47);
      final glow = Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x8A00E7FF), Color(0x0000E7FF)],
        ).createShader(Rect.fromCircle(center: center, radius: w * .27));
      canvas.drawCircle(center, w * .27, glow);

      _drawDevil(canvas, center, w * .18);
      if (showPlatform) {
        _drawPlatform(canvas, Offset(w * .5, h * .49), w * .62);
      }
    }

    // Small floating shards.
    final shard = Paint()..color = const Color(0xFF8E2CFF);
    canvas.drawPath(Path()
      ..moveTo(w * .07, h * .39)
      ..lineTo(w * .10, h * .35)
      ..lineTo(w * .12, h * .41)
      ..close(), shard);
    shard.color = const Color(0xFF00D7F2);
    canvas.drawPath(Path()
      ..moveTo(w * .86, h * .39)
      ..lineTo(w * .91, h * .35)
      ..lineTo(w * .89, h * .43)
      ..close(), shard);
  }

  void _drawDevil(Canvas canvas, Offset c, double r) {
    final p = Paint()..isAntiAlias = true;
    p.color = const Color(0xFF05040D);

    // Head/body silhouette.
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + r * .12), width: r * 1.02, height: r * 1.15), p);
    final head = Path()
      ..moveTo(c.dx - r * .62, c.dy + r * .22)
      ..quadraticBezierTo(c.dx - r * .58, c.dy - r * .66, c.dx, c.dy - r * .72)
      ..quadraticBezierTo(c.dx + r * .58, c.dy - r * .66, c.dx + r * .62, c.dy + r * .22)
      ..quadraticBezierTo(c.dx, c.dy + r * .58, c.dx - r * .62, c.dy + r * .22)
      ..close();
    canvas.drawPath(head, p);

    // Horns.
    final horns = Path()
      ..moveTo(c.dx - r * .42, c.dy - r * .43)
      ..quadraticBezierTo(c.dx - r * .78, c.dy - r * .78, c.dx - r * .62, c.dy - r * 1.12)
      ..quadraticBezierTo(c.dx - r * .30, c.dy - r * .84, c.dx - r * .20, c.dy - r * .45)
      ..moveTo(c.dx + r * .42, c.dy - r * .43)
      ..quadraticBezierTo(c.dx + r * .78, c.dy - r * .78, c.dx + r * .62, c.dy - r * 1.12)
      ..quadraticBezierTo(c.dx + r * .30, c.dy - r * .84, c.dx + r * .20, c.dy - r * .45)
      ..close();
    canvas.drawPath(horns, p);

    // Cyan eyes and subtle grin.
    p.color = const Color(0xFF43F7FF);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - r * .23, c.dy - r * .06), width: r * .18, height: r * .10), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + r * .23, c.dy - r * .06), width: r * .18, height: r * .10), p);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = math.max(1.5, r * .045);
    p.strokeCap = StrokeCap.round;
    final smile = Path()
      ..moveTo(c.dx - r * .22, c.dy + r * .25)
      ..quadraticBezierTo(c.dx, c.dy + r * .38, c.dx + r * .22, c.dy + r * .25);
    canvas.drawPath(smile, p);
    p.style = PaintingStyle.fill;

    // Tail.
    p.style = PaintingStyle.stroke;
    p.strokeWidth = math.max(2, r * .055);
    final tail = Path()
      ..moveTo(c.dx - r * .48, c.dy + r * .30)
      ..quadraticBezierTo(c.dx - r * 1.05, c.dy + r * .46, c.dx - r * .92, c.dy + r * .78)
      ..quadraticBezierTo(c.dx - r * .82, c.dy + r * .94, c.dx - r * .64, c.dy + r * .82);
    canvas.drawPath(tail, p);
    p.style = PaintingStyle.fill;
  }

  void _drawPlatform(Canvas canvas, Offset center, double width) {
    final p = Paint()..color = const Color(0xFF101529);
    final rect = Rect.fromCenter(center: center, width: width, height: 16);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), p);
    p.color = const Color(0xFF253354);
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 3), p);
  }

  void _poly(Canvas canvas, List<Offset> points, Color color) {
    final p = Paint()..color = color;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _LvlloArtPainter oldDelegate) =>
      oldDelegate.showDevil != showDevil || oldDelegate.showGrid != showGrid || oldDelegate.showPlatform != showPlatform;
}
