import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../data/models/books.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import 'trade_line_sheet.dart';
import 'trade_widgets.dart';

/// Quotations: Estimate → Jobs / Parts / Labour. An estimate moves neither
/// stock nor money; converting it opens a job card with its lines on.
class EstimatesPage extends ConsumerWidget {
  const EstimatesPage({super.key, this.tab});

  final String? tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final docs = ref.watch(adminProvider).tradeOf(TradeKind.estimate);
    final open = docs.where((d) => !d.fulfilled).toList();
    final converted = docs.length - open.length;

    String mix(TradeDoc d) {
      final bits = <String>[
        for (final k in [LineKind.job, LineKind.spare, LineKind.lube])
          if (d.lines.where((l) => l.kind == k).length case final n when n > 0)
            '$n ${lineGroupLabel(k).toLowerCase()}',
      ];
      return bits.join(', ');
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Estimates'.tr,
        subtitle: 'Estimate → Jobs / Parts / Labour'.tr,
      ),
      body: TabList(
        summary: SummaryStrip(
          cells: [
            (label: 'Estimates'.tr, value: '${docs.length}', tint: null),
            (
              label: 'Open value'.tr,
              value: Fmt.money(open.fold<double>(0, (s, d) => s + d.total)),
              tint: null,
            ),
            (label: 'Converted'.tr, value: '$converted', tint: p.success),
          ],
        ),
        emptyTitle: 'No estimates yet'.tr,
        emptyMessage:
            'Quote the jobs, parts and labour before the work starts, then convert it to a job card in one tap.'
                .tr,
        children: [
          for (final d in docs)
            DocRow(
              icon: d.fulfilled
                  ? Icons.task_alt_rounded
                  : Icons.request_quote_rounded,
              tint: d.fulfilled ? p.success : p.accent,
              title: d.party.isEmpty ? 'Walk-in'.tr : d.party,
              subtitle: [
                d.number,
                Fmt.date(d.at),
                if (mix(d).isNotEmpty) mix(d),
              ].join('  ·  '),
              amount: Fmt.money(d.total),
              pill: d.fulfilled ? 'Converted'.tr : 'Open'.tr,
              pillTone: d.fulfilled ? GTone.success : GTone.info,
              onTap: () => context.push('/trade/${d.id}'),
            ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: '+ New Estimate'.tr,
          onPressed: () =>
              context.push('/trade/new?kind=${TradeKind.estimate.name}'),
        ),
      ),
    );
  }
}
