import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// Every tappable surface in the app uses this: a subtle scale + opacity
/// response with haptics. Gives the whole product one consistent "feel".
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = true,
    this.borderRadius,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final BorderRadius? borderRadius;
  final bool enabled;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _active =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _set(bool v) {
    if (_down == v || !_active) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: _active
          ? () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap?.call();
            }
          : null,
      onLongPress: _active && widget.onLongPress != null
          ? () {
              if (widget.haptic) HapticFeedback.mediumImpact();
              widget.onLongPress!.call();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: Motion.instant,
        curve: Motion.enter,
        child: AnimatedOpacity(
          opacity: !widget.enabled ? 0.55 : (_down ? 0.92 : 1.0),
          duration: Motion.instant,
          child: widget.child,
        ),
      ),
    );
  }
}
