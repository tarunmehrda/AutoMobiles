import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_type.dart';

/// The footage the dashboard hero runs on, and where it came from.
///
/// A real car, shot on a real camera — not a shape assembled out of Bezier
/// curves. The drawn car further down is still here, but it has been demoted
/// to the understudy: it only goes on when the reel cannot.
///
/// ## Provenance
///
/// Found by web search. A low-angle dolly along the rear quarter of a red
/// convertible in an underground carpark: dark, unpopulated and already lit
/// the way this app is lit, which is why it needs almost no grading to sit
/// under a cockpit's worth of white numbers.
///
/// * Item page: <https://mixkit.co/free-stock-video/red-sports-car-74/>
/// * Source file: <https://assets.mixkit.co/videos/74/74-1080.mp4>
/// * "Red sports car", Mixkit. 1920x1080, 24fps, 10s.
/// * Licence: **Mixkit Stock Video Free License**. The item page states the
///   clip is free "for commercial or personal use" under it and asks for no
///   credit, which is why no attribution line is set below — unlike a CC BY
///   clip, where one would be mandatory. The licence's full clause list
///   renders client-side and could not be read from here, so check
///   <https://mixkit.co/license/> before this ships to a store.
///
/// ## What was done to it
///
/// The original is 10.2s, and a clip with a start and an end cuts visibly
/// every time it wraps. So a 3.0s window was taken from it at t=1.0s, and its
/// tail was cross-dissolved back over its head so the wrap has no seam. The
/// dolly never stops or changes direction across those seconds, which is what
/// makes the dissolve read as one continuous move rather than as an edit.
/// Re-encoded at full HD — 1920x1080, 24fps, H.264 / yuv420p, the one video
/// codec every target here (Android, iOS, web, Windows) can decode — with no
/// audio track, and `+faststart` so the first frame is decodable before the
/// file has finished being read. 740KB.
///
/// It is a bundled asset rather than a URL fetched at runtime. A dashboard is
/// the first screen a workshop opens in the morning, often on the counter's
/// patchy wifi, and a hero that depends on the network is a hero that is
/// sometimes simply missing.
class CarReel {
  const CarReel._();

  static const String video = 'assets/video/dashboard_car.mp4';

  /// The reel's own first frame, so the still that precedes the footage is
  /// the footage, not a stand-in for it.
  static const String poster = 'assets/video/dashboard_car_poster.jpg';

  /// Empty, because the current clip's licence asks for no credit. It is not
  /// deleted: point [video] at a CC BY or CC BY-SA clip — most of what a web
  /// search turns up — and attribution becomes a *condition of use*, at which
  /// point the credit has to appear somewhere a user can read it rather than
  /// only in a source comment nobody will open. Set it here and the hero
  /// shows it.
  static const String? credit = null;
}

/// The cockpit hero: a real car under the workshop lights, with the drawn one
/// held in reserve.
///
/// ## How this stays smooth
///
/// Smoothness is not a curve you pick at the end, it is what the widget does
/// on every one of the sixty frames a second it is given. Five things carry
/// it:
///
/// 1. **One ticker.** Every moving part the widget itself draws reads from a
///    single repeating controller. Two controllers at 3.2s and 6.5s drift
///    apart within seconds and the eye catches the beat; one clock cannot.
///    The reel runs off the platform decoder, which is a clock of its own —
///    but it sits behind the scrim with nothing to stay in step with.
/// 2. **The content never rebuilds.** [AnimatedBuilder] takes the hero
///    subtree as `child` and hands the same instance back each frame, so the
///    numbers, pills and gauge over the top are built once. Only the painter
///    is asked for a new frame, and the reel's entrance uses
///    [FadeTransition] and [ScaleTransition], which animate without
///    rebuilding the [VideoPlayer] underneath them.
/// 3. **Repaint boundaries.** The reel and the painted layer each get their
///    own, so neither marks the dashboard below them dirty.
/// 4. **Nothing is allocated per frame.** Paths, gradients and the streak
///    field are built once and scaled by a transform. Allocating a Path
///    inside `paint` is how an animation ends up janking on a mid-range
///    phone, which is what a workshop counter actually runs.
/// 5. **The loop is seamless.** The painted motion is a function of
///    `sin`/`cos` of the progress, or a value taken modulo 1; the reel was
///    cut to cross-dissolve into itself. Neither has a frame where it snaps
///    back to the start.
class WorkshopCarHero extends StatefulWidget {
  const WorkshopCarHero({
    super.key,
    required this.child,
    this.primaryColor,
    this.accentColor,
    this.reel = true,
    this.credit = CarReel.credit,
    this.scrimColor,
  });

