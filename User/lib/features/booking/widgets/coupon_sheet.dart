import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../state/draft_state.dart';
import '../../../state/providers.dart';

Future<void> showCouponSheet(BuildContext context, WidgetRef ref) {
  return GFeedback.sheet<void>(
    context,
    title: 'Coupons & offers',
    subtitle: 'Applied to the items already in your cart',
    child: const _CouponSheetBody(),
  );
}

class _CouponSheetBody extends ConsumerStatefulWidget {
  const _CouponSheetBody();

  @override
  ConsumerState<_CouponSheetBody> createState() => _CouponSheetBodyState();
}

class _CouponSheetBodyState extends ConsumerState<_CouponSheetBody> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _apply(String code) {
    final error = ref.read(draftProvider.notifier).applyCoupon(code);
    if (error != null) {
      setState(() => _error = error);
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    GFeedback.success(context, 'Coupon applied');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final coupons = ref.watch(couponsProvider);
    final draft = ref.watch(draftProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page,
          Gap.xxl + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GField(
                  hint: 'Enter a coupon code',
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: _apply,
                ),
              ),
              const SizedBox(width: Gap.sm),
              GButton(
                label: 'Apply',
                expand: false,
                size: GButtonSize.md,
                onPressed: _code.text.trim().isEmpty
                    ? null
                    : () => _apply(_code.text),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 14, color: p.danger),
                const SizedBox(width: 5),
                Text(_error!, style: AppType.labelS.c(p.danger)),
              ],
            ),
          ],
          const SizedBox(height: Gap.xl),
          Text('AVAILABLE FOR YOU', style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.md),
          for (final c in coupons)
            _CouponTile(
              coupon: c,
              subtotal: draft.subtotal,
              applied: draft.couponCode == c.code,
              onApply: () => _apply(c.code),
            ),
        ],
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({
    required this.coupon,
    required this.subtotal,
    required this.applied,
    required this.onApply,
  });

  final Coupon coupon;
  final int subtotal;
  final bool applied;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final eligible = subtotal >= coupon.minOrder && coupon.isLive;
    final saving = coupon.discountFor(subtotal);

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(
            color: applied ? coupon.color : p.line,
            width: applied ? 1.6 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 104,
            color: eligible ? coupon.color : p.line,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: coupon.color.withValues(alpha: 0.1),
                          borderRadius: R.all(4),
                          border: Border.all(
                              color: coupon.color.withValues(alpha: 0.3)),
                        ),
                        child: Text(coupon.code,
                            style: AppType.labelS
                                .c(coupon.color)
                                .copyWith(letterSpacing: 0.6)),
                      ),
                      const Spacer(),
                      if (applied)
                        Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 15, color: p.success),
                            const SizedBox(width: 4),
                            Text('Applied',
                                style: AppType.labelS.c(p.success)),
                          ],
                        )
                      else
                        Pressable(
                          onTap: eligible ? onApply : null,
                          enabled: eligible,
                          child: Text(
                            eligible ? 'Apply' : 'Not eligible',
                            style: AppType.labelM
                                .c(eligible ? p.accentInk : p.inkFaint),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(coupon.title, style: AppType.labelL.c(p.ink)),
                  const SizedBox(height: 2),
                  Text(
                    eligible && saving > 0
                        ? 'Saves ${Fmt.money(saving)} on this cart'
                        : (subtotal < coupon.minOrder
                            ? 'Add ${Fmt.money(coupon.minOrder - subtotal)} more to unlock'
                            : coupon.blurb),
                    style: AppType.bodyS.c(
                        eligible && saving > 0 ? p.success : p.inkMuted),
                  ),
                  const SizedBox(height: 6),
                  Text('Valid till ${Fmt.date(coupon.validTill)}',
                      style: AppType.labelS.s(10).c(p.inkFaint)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
