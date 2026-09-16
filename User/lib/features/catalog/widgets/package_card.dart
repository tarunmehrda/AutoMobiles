import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/anim/entrance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/seed/catalog_seed.dart';
import '../../../state/draft_state.dart';

/// Shared add/remove behaviour with consistent feedback.
class AddToggle extends ConsumerWidget {
  const AddToggle({
    super.key,
    required this.package,
    this.dense = false,
    this.expand = false,
  });

  final ServicePackage package;
  final bool dense;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final added = ref.watch(draftProvider.select((d) => d.has(package.id)));

    return Pressable(
      onTap: () {
        final nowAdded =
            ref.read(draftProvider.notifier).togglePackage(package);
        GFeedback.toast(
          context,
          nowAdded
              ? '${package.name} added to your cart'
              : '${package.name} removed',
          icon: nowAdded
              ? Icons.check_circle_rounded
              : Icons.remove_circle_outline_rounded,
          actionLabel: nowAdded ? 'View cart' : null,
          onAction: nowAdded ? () => context.push('/cart') : null,
        );
      },
      scale: 0.92,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        height: dense ? 34 : 40,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: dense ? Gap.md : Gap.lg),
        decoration: BoxDecoration(
          color: added ? p.accent : Colors.transparent,
          borderRadius: R.all(R.sm),
          border: Border.all(color: added ? p.accent : p.accent, width: 1.4),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              added ? Icons.check_rounded : Icons.add_rounded,
              size: dense ? 15 : 17,
              color: added ? p.onAccent : p.accentInk,
            ),
            const SizedBox(width: 4),
            Text(
              added ? 'Added' : 'Add',
              style: (dense ? AppType.labelS : AppType.labelM)
                  .c(added ? p.onAccent : p.accentInk),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width catalogue card.
class PackageCard extends ConsumerWidget {
  const PackageCard({
    super.key,
    required this.package,
    this.index = 0,
    this.showCategory = false,
  });

  final ServicePackage package;
  final int index;
  final bool showCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final category = Seed.categoryById(package.categoryId);
    final free = package.price == 0;

    return Entrance(
      index: index,
      stagger: const Duration(milliseconds: 45),
      child: Pressable(
        onTap: () => context.push('/service/${package.id}'),
        scale: 0.99,
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: R.all(R.lg),
            border: Border.all(color: p.line),
            boxShadow: Shadows.soft(p),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (package.popular)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg, vertical: 5),
                  color: p.accent.withValues(alpha: p.isDark ? 0.16 : 0.08),
                  child: Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          size: 13, color: p.accentInk),
                      const SizedBox(width: 5),
                      Text('MOST BOOKED THIS MONTH',
                          style: AppType.over.s(9.5).c(p.accentInk)),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: (category?.color ?? p.accent)
                                .withValues(alpha: p.isDark ? 0.2 : 0.1),
                            borderRadius: R.all(R.sm),
                          ),
                          child: Icon(
                            category?.icon ?? Icons.build_rounded,
                            color: category?.color ?? p.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showCategory && category != null) ...[
                                Text(category.name.toUpperCase(),
                                    style: AppType.over.s(9).c(p.inkFaint)),
                                const SizedBox(height: 3),
                              ],
                              Text(package.name,
                                  style: AppType.h2.c(p.ink),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(package.subtitle,
                                  style: AppType.bodyS.c(p.inkMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        _Rating(package: package),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: 6,
                      children: [
                        GTag(
                          label: Fmt.duration(package.durationHours),
                          icon: Icons.schedule_rounded,
                        ),
                        if (package.warrantyMonths > 0)
                          GTag(
                            label: '${package.warrantyMonths} mo warranty',
                            icon: Icons.verified_user_rounded,
                            tone: GTone.success,
                          ),
                        if (package.includes.isNotEmpty)
                          GTag(
                            label: '${package.includes.length} services',
                            icon: Icons.checklist_rounded,
                          ),
                        if (package.recommendedEveryKm != null)
                          GTag(
                            label:
                                'Every ${Fmt.number(package.recommendedEveryKm!)} km',
                            icon: Icons.speed_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.lg),
                    Divider(height: 1, color: p.lineSoft),
                    const SizedBox(height: Gap.md),
                    Row(
                      children: [
                        if (free)
                          Text('FREE', style: AppType.money.c(p.success))
                        else ...[
                          Text(Fmt.money(package.price),
                              style: AppType.money.c(p.ink)),
                          const SizedBox(width: 6),
                          Text(
                            Fmt.money(package.mrp),
                            style: AppType.moneyS.c(p.inkFaint).copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: p.inkFaint,
                                ),
                          ),
                          const SizedBox(width: Gap.sm),
                          GPill(
                            label: '${package.discountPercent}% off',
                            tone: GTone.success,
                            compact: true,
                          ),
                        ],
                        const Spacer(),
                        AddToggle(package: package),
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

class _Rating extends StatelessWidget {
  const _Rating({required this.package});
  final ServicePackage package;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            Icon(Icons.star_rounded, size: 14, color: p.warning),
            const SizedBox(width: 2),
            Text(package.rating.toStringAsFixed(1),
                style: AppType.labelM.c(p.ink)),
          ],
        ),
        if (package.reviewCount > 0)
          Text(Fmt.number(package.reviewCount),
              style: AppType.labelS.s(10).c(p.inkFaint)),
      ],
    );
  }
}

/// Narrow card for horizontal rails on Home.
class PackageRailCard extends ConsumerWidget {
  const PackageRailCard({super.key, required this.package, this.index = 0});

  final ServicePackage package;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final category = Seed.categoryById(package.categoryId);
    final color = category?.color ?? p.accent;

    return Entrance(
      index: index,
      stagger: const Duration(milliseconds: 55),
      child: Pressable(
        onTap: () => context.push('/service/${package.id}'),
        scale: 0.97,
        child: Container(
          width: 244,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: R.all(R.lg),
            border: Border.all(color: p.line),
            boxShadow: Shadows.soft(p),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 72,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: p.isDark ? 0.26 : 0.14),
                      color.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -8,
                      bottom: -12,
                      child: Icon(category?.icon ?? Icons.build_rounded,
                          size: 76, color: color.withValues(alpha: 0.22)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (package.discountPercent > 0)
                            GPill(
                              label: '${package.discountPercent}% OFF',
                              tone: GTone.ink,
                              compact: true,
                            ),
                          const Spacer(),
                          Text(Fmt.duration(package.durationHours),
                              style: AppType.labelS.c(p.inkMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(package.name,
                        style: AppType.h3.c(p.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 32,
                      child: Text(
                        package.subtitle,
                        style: AppType.bodyS.c(p.inkMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                package.price == 0
                                    ? 'FREE'
                                    : Fmt.money(package.price),
                                style: AppType.money.s(15).c(
                                    package.price == 0 ? p.success : p.ink),
                              ),
                              if (package.price != package.mrp)
                                Text(
                                  Fmt.money(package.mrp),
                                  style: AppType.labelS.s(10).c(p.inkFaint).copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor: p.inkFaint,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        AddToggle(package: package, dense: true),
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
