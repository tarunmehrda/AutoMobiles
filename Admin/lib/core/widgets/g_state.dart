import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/i18n/strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'g_art.dart';
import 'g_button.dart';

/// Skeleton block. Wrap groups in [GSkeletonGroup] for one shared sweep.
class GSkeleton extends StatelessWidget {
  const GSkeleton({
    super.key,
    this.height = 14,
    this.width,
    this.radius = R.xs,
    this.circle = false,
  });

  final double height;
  final double? width;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      height: height,
      width: circle ? height : width,
      decoration: BoxDecoration(
        color: p.shimmerBase,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : R.all(radius),
      ),
    );
  }
}

class GSkeletonGroup extends StatelessWidget {
  const GSkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Shimmer.fromColors(
      baseColor: p.shimmerBase,
      highlightColor: p.shimmerHighlight,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Empty / error state with an illustrative glyph and optional action.
class GEmptyState extends StatelessWidget {
  const GEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.art = Art.empty,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.tone,
  });

  final String title;
  final String message;

  /// Kept for the handful of places that want the old tinted disc — an empty
  /// state inside a card, where a full illustration would be the largest
  /// thing on screen. See [drawn].
  final IconData icon;

  /// The illustration. Defaults to the generic empty box, so a screen that
  /// says nothing about which picture it wants still gets one.
  final String art;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Tighter spacing and a smaller picture, for an empty state sitting inside
  /// a card or a tab rather than owning the screen.
  final bool compact;

  final Color? tone;

  /// Whether to draw the illustration rather than the disc. An empty [art]
  /// opts back out.
  bool get drawn => art.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final accent = tone ?? p.accent;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Gap.h1,
          vertical: compact ? Gap.lg : Gap.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (drawn)
              GArt(art, height: compact ? 96 : 138, semanticLabel: title)
            else
              Container(
                height: compact ? 64 : 84,
                width: compact ? 64 : 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.16),
                      accent.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Icon(icon, size: compact ? 28 : 36, color: accent),
              ),
            SizedBox(height: compact ? Gap.lg : Gap.xxl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: (compact ? AppType.h2 : AppType.d3)
                  .c(p.ink)
                  .w(FontWeight.w800),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.bodyM.c(p.inkMuted),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: Gap.xxl),
              GButton.accent(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
                size: GButtonSize.md,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thin gradient progress used at the top of multi-step flows.
class GStepProgress extends StatelessWidget {
  const GStepProgress({
    super.key,
    required this.step,
    required this.total,
    this.labels,
  });

  final int step;
  final int total;
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.enter,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? p.accent : p.surfaceSunken,
                    borderRadius: R.all(R.pill),
                  ),
                ),
              ),
              if (i != total - 1) const SizedBox(width: 5),
            ],
          ],
        ),
        if (labels != null && step < labels!.length) ...[
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Text(
                'Step {0} of {1}'.trf([step + 1, total]),
                style: AppType.labelS.c(p.inkFaint),
              ),
              const SizedBox(width: Gap.sm),
              Text('•', style: AppType.labelS.c(p.inkFaint)),
              const SizedBox(width: Gap.sm),
              Text(labels![step], style: AppType.labelS.c(p.accentInk)),
            ],
          ),
        ],
      ],
    );
  }
}
