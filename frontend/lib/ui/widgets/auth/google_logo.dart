import 'package:flutter/material.dart';

/// Google "G" logo rendered via CustomPainter.
/// This avoids needing an SVG package for a single icon.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;

    // Scale factor from 24x24 reference
    final double scale = s / 24;

    // Blue arc (right side)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final bluePath = Path();
    bluePath.moveTo(22.56 * scale, 12.25 * scale);
    bluePath.cubicTo(22.56 * scale, 11.47 * scale, 22.49 * scale,
        10.72 * scale, 22.36 * scale, 10.0 * scale);
    bluePath.lineTo(12.0 * scale, 10.0 * scale);
    bluePath.lineTo(12.0 * scale, 14.26 * scale);
    bluePath.lineTo(17.92 * scale, 14.26 * scale);
    bluePath.cubicTo(17.66 * scale, 15.63 * scale, 16.88 * scale,
        16.79 * scale, 15.71 * scale, 17.57 * scale);
    bluePath.lineTo(15.71 * scale, 20.34 * scale);
    bluePath.lineTo(19.28 * scale, 20.34 * scale);
    bluePath.cubicTo(21.36 * scale, 18.42 * scale, 22.56 * scale,
        15.60 * scale, 22.56 * scale, 12.25 * scale);
    bluePath.close();
    canvas.drawPath(bluePath, bluePaint);

    // Green arc (bottom-right)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    final greenPath = Path();
    greenPath.moveTo(12.0 * scale, 23.0 * scale);
    greenPath.cubicTo(14.97 * scale, 23.0 * scale, 17.46 * scale,
        22.02 * scale, 19.28 * scale, 20.34 * scale);
    greenPath.lineTo(15.71 * scale, 17.57 * scale);
    greenPath.cubicTo(14.73 * scale, 18.23 * scale, 13.48 * scale,
        18.63 * scale, 12.0 * scale, 18.63 * scale);
    greenPath.cubicTo(9.14 * scale, 18.63 * scale, 6.71 * scale,
        16.70 * scale, 5.84 * scale, 14.10 * scale);
    greenPath.lineTo(5.84 * scale, 14.10 * scale);
    greenPath.lineTo(2.18 * scale, 16.94 * scale);
    greenPath.cubicTo(3.99 * scale, 20.53 * scale, 7.7 * scale,
        23.0 * scale, 12.0 * scale, 23.0 * scale);
    greenPath.close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow arc (bottom-left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;

    final yellowPath = Path();
    yellowPath.moveTo(5.84 * scale, 14.09 * scale);
    yellowPath.cubicTo(5.62 * scale, 13.43 * scale, 5.49 * scale,
        12.73 * scale, 5.49 * scale, 12.0 * scale);
    yellowPath.cubicTo(5.49 * scale, 11.27 * scale, 5.62 * scale,
        10.57 * scale, 5.84 * scale, 9.91 * scale);
    yellowPath.lineTo(5.84 * scale, 7.07 * scale);
    yellowPath.lineTo(2.18 * scale, 7.07 * scale);
    yellowPath.cubicTo(1.43 * scale, 8.55 * scale, 1.0 * scale,
        10.22 * scale, 1.0 * scale, 12.0 * scale);
    yellowPath.cubicTo(1.0 * scale, 13.78 * scale, 1.43 * scale,
        15.45 * scale, 2.18 * scale, 16.93 * scale);
    yellowPath.lineTo(5.84 * scale, 14.09 * scale);
    yellowPath.close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red arc (top-left)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    final redPath = Path();
    redPath.moveTo(12.0 * scale, 5.38 * scale);
    redPath.cubicTo(13.62 * scale, 5.38 * scale, 15.06 * scale,
        5.94 * scale, 16.21 * scale, 7.02 * scale);
    redPath.lineTo(19.36 * scale, 3.87 * scale);
    redPath.cubicTo(17.45 * scale, 2.09 * scale, 14.97 * scale,
        1.0 * scale, 12.0 * scale, 1.0 * scale);
    redPath.cubicTo(7.7 * scale, 1.0 * scale, 3.99 * scale,
        3.47 * scale, 2.18 * scale, 7.07 * scale);
    redPath.lineTo(5.84 * scale, 9.91 * scale);
    redPath.cubicTo(6.71 * scale, 7.31 * scale, 9.14 * scale,
        5.38 * scale, 12.0 * scale, 5.38 * scale);
    redPath.close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
