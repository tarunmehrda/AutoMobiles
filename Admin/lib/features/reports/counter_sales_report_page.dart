import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../state/providers.dart';
import 'widgets/date_range_bar.dart';

/// Spares and lubes sold across the counter with no card behind them.
class CounterSalesReportPage extends ConsumerStatefulWidget {
  const CounterSalesReportPage({super.key});

  @override
  ConsumerState<CounterSalesReportPage> createState() =>
      _CounterSalesReportPageState();
}

class _CounterSalesReportPageState
    extends ConsumerState<CounterSalesReportPage> {
  ReportRange _range = ReportRange.week;
  DateSpan _span = DateSpan.of(ReportRange.week);

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final sales = ref
        .watch(counterSalesProvider)
        .where((s) => _span.contains(s.at))
        .toList();
    final total = sales.fold<double>(0, (s, e) => s + e.total);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Counter Sales'.tr,
        subtitle: 'Everything sold across the counter'.tr,
      ),
      body: Column(
        children: [
          DateRangeBar(
            range: _range,
            span: _span,
            onChanged: (r, s) => setState(() {
              _range = r;
              _span = s;
            }),
          ),
          Expanded(
            child: sales.isEmpty
                ? GEmptyState(
                    icon: Icons.storefront_rounded,
                    title: 'No counter sales'.tr,
                    art: Art.invoice,
                    message:
                        'Sell a spare from Inventory and it lands here.'.tr,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      Gap.lg,
                      Gap.page,
                      Gap.lg,
                    ),
                    itemCount: sales.length,
                    itemBuilder: (context, i) {
                      final s = sales[i];
                      return Entrance(
                        index: i.clamp(0, 8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: Gap.sm),
                          padding: const EdgeInsets.all(Gap.lg),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: R.all(R.md),
                            border: Border.all(color: p.line),
                            boxShadow: Shadows.soft(p),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.customer.isEmpty
                                          ? 'Walk-in'.tr
                                          : s.customer,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.labelL.c(p.ink),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      Tr.plural(
                                        s.items.length,
                                        '{0}  ·  {1}  ·  {2} item',
                                        '{0}  ·  {1}  ·  {2} items',
                                        [
                                          s.number,
                                          Fmt.date(s.at),
                                          s.items.length,
                                        ],
                                      ),
                                      style: AppType.bodyS.c(p.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Fmt.money(s.total),
                                    style: AppType.money.c(p.ink),
                                  ),
                                  const SizedBox(height: 4),
                                  GPill(
                                    label: s.balance <= 0
                                        ? 'Paid'.tr
                                        : 'Due {0}'.trf([Fmt.money(s.balance)]),
                                    tone: s.balance <= 0
                                        ? GTone.success
                                        : GTone.danger,
                                    compact: true,
                                  ),
                                ],
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
      bottomNavigationBar: ReportFooter(
        leftLabel: 'Total Sales',
        leftValue: '${sales.length}',
        rightLabel: 'Total Amount',
        rightValue: Fmt.money(total),
      ),
    );
  }
}
