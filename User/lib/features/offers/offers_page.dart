import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/seed/media.dart';
import '../../state/draft_state.dart';
import '../../state/providers.dart';

class OffersPage extends ConsumerWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final coupons = ref.watch(couponsProvider);
    final draft = ref.watch(draftProvider);
    final saved = ref.watch(savedPackagesProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Offers & coupons',
        subtitle: '${coupons.length} running now',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          for (var i = 0; i < coupons.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Entrance(
                index: i,
                child: _OfferCard(
                  coupon: coupons[i],
                  photo: Media.offerBanners[i % Media.offerBanners.length],
                  applied: draft.couponCode == coupons[i].code,
                  subtotal: draft.subtotal,
                ),
              ),
            ),

          const SizedBox(height: Gap.lg),
          Text('HOW COUPONS WORK', style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.sm),
          GCard(
            child: Column(
              children: [
                for (final t in const [
                  (
                    Icons.shopping_bag_rounded,
                    'One coupon per booking',
                    'The best available one is easiest — apply it in the cart.'
                  ),
                  (
                    Icons.calculate_rounded,
                    'Applied before tax',
                    'Discount comes off the service total, then GST is added.'
                  ),
                  (
                    Icons.block_rounded,
                    'Not on approved extra work',
                    'Coupons cover the package you booked, not repairs added later.'
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(t.$1, size: 17, color: p.inkMuted),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.$2, style: AppType.labelM.c(p.ink)),
                              Text(t.$3,
                                  style: AppType.bodyS.c(p.inkMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (saved.isNotEmpty) ...[
            const SizedBox(height: Gap.xl),
            Text('SAVED SERVICES', style: AppType.over.c(p.inkFaint)),
            const SizedBox(height: Gap.sm),
            GCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final id in saved)
                    GTile(
                      title: id
                          .split('-')
                          .map((w) => w.isEmpty
                              ? w
                              : '${w[0].toUpperCase()}${w.substring(1)}')
                          .join(' '),
                      icon: Icons.bookmark_rounded,
                      onTap: () => context.push('/service/$id'),
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

class _OfferCard extends ConsumerWidget {
  const _OfferCard({
    required this.coupon,
    required this.photo,
    required this.applied,
    required this.subtotal,
  });

  final Coupon coupon;
  final String photo;
  final bool applied;
  final int subtotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final daysLeft = coupon.validTill.difference(DateTime.now()).inDays;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.xl),
        border: Border.all(
            color: applied ? coupon.color : p.line,
            width: applied ? 1.6 : 1),
        boxShadow: Shadows.soft(p),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 116,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(photo, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        coupon.color.withValues(alpha: 0.95),
                        coupon.color.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(coupon.title,
                          style: AppType.d3.s(20).c(Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(coupon.blurb,
                          style: AppType.bodyS
                              .c(Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: p.inkFaint),
                    const SizedBox(width: 5),
                    Text(
                      daysLeft <= 0
                          ? 'Expired'
                          : '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                      style: AppType.labelS
                          .c(daysLeft <= 3 ? p.danger : p.inkMuted),
                    ),
                    const Spacer(),
                    if (coupon.minOrder > 0)
                      Text('Min order ${Fmt.money(coupon.minOrder)}',
                          style: AppType.labelS.c(p.inkMuted)),
                  ],
                ),
                const SizedBox(height: Gap.md),
                const GDashedLine(),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Expanded(
                      child: Pressable(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: coupon.code));
                          GFeedback.toast(context, '${coupon.code} copied',
                              icon: Icons.content_copy_rounded);
                        },
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: coupon.color.withValues(alpha: 0.08),
                            borderRadius: R.all(R.sm),
                            border: Border.all(
                                color: coupon.color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(coupon.code,
                                  style: AppType.labelL
                                      .c(coupon.color)
                                      .copyWith(letterSpacing: 1)),
                              const SizedBox(width: 6),
                              Icon(Icons.content_copy_rounded,
                                  size: 14, color: coupon.color),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: GButton(
                        label: applied ? 'Applied' : 'Apply',
                        kind: applied
                            ? GButtonKind.ghost
                            : GButtonKind.primary,
                        size: GButtonSize.md,
                        expand: true,
                        icon: applied ? Icons.check_rounded : null,
                        onPressed: applied
                            ? null
                            : () {
                                final error = ref
                                    .read(draftProvider.notifier)
                                    .applyCoupon(coupon.code);
                                if (error == null) {
                                  GFeedback.success(
                                      context, '${coupon.code} applied');
                                  context.push('/cart');
                                } else {
                                  GFeedback.toast(context, error,
                                      icon: Icons.info_rounded);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
