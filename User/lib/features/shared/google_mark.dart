import 'package:flutter/material.dart';

/// Google's four-colour G, painted rather than shipped as an asset so the
/// button stays sharp at any size and the app carries no image dependency
/// for one 20px mark.
///
/// The four shapes are Google's own artwork, traced from the official mark on
/// a 48x48 grid, so the proportions and the notch where the bar meets the
/// blue arc are exactly right.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  /// The artwork occupies x 2..45.12, y 2..46 of the 48x48 grid.
  static const _artWidth = 43.12;
  static const _artHeight = 44.0;
  static const _artCentreX = 23.56;
  static const _artCentreY = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final scale = s / (_artWidth > _artHeight ? _artWidth : _artHeight);

    canvas.save();
    canvas.translate(
      size.width / 2 - _artCentreX * scale,
      size.height / 2 - _artCentreY * scale,
    );
    canvas.scale(scale);

    final paint = Paint()..isAntiAlias = true;
    canvas.drawPath(_blueShape(), paint..color = _blue);
    canvas.drawPath(_greenShape(), paint..color = _green);
    canvas.drawPath(_yellowShape(), paint..color = _yellow);
    canvas.drawPath(_redShape(), paint..color = _red);

    canvas.restore();
  }

  /// The right-hand arc plus the bar of the G.
  static Path _blueShape() => Path()
    ..moveTo(45.12, 24.5)
    ..relativeCubicTo(0, -1.56, -0.14, -3.06, -0.4, -4.5)
    ..lineTo(24, 20)
    ..lineTo(24, 28.51)
    ..lineTo(35.84, 28.51)
    ..relativeCubicTo(-0.51, 2.75, -2.06, 5.08, -4.39, 6.64)
    ..lineTo(31.45, 40.67)
    ..lineTo(38.56, 40.67)
    ..relativeCubicTo(4.16, -3.83, 6.56, -9.47, 6.56, -16.17)
    ..close();

  /// Along the bottom.
  static Path _greenShape() => Path()
    ..moveTo(24, 46)
    ..relativeCubicTo(5.94, 0, 10.92, -1.97, 14.56, -5.33)
    ..relativeLineTo(-7.11, -5.52)
    ..relativeCubicTo(-1.97, 1.32, -4.49, 2.1, -7.45, 2.1)
    ..relativeCubicTo(-5.73, 0, -10.58, -3.87, -12.31, -9.07)
    ..lineTo(4.34, 28.18)
    ..lineTo(4.34, 33.88)
    ..cubicTo(7.96, 41.07, 15.4, 46, 24, 46)
    ..close();

  /// Down the left.
  static Path _yellowShape() => Path()
    ..moveTo(11.69, 28.18)
    ..cubicTo(11.25, 26.86, 11, 25.45, 11, 24)
    ..cubicTo(11, 22.55, 11.25, 21.14, 11.69, 19.82)
    ..lineTo(11.69, 14.12)
    ..lineTo(4.34, 14.12)
    ..cubicTo(2.85, 17.09, 2, 20.45, 2, 24)
    ..cubicTo(2, 27.55, 2.85, 30.91, 4.34, 33.88)
    ..relativeLineTo(7.35, -5.7)
    ..close();

  /// Across the top.
  static Path _redShape() => Path()
    ..moveTo(24, 10.75)
    ..relativeCubicTo(3.23, 0, 6.13, 1.11, 8.41, 3.29)
    ..relativeLineTo(6.31, -6.31)
    ..cubicTo(34.91, 4.18, 29.93, 2, 24, 2)
    ..cubicTo(15.4, 2, 7.96, 6.93, 4.34, 14.12)
    ..relativeLineTo(7.35, 5.7)
    ..relativeCubicTo(1.73, -5.2, 6.58, -9.07, 12.31, -9.07)
    ..close();

  @override
  bool shouldRepaint(covariant _GooglePainter oldDelegate) => false;
}
