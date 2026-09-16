import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/decor.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/app_state.dart';

/// The hero of the Home screen whenever a job is open. Dark, textured and
/// deliberately unlike every other card so it reads as "this is happening now".
class LiveJobCard extends ConsumerWidget {
  const LiveJobCard({super.key, required this.booking, required this.vehicle});

  final Booking booking;
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final flow = ref.read(appControllerProvider.notifier).stageFlowFor(booking);
    final index = flow.indexOf(booking.stage).clamp(0, flow.length - 1);
    final progress = (index + 1) / flow.length;
    final waiting = booking.needsApproval;
    final upcoming = booking.status == BookingStatus.upcoming;

    return Pressable(
      onTap: () => context.push('/booking/${booking.id}'),
      scale: 0.985,
      child: Container(
        decoration: BoxDecoration(
          gradient: p.inverseGradient,
          borderRadius: R.all(R.xl),
          boxShadow: Shadows.lifted(p),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: BlueprintPainter(
                    color: p.onInverse, spacing: 24, opacity: 0.055),
              ),
            ),
            Positioned(
              top: -70,
              right: -50,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    (waiting ? p.accent : p.volt).withValues(alpha: 0.22),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GPill(
                        label: upcoming ? 'SCHEDULED' : 'LIVE',
                        tone: waiting
                            ? GTone.accent
                            : (upcoming ? GTone.neutral : GTone.volt),
                        dot: true,
                        pulse: !upcoming,
                        compact: true,
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(booking.code,
                          style: AppType.labelS
                              .c(p.onInverse.withValues(alpha: 0.45))),
                      const Spacer(),
                      Icon(Icons.arrow_outward_rounded,
                          size: 18,
                          color: p.onInverse.withValues(alpha: 0.5)),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: p.onInverse.withValues(alpha: 0.08),
                          borderRadius: R.all(R.sm),
                          border: Border.all(
                              color: p.onInverse.withValues(alpha: 0.08)),
                        ),
                        child: Icon(booking.stage.icon,
                            size: 21,
                            color: waiting ? p.accent : p.volt),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              waiting
                                  ? 'Your approval is needed'
                                  : booking.stage.label,
                              style: AppType.h1.c(p.onInverse),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              waiting
                                  ? 'Repair starts the moment you approve the estimate'
                                  : '${vehicle?.title ?? 'Your vehicle'} • ${booking.stage.blurb}',
                              style: AppType.bodyS
                                  .c(p.onInverse.withValues(alpha: 0.6)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.xl),
                  ClipRRect(
                    borderRadius: R.all(R.pill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: Motion.lazy,
                      curve: Motion.enter,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 5,
                        backgroundColor: p.onInverse.withValues(alpha: 0.12),
                        valueColor:
                            AlwaysStoppedAnimation(waiting ? p.accent : p.volt),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Step ${index + 1} of ${flow.length}',
                          style: AppType.labelS
                              .c(p.onInverse.withValues(alpha: 0.55)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      if (upcoming)
                        Flexible(
                          child: Text(
                            '${Fmt.friendlyDay(booking.slot)} • ${Fmt.time(booking.slot)}',
                            style: AppType.labelS.c(p.onInverse),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        )
                      else if (booking.etaAt != null)
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 13,
                                  color: p.onInverse.withValues(alpha: 0.55)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Ready by ${Fmt.time(booking.etaAt!)}',
                                  style: AppType.labelS.c(p.onInverse),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _Action(
                          label: waiting ? 'Review estimate' : 'Track service',
                          icon: waiting
                              ? Icons.fact_check_rounded
                              : Icons.timeline_rounded,
                          filled: true,
                          tone: waiting ? p.accent : p.volt,
                          onTap: () => context.push(waiting
                              ? '/booking/${booking.id}/estimate'
                              : '/booking/${booking.id}'),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      _Action(
                        label: 'Chat',
                        icon: Icons.chat_bubble_rounded,
                        filled: false,
                        tone: p.onInverse,
                        onTap: () => context.push('/chat'),
                      ),
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

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.filled,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final fg = filled
        ? (tone == p.volt ? const Color(0xFF10160A) : p.onAccent)
        : p.onInverse;
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        decoration: BoxDecoration(
          color: filled ? tone : p.onInverse.withValues(alpha: 0.08),
          borderRadius: R.all(R.md),
          border: filled
              ? null
              : Border.all(color: p.onInverse.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppType.labelM.c(fg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
