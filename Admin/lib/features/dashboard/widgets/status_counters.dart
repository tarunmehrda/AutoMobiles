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

/// The three buckets, as the counter sees them all day. Tapping one opens
/// that list.
class StatusCounters extends ConsumerWidget {
  const StatusCounters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Row(
        children: [
          for (var i = 0; i < JobStatus.values.length; i++) ...[
            Expanded(
              child: Entrance(
                index: i,
                child: _Counter(status: JobStatus.values[i]),
              ),
            ),
            if (i != JobStatus.values.length - 1)
              const SizedBox(width: Gap.md),
          ],
        ],
      ),
    );
  }
}

class _Counter extends ConsumerWidget {
  const _Counter({required this.status});

  final JobStatus status;

  Color _tint(AppPalette p) => switch (status) {
        JobStatus.open => p.accent,
        JobStatus.complete => p.info,
        JobStatus.closed => p.success,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final count = ref.watch(bucketCountProvider(status));
    final tint = _tint(p);

    return Pressable(
      onTap: () => context.go('/jobs?status=${status.name}'),
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 58,
              width: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // A ring that fills as this bucket takes a bigger share of
                  // the floor, so the shape carries meaning, not just colour.
                  Positioned.fill(
                    child: _Ring(
                      value: _share(ref),
                      color: tint,
                      track: p.surfaceSunken,
                    ),
                  ),
                  AnimatedCount(
                    value: count.toDouble(),
                    builder: (context, v) => Text(
                      v.round().toString(),
                      style: AppType.d3.c(p.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.md),
            Text(status.label, style: AppType.labelM.c(p.ink)),
            const SizedBox(height: 1),
            Text('Job cards', style: AppType.labelS.s(10.5).c(p.inkFaint)),
          ],
        ),
      ),
    );
  }

  double _share(WidgetRef ref) {
    final total = ref.watch(jobCardsProvider).length;
    if (total == 0) return 0;
    return ref.watch(bucketCountProvider(status)) / total;
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: Motion.slow,
      curve: Motion.enter,
      builder: (context, v, _) => CircularProgressIndicator(
        value: v == 0 ? 1 : v,
        strokeWidth: 4,
        strokeCap: StrokeCap.round,
        backgroundColor: track,
        valueColor: AlwaysStoppedAnimation(v == 0 ? track : color),
      ),
    );
  }
}
