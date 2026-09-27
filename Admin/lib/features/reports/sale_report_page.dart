import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../state/providers.dart';
import 'widgets/date_range_bar.dart';

/// Every bill raised in a window, one row per job card. Doubles as the
/// customer report when the caller asks for it by that name.
class SaleReportPage extends ConsumerStatefulWidget {
  const SaleReportPage({super.key, this.title = 'Sale Report'});

  final String title;

  @override
  ConsumerState<SaleReportPage> createState() => _SaleReportPageState();
}

class _SaleReportPageState extends ConsumerState<SaleReportPage> {
  ReportRange _range = ReportRange.week;
  DateSpan _span = DateSpan.of(ReportRange.week);

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);

    final cards =
        data.jobCards.where((j) {
          if (j.status == JobStatus.open) return false;
          return _span.contains(j.completedAt ?? j.createdAt);
        }).toList()..sort(
          (a, b) => (b.completedAt ?? b.createdAt).compareTo(
            a.completedAt ?? a.createdAt,
          ),
        );

    final total = cards.fold<double>(0, (s, j) => s + j.total);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(title: widget.title),
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
            child: cards.isEmpty
                ? GEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Nothing billed in this window'.tr,
                    art: Art.invoice,
                    message: 'Pick a wider range to see more.'.tr,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      Gap.lg,
                      Gap.page,
                      Gap.lg,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (context, i) {
                      final j = cards[i];
                      final customer = data.customerById(j.customerId);
                      final vehicle = data.vehicleById(j.vehicleId);
                      return Entrance(
                        index: i.clamp(0, 8),
                        child: Pressable(
                          onTap: () => context.push('/job/${j.id}'),
                          scale: 0.985,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer?.name ?? 'Walk-in'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppType.labelL.c(p.ink),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        customer?.phone ?? '',
                                        style: AppType.bodyS.c(p.inkMuted),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        vehicle == null
                                            ? j.number
                                            : '${Fmt.plate(vehicle.regNo)} - ${vehicle.title}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppType.bodyS.c(p.inkSoft),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Gap.sm),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Fmt.money(j.total),
                                      style: AppType.money.c(p.ink),
                                    ),
                                    const SizedBox(height: 5),
                                    GPill(
                                      label: j.settled
                                          ? 'Paid'.tr
                                          : 'Due {0}'.trf([
                                              Fmt.money(j.balance),
                                            ]),
                                      tone: j.settled
                                          ? GTone.info
                                          : GTone.danger,
                                      compact: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: ReportFooter(
        leftLabel: 'Cards billed',
        leftValue: '${cards.length}',
        rightLabel: 'Total Amount',
        rightValue: Fmt.money(total),
      ),
    );
  }
}
