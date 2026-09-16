import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import 'widgets/package_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery ?? '';
    if (initial.isNotEmpty) {
      _controller.text = initial;
      _query = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _commit(initial));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String term) {
    if (term.trim().length < 2) return;
    ref.read(appControllerProvider.notifier).pushSearch(term.trim());
  }

  void _run(String term) {
    _controller.text = term;
    setState(() => _query = term);
    _commit(term);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final results = ref.watch(searchProvider(_query));
    final recent = ref.watch(recentSearchesProvider);
    final categories = ref.watch(categoriesProvider);
    final hasQuery = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.lg, Gap.md, Gap.page, Gap.md),
              child: Row(
                children: [
                  GIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 44,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: GSearchBar(
                      hint: 'Search services, parts or symptoms',
                      controller: _controller,
                      autofocus: _query.isEmpty,
                      onChanged: (v) => setState(() => _query = v),
                      onClear: _query.isEmpty
                          ? null
                          : () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: hasQuery
                  ? _results(results)
                  : _suggestions(recent, categories),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(List results) {
    final p = context.c;
    if (results.isEmpty) {
      return GEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No match for "$_query"',
        message:
            'Try a simpler word like "brake", "AC" or "service". If it is not '
            'listed, the workshop can still quote it — just ask on chat.',
        actionLabel: 'Ask the garage',
        onAction: () => context.push('/chat'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
      itemCount: results.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Text(
              '${results.length} result${results.length == 1 ? '' : 's'} for "$_query"',
              style: AppType.labelM.c(p.inkMuted),
            ),
          );
        }
        return PackageCard(
          package: results[i - 1],
          index: i - 1,
          showCategory: true,
        );
      },
    );
  }

  Widget _suggestions(List<String> recent, List categories) {
    final p = context.c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Text('RECENT', style: AppType.over.c(p.inkFaint)),
              const Spacer(),
              GLink(
                label: 'Clear',
                onTap: () =>
                    ref.read(appControllerProvider.notifier).clearSearches(),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          for (var i = 0; i < recent.length; i++)
            Entrance(
              index: i,
              stagger: const Duration(milliseconds: 30),
              child: Pressable(
                onTap: () => _run(recent[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.md),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 18, color: p.inkFaint),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(recent[i],
                            style: AppType.bodyL.c(p.inkSoft)),
                      ),
                      Icon(Icons.north_west_rounded,
                          size: 15, color: p.inkFaint),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: Gap.xl),
        ],
        Text('TRENDING', style: AppType.over.c(p.inkFaint)),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final s in Seed.popularSearches)
              Pressable(
                onTap: () => _run(s),
                scale: 0.94,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg, vertical: Gap.md),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: R.all(R.pill),
                    border: Border.all(color: p.line),
                  ),
                  child: Text(s, style: AppType.labelM.c(p.inkSoft)),
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.xxl),
        Text('BROWSE BY CATEGORY', style: AppType.over.c(p.inkFaint)),
        const SizedBox(height: Gap.md),
        for (var i = 0; i < categories.length; i++)
          Entrance(
            index: i,
            stagger: const Duration(milliseconds: 28),
            child: Pressable(
              onTap: () => context.push('/category/${categories[i].id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                child: Row(
                  children: [
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: categories[i]
                            .color
                            .withValues(alpha: p.isDark ? 0.2 : 0.1),
                        borderRadius: R.all(R.sm),
                      ),
                      child: Icon(categories[i].icon,
                          size: 18, color: categories[i].color),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(categories[i].name,
                              style: AppType.labelL.c(p.ink)),
                          Text(categories[i].tagline,
                              style: AppType.bodyS.c(p.inkMuted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: p.inkFaint),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
