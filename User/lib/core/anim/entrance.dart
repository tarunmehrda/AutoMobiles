import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Fade + rise entrance. Staggered by [index] so lists cascade in.
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
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _c.value = 1;
      return;
    }
    final total = widget.delay + widget.stagger * widget.index;
    if (total == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(total, () {
        if (!_disposed && mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Motion.enter);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final t = curve.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: widget.scaleFrom == null
                ? child
                : Transform.scale(
                    scale: widget.scaleFrom! + (1 - widget.scaleFrom!) * t,
                    child: child,
                  ),
          ),
        );
      },
      child: widget.child,
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
          position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
