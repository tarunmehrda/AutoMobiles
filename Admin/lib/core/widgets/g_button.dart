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

  double get _height => switch (size) {
        GButtonSize.sm => 38,
        GButtonSize.md => 46,
        GButtonSize.lg => 56,
      };

  double get _radius => switch (size) {
        GButtonSize.sm => R.sm,
        GButtonSize.md => R.md,
        GButtonSize.lg => R.lg,
      };

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
        fg = p.ink;
        border = Border.all(color: p.line, width: 1.4);
      case GButtonKind.ghost:
        bg = p.surfaceSunken;
        fg = p.ink;
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
                strokeWidth: 2.2, color: fg.withValues(alpha: 0.9)),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: size == GButtonSize.sm ? 16 : 19, color: fg),
                const SizedBox(width: Gap.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: _text.c(fg),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: Gap.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.16),
                    borderRadius: R.all(R.xs),
                  ),
                  child: Text(badge!, style: AppType.moneyS.c(fg)),
                ),
              ],
              if (trailingIcon != null) ...[
                const SizedBox(width: Gap.sm),
                Icon(trailingIcon,
                    size: size == GButtonSize.sm ? 16 : 19, color: fg),
              ],
            ],
          );

    return Pressable(
      onTap: disabled ? null : onPressed,
      enabled: !disabled,
      scale: 0.975,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        height: _height,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(
            horizontal: size == GButtonSize.sm ? Gap.md : Gap.xl),
        decoration: BoxDecoration(
          color: disabled && gradient != null ? p.inkFaint : bg,
          gradient: gradient,
          borderRadius: R.all(_radius),
          border: border,
          boxShadow: shadow,
        ),
        child: Center(child: content),
      ),
    );
  }
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
          borderRadius: R.all(R.md),
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
                  constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: R.all(R.pill),
                    border: Border.all(color: background ?? p.surface, width: 2),
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
