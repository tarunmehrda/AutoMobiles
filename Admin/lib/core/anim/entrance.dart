import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Marks the moment a screenful of [Entrance] widgets began arriving.
///
/// Without it, an `Entrance` inside a `ListView.builder` is wrong twice
/// over. The list recycles, so scrolling away and back builds a fresh State
/// and the row fades in all over again — the list flickers every time you
/// move through it. And the stagger is counted from whenever the row
/// happened to be built, so a row you scroll to after the cascade has
/// finished still sits invisible for its share of the delay before popping
/// in.
///
/// A scope gives every descendant one shared clock. A row built while the
/// cascade is still running joins it partway; a row built after it has
/// finished simply appears, because the entrance it would have played is
/// already over.
/// Stateful, so the clock survives its parent rebuilding. As a plain
/// [InheritedWidget] it would be reconstructed — and the stopwatch restarted
/// — every time the screen above it rebuilt, which on this list is every
/// keystroke in the search box: the cascade would replay as you typed.
class EntranceScope extends StatefulWidget {
  const EntranceScope({super.key, required this.child});

  final Widget child;

  /// How long ago this scope appeared, or null outside one.
  static Duration? elapsedOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_EntranceClock>()?.clock.elapsed;

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope> {
  final Stopwatch _clock = Stopwatch()..start();

  @override
  Widget build(BuildContext context) =>
      _EntranceClock(clock: _clock, child: widget.child);
}

/// Carries the stopwatch itself rather than a reading of it, so every
/// descendant asks the same clock what time it is now.
class _EntranceClock extends InheritedWidget {
  const _EntranceClock({required this.clock, required super.child});

  final Stopwatch clock;

  @override
  bool updateShouldNotify(_EntranceClock oldWidget) => oldWidget.clock != clock;
}

/// Fade + rise entrance. Staggered by [index] so lists cascade in.
///
/// Wrap a list in an [EntranceScope] and the cascade stops replaying as the
/// list is scrolled.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.offset = 18,
    this.duration = Motion.slow,
    this.stagger = const Duration(milliseconds: 55),
    this.scaleFrom,
    this.enabled = true,
  });

  final Widget child;
  final int index;
  final Duration delay;
  final double offset;
  final Duration duration;
  final Duration stagger;
  final double? scaleFrom;
  final bool enabled;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// Built once. It used to be created inside `build`, which allocated a new
  /// one — and left the old one listening — on every frame of every row.
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _c,
    curve: Motion.enter,
  );

  /// Held so it can be cancelled on dispose rather than firing into a dead
  /// State and being caught by a flag.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _c.value = 1;
      return;
    }

    final start = widget.delay + widget.stagger * widget.index;
    final elapsed = EntranceScope.elapsedOf(context);

    // No scope: behave as a one-off entrance, timed from now.
    if (elapsed == null) {
      _begin(start);
      return;
    }

    // The whole entrance already happened while this row was off screen.
    // Showing it finished is the honest result — replaying it is the flicker.
    if (elapsed >= start + widget.duration) {
      _c.value = 1;
      return;
    }
    // Mid-cascade: join it where it already is.
    if (elapsed >= start) {
      _c.forward(
        from: (elapsed - start).inMicroseconds / widget.duration.inMicroseconds,
      );
      return;
    }
    _begin(start - elapsed);
  }

  void _begin(Duration wait) {
    if (wait <= Duration.zero) {
      _c.forward();
      return;
    }
    _timer = Timer(wait, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FadeTransition rather than an Opacity rebuilt by the builder: it drives
    // the fade at the render layer, so the subtree is not rebuilt sixty times
    // a second for every row on screen.
    Widget child = widget.child;

    if (widget.scaleFrom != null) {
      child = ScaleTransition(
        scale: _curve.drive(Tween(begin: widget.scaleFrom, end: 1)),
        child: child,
      );
    }

    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        // The offset is in pixels, not a fraction of the row, so this stays a
        // Transform. Rebuilding one Transform per frame is cheap; the
        // saveLayer that Opacity forced was not.
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

/// Counts a number up when it first appears (and on every change).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.builder,
    this.duration = Motion.slow,
    this.curve = Motion.enter,
  });

  final double value;
  final Widget Function(BuildContext, double) builder;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

/// Cross-fades between children of possibly different sizes.
class GSwap extends StatelessWidget {
  const GSwap({
    super.key,
    required this.child,
    this.duration = Motion.base,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
