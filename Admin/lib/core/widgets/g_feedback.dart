import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'g_badge.dart';
import 'g_button.dart';
import 'pressable.dart';

/// App-wide feedback helpers. Every toast/sheet/dialog in the product goes
/// through here so timing, shape and haptics never drift.
class GFeedback {
  const GFeedback._();

  static void toast(
    BuildContext context,
    String message, {
    GTone tone = GTone.ink,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final p = context.c;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final t = toneOf(context, tone);
    final bg = tone == GTone.ink ? p.inverse : t.bg;
    final fg = tone == GTone.ink ? p.onInverse : t.fg;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: bg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg, vertical: Gap.md),
          margin: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          shape: RoundedRectangleBorder(
            borderRadius: R.rMd,
            side: BorderSide(
                color: tone == GTone.ink ? Colors.transparent : t.fg.withValues(alpha: 0.2)),
          ),
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: Gap.md),
              ],
              Expanded(
                child: Text(message, style: AppType.labelM.c(fg)),
              ),
              if (actionLabel != null)
                Pressable(
                  onTap: () {
                    messenger.hideCurrentSnackBar();
                    onAction?.call();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: Gap.md),
                    child: Text(actionLabel,
                        style: AppType.labelM.c(
                            tone == GTone.ink ? p.volt : t.fg)),
                  ),
                ),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) => toast(
      context, message,
      tone: GTone.success, icon: Icons.check_circle_rounded);

  static void error(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    toast(context, message, tone: GTone.danger, icon: Icons.error_rounded);
  }

  static void info(BuildContext context, String message) =>
      toast(context, message, icon: Icons.info_rounded);

  /// Rounded modal sheet with a grab handle and safe-area padding.
  static Future<T?> sheet<T>(
    BuildContext context, {
    required Widget child,
    bool isScrollControlled = true,
    bool dismissible = true,
    String? title,
    String? subtitle,
  }) {
    final p = context.c;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      barrierColor: p.scrim,
      builder: (context) {
        final p = context.c;
        return Container(
          margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + Gap.h2),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(R.xxl)),
            border: Border(top: BorderSide(color: p.line)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Gap.md),
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                    color: p.line, borderRadius: R.all(R.pill)),
              ),
              if (title != null) ...[
                const SizedBox(height: Gap.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: AppType.d3.c(p.ink)),
                            if (subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(subtitle,
                                  style: AppType.bodyS.c(p.inkMuted)),
                            ],
                          ],
                        ),
                      ),
                      GIconButton(
                        icon: Icons.close_rounded,
                        size: 36,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
              Flexible(child: child),
            ],
          ),
        );
      },
    );
  }

  /// Confirmation dialog. Returns true when the primary action is chosen.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: context.c.scrim,
      builder: (context) {
        final p = context.c;
        final tone = destructive ? GTone.danger : GTone.accent;
        final t = toneOf(context, tone);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
          child: Padding(
            padding: const EdgeInsets.all(Gap.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    height: 46,
                    width: 46,
                    decoration:
                        BoxDecoration(color: t.bg, borderRadius: R.all(R.md)),
                    child: Icon(icon, color: t.fg, size: 23),
                  ),
                  const SizedBox(height: Gap.lg),
                ],
                Text(title, style: AppType.d3.c(p.ink)),
                const SizedBox(height: Gap.sm),
                Text(message, style: AppType.bodyM.c(p.inkMuted)),
                const SizedBox(height: Gap.xxl),
                Row(
                  children: [
                    Expanded(
                      child: GButton(
                        label: cancelLabel,
                        kind: GButtonKind.ghost,
                        size: GButtonSize.md,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GButton(
                        label: confirmLabel,
                        kind: destructive
                            ? GButtonKind.danger
                            : GButtonKind.primary,
                        size: GButtonSize.md,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }
}

/// Sticky bottom action bar with a blurred, bordered surface.
class GBottomBar extends StatelessWidget {
  const GBottomBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
        boxShadow: Shadows.lifted(p),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Single-select row for sheets — replaces RadioListTile so the selection
/// affordance matches the rest of the design system.
class GOptionRow extends StatelessWidget {
  const GOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: AnimatedContainer(
        duration: Motion.fast,
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: Gap.md),
        decoration: BoxDecoration(
          color: selected ? p.surfaceSunken : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: selected ? p.ink : p.line),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: selected ? p.ink : p.inkMuted),
              const SizedBox(width: Gap.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppType.labelL.c(p.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppType.bodyS.c(p.inkMuted)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: Gap.sm)],
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 21,
              color: selected ? p.accent : p.line,
            ),
          ],
        ),
      ),
    );
  }
}
