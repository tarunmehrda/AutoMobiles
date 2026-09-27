import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';

/// Faint engineering grid + corner arcs. Painted behind dark hero surfaces
/// to give them texture instead of a flat fill.
class BlueprintPainter extends CustomPainter {
  BlueprintPainter({
    required this.color,
    this.spacing = 22,
    this.opacity = 0.07,
    this.drawArcs = true,
  });

  final Color color;
  final double spacing;
  final double opacity;
  final bool drawArcs;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
    }

    if (!drawArcs) return;
    final arc = Paint()
      ..color = color.withValues(alpha: opacity * 1.6)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.92, size.height * 0.1),
        34.0 * i,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BlueprintPainter old) =>
      old.color != color || old.spacing != spacing || old.opacity != opacity;
}

/// Radial health gauge — the centrepiece of the digital inspection report.
class HealthGauge extends StatelessWidget {
  const HealthGauge({
    super.key,
    required this.score,
    this.size = 150,
    this.label = 'Health score',
    this.trackColor,
  });

  /// 0..1
  final double score;
  final double size;
  final String label;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final color = p.health(score);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.clamp(0, 1)),
      duration: Motion.lazy,
      curve: Motion.spring,
      builder: (context, v, _) {
        return SizedBox(
          height: size,
          width: size,
          child: CustomPaint(
            painter: _GaugePainter(
              value: v,
              color: color,
              track: trackColor ?? p.surfaceSunken,
              tickColor: p.inkFaint.withValues(alpha: 0.5),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(v * 100).round()}',
                    style: AppType.moneyL.s(size * 0.26).c(p.ink),
                  ),
                  Text(
                    label.toUpperCase(),
                    style: AppType.over.s(9).c(p.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.color,
    required this.track,
    required this.tickColor,
  });

  final double value;
  final Color color;
  final Color track;
  final Color tickColor;

  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..color = track
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    canvas.drawArc(
      rect,
      _start,
      _sweep * value,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: _start,
          endAngle: _start + _sweep,
          colors: [color.withValues(alpha: 0.55), color],
          transform: GradientRotation(_start),
        ).createShader(rect)
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Tick marks around the dial.
    final center = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2 - stroke * 1.35;
    final tick = Paint()
      ..color = tickColor
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= 20; i++) {
      final a = _start + _sweep * (i / 20);
      final long = i % 5 == 0;
      final r1 = rOuter - (long ? 8 : 4);
      canvas.drawLine(
        center + Offset(math.cos(a) * r1, math.sin(a) * r1),
        center + Offset(math.cos(a) * rOuter, math.sin(a) * rOuter),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color;
}

/// Horizontal capsule meter used for per-item inspection severity.
class GMeter extends StatelessWidget {
  const GMeter({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
    this.segments,
  });

  final double value;
  final Color? color;
  final double height;
  final int? segments;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final c = color ?? p.health(value);
    if (segments != null) {
      final filled = (value * segments!).round();
      return Row(
        children: [
          for (var i = 0; i < segments!; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: Motion.base + Duration(milliseconds: i * 40),
                curve: Motion.enter,
                height: height,
                decoration: BoxDecoration(
                  color: i < filled ? c : p.surfaceSunken,
                  borderRadius: R.all(R.pill),
                ),
              ),
            ),
            if (i != segments! - 1) const SizedBox(width: 3),
          ],
        ],
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: Motion.slow,
      curve: Motion.enter,
      builder: (context, v, _) => ClipRRect(
        borderRadius: R.all(R.pill),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: p.surfaceSunken,
          valueColor: AlwaysStoppedAnimation(c),
        ),
      ),
    );
  }
}

/// Soft ambient glow used behind hero numbers and success states.
class GGlow extends StatelessWidget {
  const GGlow({
    super.key,
    required this.child,
    this.color,
    this.radius = 140,
    this.alignment = Alignment.topRight,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.c.accent;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: alignment,
              child: Container(
                height: radius,
                width: radius,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.withValues(alpha: 0.30),
                      c.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Ticket-style notch used on invoices and coupons.
class NotchedCardClipper extends CustomClipper<Path> {
  NotchedCardClipper({
    required this.notchY,
    this.radius = 12,
    this.corner = 20,
  });

  final double notchY;
  final double radius;
  final double corner;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(corner),
        ),
      );
    final notch = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, notchY), radius: radius))
      ..addOval(
        Rect.fromCircle(center: Offset(size.width, notchY), radius: radius),
      );
    return Path.combine(PathOperation.difference, path, notch);
  }

  @override
  bool shouldReclip(covariant NotchedCardClipper old) =>
      old.notchY != notchY || old.radius != radius;
}
