import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'pressable.dart';

enum GButtonKind { primary, accent, outline, ghost, danger, volt }

enum GButtonSize { sm, md, lg }

class GButton extends StatelessWidget {
  const GButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = GButtonKind.primary,
    this.size = GButtonSize.lg,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    this.badge,
    this.onDark = false,
  });

  const GButton.accent({
    super.key,
    required this.label,
    this.onPressed,
    this.size = GButtonSize.lg,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    this.badge,
    this.onDark = false,
  }) : kind = GButtonKind.accent;

  const GButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.size = GButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.badge,
    this.onDark = false,
  }) : kind = GButtonKind.outline;

  const GButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = GButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.badge,
    this.onDark = false,
  }) : kind = GButtonKind.ghost;

  final String label;
  final VoidCallback? onPressed;
  final GButtonKind kind;
  final GButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;

  /// Optional trailing pill (e.g. a price on the sticky CTA).
  final String? badge;

  /// Set on an inverse surface. Outline and ghost buttons take their ink from
  /// the page, and on a dark card that ink is dark — which is how a Call
  /// button ends up invisible.
  final bool onDark;

  double get _height => switch (size) {
    GButtonSize.sm => 38,
    GButtonSize.md => 46,
    GButtonSize.lg => 56,
  };

  /// Pills at every size.
  ///
  /// The three sizes used to step 12 / 16 / 20, which meant a Back at md and a
  /// Next at lg sitting in the same row had visibly different corners. A
  /// single radius that is larger than any of the heights removes the choice
  /// and the mismatch with it.
  double get _radius => R.pill;

  TextStyle get _text => switch (size) {
    GButtonSize.sm => AppType.labelM,
    GButtonSize.md => AppType.labelL,
    GButtonSize.lg => AppType.labelL.s(15.5),
  };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final disabled = onPressed == null || loading;

    late final Color bg;
    late final Color fg;
    Border? border;
    List<BoxShadow>? shadow;
    Gradient? gradient;

    switch (kind) {
      case GButtonKind.primary:
        bg = p.ink;
        fg = p.isDark ? p.canvas : Colors.white;
        shadow = disabled ? null : Shadows.soft(p);
      case GButtonKind.accent:
        bg = p.accent;
        fg = p.onAccent;
        gradient = disabled ? null : p.accentGradient;
        shadow = disabled ? null : Shadows.accent(p);
      case GButtonKind.outline:
        bg = Colors.transparent;
        fg = onDark ? p.onInverse : p.ink;
        border = Border.all(
          color: onDark ? p.onInverse.withValues(alpha: 0.35) : p.line,
          width: 1.4,
        );
      case GButtonKind.ghost:
        bg = onDark ? p.onInverse.withValues(alpha: 0.12) : p.surfaceSunken;
        fg = onDark ? p.onInverse : p.ink;
      case GButtonKind.danger:
        bg = p.dangerSoft;
        fg = p.danger;
      case GButtonKind.volt:
        bg = p.volt;
        fg = const Color(0xFF10160A);
    }

    final content = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: fg.withValues(alpha: 0.9),
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: size == GButtonSize.sm ? 16 : 19, color: fg),
                const SizedBox(width: Gap.sm),
              ],
              // A button label is never shortened to "Update or …". If the
              // words do not fit, the type gives way instead — the whole
              // label always stays readable.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: _text.c(fg),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: Gap.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.16),
                    borderRadius: R.all(R.xs),
                  ),
                  child: Text(badge!, style: AppType.moneyS.c(fg)),
                ),
              ],
              if (trailingIcon != null) ...[
                const SizedBox(width: Gap.sm),
                Icon(
                  trailingIcon,
                  size: size == GButtonSize.sm ? 16 : 19,
                  color: fg,
                ),
              ],
            ],
          );

    Widget body(bool fill) => Pressable(
      onTap: disabled ? null : onPressed,
      enabled: !disabled,
      scale: 0.975,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        height: _height,
        width: fill ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: size == GButtonSize.sm ? Gap.md : Gap.xl,
        ),
        decoration: BoxDecoration(
          color: disabled && gradient != null ? p.inkFaint : bg,
          gradient: gradient,
          borderRadius: R.all(_radius),
          border: border,
          boxShadow: shadow,
        ),
        child: Center(
          child: loading
              ? content
              : (fill
                    ? content
                    // A shrink-wrapped button must not ask its row for
                    // infinity either.
                    : _tight(content)),
        ),
      ),
    );

    // A button that was never going to stretch is built straight, with no
    // [LayoutBuilder] over it. That matters beyond one frame saved: a
    // LayoutBuilder cannot answer an intrinsic measurement, and anything that
    // measures its children before laying them out — `AlertDialog.actions`,
    // `OverflowBar`, `IntrinsicWidth`, a `Table` — asks for one. Wrapped, the
    // button threw on layout there and took the whole dialog down with it.
    if (!expand) return body(false);

    // `expand` means "fill the width you are given", not "demand infinity".
    // Dropped straight into a Row the width on offer is unbounded, and
    // forcing it there is a hard crash rather than a layout nudge — so the
    // button shrink-wraps instead, and the caller gets a button rather than
    // a red screen.
    return LayoutBuilder(
      builder: (context, box) => body(box.maxWidth.isFinite),
    );
  }

  /// The label row, told to take only the width it needs.
  static Widget _tight(Widget content) => content is Row
      ? Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: content.mainAxisAlignment,
          children: content.children,
        )
      : content;
}

/// Compact square icon button used in app bars and card corners.
class GIconButton extends StatelessWidget {
  const GIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 42,
    this.background,
    this.foreground,
    this.bordered = true,
    this.badgeCount,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? foreground;
  final bool bordered;
  final int? badgeCount;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final button = Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: background ?? p.surface,
          shape: BoxShape.circle,
          border: bordered ? Border.all(color: p.line) : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, size: size * 0.45, color: foreground ?? p.ink),
            if (badgeCount != null && badgeCount! > 0)
              Positioned(
                top: size * 0.16,
                right: size * 0.16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(
                    minWidth: 15,
                    minHeight: 15,
                  ),
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: R.all(R.pill),
                    border: Border.all(
                      color: background ?? p.surface,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      badgeCount! > 9 ? '9+' : '$badgeCount',
                      style: AppType.labelS.s(9).c(p.onAccent),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Text-only action, used for "See all" style affordances.
class GLink extends StatelessWidget {
  const GLink({super.key, required this.label, this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppType.labelM.c(p.accentInk)),
            if (icon != null) ...[
              const SizedBox(width: 3),
              Icon(icon, size: 15, color: p.accentInk),
            ],
          ],
        ),
      ),
    );
  }
}
