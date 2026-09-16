import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/pressable.dart';

/// One square on the console grid — Inventory, Reports, Feedback and friends.
class ConsoleTile extends StatelessWidget {
  const ConsoleTile({
    super.key,
    required this.title,
    required this.blurb,
    required this.icon,
    required this.tone,
    this.onTap,
    this.badge,
  });

  final String title;
  final String blurb;
  final IconData icon;
  final GTone tone;
  final VoidCallback? onTap;

  /// Small count in the corner — low stock, unread bookings, and so on.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = toneOf(context, tone);
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration:
                      BoxDecoration(color: t.bg, borderRadius: R.all(R.sm)),
                  child: Icon(icon, size: 19, color: t.fg),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: R.all(R.pill),
                    ),
                    child: Text(badge!, style: AppType.labelS.s(10).c(t.fg)),
                  ),
              ],
            ),
            const Spacer(),
            Text(title,
                style: AppType.labelL.c(p.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              blurb,
              style: AppType.bodyS.s(11.5).c(p.inkMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