  final Widget child;
  final Color? primaryColor;
  final Color? accentColor;

  /// The colour the footage is graded towards. The hero was born carbon, but
  /// the dashboard now opens on a warm orange canopy, and a scrim resolving
  /// to near-black under an orange panel leaves a grey bruise across the
  /// middle of it. Pass the panel's own colour and the reel sinks into it.
  final Color? scrimColor;

  /// Whether to run [CarReel], or fall back to the car the painter draws.
  ///
  /// Worth turning off for a golden test, or on a build where half a megabyte
  /// of video is not worth the hero.
  final bool reel;

  /// The credit line for [CarReel.video], shown in the corner of the hero, or
  /// null for footage that needs none. See [CarReel.credit].
  final String? credit;

  @override
  State<WorkshopCarHero> createState() => _WorkshopCarHeroState();
}

class _WorkshopCarHeroState extends State<WorkshopCarHero>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// The one clock. Long enough that the streak field never looks like it is
  /// repeating, short enough that the wheels do not crawl.
  late final AnimationController _loop;

  /// The arrival, played once. Separate from [_loop] because it has a start
  /// and an end, and folding a one-shot into a repeating controller is how
  /// you get an entrance that replays forever.
  late final AnimationController _entrance;

  late final Animation<double> _arrive;

  /// The reel's push-in. It settles towards its resting frame rather than
  /// away from it, so the hero opens by arriving rather than by receding.
  late final Animation<double> _settle;

  /// Built once. Regenerating these inside `paint` would allocate on every
  /// frame, which is the usual reason a canvas animation stutters.
  late final List<_Streak> _streaks;

  VideoPlayerController? _video;
  bool _playing = false;

  /// The poster is a bundled asset, so it failing means the asset has gone
  /// from the bundle entirely — at which point the reel is not coming back
  /// and the drawn car takes the hero.
  bool _posterFailed = false;

  /// True when the real car is on screen in some form, still or moving. The
  /// painter stops drawing its own car at that point, rather than the two
  /// overlapping.
  bool get _reelUp => widget.reel && !_posterFailed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // easeOutCubic rather than a spring: the car should settle, not bounce.
    // A bouncing car reads as a toy, and this one sits behind a number the
    // owner is meant to trust.
    _arrive = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _settle = Tween<double>(begin: 1.07, end: 1.0).animate(_arrive);

    final rng = math.Random(7);
    _streaks = List.generate(18, (i) {
      return _Streak(
        // Spread along the loop so the field is already full on frame one
        // instead of filing in from the right edge.
        phase: rng.nextDouble(),
        y: 0.12 + rng.nextDouble() * 0.82,
        length: 0.05 + rng.nextDouble() * 0.16,
        speed: 0.7 + rng.nextDouble() * 0.9,
        opacity: 0.05 + rng.nextDouble() * 0.18,
      );
    });

    _entrance.forward();
    _syncClock();
    if (widget.reel) _load();
  }

  /// [_loop] drives the drawn car and nothing else, so it runs only when the
  /// drawn car is on. Leaving it repeating behind the reel would hold a
  /// ticker open — and with it a vsync callback every frame — to advance
  /// numbers that nothing reads.
  void _syncClock() {
    if (_reelUp) {
      if (_loop.isAnimating) _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void didUpdateWidget(WorkshopCarHero old) {
    super.didUpdateWidget(old);
    if (old.reel != widget.reel) {
      _syncClock();
      if (widget.reel && _video == null) _load();
    }
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.asset(CarReel.video);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      // A dashboard that starts talking when you open it is a dashboard
      // people turn off. The clip ships without an audio track anyway; this
      // is belt and braces.
      await controller.setVolume(0);
      await controller.play();
    } catch (error) {
      // No decoder, no asset, or a platform with no video support at all.
      // The poster still carries the hero, so this is a downgrade rather
      // than a failure and the drawn car is not needed.
      debugPrint('car reel unavailable, holding the poster frame: $error');
      await _discard(controller);
      return;
    }

    if (!mounted) {
      await _discard(controller);
      return;
    }
    setState(() {
      _video = controller;
      _playing = true;
    });
  }

  /// Teardown for a controller we are abandoning. It has already failed us
  /// once, so its own `dispose` is not to be trusted to stay quiet either.
  Future<void> _discard(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (_) {
      // Nothing useful is left to do with it.
    }
  }

  /// A decoder left running behind a backgrounded app is a battery complaint
  /// waiting to be filed against the workshop's phone.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    state == AppLifecycleState.resumed ? video.play() : video.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video?.dispose();
    _loop.dispose();
    _entrance.dispose();
    super.dispose();
  }

  /// The still, and the footage over it once the decoder has caught up.
  ///
  /// The poster is bundled, so the real car is on screen from the first frame
  /// and the reel dissolves into motion rather than punching in from black.
  Widget _reelLayer() {
    return FadeTransition(
      opacity: _arrive,
      child: ScaleTransition(
        scale: _settle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              CarReel.poster,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, error, _) {
                // Flipped after this frame rather than during it: calling
                // setState from inside build is an error.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _posterFailed = true);
                  // The drawn car is about to take over, so it needs its
                  // clock back.
                  _syncClock();
                });
                return const SizedBox.expand();
              },
            ),
            if (_playing && _video != null) _movingFrame(_video!),
          ],
        ),
      ),
    );
  }

  /// `BoxFit.cover` for a texture: scale the reel's own frame up until it
  /// fills, and crop the overhang.
  Widget _movingFrame(VideoPlayerController controller) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) return const SizedBox.shrink();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final primary = widget.primaryColor ?? p.accent;
    final secondary = widget.accentColor ?? p.volt;
    final reelUp = _reelUp;

    return ClipRect(
      // The old radar swept its beam straight out over the cards below.
      // A hero is a box; what it paints stays in the box.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (reelUp) ...[
            Positioned.fill(child: RepaintBoundary(child: _reelLayer())),
            Positioned.fill(
              child: _ReelScrim(
                glow: primary,
                base: widget.scrimColor ?? const Color(0xFF0C1017),
              ),
            ),
          ],

          // The understudy, and everything that was only ever there to light
          // it: the floor pool, the speed streaks, the headlight.
          //
          // It comes out of the tree entirely when the reel is up rather than
          // being drawn at zero opacity underneath it. That is worth more
          // than the paint it saves. The streak field is a stand-in for
          // motion, and laid over footage that already *has* motion it stops
          // reading as speed and starts reading as scratches on the lens; the
          // floor pool lights a car that is no longer there. Dropping the
          // layer also takes a sixty-frames-a-second [CustomPaint] off the
          // first screen of the app, and leaves the reel's own decoder as the
          // only thing on this page asking for frames.
          if (!reelUp)
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_loop, _arrive]),
                  builder: (context, _) => CustomPaint(
                    painter: _CarHeroPainter(
                      t: _loop.value,
                      arrive: _arrive.value,
                      primary: primary,
                      secondary: secondary,
                      streaks: _streaks,
                    ),
                  ),
                ),
              ),
            ),

          // Only once the footage is actually on screen: a credit for a
          // picture nobody can see would be a lie.
          if (reelUp && widget.credit != null)
            Positioned(
              right: 10,
              bottom: 6,
              child: IgnorePointer(
                child: Text(
                  widget.credit!,
                  style: AppType.bodyS
                      .s(8)
                      .c(Colors.white.withValues(alpha: 0.38)),
                ),
              ),
            ),

          // Passed as a sibling rather than through the builder: this subtree
          // is never rebuilt by the animation.
          widget.child,
        ],
      ),
    );
  }
}

