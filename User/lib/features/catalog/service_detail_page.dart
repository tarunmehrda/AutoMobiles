import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../data/seed/media.dart';
import '../../state/app_state.dart';
import '../../state/draft_state.dart';
import '../../state/providers.dart';

class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({super.key, required this.packageId});

  final String packageId;

  static const _reviews = [
    (
      'Nikhil A.',
      5.0,
      'Picked the car up at 9, back by 6 washed and vacuumed. The inspection '
          'photos made it obvious why the pads needed doing.'
    ),
    (
      'Sunita R.',
      4.5,
      'Quote was ₹3,032 and the bill was ₹3,032. That never happens anywhere else.'
    ),
    (
      'Devinder S.',
      5.0,
      'They called before adding anything extra. I declined one item and there '
          'was zero pushback.'
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final pkg = Seed.packageById(packageId);
    final draft = ref.watch(draftProvider);
    final saved = ref.watch(savedPackagesProvider);

    if (pkg == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        body: GEmptyState(
          icon: Icons.help_outline_rounded,
          title: 'Service unavailable',
          message: 'This service is no longer offered.',
          actionLabel: 'Browse catalogue',
          onAction: () => context.go('/book'),
        ),
      );
    }

    final category = Seed.categoryById(pkg.categoryId);
    final added = draft.has(pkg.id);
    final isSaved = saved.contains(pkg.id);
    final vehicle = ref.watch(activeVehicleProvider);
    final related = Seed.byCategory(pkg.categoryId)
        .where((e) => e.id != pkg.id)
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: p.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: p.canvas,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(Gap.sm),
              child: GIconButton(
                icon: Icons.arrow_back_rounded,
                size: 40,
                background: p.surface.withValues(alpha: 0.92),
                onTap: () => context.pop(),
              ),
            ),
            actions: [
              GIconButton(
                icon: isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: 40,
                foreground: isSaved ? p.accent : null,
                background: p.surface.withValues(alpha: 0.92),
                onTap: () {
                  ref
                      .read(appControllerProvider.notifier)
                      .toggleSavedPackage(pkg.id);
                  GFeedback.toast(
                    context,
                    isSaved ? 'Removed from saved' : 'Saved for later',
                    icon: Icons.bookmark_rounded,
                  );
                },
              ),
              const SizedBox(width: Gap.sm),
              Padding(
                padding: const EdgeInsets.only(right: Gap.sm),
                child: GIconButton(
                  icon: Icons.ios_share_rounded,
                  size: 40,
                  background: p.surface.withValues(alpha: 0.92),
                  onTap: () => SharePlus.instance.share(
                    ShareParams(
                      text:
                          '${pkg.name} at ${Seed.garage.name} — ${Fmt.money(pkg.price)} '
                          '(was ${Fmt.money(pkg.mrp)}). Book it on Balaji Automobiles.',
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(Media.photoForCategory(pkg.categoryId),
                      fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          (category?.color ?? p.ink).withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: Gap.page,
                    right: Gap.page,
                    bottom: Gap.xl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pkg.popular)
                          GPill(
                            label: 'MOST BOOKED',
                            tone: GTone.volt,
                            compact: true,
                          ),
                        const SizedBox(height: Gap.sm),
                        Text(pkg.name,
                            style: AppType.d2.s(25).c(Colors.white)),
                        const SizedBox(height: 3),
                        Text(pkg.subtitle,
                            style: AppType.bodyM
                                .c(Colors.white.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // --- price card -----------------------------------------
                Entrance(child: _PriceCard(package: pkg)),
                const SizedBox(height: Gap.lg),

                // --- spec grid ------------------------------------------
                Entrance(index: 1, child: _SpecGrid(package: pkg)),
                const SizedBox(height: Gap.xxl),

                if (vehicle != null) ...[
                  Entrance(
                    index: 2,
                    child: Container(
                      padding: const EdgeInsets.all(Gap.md),
                      decoration: BoxDecoration(
                        color: p.infoSoft,
                        borderRadius: R.all(R.md),
                        border:
                            Border.all(color: p.info.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car_rounded,
                              size: 18, color: p.info),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Text(
                              'Priced for your ${vehicle.title} • ${vehicle.fuel.label}',
                              style: AppType.labelM.c(p.info),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.xxl),
                ],

                // --- description ----------------------------------------
                Text('What this covers', style: AppType.h1.c(p.ink)),
                const SizedBox(height: Gap.sm),
                Text(pkg.description, style: AppType.bodyL.c(p.inkSoft)),
                const SizedBox(height: Gap.xxl),

                // --- includes -------------------------------------------
                _ListBlock(
                  title: 'Included',
                  items: pkg.includes,
                  icon: Icons.check_rounded,
                  tone: GTone.success,
                ),
                if (pkg.excludes.isNotEmpty) ...[
                  const SizedBox(height: Gap.xl),
                  _ListBlock(
                    title: 'Not included',
                    items: pkg.excludes,
                    icon: Icons.close_rounded,
                    tone: GTone.danger,
                    muted: true,
                  ),
                ],
                const SizedBox(height: Gap.xxl),

                // --- add-ons --------------------------------------------
                Text('Pair it with', style: AppType.h1.c(p.ink)),
                const SizedBox(height: Gap.sm),
                Text('Cheaper when booked together',
                    style: AppType.bodyS.c(p.inkMuted)),
                const SizedBox(height: Gap.md),
                for (final a in Seed.addOns.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: GCard(
                      padding: const EdgeInsets.all(Gap.md),
                      onTap: () =>
                          ref.read(draftProvider.notifier).toggleAddOn(a),
                      child: Row(
                        children: [
                          Icon(a.icon, size: 20, color: p.inkSoft),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.name,
                                    style: AppType.labelM.c(p.ink)),
                                Text(a.blurb,
                                    style: AppType.bodyS.c(p.inkMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Text('+${Fmt.money(a.price)}',
                              style: AppType.moneyS.c(p.accentInk)),
                          const SizedBox(width: Gap.sm),
                          Icon(
                            draft.has(a.id)
                                ? Icons.check_circle_rounded
                                : Icons.add_circle_outline_rounded,
                            size: 21,
                            color: draft.has(a.id) ? p.accent : p.inkFaint,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: Gap.xxl),

                // --- reviews ---------------------------------------------
                Row(
                  children: [
                    Text('What customers say', style: AppType.h1.c(p.ink)),
                    const Spacer(),
                    Icon(Icons.star_rounded, size: 17, color: p.warning),
                    const SizedBox(width: 3),
                    Text('${pkg.rating}',
                        style: AppType.labelL.c(p.ink)),
                    Text(' (${Fmt.number(pkg.reviewCount)})',
                        style: AppType.labelS.c(p.inkFaint)),
                  ],
                ),
                const SizedBox(height: Gap.md),
                SizedBox(
                  height: 152,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _reviews.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Gap.md),
                    itemBuilder: (context, i) {
                      final r = _reviews[i];
                      return Container(
                        width: 268,
                        padding: const EdgeInsets.all(Gap.lg),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: R.all(R.lg),
                          border: Border.all(color: p.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GAvatar(
                                    initials: Fmt.initials(r.$1),
                                    size: 30,
                                    tone: GTone.neutral),
                                const SizedBox(width: Gap.sm),
                                Expanded(
                                  child: Text(r.$1,
                                      style: AppType.labelM.c(p.ink)),
                                ),
                                Icon(Icons.star_rounded,
                                    size: 14, color: p.warning),
                                Text('${r.$2}',
                                    style: AppType.labelS.c(p.inkSoft)),
                              ],
                            ),
                            const SizedBox(height: Gap.sm),
                            Expanded(
                              child: Text(
                                r.$3,
                                style: AppType.bodyS.c(p.inkMuted),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                if (related.isNotEmpty) ...[
                  const SizedBox(height: Gap.xxl),
                  Text('More in ${category?.name ?? 'this category'}',
                      style: AppType.h1.c(p.ink)),
                  const SizedBox(height: Gap.md),
                  for (var i = 0; i < related.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: Pressable(
                        onTap: () =>
                            context.pushReplacement('/service/${related[i].id}'),
                        child: GCard(
                          padding: const EdgeInsets.all(Gap.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(related[i].name,
                                        style: AppType.labelL.c(p.ink)),
                                    Text(
                                      '${Fmt.duration(related[i].durationHours)} • ${Fmt.money(related[i].price)}',
                                      style: AppType.bodyS.c(p.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: p.inkFaint),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: Gap.h2),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pkg.price == 0 ? 'FREE' : Fmt.money(pkg.price),
                      style: AppType.moneyL
                          .s(21)
                          .c(pkg.price == 0 ? p.success : p.ink),
                    ),
                    if (pkg.price != pkg.mrp) ...[
                      const SizedBox(width: 5),
                      Text(
                        Fmt.money(pkg.mrp),
                        style: AppType.labelS.c(p.inkFaint).copyWith(
                              decoration: TextDecoration.lineThrough,
                              decorationColor: p.inkFaint,
                            ),
                      ),
                    ],
                  ],
                ),
                Text('Incl. taxes at checkout',
                    style: AppType.labelS.s(10).c(p.inkFaint)),
              ],
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: GButton.accent(
                label: added ? 'Go to cart' : 'Add to cart',
                icon: added ? Icons.shopping_bag_rounded : Icons.add_rounded,
                onPressed: () {
                  if (added) {
                    context.push('/cart');
                  } else {
                    ref.read(draftProvider.notifier).togglePackage(pkg);
                    GFeedback.toast(context, '${pkg.name} added',
                        icon: Icons.check_circle_rounded,
                        actionLabel: 'View cart',
                        onAction: () => context.push('/cart'));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.package});

  final ServicePackage package;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final free = package.price == 0;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            p.accentSoft,
            p.accentSoft.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        free ? 'FREE' : Fmt.money(package.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.moneyL.c(free ? p.success : p.ink),
                      ),
                    ),
                    if (!free) ...[
                      const SizedBox(width: Gap.sm),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          Fmt.money(package.mrp),
                          style: AppType.money.s(14).c(p.inkFaint).copyWith(
                                decoration: TextDecoration.lineThrough,
                                decorationColor: p.inkFaint,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  free
                      ? 'Complimentary with any service booking'
                      : 'You save ${Fmt.money(package.savings)}',
                  style: AppType.labelM.c(p.accentInk),
                ),
              ],
            ),
          ),
          if (!free)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md, vertical: Gap.sm),
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: R.all(R.sm),
              ),
              child: Column(
                children: [
                  Text('${package.discountPercent}%',
                      style: AppType.money.s(18).c(p.onAccent)),
                  Text('OFF', style: AppType.over.s(9).c(p.onAccent)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SpecGrid extends StatelessWidget {
  const _SpecGrid({required this.package});

  final ServicePackage package;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final specs = <(IconData, String, String)>[
      (Icons.schedule_rounded, 'Takes', Fmt.duration(package.durationHours)),
      if (package.warrantyMonths > 0)
        (
          Icons.verified_user_rounded,
          'Warranty',
          '${package.warrantyMonths} months'
        ),
      if (package.recommendedEveryKm != null)
        (
          Icons.speed_rounded,
          'Interval',
          'Every ${Fmt.number(package.recommendedEveryKm!)} km'
        ),
      (
        Icons.checklist_rounded,
        'Checks',
        '${package.includes.length} items'
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < specs.length; i++) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                child: Column(
                  children: [
                    Icon(specs[i].$1, size: 18, color: p.inkMuted),
                    const SizedBox(height: 6),
                    Text(specs[i].$3,
                        textAlign: TextAlign.center,
                        style: AppType.labelM.s(12).c(p.ink)),
                    Text(specs[i].$2.toUpperCase(),
                        style: AppType.over.s(8.5).c(p.inkFaint)),
                  ],
                ),
              ),
            ),
            if (i != specs.length - 1)
              Container(height: 42, width: 1, color: p.lineSoft),
          ],
        ],
      ),
    );
  }
}

class _ListBlock extends StatelessWidget {
  const _ListBlock({
    required this.title,
    required this.items,
    required this.icon,
    required this.tone,
    this.muted = false,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final GTone tone;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = toneOf(context, tone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: AppType.h1.c(p.ink)),
            const SizedBox(width: Gap.sm),
            Text('${items.length}', style: AppType.labelM.c(p.inkFaint)),
          ],
        ),
        const SizedBox(height: Gap.md),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg, vertical: Gap.md),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: R.all(R.lg),
            border: Border.all(color: p.line),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 18,
                        width: 18,
                        margin: const EdgeInsets.only(top: 1),
                        decoration:
                            BoxDecoration(color: t.bg, shape: BoxShape.circle),
                        child: Icon(icon, size: 12, color: t.fg),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          items[i],
                          style: AppType.bodyM
                              .c(muted ? p.inkMuted : p.inkSoft),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
