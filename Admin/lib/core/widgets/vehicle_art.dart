import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../data/models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'pressable.dart';

/// The vehicle itself, drawn or photographed, and animated on the change.
///
/// ## Why there are two of these and not one
///
/// A photograph is the better picture where one exists: the counter is
/// looking for *their* customer's car and recognises it faster than it reads
/// `Maruti Suzuki Swift VXi`. But photography only covers cars, and only the
/// popular ones. A workshop that takes in bikes and autos would be looking at
/// a stock sedan on every other job card.
///
/// So the fallback is a drawing rather than a stand-in photograph. It is
/// correct for the body it claims to be, it costs nothing to ship, and next
/// to the damage sheet's line art it reads as the same hand.
///
/// ## The motion
///
/// Changing the make, the model or the type is the moment this widget exists
/// for — it is the only confirmation the counter gets that the pick landed.
/// So the change is what is animated, and in two registers:
///
/// * a **photograph** slides in from the left and settles, the outgoing one
///   leaving the same way, so a run of picks reads as one thing replacing
///   another rather than a flicker;
/// * a **drawing** traces itself on, stroke by stroke, front to back. It
///   takes about as long as the slide, so switching between a model that has
///   a photograph and one that does not does not change the rhythm.
///
/// Nothing loops. This sits on a form the counter is working down, and a
/// picture that never stops moving beside a text field is a picture that is
/// read once and then resented.
class VehicleArt extends StatelessWidget {
  const VehicleArt({
    super.key,
    required this.shape,
    this.photo,
    this.height = 132,
    this.tint,
    this.animate = true,
  });

  /// What to draw when there is no [photo]. Also what a photograph is framed
  /// as, so a bike thumbnail is not letterboxed to a car's proportions.
  final VehicleShape shape;

  /// A bundled photograph of this exact model, or null to draw it instead.
  final String? photo;

  final double height;

  /// The ink the drawing is made in. Defaults to the palette's muted ink.
  final Color? tint;

  /// Off for a printed document or a golden test, where the picture has to be
  /// whatever it finally settles on from the first frame.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final art = photo == null
        ? _Silhouette(shape: shape, color: tint ?? p.inkMuted, animate: animate)
        : _Photo(asset: photo!, height: height);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: animate
            ? AnimatedSwitcher(
                duration: Motion.slow,
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                // The default layout centres the incoming child over the
                // outgoing one and sizes to the larger; both children here
                // fill the box, so a plain stack is what is wanted and it
                // keeps the two from fighting over the box's height.
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(-0.22, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(parent: anim, curve: Motion.spring),
                        ),
                    child: child,
                  ),
                ),
                // Keyed on what is actually being shown. Re-picking the same
                // model must not replay the entrance, and a variant change
                // that does not change the picture must not either.
                child: KeyedSubtree(
                  key: ValueKey('${photo ?? ''}|${shape.name}'),
                  child: art,
                ),
              )
            : art,
      ),
    );
  }
}

