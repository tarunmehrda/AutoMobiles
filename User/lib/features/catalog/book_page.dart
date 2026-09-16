import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/draft_state.dart';
import '../../state/providers.dart';
import '../vehicle/widgets/vehicle_selector.dart';
import 'widgets/category_tile.dart';
import 'widgets/package_card.dart';

class BookPage extends ConsumerWidget {
  const BookPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final categories = ref.watch(categoriesProvider);
    final packages = ref.watch(packagesProvider);
    final draft = ref.watch(draftProvider);
    final popular = packages.where((e) => e.popular).toList();

    return Scaffold(
      backgroundColor: p.canvas,
      body: CustomScrollView(
        slivers: [
          GSliverHeader(
            eyebrow: 'Catalogue',
            title: 'Book a service',
            subtitle: '${packages.length} services across ${categories.length} categories',
            actions: const [VehiclePill()],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
              child: GSearchBar(
                hint: 'Search "brake pads", "AC", "oil change"',
                readOnly: true,
                onTap: () => context.push('/search'),
              ),
            ),
          ),

          // Popular searches as quick chips.
          SliverToBoxAdapter(
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                itemCount: Seed.popularSearches.length,
                separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
                itemBuilder: (context, i) => Pressable(
                  onTap: () => context.push('/search?q=${Uri.encodeComponent(Seed.popularSearches[i])}'),
                  scale: 0.94,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: R.all(R.pill),
                      border: Border.all(color: p.line),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up_rounded,
                            size: 13, color: p.inkFaint),
                        const SizedBox(width: 5),
                        Text(Seed.popularSearches[i],
                            style: AppType.labelS.c(p.inkSoft)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: GSectionHeader(
              eyebrow: 'Everyone books these',
              title: 'Most popular',
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                itemCount: popular.length,
                separatorBuilder: (_, _) => const SizedBox(width: Gap.md),
                itemBuilder: (context, i) =>
                    PackageRailCard(package: popular[i], index: i),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: GSectionHeader(
              eyebrow: 'Browse',
              title: 'All categories',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Gap.md,
                crossAxisSpacing: Gap.md,
                mainAxisExtent: 186,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) =>
                    CategoryCard(category: categories[i], index: i),
                childCount: categories.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: GSectionHeader(
              eyebrow: 'Add to any booking',
              title: 'Popular add-ons',
              subtitle: 'Cheaper when combined with a service',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h3),
            sliver: SliverList.separated(
              itemCount: Seed.addOns.length,
              separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
              itemBuilder: (context, i) {
                final a = Seed.addOns[i];
                final added = draft.has(a.id);
                return Entrance(
                  index: i,
                  stagger: const Duration(milliseconds: 35),
                  child: GCard(
                    padding: const EdgeInsets.all(Gap.md),
                    onTap: () =>
                        ref.read(draftProvider.notifier).toggleAddOn(a),
                    child: Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                              color: p.surfaceSunken,
                              borderRadius: R.all(R.sm)),
                          child: Icon(a.icon, size: 19, color: p.inkSoft),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name, style: AppType.labelL.c(p.ink)),
                              Text(a.blurb,
                                  style: AppType.bodyS.c(p.inkMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(Fmt.money(a.price),
                                style: AppType.moneyS.c(p.ink)),
                            if (a.mrp != null)
                              Text(
                                Fmt.money(a.mrp!),
                                style: AppType.labelS.s(10).c(p.inkFaint).copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: p.inkFaint,
                                    ),
                              ),
                          ],
                        ),
                        const SizedBox(width: Gap.md),
                        AnimatedContainer(
                          duration: Motion.fast,
                          height: 28,
                          width: 28,
                          decoration: BoxDecoration(
                            color: added ? p.accent : Colors.transparent,
                            borderRadius: R.all(R.xs),
                            border: Border.all(
                                color: added ? p.accent : p.line, width: 1.4),
                          ),
                          child: Icon(
                            added ? Icons.check_rounded : Icons.add_rounded,
                            size: 16,
                            color: added ? p.onAccent : p.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: draft.isEmpty
          ? null
          : GBottomBar(
              child: GButton.accent(
                label: '${draft.count} service${draft.count == 1 ? '' : 's'} in cart',
                badge: Fmt.money(draft.subtotal),
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => context.push('/cart'),
              ),
            ),
    );
  }
}
