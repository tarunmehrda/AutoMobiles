import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/anim/entrance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/enums.dart';
import '../../../state/providers.dart';

/// The three job-card buckets, side by side, in the order a card moves
/// through them: open on the floor, complete and waiting, closed and filed.
///
/// They are counts, not gauges. The old cards wrapped each number in a radial
/// ring showing its share of the total, which looked like telemetry and told
/// the owner nothing — a workshop does not want to know that 60% of its cards
/// are open, it wants to know that six are. So the ring is gone and the
/// number got the space it was using.
class StatusCounters extends ConsumerWidget {
  const StatusCounters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      // IntrinsicHeight, because a Row cannot stretch its children inside a
      // sliver that gives it no height to stretch to. Without it the three
      // cards end up different heights whenever one title wraps to two lines.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < JobStatus.values.length; i++) ...[
              Expanded(
                child: Entrance(
                  index: i + 1,
                  offset: 14,
                  child: _BucketCard(status: JobStatus.values[i]),
                ),
              ),
              if (i != JobStatus.values.length - 1)
                const SizedBox(width: Gap.md - 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _BucketCard extends ConsumerWidget {
  const _BucketCard({required this.status});

  final JobStatus status;

  Color _tint(AppPalette p) => switch (status) {
    JobStatus.open => p.accent,
    JobStatus.complete => p.success,
    JobStatus.closed => p.info,
  };

  IconData _icon() => switch (status) {
    JobStatus.open => Icons.description_rounded,
    JobStatus.complete => Icons.check_circle_outline_rounded,
    JobStatus.closed => Icons.lock_rounded,
  };

  String _title() => switch (status) {
    JobStatus.open => 'On the Floor',
    JobStatus.complete => 'Ready to Go',
    JobStatus.closed => 'Handed Over',
  };

  String _subtitle() => switch (status) {
    JobStatus.open => 'Work under way',
    JobStatus.complete => 'Waiting on pickup',
    JobStatus.closed => 'Settled and filed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final count = ref.watch(bucketCountProvider(status));
    final tint = _tint(p);

    return Pressable(
      onTap: () => context.push('/jobs?status=${status.name}'),
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md),
        decoration: BoxDecoration(
          color: p.isDark ? p.surface : Colors.white,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.isDark ? p.line : p.lineSoft),
          boxShadow: p.isDark ? null : Shadows.soft(p),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: p.isDark ? 0.18 : 0.12),
                    borderRadius: R.all(R.sm),
                  ),
                  child: Icon(_icon(), size: 21, color: tint),
                ),
                const Spacer(),
                Container(
                  height: 22,
                  width: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.isDark ? p.surfaceSunken : p.canvas,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: p.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            AnimatedCount(
              value: count.toDouble(),
              builder: (context, v) => Text(
                v.round().toString(),
                style: AppType.d2
                    .s(30)
                    .c(p.ink)
                    .w(FontWeight.w900)
                    .copyWith(height: 1.05),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _title(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelM
                  .s(12)
                  .c(p.ink)
                  .w(FontWeight.w700)
                  .copyWith(height: 1.2),
            ),
            const SizedBox(height: 2),
            Text(
              _subtitle(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodyS.s(10).c(p.inkMuted).copyWith(height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
