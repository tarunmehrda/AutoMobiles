import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/anim/entrance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/directions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../state/providers.dart';

/// What the workshop offers, as the workshop published it. Reached from the
/// preferred-garage card on Home.
Future<void> showWorkshopDetailsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _WorkshopDetailsSheet(),
    );

class _WorkshopDetailsSheet extends ConsumerWidget {
  const _WorkshopDetailsSheet();

  Future<void> _open(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final shop = ref.watch(workshopProvider);

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: p.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xxl)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- dark header -------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
                Gap.page, Gap.lg, Gap.page, Gap.lg),
            decoration: BoxDecoration(gradient: p.inverseGradient),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Workshop Details',
                          style: AppType.h1.c(p.onInverse)),
                      const SizedBox(height: 2),
                      Text('Services and information about this workshop',
                          style: AppType.bodyS
                              .c(p.onInverse.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  scale: 0.9,
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.xs),
                    child: Icon(Icons.close_rounded,
                        size: 22, color: p.onInverse),
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.lg, Gap.page, Gap.h1),
              children: [
                Container(
                  padding: const EdgeInsets.all(Gap.lg),
                  decoration: BoxDecoration(
                    gradient: p.inverseGradient,
                    borderRadius: R.all(R.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.onInverse.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(shop.initials,
                                style: AppType.labelL.c(p.onInverse)),
                          ),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(shop.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.h1.c(p.onInverse)),
                                if (shop.reviewCount > 0)
                                  Row(
                                    children: [
                                      Icon(Icons.star_rounded,
                                          size: 15, color: p.volt),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${shop.rating.toStringAsFixed(1)} '
                                          'Rating • ${shop.reviewCount} reviews',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppType.bodyS.c(p.onInverse
                                              .withValues(alpha: 0.7)),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (shop.address.isNotEmpty) ...[
                        const SizedBox(height: Gap.lg),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 16, color: p.accent),
                            const SizedBox(width: Gap.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Address',
                                      style: AppType.labelS.c(p.onInverse
                                          .withValues(alpha: 0.6))),
                                  Text(shop.address,
                                      style: AppType.bodyM.c(p.onInverse)),
                                ],
                              ),
                            ),
                            Pressable(
                              onTap: () async {
                                if (!await openDirections(
                                      address: shop.address,
                                    ) &&
                                    context.mounted) {
                                  GFeedback.error(
                                    context,
                                    'Could not open maps on this phone.',
                                  );
                                }
                              },
                              scale: 0.9,
                              child: Container(
                                height: 36,
                                width: 36,
                                decoration: BoxDecoration(
                                  color: p.info,
                                  borderRadius: R.all(R.sm),
                                ),
                                child: const Icon(Icons.navigation_rounded,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: Gap.lg),
                      Row(
                        children: [
                          if (shop.phone.isNotEmpty) ...[
                            Pressable(
                              onTap: () =>
                                  _open(Uri.parse('tel:${shop.phone}')),
                              scale: 0.9,
                              child: Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: p.onInverse.withValues(alpha: 0.1),
                                  borderRadius: R.all(R.sm),
                                ),
                                child: Icon(Icons.call_rounded,
                                    size: 19, color: p.success),
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                          ],
                          Expanded(
                            child: GButton.accent(
                              label: 'Book Service',
                              icon: Icons.calendar_month_rounded,
                              // With this workshop already chosen: the
                              // customer is looking at it. Leaving the garage
                              // off sent them to the directory to find it
                              // all over again.
                              onPressed: () {
                                Navigator.of(context).pop();
                                context.push(shop.isLinked
                                    ? '/book?garage='
                                        '${Uri.encodeComponent(shop.id)}'
                                    : '/book');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: Gap.xl),
                if (shop.services.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.xl),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 44, color: p.inkFaint),
                        const SizedBox(height: Gap.md),
                        Text('No services available',
                            style: AppType.h2.c(p.ink)),
                        const SizedBox(height: 4),
                        Text("This workshop hasn't added any services yet",
                            textAlign: TextAlign.center,
                            style: AppType.bodyS.c(p.inkMuted)),
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < shop.services.length; i++)
                    Entrance(
                      index: i.clamp(0, 8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: Gap.sm),
                        padding: const EdgeInsets.all(Gap.lg),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: R.all(R.md),
                          border: Border.all(color: p.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shop.services[i].name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.labelL.c(p.ink),
                                  ),
                                  if (shop.services[i].blurb.isNotEmpty)
                                    Text(
                                      shop.services[i].blurb,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.bodyS.c(p.inkMuted),
                                    ),
                                  Text(
                                      'About '
                                      '${shop.services[i].durationMins} min',
                                      style:
                                          AppType.labelS.c(p.inkFaint)),
                                ],
                              ),
                            ),
                            Text(Fmt.money(shop.services[i].price),
                                style: AppType.money.c(p.ink)),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
