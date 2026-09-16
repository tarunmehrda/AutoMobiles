import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_surface.dart';
import '../../../data/models/enums.dart';
import '../../../state/draft_state.dart';

/// The price breakdown shown in the cart, at checkout and on the summary.
/// One widget so the numbers can never disagree between screens.
class BillSummary extends StatelessWidget {
  const BillSummary({super.key, required this.draft, this.title = 'Bill details'});

  final BookingDraft draft;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 17, color: p.inkMuted),
              const SizedBox(width: Gap.sm),
              Text(title, style: AppType.h2.c(p.ink)),
            ],
          ),
          const SizedBox(height: Gap.md),
          GKeyValue(
            label: 'Item total (MRP)',
            value: Fmt.money(draft.mrpTotal),
          ),
          if (draft.itemSavings > 0)
            GKeyValue(
              label: 'Package discount',
              value: '− ${Fmt.money(draft.itemSavings)}',
              valueColor: p.success,
            ),
          if (draft.mode == ServiceMode.pickup)
            GKeyValue(
              label: 'Pickup & drop',
              value: Fmt.money(draft.pickupFee),
            ),
          if (draft.discount > 0)
            GKeyValue(
              label: 'Coupon ${draft.couponCode}',
              value: '− ${Fmt.money(draft.discount)}',
              valueColor: p.success,
            ),
          GKeyValue(
            label: 'GST (18%)',
            value: Fmt.money(draft.gst),
          ),
          const SizedBox(height: Gap.sm),
          const GDashedLine(),
          const SizedBox(height: Gap.sm),
          GKeyValue(
            label: 'Amount payable',
            value: Fmt.money(draft.total),
            emphasize: true,
          ),
          if (draft.totalSavings > 0) ...[
            const SizedBox(height: Gap.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md, vertical: Gap.sm),
              decoration: BoxDecoration(
                color: p.successSoft,
                borderRadius: R.all(R.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.savings_rounded, size: 15, color: p.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You save ${Fmt.money(draft.totalSavings)} on this booking',
                      maxLines: 2,
                      style: AppType.labelM.c(p.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
