import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/decor.dart';

/// The console's cold open.
///
/// One controller drives the whole thing so the beats stay in lockstep: a
/// headlight streak crosses the screen, the lockup drives in behind it and
/// settles, a specular sweep runs across the artwork, then the strapline
/// rises. Held just long enough for the store to be read and the router to
/// settle — the timeline is under two seconds end to end.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  // The headlight streak that crosses behind the lockup.
  late final Animation<double> _streak = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.02, 0.46, curve: Curves.easeInOutCubic),
  );

  // Lockup: drives in from the left and overshoots home.
  late final Animation<double> _enter = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.08, 0.62, curve: Motion.spring),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.08, 0.38, curve: Curves.easeOut),
  );

  // Specular sweep across the artwork, once it has landed.
  late final Animation<double> _shine = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.52, 0.94, curve: Curves.easeInOut),
  );

  late final Animation<double> _tagline = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.50, 0.82, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) context.go('/home');
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final w = MediaQuery.sizeOf(context).width;
    final logoWidth = math.min(w * 0.78, 380.0);

    return Scaffold(
      backgroundColor: BrandArt.carbon,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BlueprintPainter(
                  color: p.onInverse, spacing: 26, opacity: 0.05),
            ),
          ),

          // Amber bloom over the shoulder of the mark.
          Positioned(
            top: -130,
            right: -100,
            child: Container(
              height: 340,
              width: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  p.accent.withValues(alpha: 0.26),
                  p.accent.withValues(alpha: 0),
                ]),
              ),
            ),
          ),

          // The pass-by: amber streaks crossing the frame behind the mark,
          // full width so they read as headlights rather than decoration.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _streak,
              builder: (context, _) => CustomPaint(
                painter: _StreakPainter(color: p.accent, t: _streak.value),
              ),
            ),
          ),

          Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _logoFade.value,
                      child: Transform.translate(
                        offset: Offset(-34 * (1 - _enter.value), 0),
                        child: Transform.scale(
                          scale: 0.90 + 0.10 * _enter.value,
                          child: _Shine(
                            t: _shine.value,
                            child: BrandLogo(width: logoWidth, onDark: true),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.xxl),
                    Opacity(
                      opacity: _tagline.value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - _tagline.value)),
                        child: Text(
                          AppConfig.tagline.toUpperCase(),
                          style: AppType.labelM
                              .c(p.onInverse.withValues(alpha: 0.58))
                              .copyWith(letterSpacing: 2.4),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: Gap.h2,
            child: Opacity(
              opacity: 0.5,
              child: Column(
                children: [
                  SizedBox(
                    height: 2,
                    width: 96,
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) => LinearProgressIndicator(
                        value: _c.value,
                        backgroundColor: p.onInverse.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(p.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  Text('v${AppConfig.version}',
                      style: AppType.labelS.c(p.onInverse)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A raking band of light dragged across whatever it wraps.
///
/// [t] runs 0..1; the band itself is pushed a little past both edges so it
/// starts and ends off the artwork rather than popping on top of it.
class _Shine extends StatelessWidget {
  const _Shine({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t <= 0 || t >= 1) return child;
    final x = -0.25 + 1.5 * t;
    double at(double v) => v.clamp(0.0, 1.0);
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
          Color(0xB3FFFFFF),
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [0, at(x - 0.16), at(x), at(x + 0.16), 1],
      ).createShader(rect),
      child: child,
    );
  }
}

/// Three tapered lines shot across the frame, echoing the speed lines cut
/// into the mark's own "B". They lead the lockup in and are gone by the time
/// it lands.
class _StreakPainter extends CustomPainter {
  _StreakPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;

    for (var i = 0; i < 3; i++) {
      // Each line is offset in time so they fan rather than march.
      final lt = ((t - i * 0.07) / (1 - 0.14)).clamp(0.0, 1.0);
      if (lt <= 0) continue;

      final y = size.height * (0.415 + i * 0.037);
      final len = size.width * (0.46 - i * 0.08);
      final head = -len + (size.width + len * 2) * lt;

      // Fade in on entry, out on exit.
      final a = math.sin(lt * math.pi).clamp(0.0, 1.0) * (0.70 - i * 0.16);

      canvas.drawLine(
        Offset(head - len, y),
        Offset(head, y),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.4 - i * 0.7
          ..shader = LinearGradient(colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: a),
          ]).createShader(
            Rect.fromLTWH(head - len, y - 2, len, 4),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StreakPainter old) =>
      old.t != t || old.color != color;
}
