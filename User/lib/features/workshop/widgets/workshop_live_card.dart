import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/workshop.dart';

/// What the garage is doing to the car, right now.
///
/// Unlike the booking card beside it, nothing here was written by this app —
/// every line is the workshop's own job card arriving over the wire as the
/// counter fills it in. The progress bar moves while you are looking at it.
class WorkshopLiveCard extends StatelessWidget {
  const WorkshopLiveCard({super.key, required this.card});

  final WorkshopCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final ready = card.isComplete;
    final done = card.items.where((e) => e.isFinished).length;

    return Pressable(
      onTap: () => context.push('/workshop/${card.id}'),
      scale: 0.985,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.xl),
          border: Border.all(
            color: ready ? p.success.withValues(alpha: 0.5) : p.line,
          ),
          boxShadow: Shadows.soft(p),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GPill(
                    label: ready ? 'READY' : 'AT THE WORKSHOP',
                    tone: ready ? GTone.success : GTone.volt,
                    dot: true,
                    pulse: !ready,
                    compact: true,
                  ),
                  const Spacer(),
                  Text(card.number,
                      style: AppType.labelS.copyWith(color: p.inkMuted)),
                ],
              ),
              const SizedBox(height: Gap.lg),
              Text(
                card.vehicleTitle.isEmpty ? card.regNo : card.vehicleTitle,
                style: AppType.h3.copyWith(color: p.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Gap.xxs),
              Text(
                card.garageName.isEmpty
                    ? card.statusLabel
                    : '${card.statusLabel} · ${card.garageName}',
                style: AppType.bodyS.copyWith(color: p.inkSoft),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Gap.lg),

              // The bar is the point of this card: it is the workshop's own
              // count of what is finished, not an estimate made here.
              ClipRRect(
                borderRadius: R.all(R.pill),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: card.progress),
                  duration: Motion.slow,
                  curve: Motion.enter,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: p.surfaceSunken,
                    valueColor: AlwaysStoppedAnimation(
                        ready ? p.success : p.accent),
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.items.isEmpty
                          ? 'Nothing billed yet'
                          : '$done of ${card.items.length} jobs done',
                      style: AppType.labelM.copyWith(color: p.inkSoft),
                    ),
                  ),
                  if (card.total > 0)
                    Text(Fmt.money(card.total),
                        style: AppType.money.copyWith(color: p.ink)),
                ],
              ),
              if (card.promisedAt != null && !ready) ...[
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 15, color: p.inkMuted),
                    const SizedBox(width: Gap.xs),
                    Text(
                      'Promised ${Fmt.relative(card.promisedAt!)}',
                      style: AppType.labelS.copyWith(color: p.inkMuted),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
