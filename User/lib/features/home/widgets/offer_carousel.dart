import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/seed/media.dart';
import '../../../state/draft_state.dart';
import '../../../state/providers.dart';

/// Auto-advancing offer rail. Pauses the moment the user touches it so it
/// never fights the scroll, and copies the code on tap.
class OfferCarousel extends ConsumerStatefulWidget {
  const OfferCarousel({super.key});

  @override
  ConsumerState<OfferCarousel> createState() => _OfferCarouselState();
}

class _OfferCarouselState extends ConsumerState<OfferCarousel> {
  final _controller = PageController(viewportFraction: 0.88);
  Timer? _timer;
  int _index = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _paused || !_controller.hasClients) return;
      final count = ref.read(couponsProvider).length;
      if (count < 2) return;
      _controller.animateToPage(
        (_index + 1) % count,
        duration: Motion.slow,
        curve: Motion.emphasized,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final coupons = ref.watch(couponsProvider);
    if (coupons.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Listener(
            onPointerDown: (_) => _paused = true,
            child: PageView.builder(
              controller: _controller,
              padEnds: false,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: coupons.length,
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsets.fromLTRB(
                    i == 0 ? Gap.page : Gap.sm, 0, Gap.sm, 0),
                child: _OfferCard(coupon: coupons[i], photo: Media.offerBanners[i % Media.offerBanners.length]),
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < coupons.length; i++) ...[
              AnimatedContainer(
                duration: Motion.base,
                curve: Motion.spring,
                height: 5,
                width: i == _index ? 20 : 5,
                decoration: BoxDecoration(
                  color: i == _index ? p.accent : p.line,
                  borderRadius: R.all(R.pill),
                ),
              ),
              if (i != coupons.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.coupon, required this.photo});

  final Coupon coupon;
  final String photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    return Pressable(
      onTap: () {
        final error = ref.read(draftProvider.notifier).applyCoupon(coupon.code);
        HapticFeedback.selectionClick();
        if (error == null) {
          GFeedback.success(context, '${coupon.code} applied to your cart');
        } else {
          Clipboard.setData(ClipboardData(text: coupon.code));
          GFeedback.toast(context, '$error • code copied',
              icon: Icons.content_copy_rounded);
        }
      },
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: R.all(R.lg),
          boxShadow: Shadows.soft(p),
        ),
        clipBehavior: Clip.antiAlias,
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
                    coupon.color.withValues(alpha: 0.96),
                    coupon.color.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
            Padding(
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
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: R.all(R.xs),
                        ),
                        child: Text('LIMITED TIME',
                            style: AppType.over.s(9).c(Colors.white)),
                      ),
                      const Spacer(),
                      Text('Ends ${Fmt.dateShort(coupon.validTill)}',
                          style: AppType.labelS
                              .c(Colors.white.withValues(alpha: 0.8))),
                    ],
                  ),
                  const Spacer(),
                  Text(coupon.title,
                      style: AppType.d3.s(21).c(Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(coupon.blurb,
                      style: AppType.bodyS
                          .c(Colors.white.withValues(alpha: 0.85)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: R.all(R.xs),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(coupon.code,
                                style: AppType.labelM
                                    .c(coupon.color)
                                    .copyWith(letterSpacing: 0.8)),
                            const SizedBox(width: 5),
                            Icon(Icons.local_activity_rounded,
                                size: 14, color: coupon.color),
                          ],
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text('Tap to apply',
                          style: AppType.labelS
                              .c(Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