/// What makes the footage a *backdrop* rather than a picture competing with
/// the numbers.
///
/// The job is to buy contrast for the type, not to grade the footage into a
/// flat rectangle. A veil settles the whole frame onto [base]; a
/// left-to-right ramp holds the left half down, where the greeting, the
/// workshop pill and the plan line sit, and opens across the right where the
/// car's own flank is, so the footage survives as a picture in the one place
/// nothing is written over it; and a top-to-bottom ramp buys a legible status
/// bar and a solid floor where the hero hands off to the cards below.
///
/// The right side staying open is the one call here that is not obvious. The
/// carpark has a lit doorway in it, and it is by a wide margin the brightest
/// thing in the frame. Under the old carbon grade it had to be buried, because
/// nothing else on screen could out-shine it. Under an orange canopy it is an
/// asset: it lands behind the car, reads as the workshop's own lighting, and
/// gives the panel the depth a flat gradient cannot.
class _ReelScrim extends StatelessWidget {
  const _ReelScrim({required this.glow, required this.base});

  final Color glow;

  /// What the footage is graded towards — the hero's own backdrop colour, so
  /// the scrim resolves into it and the two never fight over the same pixels.
  final Color base;

  @override
  Widget build(BuildContext context) {
    final carbon = base;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: carbon.withValues(alpha: 0.34)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  carbon.withValues(alpha: 0.94),
                  carbon.withValues(alpha: 0.80),
                  carbon.withValues(alpha: 0.30),
                  carbon.withValues(alpha: 0.22),
                ],
                stops: const [0.0, 0.34, 0.72, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  carbon.withValues(alpha: 0.46),
                  carbon.withValues(alpha: 0.10),
                  carbon.withValues(alpha: 0.10),
                  carbon.withValues(alpha: 0.52),
                ],
                stops: const [0.0, 0.26, 0.64, 1.0],
              ),
            ),
          ),
          // A low bloom in the accent, placed over the doorway light the clip
          // already has, so the brightest thing on screen is the app's own
          // orange rather than a stranger's fluorescent tube.
          Align(
            alignment: const Alignment(0.72, 0.30),
            child: FractionallySizedBox(
              widthFactor: 0.9,
              heightFactor: 1.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: 0.20),
                      glow.withValues(alpha: 0.0),
                    ],
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