/// A bundled photograph, darkened towards the bottom so type can sit on it.
class _Photo extends StatelessWidget {
  const _Photo({required this.asset, required this.height});

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          // Decoding at the size it is drawn at rather than at the file's own
          // 1200px keeps a list of these off the image cache's ceiling.
          cacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
              .round(),
          // A file listed in the manifest but missing from the build is a
          // broken box on a counter screen; a plain surface is not.
          errorBuilder: (_, _, _) => ColoredBox(color: p.surfaceSunken),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: 0.38),
              ],
              stops: const [0.45, 0.7, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The drawings
// ---------------------------------------------------------------------------

/// One side elevation per body style, as SVG path data in a 200x100 box.
///
/// Deliberately *not* the damage sheet's drawings. Those are a technical
/// four-view sheet meant to be marked on with a finger, so they carry every
/// panel line a body shop argues about. These are one clean outline each,
/// meant to be read at 40px on a list row, and there is a six-wheeler here
/// because the setup screen offers one and the damage sheet does not.
///
/// Front is at the right in every one of them, so a row of them all face the
/// same way.
const Map<VehicleShape, List<String>> _drawings = {
  VehicleShape.twoWheeler: [
    'M 34 30 L 58 40 L 98 42 Q 118 30 138 38 L 146 52 L 130 58 L 134 72 L 104 74 L 100 56 L 62 56 Z',
    'M 150 40 L 161 72',
    'M 140 32 L 170 27',
    'M 142 54 Q 162 45 182 58',
    'M 100 70 L 46 72',
    'M 124 74 Q 98 85 70 81',
    'M 42 72 m -22 0 a 22 22 0 1 0 44 0 a 22 22 0 1 0 -44 0',
    'M 42 72 m -9 0 a 9 9 0 1 0 18 0 a 9 9 0 1 0 -18 0',
    'M 158 72 m -22 0 a 22 22 0 1 0 44 0 a 22 22 0 1 0 -44 0',
    'M 158 72 m -9 0 a 9 9 0 1 0 18 0 a 9 9 0 1 0 -18 0',
  ],
  VehicleShape.threeWheeler: [
    'M 34 78 L 30 44 Q 33 20 64 15 L 122 14 Q 150 18 156 42 L 162 70 L 166 78 Z',
    'M 46 26 Q 50 20 62 18 L 92 17 L 92 50 L 44 50 Z',
    'M 102 18 L 128 19 Q 144 23 148 36 L 102 40 Z',
    'M 97 15 L 97 52',
    'M 38 52 L 156 52',
    'M 36 66 L 160 66',
    'M 148 38 Q 157 41 159 51 L 145 52 Z',
    'M 56 80 m -19 0 a 19 19 0 1 0 38 0 a 19 19 0 1 0 -38 0',
    'M 56 80 m -8 0 a 8 8 0 1 0 16 0 a 8 8 0 1 0 -16 0',
    'M 164 82 m -15 0 a 15 15 0 1 0 30 0 a 15 15 0 1 0 -30 0',
    'M 164 82 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0',
  ],
  VehicleShape.fourWheeler: [
    'M 8 74 L 7 54 Q 7 44 18 42 L 56 40 L 78 18 L 128 18 L 152 39 L 182 42 Q 194 45 195 57 L 195 74 Z',
    'M 64 39 L 82 21 L 100 21 L 100 39 Z',
    'M 106 39 L 106 21 L 124 21 L 140 39 Z',
    'M 103 39 L 103 66',
    'M 64 41 L 64 65',
    'M 142 41 L 142 65',
    'M 88 46 L 97 46',
    'M 110 46 L 119 46',
    'M 62 64 L 142 64',
    'M 43 75 m -16 0 a 16 16 0 1 0 32 0 a 16 16 0 1 0 -32 0',
    'M 43 75 m -7 0 a 7 7 0 1 0 14 0 a 7 7 0 1 0 -14 0',
    'M 157 75 m -16 0 a 16 16 0 1 0 32 0 a 16 16 0 1 0 -32 0',
    'M 157 75 m -7 0 a 7 7 0 1 0 14 0 a 7 7 0 1 0 -14 0',
  ],
  VehicleShape.sixWheeler: [
    'M 10 70 L 10 20 L 114 20 L 114 70 Z',
    'M 44 20 L 44 70',
    'M 78 20 L 78 70',
    'M 118 72 L 116 34 Q 118 22 130 20 L 158 20 Q 172 24 178 40 L 184 56 L 186 72 Z',
    'M 128 28 L 156 27 Q 166 30 170 42 L 128 44 Z',
    'M 8 72 L 188 72',
    'M 176 54 L 187 55 L 187 63 L 177 62 Z',
    'M 28 78 m -15 0 a 15 15 0 1 0 30 0 a 15 15 0 1 0 -30 0',
    'M 28 78 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0',
    'M 60 78 m -15 0 a 15 15 0 1 0 30 0 a 15 15 0 1 0 -30 0',
    'M 60 78 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0',
    'M 158 78 m -15 0 a 15 15 0 1 0 30 0 a 15 15 0 1 0 -30 0',
    'M 158 78 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0',
  ],
};

/// The box [_drawings] are laid out in. Everything is scaled to fit it.
const Size _box = Size(200, 100);

/// The outline, traced on when it appears.
class _Silhouette extends StatefulWidget {
  const _Silhouette({
    required this.shape,
    required this.color,
    required this.animate,
  });

  final VehicleShape shape;
  final Color color;
  final bool animate;

  @override
  State<_Silhouette> createState() => _SilhouetteState();
}

class _SilhouetteState extends State<_Silhouette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.lazy,
    value: widget.animate ? 0 : 1,
  );

  /// Parsed once. `parseSvgPathData` is a string parse and `computeMetrics`
  /// walks the whole outline — doing either inside `paint` would do it sixty
  /// times a second for the length of the trace.
  late List<ui.PathMetric> _metrics = _measure(widget.shape);

  static List<ui.PathMetric> _measure(VehicleShape shape) => [
    for (final d in _drawings[shape]!) ...parseSvgPathData(d).computeMetrics(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void didUpdateWidget(_Silhouette old) {
    super.didUpdateWidget(old);
    // The switcher usually gives a new shape a new State, but this widget is
    // also used on its own — on the type chips, where the shape is fixed but
    // the colour is not. Re-measure only when the drawing itself changed.
    if (old.shape != widget.shape) {
      _metrics = _measure(widget.shape);
      if (widget.animate) _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _SilhouettePainter(
            metrics: _metrics,
            color: widget.color,
            progress: _c.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter({
    required this.metrics,
    required this.color,
    required this.progress,
  });

  final List<ui.PathMetric> metrics;
  final Color color;

  /// 0 is nothing drawn, 1 is the whole outline.
  final double progress;

  /// How much of the run each stroke gets to itself. The rest is the stagger,
  /// so the drawing arrives front to back instead of every line at once.
  static const double _strokeShare = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || metrics.isEmpty) return;

    // Contain rather than fill: a wide card must not crop the vehicle's nose
    // off, and a narrow one must not stretch it.
    final scale = (size.width / _box.width).clamp(
      0.0,
      size.height / _box.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - _box.width * scale) / 2,
      (size.height - _box.height * scale) / 2,
    );
    canvas.scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.6;

    final stagger = metrics.length <= 1
        ? 0.0
        : (1 - _strokeShare) / (metrics.length - 1);

    for (var i = 0; i < metrics.length; i++) {
      final m = metrics[i];
      final t = ((progress - stagger * i) / _strokeShare)
          .clamp(0.0, 1.0)
          .toDouble();
      if (t <= 0) continue;
      canvas.drawPath(
        t >= 1 ? m.extractPath(0, m.length) : m.extractPath(0, m.length * t),
        paint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter old) =>
      old.progress != progress ||
      old.color != color ||
      !identical(old.metrics, metrics);
}

// ---------------------------------------------------------------------------
// Picking a body style
// ---------------------------------------------------------------------------

/// One tappable body style: the drawing, its name, and a selected state.
///
/// The drawing is the control. A row of four Material glyphs all read as the
/// same grey shape at a glance, and the counter picking `2W` on a car is a
/// mis-drawn damage sheet and a bike on the customer's invoice. Here the
/// chosen one inverts and re-traces itself, which is both the confirmation
/// that the tap landed and a second look at what was actually picked.
class VehicleShapeChip extends StatelessWidget {
  const VehicleShapeChip({
    super.key,
    required this.shape,
    required this.selected,
    required this.onTap,
    this.showLabel = true,
  });

  final VehicleShape shape;
  final bool selected;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final ink = selected ? (p.isDark ? p.canvas : Colors.white) : p.inkSoft;

    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.emphasized,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.sm,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? p.ink : p.surface,
          borderRadius: R.rMd,
          border: Border.all(color: selected ? p.ink : p.line),
          boxShadow: selected ? Shadows.soft(p) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 30,
              // A fresh State on every change of selection, so the outline
              // re-traces itself in the new ink rather than just recolouring.
              child: KeyedSubtree(
                key: ValueKey(selected),
                child: _Silhouette(shape: shape, color: ink, animate: true),
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: Motion.fast,
                style: AppType.labelS.s(10.5).c(ink),
                child: Text(shape.short),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
