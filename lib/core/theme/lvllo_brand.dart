import 'package:flutter/material.dart';

import 'design_tokens.dart';

class LvlloBrandMark extends StatelessWidget {
  const LvlloBrandMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: GameColors.cosmicGradient,
        boxShadow: GameShadows.primaryGlow,
      ),
      child: CustomPaint(
        painter: _DevilPainter(),
      ),
    );
  }
}

class _DevilPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = size.width;
    final paint = Paint()..isAntiAlias = true;

    paint.color = const Color(0xFF080B22);
    canvas.drawCircle(c, s * .31, paint);

    paint.color = const Color(0xFF080B22);
    final horns = Path()
      ..moveTo(s * .29, s * .42)
      ..quadraticBezierTo(s * .16, s * .27, s * .25, s * .18)
      ..quadraticBezierTo(s * .34, s * .28, s * .37, s * .39)
      ..moveTo(s * .71, s * .42)
      ..quadraticBezierTo(s * .84, s * .27, s * .75, s * .18)
      ..quadraticBezierTo(s * .66, s * .28, s * .63, s * .39);
    canvas.drawPath(horns, paint);

    paint.color = const Color(0xFF8AF7FF);
    canvas.drawOval(Rect.fromLTWH(s * .33, s * .43, s * .10, s * .055), paint);
    canvas.drawOval(Rect.fromLTWH(s * .57, s * .43, s * .10, s * .055), paint);

    paint.color = const Color(0xFF8AF7FF);
    final mouth = Path()
      ..moveTo(s * .40, s * .61)
      ..quadraticBezierTo(s * .50, s * .68, s * .60, s * .61);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = s * .035;
    paint.strokeCap = StrokeCap.round;
    canvas.drawPath(mouth, paint);
    paint.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
