import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'g_button.dart';
import 'pressable.dart';

/// The app's base card. Hairline border + whisper-soft shadow rather than
/// Material elevation, so stacked content stays calm.
class GCard extends StatelessWidget {
  const GCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.onTap,
    this.radius = R.lg,
    this.color,
    this.border = true,
    this.elevated = false,
    this.gradient,
    this.borderColor,
    this.margin,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final bool border;
  final bool elevated;
  final Gradient? gradient;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final box = Container(
      margin: margin,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? p.surface) : null,
        gradient: gradient,
        borderRadius: R.all(radius),
        border: border
            ? Border.all(color: borderColor ?? p.line, width: 1)
            : null,
        boxShadow: elevated ? Shadows.lifted(p) : Shadows.soft(p),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, scale: 0.985, child: box);
  }
}

/// Section heading with optional eyebrow and trailing action.
class GSectionHeader extends StatelessWidget {
  const GSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(Gap.page, Gap.xxl, Gap.page, Gap.md),
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(),
                      style: AppType.over.c(p.accentInk)),
                  const SizedBox(height: 5),
                ],
                Text(title, style: AppType.h1.c(p.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: AppType.bodyS.c(p.inkMuted)),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            GLink(
              label: actionLabel!,
              onTap: onAction,
              icon: Icons.arrow_forward_rounded,
            ),
        ],
      ),
    );
  }
}

/// Row used across Account, Support and settings lists.
class GTile extends StatelessWidget {
  const GTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.iconBg,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.dense = false,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBg;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool dense;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: dense ? Gap.md : Gap.lg - 2),
        child: Row(
          children: [
            if (leading != null)
              leading!
            else if (icon != null)
              Container(
                height: dense ? 34 : 40,
                width: dense ? 34 : 40,
                decoration: BoxDecoration(
                  color: iconBg ?? p.surfaceSunken,
                  borderRadius: R.all(R.sm),
                ),
                child: Icon(icon, size: dense ? 17 : 20, color: iconColor ?? p.inkSoft),
              ),
            if (leading != null || icon != null) const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.labelL.c(p.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: AppType.bodyS.c(p.inkMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null && showChevron && onTap != null)
              Icon(Icons.chevron_right_rounded, color: p.inkFaint, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Grouped container for a run of [GTile]s.
class GTileGroup extends StatelessWidget {
  const GTileGroup({super.key, required this.children, this.title});

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xs, 0, 0, Gap.sm),
            child: Text(title!.toUpperCase(), style: AppType.over.c(p.inkFaint)),
          ),
        GCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 68),
                    child: Divider(height: 1, color: p.lineSoft),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Dashed separator used on invoices and job cards.
class GDashedLine extends StatelessWidget {
  const GDashedLine({super.key, this.color, this.height = 1, this.dash = 5, this.gap = 4});

  final Color? color;
  final double height;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return LayoutBuilder(
      builder: (context, c) {
        final count = (c.maxWidth / (dash + gap)).floor().clamp(1, 400);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: height,
              color: color ?? p.line,
            ),
          ),
        );
      },
    );
  }
}

/// Key/value row used in summaries and invoices.
class GKeyValue extends StatelessWidget {
  const GKeyValue({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
    this.labelColor,
    this.strikeValue,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;
  final Color? labelColor;
  final String? strikeValue;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize
                  ? AppType.labelL.c(labelColor ?? p.ink)
                  : AppType.bodyM.c(labelColor ?? p.inkMuted),
            ),
          ),
          const SizedBox(width: Gap.md),
          if (strikeValue != null) ...[
            Text(
              strikeValue!,
              style: AppType.moneyS.c(p.inkFaint).copyWith(
                  decoration: TextDecoration.lineThrough,
                  decorationColor: p.inkFaint),
            ),
            const SizedBox(width: Gap.sm),
          ],
          Text(
            value,
            style: emphasize
                ? AppType.money.c(valueColor ?? p.ink)
                : AppType.moneyS.c(valueColor ?? p.inkSoft),
          ),
        ],
      ),
    );
  }
}
