import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'pressable.dart';

enum GTone { neutral, accent, success, warning, danger, info, ink, volt }

class ToneColors {
  const ToneColors(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

ToneColors toneOf(BuildContext context, GTone tone) {
  final p = context.c;
  return switch (tone) {
    GTone.neutral => ToneColors(p.inkMuted, p.surfaceSunken),
    GTone.accent => ToneColors(p.accentInk, p.accentSoft),
    GTone.success => ToneColors(p.success, p.successSoft),
    GTone.warning => ToneColors(p.warning, p.warningSoft),
    GTone.danger => ToneColors(p.danger, p.dangerSoft),
    GTone.info => ToneColors(p.info, p.infoSoft),
    GTone.ink => ToneColors(p.isDark ? p.canvas : Colors.white, p.ink),
    GTone.volt => ToneColors(const Color(0xFF10160A), p.volt),
  };
}

/// Small status pill: booking status, discount, urgency, health.
class GPill extends StatelessWidget {
  const GPill({
    super.key,
    required this.label,
    this.tone = GTone.neutral,
    this.icon,
    this.dot = false,
    this.compact = false,
    this.pulse = false,
  });

  final String label;
  final GTone tone;
  final IconData? icon;
  final bool dot;
  final bool compact;

  /// Animated ring for "live" states.
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final t = toneOf(context, tone);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? Gap.sm : Gap.md, vertical: compact ? 3 : 5.5),
      decoration: BoxDecoration(color: t.bg, borderRadius: R.all(R.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            _Dot(color: t.fg, pulse: pulse),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: compact ? 11 : 13, color: t.fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (compact ? AppType.labelS.s(10.5) : AppType.labelS).c(t.fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.pulse});
  final Color color;
  final bool pulse;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  // Created only when the dot actually pulses. A `late final` here would be
  // constructed by dispose() on the far more common static dots, which builds
  // a Ticker against an already-deactivated element.
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _start();
  }

  void _start() {
    _c ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _c!.repeat();
  }

  @override
  void didUpdateWidget(covariant _Dot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse) {
      if (!(_c?.isAnimating ?? false)) _start();
    } else {
      _c?.stop();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = Container(
      height: 7,
      width: 7,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (!widget.pulse || _c == null) return core;
    return SizedBox(
      height: 7,
      width: 7,
      child: AnimatedBuilder(
        animation: _c!,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_c!.value);
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: (1 - t) * 0.55,
                child: Container(
                  height: 7 + 12 * t,
                  width: 7 + 12 * t,
                  decoration: BoxDecoration(
                      color: widget.color, shape: BoxShape.circle),
                ),
              ),
              child!,
            ],
          );
        },
        child: core,
      ),
    );
  }
}

/// Rectangular tag with a leading icon — used on service cards.
class GTag extends StatelessWidget {
  const GTag({
    super.key,
    required this.label,
    this.icon,
    this.tone = GTone.neutral,
    this.outlined = false,
  });

  final String label;
  final IconData? icon;
  final GTone tone;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final t = toneOf(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : t.bg,
        borderRadius: R.all(R.xs),
        border: outlined ? Border.all(color: context.c.line) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: t.fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelS.s(11).c(t.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling single-select chips.
class GChoiceChips<T> extends StatelessWidget {
  const GChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.labelOf,
    this.padding = const EdgeInsets.symmetric(horizontal: Gap.page),
    this.iconOf,
    this.countOf,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelect;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;
  final String? Function(T)? countOf;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, i) {
          final o = options[i];
          final isSel = o == selected;
          final icon = iconOf?.call(o);
          final count = countOf?.call(o);
          return Pressable(
            onTap: () => onSelect(o),
            scale: 0.94,
            child: AnimatedContainer(
              duration: Motion.fast,
              curve: Motion.enter,
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              decoration: BoxDecoration(
                color: isSel ? p.ink : p.surface,
                borderRadius: R.all(R.pill),
                border: Border.all(color: isSel ? p.ink : p.line),
                boxShadow: isSel ? Shadows.soft(p) : null,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon,
                        size: 15,
                        color: isSel
                            ? (p.isDark ? p.canvas : Colors.white)
                            : p.inkMuted),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    labelOf(o),
                    style: AppType.labelM.c(isSel
                        ? (p.isDark ? p.canvas : Colors.white)
                        : p.inkSoft),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 5),
                    Text(count,
                        style: AppType.labelS.c(isSel
                            ? (p.isDark ? p.canvas : Colors.white)
                                .withValues(alpha: 0.6)
                            : p.inkFaint)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Avatar with initials fallback.
class GAvatar extends StatelessWidget {
  const GAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.imageUrl,
    this.tone = GTone.ink,
  });

  final String initials;
  final double size;
  final String? imageUrl;
  final GTone tone;

  @override
  Widget build(BuildContext context) {
    final t = toneOf(context, tone);
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.bg,
        shape: BoxShape.circle,
        image: imageUrl != null && imageUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? null
          : Text(initials,
              style: AppType.h3.s(size * 0.36).c(t.fg)),
    );
  }
}
