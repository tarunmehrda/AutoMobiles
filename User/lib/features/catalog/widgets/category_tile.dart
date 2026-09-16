import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/anim/entrance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/seed/catalog_seed.dart';

/// Compact 4-up tile for the Home quick grid.
class CategoryQuickTile extends StatelessWidget {
  const CategoryQuickTile({
    super.key,
    required this.category,
    this.index = 0,
    this.onTap,
    this.label,
    this.icon,
  });

  final ServiceCategory category;
  final int index;
  final VoidCallback? onTap;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final color = category.color;
    return Entrance(
      index: index,
      stagger: const Duration(milliseconds: 40),
      child: Pressable(
        onTap: onTap ?? () => context.push('/category/${category.id}'),
        scale: 0.93,
        child: Column(
          children: [
            Container(
              height: 62,
              width: 62,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: R.all(R.lg),
                border: Border.all(color: p.line),
                boxShadow: Shadows.soft(p),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 62,
                    width: 62,
                    decoration: BoxDecoration(
                      borderRadius: R.all(R.lg),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: p.isDark ? 0.22 : 0.12),
                          color.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                  Icon(icon ?? category.icon, size: 26, color: color),
                ],
              ),
            ),
            const SizedBox(height: Gap.sm),
            SizedBox(
              height: 30,
              child: Text(
                label ?? _short(category.name),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppType.labelS.s(11).c(p.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _short(String name) {
    if (name.contains('&')) return name.split('&').first.trim();
    if (name.contains(' service')) return name.replaceAll(' service', '');
    return name;
  }
}

/// Rich 2-up card used on the Book tab.
class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, this.index = 0});

  final ServiceCategory category;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final color = category.color;
    final count = Seed.byCategory(category.id).length;
    final from = Seed.byCategory(category.id)
        .map((e) => e.price)
        .where((e) => e > 0)
        .fold<int?>(null, (min, e) => min == null || e < min ? e : min);

    return Entrance(
      index: index,
      stagger: const Duration(milliseconds: 45),
      child: Pressable(
        onTap: () => context.push('/category/${category.id}'),
        scale: 0.97,
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: R.all(R.lg),
            border: Border.all(color: p.line),
            boxShadow: Shadows.soft(p),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -18,
                child: Icon(category.icon,
                    size: 92, color: color.withValues(alpha: 0.07)),
              ),
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: p.isDark ? 0.2 : 0.11),
                        borderRadius: R.all(R.sm),
                      ),
                      child: Icon(category.icon, size: 20, color: color),
                    ),
                    const SizedBox(height: Gap.md),
                    Text(category.name,
                        style: AppType.h3.c(p.ink),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(category.tagline,
                        style: AppType.bodyS.s(11.5).c(p.inkMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: Gap.md),
                    Row(
                      children: [
                        Flexible(
                          child: Text('$count services',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.labelS.c(p.inkFaint)),
                        ),
                        if (from != null) ...[
                          const SizedBox(width: 6),
                          Text('•', style: AppType.labelS.c(p.inkFaint)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('from ₹$from',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.labelS.c(p.accentInk)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