/// One motion line in the field behind the car.
@immutable
class _Streak {
  const _Streak({
    required this.phase,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
  });

  final double phase;
  final double y;
  final double length;
  final double speed;
  final double opacity;
}

class _CarHeroPainter extends CustomPainter {
  _CarHeroPainter({
    required this.t,
    required this.arrive,
    required this.primary,
    required this.secondary,
    required this.streaks,
  });

  /// The single clock, 0..1, looping.
  final double t;

  /// The one-shot arrival, 0..1.
  final double arrive;

  final Color primary;
  final Color secondary;
  final List<_Streak> streaks;

  /// The car is drawn in this box and scaled to fit, so every coordinate
  /// below is a fixed number rather than a fraction of the screen. It is the
  /// difference between a shape that is drawn once and a shape recomputed
  /// against the layout on every frame.
  static const Size _design = Size(150, 54);

  /// Side profile, nose to the right. Built once at class load, not per
  /// frame and not per instance.
  static final Path _body = _buildBody();
  static final Path _glass = _buildGlass();

  static Path _buildBody() {
    return Path()
      ..moveTo(6, 44)
      ..lineTo(5, 33)
      ..quadraticBezierTo(5, 27, 14, 26)
      ..lineTo(40, 24)
      ..quadraticBezierTo(52, 9, 68, 8)
      ..lineTo(92, 8)
      ..quadraticBezierTo(104, 9, 112, 22)
      ..lineTo(134, 26)
      ..quadraticBezierTo(145, 28, 146, 36)
      ..lineTo(146, 44)
      ..close();
  }

  static Path _buildGlass() {
    return Path()
      ..moveTo(48, 23)
      ..quadraticBezierTo(57, 13, 69, 12)
      ..lineTo(86, 12)
      ..lineTo(86, 22)
      ..close()
      ..moveTo(92, 12)
      ..lineTo(90, 12)
      ..lineTo(90, 22)
      ..lineTo(110, 23)
      ..quadraticBezierTo(103, 13, 92, 12)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tau = math.pi * 2;

    _paintFloor(canvas, size);
    _paintStreaks(canvas, size);

    // --- where the car sits -------------------------------------------
    //
    // Scale from the design box, then place it on the right so the numbers
    // on the left keep a clean field to sit on.
    final scale = (size.width * 0.58) / _design.width;
    final carW = _design.width * scale;
    final carH = _design.height * scale;

    // The arrival slides in from off the right edge and settles.
    final slide = (1 - arrive) * size.width * 0.55;

    // Idle float: one sine over the loop, so the last frame meets the first
    // exactly and the seam is invisible.
    final float = math.sin(t * tau) * 3.0 * scale;

    // A whisper of body roll, a quarter turn out of phase with the float, so
    // the car breathes rather than bobs like a cork.
    final roll = math.sin(t * tau + math.pi / 2) * 0.006;

    final left = size.width - carW * 0.92 + slide;
    final top = size.height * 0.46 - carH * 0.35 + float;

    canvas.save();
    canvas.translate(left + carW / 2, top + carH / 2);
    canvas.rotate(roll);
    canvas.translate(-carW / 2, -carH / 2);
    canvas.scale(scale);

    _paintGlow(canvas);
    _paintBody(canvas);
    _paintWheels(canvas, t);
    _paintHeadlight(canvas, t);

    canvas.restore();
  }

