import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/entities.dart';
import '../../data/seed/catalog_seed.dart';

class HelpPage extends ConsumerStatefulWidget {
  const HelpPage({super.key});

  @override
  ConsumerState<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends ConsumerState<HelpPage> {
  final _search = TextEditingController();
  String _query = '';
  String _group = 'All';
  int? _openIndex;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final groups = <String>{'All', ...Seed.faqs.map((f) => f.group)}.toList();
    final q = _query.trim().toLowerCase();

    final faqs = Seed.faqs.where((f) {
      final matchesGroup = _group == 'All' || f.group == _group;
      final matchesQuery = q.isEmpty ||
          f.question.toLowerCase().contains(q) ||
          f.answer.toLowerCase().contains(q);
      return matchesGroup && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Help centre',
        subtitle: '${Seed.faqs.length} answers, no hold music',
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.h2),
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
            child: GSearchBar(
              hint: 'Search help',
              controller: _search,
              onChanged: (v) => setState(() {
                _query = v;
                _openIndex = null;
              }),
              onClear: _query.isEmpty
                  ? null
                  : () {
                      _search.clear();
                      setState(() => _query = '');
                    },
            ),
          ),
          GChoiceChips<String>(
            options: groups,
            selected: _group,
            onSelect: (g) => setState(() {
              _group = g;
              _openIndex = null;
            }),
            labelOf: (g) => g,
          ),
          const SizedBox(height: Gap.lg),

          if (faqs.isEmpty)
            GEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No answer matched',
              message:
                  'Ask us directly — the workshop usually replies within a few '
                  'minutes during working hours.',
              actionLabel: 'Open chat',
              onAction: () => context.push('/chat'),
              compact: true,
            )
          else
            for (var i = 0; i < faqs.length; i++)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
                child: _FaqTile(
                  faq: faqs[i],
                  index: i,
                  open: _openIndex == i,
                  onTap: () =>
                      setState(() => _openIndex = _openIndex == i ? null : i),
                ),
              ),

          const SizedBox(height: Gap.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: GCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Still need a human?', style: AppType.h1.c(p.ink)),
                  const SizedBox(height: 4),
                  Text(
                    'Call the workshop, message on WhatsApp, or raise a ticket '
                    'and we will reply within 24 hours.',
                    style: AppType.bodyM.c(p.inkMuted),
                  ),
                  const SizedBox(height: Gap.lg),
                  Row(
                    children: [
                      Expanded(
                        child: GButton.outline(
                          label: 'Call',
                          icon: Icons.call_rounded,
                          expand: true,
                          onPressed: () async {
                            final uri = Uri.parse('tel:${Seed.garage.phone}');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: GButton.accent(
                          label: 'Raise a ticket',
                          size: GButtonSize.md,
                          onPressed: () => context.push('/tickets'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.faq,
    required this.index,
    required this.open,
    required this.onTap,
  });

  final FaqItem faq;
  final int index;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Entrance(
      index: index,
      stagger: const Duration(milliseconds: 30),
      child: GCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        borderColor: open ? p.accent.withValues(alpha: 0.4) : null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(faq.question,
                        style: AppType.labelL.c(p.ink)),
                  ),
                  const SizedBox(width: Gap.md),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: Motion.fast,
                    child: Icon(Icons.expand_more_rounded,
                        size: 20, color: open ? p.accent : p.inkFaint),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: p.lineSoft, height: Gap.md),
                    const SizedBox(height: Gap.sm),
                    Text(faq.answer, style: AppType.bodyM.c(p.inkSoft)),
                    const SizedBox(height: Gap.md),
                    GPill(label: faq.group, tone: GTone.neutral, compact: true),
                  ],
                ),
              ),
              crossFadeState:
                  open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: Motion.base,
              sizeCurve: Motion.enter,
            ),
          ],
        ),
      ),
    );
  }
}
