import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/pressable.dart';

/// One tool in the dashboard's toolbox.
///
/// A plain white card with a tinted glyph and a chevron. The tint is the only
/// thing that varies between tiles, and it varies so the eye can find
/// Inventory without reading the word — nine identically-grey tiles are a
/// list, not a toolbox.
class ActionTile extends StatelessWidget {
  const ActionTile({
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

  /// Small count or alert on the tile — low stock, waiting bookings, etc.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = toneOf(context, tone);

    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.isDark ? p.surface : Colors.white,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.isDark ? p.line : p.lineSoft),
          boxShadow: p.isDark ? null : Shadows.soft(p),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: p.isDark
                        ? t.fg.withValues(alpha: 0.18)
                        : Color.alphaBlend(t.fg.withValues(alpha: 0.10), t.bg),
                    borderRadius: R.all(R.sm),
                  ),
                  child: Icon(icon, size: 22, color: t.fg),
                ),
                const Spacer(),
                if (badge != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: R.all(R.pill),
                      ),
                      child: Text(
                        badge!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelS
                            .s(8.5)
                            .c(p.onAccent)
                            .w(FontWeight.w800),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 22,
                    width: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.isDark ? p.surfaceSunken : p.canvas,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: p.inkMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelM
                  .s(12.5)
                  .c(p.ink)
                  .w(FontWeight.w700)
                  .copyWith(height: 1.15),
            ),
            const SizedBox(height: 2),
            Text(
              blurb,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodyS.s(10).c(p.inkMuted).copyWith(height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