  /// A soft pool of light on the floor, so the car is standing on something.
  void _paintFloor(Canvas canvas, Size size) {
    final y = size.height * 0.78;
    final rect = Rect.fromLTWH(0, y, size.width, size.height - y);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withValues(alpha: 0.10),
            primary.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );
  }

  /// The motion field. Each streak advances by its own speed and wraps with
  /// a modulo, which is what keeps the loop from ever restarting visibly.
  void _paintStreaks(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;

    for (final s in streaks) {
      final progress = (s.phase + t * s.speed) % 1.0;
      // Right to left: the car is the still point, the world moves past it.
      final x = size.width * (1.15 - progress * 1.3);
      final len = size.width * s.length;
      final y = size.height * s.y;

      // Fade in and out at the edges so nothing pops into existence.
      final edge = math.sin(progress * math.pi).clamp(0.0, 1.0);

      canvas.drawLine(
        Offset(x, y),
        Offset(x - len, y),
        paint..color = secondary.withValues(alpha: s.opacity * edge * arrive),
      );
    }
  }

  /// The halo the body sits in. Drawn before the body so it reads as light
  /// coming off it rather than a stroke around it.
  void _paintGlow(Canvas canvas) {
    canvas.drawPath(
      _body,
      Paint()
        ..color = primary.withValues(alpha: 0.30 * arrive)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
        ..style = PaintingStyle.fill,
    );
  }

  void _paintBody(Canvas canvas) {
    final bounds = _body.getBounds();

    canvas.drawPath(
      _body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10 * arrive),
            primary.withValues(alpha: 0.16 * arrive),
          ],
        ).createShader(bounds),
    );

    canvas.drawPath(
      _body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = primary.withValues(alpha: 0.95 * arrive),
    );

    canvas.drawPath(
      _glass,
      Paint()..color = secondary.withValues(alpha: 0.22 * arrive),
    );
    canvas.drawPath(
      _glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = secondary.withValues(alpha: 0.55 * arrive),
    );
  }

  /// Wheels turn off the same clock as everything else, so the car never
  /// looks like its legs are out of step with its body.
  void _paintWheels(Canvas canvas, double t) {
    const centres = [Offset(38, 44), Offset(116, 44)];
    const r = 13.0;
    final angle = t * math.pi * 2 * 3;

    final tyre = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = primary.withValues(alpha: 0.9 * arrive);

    final hub = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = secondary.withValues(alpha: 0.7 * arrive);

    for (final c in centres) {
      canvas.drawCircle(c, r, tyre);
      canvas.drawCircle(
        c,
        r * 0.30,
        Paint()..color = primary.withValues(alpha: 0.85 * arrive),
      );

      // Five spokes. Drawn as lines from a rotating basis rather than by
      // rotating the canvas five times, which would mean five save/restore
      // pairs per wheel per frame.
      for (var i = 0; i < 5; i++) {
        final a = angle + i * (math.pi * 2 / 5);
        final dx = math.cos(a);
        final dy = math.sin(a);
        canvas.drawLine(
          Offset(c.dx + dx * r * 0.34, c.dy + dy * r * 0.34),
          Offset(c.dx + dx * r * 0.86, c.dy + dy * r * 0.86),
          hub,
        );
      }
    }
  }

  /// A headlight that breathes. The same sine as the float, doubled, so the
  /// two motions stay related instead of fighting.
  void _paintHeadlight(Canvas canvas, double t) {
    final pulse = 0.72 + math.sin(t * math.pi * 4) * 0.28;
    const origin = Offset(144, 30);

    final cone = Path()
      ..moveTo(origin.dx, origin.dy - 3)
      ..lineTo(origin.dx + 46, origin.dy - 18)
      ..lineTo(origin.dx + 46, origin.dy + 16)
      ..lineTo(origin.dx, origin.dy + 3)
      ..close();

    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            secondary.withValues(alpha: 0.34 * pulse * arrive),
            secondary.withValues(alpha: 0.0),
          ],
        ).createShader(cone.getBounds()),
    );

    canvas.drawCircle(
      origin,
      3.4,
      Paint()..color = secondary.withValues(alpha: pulse * arrive),
    );
    canvas.drawCircle(
      origin,
      7.0,
      Paint()
        ..color = secondary.withValues(alpha: 0.4 * pulse * arrive)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  /// The whole point of the frame budget: repaint when the clock moved, and
  /// not because some unrelated part of the dashboard rebuilt.
  @override
  bool shouldRepaint(_CarHeroPainter old) =>
      old.t != t ||
      old.arrive != arrive ||
      old.primary != primary ||
      old.secondary != secondary;
}
