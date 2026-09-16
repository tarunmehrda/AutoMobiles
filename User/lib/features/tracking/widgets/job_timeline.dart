import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';

/// Vertical job tracker. Completed steps carry their real timestamp and note,
/// the current step pulses, and future steps stay quiet so the eye lands on
/// what is happening right now.
class JobTimeline extends StatelessWidget {
  const JobTimeline({super.key, required this.booking, required this.flow});

  final Booking booking;
  final List<JobStage> flow;

  TimelineEvent? _eventFor(JobStage stage) {
    for (final e in booking.timeline.reversed) {
      if (e.stage == stage) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final currentIndex = flow.indexOf(booking.stage).clamp(0, flow.length - 1);
    final cancelled = booking.status == BookingStatus.cancelled;

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.sm),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        children: [
          for (var i = 0; i < flow.length; i++)
            _Step(
              stage: flow[i],
              event: _eventFor(flow[i]),
              state: cancelled && i > currentIndex
                  ? _StepState.skipped
                  : (i < currentIndex
                      ? _StepState.done
                      : (i == currentIndex
                          ? _StepState.current
                          : _StepState.pending)),
              isLast: i == flow.length - 1,
              waiting: booking.needsApproval && i == currentIndex,
            ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, pending, skipped }

class _Step extends StatelessWidget {
  const _Step({
    required this.stage,
    required this.event,
    required this.state,
    required this.isLast,
    required this.waiting,
  });

  final JobStage stage;
  final TimelineEvent? event;
  final _StepState state;
  final bool isLast;
  final bool waiting;

  /// Same-day events show a time; anything older shows its date, so a
  /// two-day-old booking never reads as if it happened before this morning.
  static String _stamp(DateTime at) {
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return sameDay ? Fmt.time(at) : Fmt.dateShort(at);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    final Color dotColor = switch (state) {
      _StepState.done => p.success,
      _StepState.current => waiting ? p.accent : p.info,
      _StepState.pending => p.line,
      _StepState.skipped => p.line,
    };
    final Color textColor = switch (state) {
      _StepState.done => p.ink,
      _StepState.current => p.ink,
      _StepState.pending => p.inkFaint,
      _StepState.skipped => p.inkFaint,
    };

    final hasNote = event?.note != null && event!.note!.isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- rail -------------------------------------------------
          SizedBox(
            width: 26,
            child: Column(
              children: [
                _Dot(color: dotColor, state: state, icon: stage.icon),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: state == _StepState.done
                            ? p.success.withValues(alpha: 0.35)
                            : p.line,
                        borderRadius: R.all(R.pill),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),

          // --- content ----------------------------------------------
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? Gap.md : Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stage.label,
                          style: (state == _StepState.current
                                  ? AppType.labelL
                                  : AppType.labelM)
                              .c(textColor),
                        ),
                      ),
                      if (event != null)
                        Text(_stamp(event!.at),
                            style: AppType.labelS.c(p.inkFaint))
                      else if (state == _StepState.current)
                        const GPill(
                            label: 'NOW',
                            tone: GTone.info,
                            compact: true,
                            dot: true,
                            pulse: true),
                    ],
                  ),
                  if (hasNote) ...[
                    const SizedBox(height: 3),
                    Text(event!.note!,
                        style: AppType.bodyS.c(p.inkMuted)),
                  ] else if (state == _StepState.current) ...[
                    const SizedBox(height: 3),
                    Text(stage.blurb, style: AppType.bodyS.c(p.inkMuted)),
                  ],
                  if (event?.actor != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_rounded,
                            size: 12, color: p.inkFaint),
                        const SizedBox(width: 3),
                        Text(event!.actor!,
                            style: AppType.labelS.s(10.5).c(p.inkFaint)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.state, required this.icon});

  final Color color;
  final _StepState state;
  final IconData icon;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  // Only the current step pulses; every other dot must never build a Ticker,
  // least of all from dispose().
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.state == _StepState.current) _start();
  }

  void _start() {
    _c ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _c!.repeat();
  }

  @override
  void didUpdateWidget(covariant _Dot old) {
    super.didUpdateWidget(old);
    if (widget.state == _StepState.current) {
      if (!(_c?.isAnimating ?? false)) _start();
    } else if (_c != null) {
      _c!.stop();
      _c!.value = 0;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final isDone = widget.state == _StepState.done;
    final isCurrent = widget.state == _StepState.current;

    final core = Container(
      height: 24,
      width: 24,
      decoration: BoxDecoration(
        color: isDone || isCurrent ? widget.color : p.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDone || isCurrent ? widget.color : p.line,
          width: 2,
        ),
      ),
      child: Icon(
        isDone ? Icons.check_rounded : widget.icon,
        size: isDone ? 13 : 12,
        color: isDone || isCurrent ? Colors.white : p.inkFaint,
      ),
    );

    if (!isCurrent || _c == null) return core;

    return AnimatedBuilder(
      animation: _c!,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_c!.value);
        return SizedBox(
          height: 24,
          width: 24,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: (1 - t) * 0.4,
                child: Container(
                  height: 24 + 18 * t,
                  width: 24 + 18 * t,
                  decoration: BoxDecoration(
                      color: widget.color, shape: BoxShape.circle),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: core,
    );
  }
}
