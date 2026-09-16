import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'g_button.dart';

/// Standard page header: back chevron, title, optional subtitle and actions.
/// Used instead of AppBar so spacing matches the rest of the design system.
class GHeader extends StatelessWidget implements PreferredSizeWidget {
  const GHeader({
    super.key,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
    this.background,
    this.bottom,
    this.centered = false,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final Color? background;
  final Widget? bottom;
  final bool centered;

  @override
  Size get preferredSize => Size.fromHeight(bottom == null ? 62 : 62 + 54);

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      color: background ?? Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  const SizedBox(width: Gap.lg),
                  if (showBack) ...[
                    GIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 40,
                      onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: Gap.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: centered
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (title != null)
                          Text(title!,
                              style: AppType.h1.c(p.ink),
                              overflow: TextOverflow.ellipsis),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: AppType.bodyS.c(p.inkMuted),
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  for (final a in actions) ...[
                    a,
                    const SizedBox(width: Gap.sm),
                  ],
                  SizedBox(width: actions.isEmpty ? Gap.lg : Gap.sm),
                ],
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}

/// Large collapsing title used on the tab roots (My Garage, Support, Account).
class GSliverHeader extends StatelessWidget {
  const GSliverHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.eyebrow,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null) ...[
                    Text(eyebrow!.toUpperCase(),
                        style: AppType.over.c(p.accentInk)),
                    const SizedBox(height: 6),
                  ],
                  Text(title, style: AppType.d2.c(p.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: AppType.bodyM.c(p.inkMuted)),
                  ],
                ],
              ),
            ),
            for (final a in actions) ...[const SizedBox(width: Gap.sm), a],
          ],
        ),
      ),
    );
  }
}
