import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/providers.dart';

enum _Range { week, month, quarter, year }

extension on _Range {
  String get label => switch (this) {
    _Range.week => '7 days'.tr,
    _Range.month => '30 days'.tr,
    _Range.quarter => '90 days'.tr,
    _Range.year => '1 year'.tr,
  };

  int get days => switch (this) {
    _Range.week => 7,
    _Range.month => 30,
    _Range.quarter => 90,
    _Range.year => 365,
  };
}

/// What the workshop earned, collected and turned around. Everything is
/// derived from the job cards themselves, so the numbers cannot drift from
/// the bills they came out of.
///
/// Reached from Analytics, not Reports — Reports is the list of ledgers, this
/// is the picture.
class RevenueAnalyticsPage extends ConsumerStatefulWidget {
  const RevenueAnalyticsPage({super.key});

  @override
  ConsumerState<RevenueAnalyticsPage> createState() =>
      _RevenueAnalyticsPageState();
}

class _RevenueAnalyticsPageState extends ConsumerState<RevenueAnalyticsPage> {
  _Range _range = _Range.month;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);

    final now = DateTime.now();
    final to = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final from = to.subtract(Duration(days: _range.days));

    final billed = data.revenueBetween(from, to);
    final collected = data.collectedBetween(from, to);

    final inRange = data.jobCards
        .where(
          (j) =>
              j.status != JobStatus.open &&
              !(j.completedAt ?? j.createdAt).isBefore(from) &&
              (j.completedAt ?? j.createdAt).isBefore(to),
        )
        .toList();

    final kindSplit = <LineKind, double>{
      for (final k in LineKind.values)
        k: inRange.fold<double>(0, (s, j) => s + j.totalOf(k)),
    };
    final splitTotal = kindSplit.values.fold<double>(0, (s, v) => s + v);

    final opened = data.jobCards
        .where((j) => !j.createdAt.isBefore(from) && j.createdAt.isBefore(to))
        .length;

    final turnaround = _averageTurnaround(inRange);
    final topItems = _topItems(inRange);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Revenue Analytics'.tr,
        subtitle: 'Everything below is for the last {0}.'.trf([_range.label]),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
          children: [
            GSegmented<_Range>(
              options: _Range.values,
              selected: _range,
              onSelect: (r) => setState(() => _range = r),
              labelOf: (r) => r.label,
            ),
            const SizedBox(height: Gap.lg),

            // --- headline ------------------------------------------------
            Entrance(
              child: Container(
                padding: const EdgeInsets.all(Gap.xl),
                decoration: BoxDecoration(
                  gradient: p.inverseGradient,
                  borderRadius: R.all(R.xl),
                  boxShadow: Shadows.lifted(p),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: R.all(R.xl),
                        child: CustomPaint(
                          painter: BlueprintPainter(
                            color: p.onInverse,
                            opacity: 0.06,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BILLED',
                          style: AppType.over.c(
                            p.onInverse.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedCount(
                          value: billed,
                          builder: (context, v) => Text(
                            Fmt.money(v),
                            style: AppType.d1.c(p.onInverse),
                          ),
                        ),
                        const SizedBox(height: Gap.lg),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Collected'.tr,
                                    style: AppType.labelS.c(
                                      p.onInverse.withValues(alpha: 0.55),
                                    ),
                                  ),
                                  Text(
                                    Fmt.money(collected),
                                    style: AppType.money.c(p.volt),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Still owed'.tr,
                                    style: AppType.labelS.c(
                                      p.onInverse.withValues(alpha: 0.55),
                                    ),
                                  ),
                                  Text(
                                    Fmt.money(
                                      (billed - collected).clamp(
                                        0,
                                        double.infinity,
                                      ),
                                    ),
                                    style: AppType.money.c(p.onInverse),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (billed > 0) ...[
                          const SizedBox(height: Gap.md),
                          GMeter(
                            value: (collected / billed).clamp(0, 1),
                            color: p.volt,
                            height: 5,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '{0}% of what was billed has come in'.trf([
                              ((collected / billed) * 100).round(),
                            ]),
                            style: AppType.labelS.c(
                              p.onInverse.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: Gap.lg),

            // --- throughput ----------------------------------------------
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Cards opened'.tr,
                    value: '$opened',
                    icon: Icons.note_add_rounded,
                    tone: GTone.accent,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _MetricCard(
                    label: 'Average bill'.tr,
                    value: inRange.isEmpty
                        ? '—'
                        : Fmt.money(billed / inRange.length),
                    icon: Icons.receipt_long_rounded,
                    tone: GTone.info,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _MetricCard(
                    label: 'Turnaround'.tr,
                    value: turnaround == null ? '—' : Fmt.duration(turnaround),
                    icon: Icons.timer_rounded,
                    tone: GTone.success,
                  ),
                ),
              ],
            ),

            // --- revenue split -------------------------------------------
            GSectionHeader(
              title: 'Where the money came from'.tr,
              padding: EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
            ),
            if (splitTotal <= 0)
              Text(
                'Nothing billed in this window.'.tr,
                style: AppType.bodyS.c(p.inkFaint),
              )
            else
              GCard(
                child: Column(
                  children: [
                    for (final k in LineKind.values) ...[
                      Row(
                        children: [
                          Icon(k.icon, size: 16, color: p.inkMuted),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: Text(
                              k.label,
                              style: AppType.labelM.c(p.ink),
                            ),
                          ),
                          Text(
                            Fmt.money(kindSplit[k]!),
                            style: AppType.moneyS.c(p.inkSoft),
                          ),
                          const SizedBox(width: Gap.sm),
                          SizedBox(
                            width: 38,
                            child: Text(
                              '${((kindSplit[k]! / splitTotal) * 100).round()}%',
                              textAlign: TextAlign.right,
                              style: AppType.labelS.c(p.inkFaint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      GMeter(
                        value: kindSplit[k]! / splitTotal,
                        color: switch (k) {
                          LineKind.job => p.accent,
                          LineKind.spare => p.info,
                          LineKind.lube => p.success,
                        },
                        height: 5,
                      ),
                      if (k != LineKind.values.last)
                        const SizedBox(height: Gap.md),
                    ],
                  ],
                ),
              ),

            // --- most billed ---------------------------------------------
            GSectionHeader(
              title: 'Most billed lines'.tr,
              padding: EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
            ),
            if (topItems.isEmpty)
              Text(
                'Nothing to rank yet.'.tr,
                style: AppType.bodyS.c(p.inkFaint),
              )
            else
              GCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < topItems.length; i++)
                      GTile(
                        dense: true,
                        title: topItems[i].$1,
                        subtitle: Tr.plural(
                          topItems[i].$2,
                          '{0} time',
                          '{0} times',
                        ),
                        showChevron: false,
                        leading: SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}',
                            style: AppType.money.s(15).c(p.inkFaint),
                          ),
                        ),
                        trailing: Text(
                          Fmt.money(topItems[i].$3),
                          style: AppType.money.s(14).c(p.ink),
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: Gap.xxl),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: p.inkFaint),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Billed counts a card once it reaches Complete. Collected counts payments on the day they were recorded, so the two need not match inside one window.'
                        .tr,
                    style: AppType.bodyS.c(p.inkFaint),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Hours from opening a card to marking it complete.
  double? _averageTurnaround(List<JobCard> cards) {
    final done = cards.where((j) => j.completedAt != null).toList();
    if (done.isEmpty) return null;
    // A card cannot be finished before it was opened. A clock that moved,
    // or a row written under an older build's timezone handling, used to
    // read back as a negative average — a turnaround of minus an hour and
    // three quarters, which is not a number anybody can act on.
    final total = done.fold<double>(
      0,
      (s, j) =>
          s +
          (j.completedAt!.difference(j.createdAt).inMinutes / 60.0).clamp(
            0,
            double.infinity,
          ),
    );
    return total / done.length;
  }

  /// (name, times billed, value) for the five biggest earners.
  List<(String, int, double)> _topItems(List<JobCard> cards) {
    final counts = <String, int>{};
    final values = <String, double>{};
    for (final card in cards) {
      for (final line in card.items) {
        counts[line.name] = (counts[line.name] ?? 0) + 1;
        values[line.name] = (values[line.name] ?? 0) + line.amount;
      }
    }
    final rows =
        values.entries.map((e) => (e.key, counts[e.key] ?? 0, e.value)).toList()
          ..sort((a, b) => b.$3.compareTo(a.$3));
    return rows.take(5).toList();
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final GTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = toneOf(context, tone);
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: t.fg),
          const SizedBox(height: Gap.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.money.s(15).c(p.ink),
          ),
          Text(label, maxLines: 2, style: AppType.labelS.s(10).c(p.inkMuted)),
        ],
      ),
    );
  }
}
