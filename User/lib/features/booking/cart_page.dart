import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/draft_state.dart';
import '../../state/providers.dart';
import '../vehicle/widgets/vehicle_selector.dart';
import 'widgets/bill_summary.dart';
import 'widgets/coupon_sheet.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final draft = ref.watch(draftProvider);
    final vehicle = ref.watch(activeVehicleProvider);

    if (draft.isEmpty) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Your cart'),
        body: GEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Nothing in the cart yet',
          message:
              'Add a service and we will price it for your exact car, taxes and all.',
          actionLabel: 'Browse services',
          onAction: () {
            context.pop();
            context.go('/book');
          },
        ),
      );
    }

    final suggestions = Seed.addOns.where((a) => !draft.has(a.id)).take(5).toList();

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Your cart',
        subtitle: '${draft.count} item${draft.count == 1 ? '' : 's'} • '
            '${Fmt.duration(draft.hours)} at the workshop',
        actions: [
          GIconButton(
            icon: Icons.delete_outline_rounded,
            size: 40,
            onTap: () async {
              final ok = await GFeedback.confirm(
                context,
                title: 'Empty the cart?',
                message: 'All selected services will be removed.',
                confirmLabel: 'Empty cart',
                destructive: true,
                icon: Icons.delete_outline_rounded,
              );
              if (ok) {
                ref.read(draftProvider.notifier).clear();
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          // --- vehicle -------------------------------------------------
          Entrance(
            child: GCard(
              padding: const EdgeInsets.all(Gap.md),
              onTap: () => showVehicleSelector(context, ref),
              child: Row(
                children: [
                  Icon(Icons.directions_car_rounded,
                      size: 20, color: p.inkMuted),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SERVICING', style: AppType.over.c(p.inkFaint)),
                        const SizedBox(height: 2),
                        Text(
                          vehicle == null
                              ? 'Select a vehicle'
                              : '${vehicle.title} • ${vehicle.regNumber}',
                          style: AppType.labelL.c(p.ink),
                        ),
                      ],
                    ),
                  ),
                  Text('Change', style: AppType.labelM.c(p.accentInk)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),

          // --- lines ---------------------------------------------------
          Text('SERVICES', style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.sm),
          for (var i = 0; i < draft.lines.length; i++)
            Entrance(
              index: i,
              stagger: const Duration(milliseconds: 40),
              child: Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: _CartLineTile(
                  line: draft.lines[i],
                  onRemove: () {
                    ref.read(draftProvider.notifier).remove(draft.lines[i].id);
                    GFeedback.toast(context, 'Removed from cart',
                        icon: Icons.remove_circle_outline_rounded);
                  },
                ),
              ),
            ),

          const SizedBox(height: Gap.sm),
          Pressable(
            onTap: () {
              context.pop();
              context.go('/book');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 17, color: p.accentInk),
                  const SizedBox(width: 5),
                  Text('Add more services',
                      style: AppType.labelL.c(p.accentInk)),
                ],
              ),
            ),
          ),

          // --- suggestions ---------------------------------------------
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Text('FREQUENTLY ADDED', style: AppType.over.c(p.inkFaint)),
            const SizedBox(height: Gap.sm),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
                itemBuilder: (context, i) {
                  final a = suggestions[i];
                  return Pressable(
                    onTap: () {
                      ref.read(draftProvider.notifier).toggleAddOn(a);
                      GFeedback.toast(context, '${a.name} added',
                          icon: Icons.check_circle_rounded);
                    },
                    scale: 0.95,
                    child: Container(
                      width: 156,
                      padding: const EdgeInsets.all(Gap.md),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: R.all(R.md),
                        border: Border.all(color: p.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(a.icon, size: 19, color: p.inkSoft),
                          const Spacer(),
                          Text(a.name,
                              style: AppType.labelM.c(p.ink),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text('+${Fmt.money(a.price)}',
                                  style: AppType.moneyS.c(p.accentInk)),
                              const Spacer(),
                              Icon(Icons.add_circle_rounded,
                                  size: 18, color: p.accent),
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

          const SizedBox(height: Gap.xl),

          // --- coupon ---------------------------------------------------
          Entrance(index: 2, child: _CouponRow(draft: draft)),
          const SizedBox(height: Gap.xl),

          // --- bill -----------------------------------------------------
          Entrance(index: 3, child: BillSummary(draft: draft)),
          const SizedBox(height: Gap.lg),

          Row(
            children: [
              Icon(Icons.verified_user_rounded, size: 15, color: p.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Final bill matches this estimate unless you approve extra work.',
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.money(draft.total),
                    style: AppType.moneyL.s(21).c(p.ink)),
                if (draft.totalSavings > 0)
                  Text('Saving ${Fmt.money(draft.totalSavings)}',
                      style: AppType.labelS.c(p.success)),
              ],
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: GButton.accent(
                label: 'Select slot',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => context.push('/checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line, required this.onRemove});

  final CartLine line;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final category =
        line.categoryId == null ? null : Seed.categoryById(line.categoryId!);
    final saved = line.mrp - line.price;

    return Dismissible(
      key: ValueKey(line.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Gap.xl),
        decoration: BoxDecoration(
          color: p.dangerSoft,
          borderRadius: R.all(R.lg),
        ),
        child: Icon(Icons.delete_rounded, color: p.danger),
      ),
      child: GCard(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: (category?.color ?? p.inkMuted)
                    .withValues(alpha: p.isDark ? 0.2 : 0.1),
                borderRadius: R.all(R.sm),
              ),
              child: Icon(
                line.isAddOn
                    ? Icons.add_circle_outline_rounded
                    : (category?.icon ?? Icons.build_rounded),
                size: 20,
                color: category?.color ?? p.inkMuted,
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(line.name,
                            style: AppType.labelL.c(p.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (line.isAddOn) ...[
                        const SizedBox(width: Gap.sm),
                        const GTag(label: 'ADD-ON'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(Fmt.money(line.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.moneyS.c(p.ink)),
                      ),
                      if (saved > 0) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            Fmt.money(line.mrp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.labelS.s(10.5).c(p.inkFaint).copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: p.inkFaint,
                                ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text('save ${Fmt.money(saved)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.labelS.s(10.5).c(p.success)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            GIconButton(
              icon: Icons.close_rounded,
              size: 32,
              bordered: false,
              background: p.surfaceSunken,
              foreground: p.inkMuted,
              onTap: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponRow extends ConsumerWidget {
  const _CouponRow({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final coupon = draft.coupon;

    if (coupon != null) {
      return Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.successSoft,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.local_activity_rounded, color: p.success, size: 22),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${coupon.code} applied',
                      style: AppType.labelL.c(p.success)),
                  Text('You saved ${Fmt.money(draft.discount)}',
                      style: AppType.bodyS.c(p.success.withValues(alpha: 0.85))),
                ],
              ),
            ),
            Pressable(
              onTap: () {
                ref.read(draftProvider.notifier).removeCoupon();
                GFeedback.info(context, 'Coupon removed');
              },
              child: Text('Remove', style: AppType.labelM.c(p.danger)),
            ),
          ],
        ),
      );
    }

    return Pressable(
      onTap: () => showCouponSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Icon(Icons.local_activity_outlined, color: p.accentInk, size: 22),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apply a coupon', style: AppType.labelL.c(p.ink)),
                  Text('${Seed.coupons().length} offers available for you',
                      style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}
