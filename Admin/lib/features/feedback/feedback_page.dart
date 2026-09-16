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
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../state/providers.dart';

/// Ratings customers left against closed job cards, newest first, with the
/// distribution above so a run of bad weeks is obvious.
class FeedbackPage extends ConsumerWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final reviews = ref.watch(reviewsProvider);
    final average = ref.watch(averageRatingProvider);
    final data = ref.watch(adminDataProvider);

    final sorted = [...reviews]..sort((a, b) => b.at.compareTo(a.at));
    final counts = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
    for (final r in reviews) {
      counts[r.stars] = (counts[r.stars] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Feedback',
        subtitle: reviews.isEmpty
            ? 'Nothing yet'
            : '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
      ),
      body: reviews.isEmpty
          ? const GEmptyState(
              icon: Icons.star_rounded,
              title: 'No reviews yet',
              message:
                  'Ratings customers leave after a job card closes appear '
                  'here, against the card they relate to.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.md, Gap.page, Gap.h2),
              children: [
                // --- headline -----------------------------------------
                Container(
                  padding: const EdgeInsets.all(Gap.lg),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: R.all(R.lg),
                    border: Border.all(color: p.line),
                    boxShadow: Shadows.soft(p),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(average.toStringAsFixed(1),
                              style: AppType.d1.c(p.ink)),
                          _Stars(value: average),
                          const SizedBox(height: 3),
                          Text('${reviews.length} total',
                              style: AppType.labelS.c(p.inkFaint)),
                        ],
                      ),
                      const SizedBox(width: Gap.xl),
                      Expanded(
                        child: Column(
                          children: [
                            for (var star = 5; star >= 1; star--)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      child: Text('$star',
                                          style: AppType.labelS
                                              .c(p.inkFaint)),
                                    ),
                                    const SizedBox(width: Gap.sm),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: R.all(R.pill),
                                        child: LinearProgressIndicator(
                                          value: reviews.isEmpty
                                              ? 0
                                              : counts[star]! /
                                                  reviews.length,
                                          minHeight: 6,
                                          backgroundColor: p.surfaceSunken,
                                          valueColor: AlwaysStoppedAnimation(
                                              star >= 4
                                                  ? p.success
                                                  : star == 3
                                                      ? p.warning
                                                      : p.danger),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: Gap.sm),
                                    SizedBox(
                                      width: 18,
                                      child: Text('${counts[star]}',
                                          textAlign: TextAlign.right,
                                          style: AppType.labelS
                                              .c(p.inkMuted)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: Gap.xxl),

                for (var i = 0; i < sorted.length; i++)
                  Entrance(
                    index: i.clamp(0, 8),
                    child: Builder(
                      builder: (context) {
                        final r = sorted[i];
                        final card = data.jobById(r.jobCardId);
                        final customer =
                            data.customerById(card?.customerId ?? '');
                        return Pressable(
                          onTap: card == null
                              ? null
                              : () => context.push('/job/${card.id}'),
                          scale: 0.985,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: Gap.md),
                            padding: const EdgeInsets.all(Gap.lg),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: R.all(R.lg),
                              border: Border.all(color: p.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GAvatar(
                                      initials: Fmt.initials(
                                          customer?.name ?? '?'),
                                      size: 34,
                                      tone: GTone.neutral,
                                    ),
                                    const SizedBox(width: Gap.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(customer?.name ?? 'Customer',
                                              style:
                                                  AppType.labelL.c(p.ink)),
                                          Text(
                                            '${card?.number ?? ''} • '
                                            '${Fmt.relative(r.at)}',
                                            style: AppType.bodyS
                                                .c(p.inkMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _Stars(value: r.stars.toDouble()),
                                  ],
                                ),
                                if (r.comment.isNotEmpty) ...[
                                  const SizedBox(height: Gap.md),
                                  Text(r.comment,
                                      style: AppType.bodyM.c(p.inkSoft)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            value >= i
                ? Icons.star_rounded
                : value >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: 15,
            color: value >= i - 0.5 ? p.warning : p.inkFaint,
          ),
      ],
    );
  }
}
