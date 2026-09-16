import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/seed/media.dart';
import '../../state/providers.dart';

class InspectionPage extends ConsumerStatefulWidget {
  const InspectionPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends ConsumerState<InspectionPage> {
  Condition? _filter;

  static IconData _areaIcon(String area) => switch (area.toLowerCase()) {
        'engine' => Icons.settings_suggest_rounded,
        'brakes' => Icons.disc_full_rounded,
        'tyres' => Icons.tire_repair_rounded,
        'battery' => Icons.battery_charging_full_rounded,
        'suspension' => Icons.compress_rounded,
        'ac' => Icons.ac_unit_rounded,
        'electricals' => Icons.electrical_services_rounded,
        _ => Icons.fact_check_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final booking = ref.watch(bookingProvider(widget.bookingId));
    final inspection = ref.watch(inspectionProvider(widget.bookingId));

    if (inspection == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Inspection report'),
        body: GEmptyState(
          icon: Icons.search_rounded,
          title: 'Inspection not done yet',
          message:
              'Your 38-point report appears here the moment the technician '
              'finishes. You will get a notification.',
          actionLabel: 'Back to booking',
          onAction: () => context.pop(),
        ),
      );
    }

    final items = _filter == null
        ? inspection.items
        : inspection.items.where((e) => e.condition == _filter).toList();

    final areas = <String, List<InspectionItem>>{};
    for (final i in items) {
      (areas[i.area] ??= []).add(i);
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Inspection report',
        subtitle:
            '${inspection.items.length} checkpoints • ${Fmt.dateTime(inspection.createdAt)}',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          // --- score ----------------------------------------------------
          Entrance(
            child: GCard(
              padding: const EdgeInsets.all(Gap.xl),
              child: Column(
                children: [
                  Row(
                    children: [
                      HealthGauge(score: inspection.score, size: 128),
                      const SizedBox(width: Gap.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_verdict(inspection.score),
                                style: AppType.h1.c(p.ink)),
                            const SizedBox(height: 4),
                            Text(
                              'Checked by ${inspection.technician ?? 'our technician'}',
                              style: AppType.bodyS.c(p.inkMuted),
                            ),
                            const SizedBox(height: Gap.lg),
                            _countRow(
                                p, Condition.replace, inspection.count(Condition.replace)),
                            const SizedBox(height: 6),
                            _countRow(
                                p, Condition.monitor, inspection.count(Condition.monitor)),
                            const SizedBox(height: 6),
                            _countRow(
                                p, Condition.good, inspection.count(Condition.good)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (inspection.summary != null) ...[
                    const SizedBox(height: Gap.xl),
                    Container(
                      padding: const EdgeInsets.all(Gap.md),
                      decoration: BoxDecoration(
                        color: p.surfaceSunken,
                        borderRadius: R.all(R.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote_rounded,
                              size: 17, color: p.inkFaint),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: Text(inspection.summary!,
                                style: AppType.bodyM.c(p.inkSoft)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // --- filters --------------------------------------------------
          const SizedBox(height: Gap.xl),
          Row(
            children: [
              _FilterChip(
                label: 'All',
                count: inspection.items.length,
                selected: _filter == null,
                color: p.ink,
                onTap: () => setState(() => _filter = null),
              ),
              const SizedBox(width: Gap.sm),
              for (final c in [
                Condition.replace,
                Condition.monitor,
                Condition.good
              ]) ...[
                _FilterChip(
                  label: c.label,
                  count: inspection.count(c),
                  selected: _filter == c,
                  color: _conditionColor(p, c),
                  onTap: () => setState(
                      () => _filter = _filter == c ? null : c),
                ),
                const SizedBox(width: Gap.sm),
              ],
            ],
          ),

          const SizedBox(height: Gap.xl),

          if (items.isEmpty)
            GEmptyState(
              icon: Icons.done_all_rounded,
              title: 'Nothing in this filter',
              message: 'Good news — no items are in this condition.',
              compact: true,
              actionLabel: 'Show everything',
              onAction: () => setState(() => _filter = null),
            )
          else
            for (final entry in areas.entries) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.md),
                child: Row(
                  children: [
                    Icon(_areaIcon(entry.key), size: 17, color: p.inkMuted),
                    const SizedBox(width: Gap.sm),
                    Text(entry.key.toUpperCase(),
                        style: AppType.over.c(p.inkFaint)),
                    const SizedBox(width: Gap.sm),
                    Expanded(child: Divider(color: p.lineSoft)),
                  ],
                ),
              ),
              for (var i = 0; i < entry.value.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: _ItemCard(
                    item: entry.value[i],
                    index: i,
                    photo: Media.photoForArea(entry.key),
                  ),
                ),
              const SizedBox(height: Gap.lg),
            ],

          const SizedBox(height: Gap.md),
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: R.all(R.md),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_clock_rounded, size: 16, color: p.inkMuted),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'This report is stored against your vehicle permanently and '
                    'cannot be edited after the job closes.',
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: booking == null
          ? null
          : GBottomBar(
              child: Row(
                children: [
                  Expanded(
                    child: GButton(
                      label: 'Ask',
                      kind: GButtonKind.ghost,
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed: () => context.push('/chat'),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    flex: 2,
                    child: GButton.accent(
                      label: booking.needsApproval
                          ? 'Review estimate'
                          : 'View estimate',
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: () => context
                          .push('/booking/${widget.bookingId}/estimate'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _verdict(double score) {
    if (score >= 0.85) return 'In great shape';
    if (score >= 0.7) return 'Healthy overall';
    if (score >= 0.5) return 'Needs attention';
    return 'Urgent work needed';
  }

  Widget _countRow(AppPalette p, Condition c, int count) {
    final color = _conditionColor(p, c);
    return Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Gap.sm),
        Text('$count ${c.label.toLowerCase()}',
            style: AppType.labelM.c(p.inkSoft)),
      ],
    );
  }
}

Color _conditionColor(AppPalette p, Condition c) => switch (c) {
      Condition.good => p.success,
      Condition.monitor => p.warning,
      Condition.replace => p.danger,
    };

GTone _conditionTone(Condition c) => switch (c) {
      Condition.good => GTone.success,
      Condition.monitor => GTone.warning,
      Condition.replace => GTone.danger,
    };

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        scale: 0.95,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : p.surface,
            borderRadius: R.all(R.md),
            border: Border.all(color: selected ? color : p.line),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: AppType.money
                      .s(16)
                      .c(selected ? color : p.ink)),
              Text(label,
                  style: AppType.labelS
                      .s(10)
                      .c(selected ? color : p.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatefulWidget {
  const _ItemCard({
    required this.item,
    required this.index,
    required this.photo,
  });

  final InspectionItem item;
  final int index;
  final String photo;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final item = widget.item;
    final color = _conditionColor(p, item.condition);
    final expandable = item.note != null || item.condition != Condition.good;

    return Entrance(
      index: widget.index,
      stagger: const Duration(milliseconds: 35),
      child: GCard(
        padding: EdgeInsets.zero,
        onTap: expandable ? () => setState(() => _open = !_open) : null,
        borderColor: _open ? color.withValues(alpha: 0.4) : null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 34,
                    decoration: BoxDecoration(
                        color: color, borderRadius: R.all(R.pill)),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: AppType.labelL.c(p.ink)),
                        if (item.measurement != null) ...[
                          const SizedBox(height: 2),
                          Text(item.measurement!,
                              style: AppType.labelS.c(p.inkMuted)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  GPill(
                    label: item.condition.label,
                    tone: _conditionTone(item.condition),
                    compact: true,
                  ),
                  if (expandable)
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: Motion.fast,
                      child: Icon(Icons.expand_more_rounded,
                          size: 20, color: p.inkFaint),
                    ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: p.lineSoft, height: Gap.lg),
                    if (item.note != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.engineering_rounded,
                              size: 16, color: p.inkMuted),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: Text(item.note!,
                                style: AppType.bodyM.c(p.inkSoft)),
                          ),
                        ],
                      ),
                    if (item.condition != Condition.good) ...[
                      const SizedBox(height: Gap.md),
                      ClipRRect(
                        borderRadius: R.all(R.md),
                        child: Stack(
                          children: [
                            Image.asset(
                              widget.photo,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              left: Gap.sm,
                              bottom: Gap.sm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: Gap.sm, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: R.all(R.xs),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_camera_rounded,
                                        size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text('Technician photo',
                                        style: AppType.labelS
                                            .s(10)
                                            .c(Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gap.sm),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 14, color: color),
                          const SizedBox(width: 5),
                          Text(item.condition.advice,
                              style: AppType.labelS.c(color)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              crossFadeState: _open
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: Motion.base,
              sizeCurve: Motion.enter,
            ),
          ],
        ),
      ),
    );
  }
}
