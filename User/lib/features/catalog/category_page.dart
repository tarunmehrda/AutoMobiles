import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../data/models/entities.dart';
import '../../data/seed/catalog_seed.dart';
import '../../data/seed/media.dart';
import '../../state/draft_state.dart';
import 'widgets/package_card.dart';

class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  String _group = 'All';
  String _sort = 'Recommended';

  static const _sorts = [
    'Recommended',
    'Price: low to high',
    'Price: high to low',
    'Highest rated',
    'Quickest',
  ];

  List<ServicePackage> _apply(List<ServicePackage> input) {
    var list = _group == 'All'
        ? [...input]
        : input.where((p) => p.groups.contains(_group)).toList();

    switch (_sort) {
      case 'Price: low to high':
        list.sort((a, b) => a.price.compareTo(b.price));
      case 'Price: high to low':
        list.sort((a, b) => b.price.compareTo(a.price));
      case 'Highest rated':
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case 'Quickest':
        list.sort((a, b) => a.durationHours.compareTo(b.durationHours));
      default:
        list.sort((a, b) {
          if (a.popular != b.popular) return a.popular ? -1 : 1;
          return b.rating.compareTo(a.rating);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final category = Seed.categoryById(widget.categoryId);
    final draft = ref.watch(draftProvider);

    if (category == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        body: GEmptyState(
          icon: Icons.help_outline_rounded,
          title: 'Category not found',
          message: 'It may have been renamed or removed.',
          actionLabel: 'Back to catalogue',
          onAction: () => context.go('/book'),
        ),
      );
    }

    final all = Seed.byCategory(category.id);
    final groups = <String>{
      'All',
      for (final p in all) ...p.groups,
    }.toList();
    final list = _apply(all);

    return Scaffold(
      backgroundColor: p.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 212,
            pinned: true,
            stretch: true,
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
              Padding(
                padding: const EdgeInsets.all(Gap.sm),
                child: GIconButton(
                  icon: Icons.search_rounded,
                  size: 40,
                  background: p.surface.withValues(alpha: 0.92),
                  onTap: () => context.push('/search'),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
              title: LayoutBuilder(
                builder: (context, c) => Text(
                  category.name,
                  style: AppType.h1.c(Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(Media.photoForCategory(category.id),
                      fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          category.color.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: Gap.page,
                    right: Gap.page,
                    bottom: 48,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: R.all(R.sm),
                              ),
                              child: Icon(category.icon,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: Gap.md),
                            Expanded(
                              child: Text(
                                category.tagline,
                                style: AppType.bodyM.c(
                                    Colors.white.withValues(alpha: 0.9)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter + sort row.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, Gap.lg, 0, Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: GChoiceChips<String>(
                      options: groups,
                      selected: _group,
                      onSelect: (g) => setState(() => _group = g),
                      labelOf: (g) => g,
                      countOf: (g) => g == 'All'
                          ? '${all.length}'
                          : '${all.where((p) => p.groups.contains(g)).length}',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: Gap.page),
                    child: GIconButton(
                      icon: Icons.swap_vert_rounded,
                      size: 40,
                      tooltip: 'Sort',
                      onTap: _pickSort,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
              child: Row(
                children: [
                  Text('${list.length} services',
                      style: AppType.labelM.c(p.inkMuted)),
                  const Spacer(),
                  Text('Sorted by $_sort',
                      style: AppType.labelS.c(p.inkFaint)),
                ],
              ),
            ),
          ),

          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: GEmptyState(
                icon: Icons.filter_alt_off_rounded,
                title: 'Nothing in this filter',
                message: 'Try another tab, or clear the filter to see everything.',
                actionLabel: 'Show all',
                onAction: () => setState(() => _group = 'All'),
                compact: true,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h3),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                itemBuilder: (context, i) =>
                    PackageCard(package: list[i], index: i),
              ),
            ),
        ],
      ),
      bottomNavigationBar: draft.isEmpty
          ? null
          : GBottomBar(
              child: GButton.accent(
                label: 'View cart • ${draft.count} item${draft.count == 1 ? '' : 's'}',
                badge: Fmt.money(draft.subtotal),
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => context.push('/cart'),
              ),
            ),
    );
  }

  void _pickSort() {
    GFeedback.sheet<void>(
      context,
      title: 'Sort services',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in _sorts)
              GOptionRow(
                label: s,
                selected: _sort == s,
                onTap: () {
                  setState(() => _sort = s);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
