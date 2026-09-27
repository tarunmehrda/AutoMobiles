import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/providers.dart';

/// The way into everything the workshop stocks and sells: what is on the
/// shelf, the master lists behind a bill, and the paperwork that moves stock
/// in and out without a job card.
class InventoryDashboardPage extends ConsumerWidget {
  const InventoryDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final split = ref.watch(stockSplitProvider);
    final low = ref.watch(lowStockProvider);
    final suppliers = ref.watch(suppliersProvider);
    final sales = ref.watch(counterSalesProvider);
    final orders = ref.watch(purchaseOrdersProvider);
    final pendingOrders = orders.where((o) => !o.received).length;

    final spares = ref.watch(mastersProvider(LineKind.spare));
    final lubes = ref.watch(mastersProvider(LineKind.lube));
    final jobs = ref.watch(mastersProvider(LineKind.job));
    final lines = spares.length + lubes.length + jobs.length;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Inventory'.tr,
        subtitle: 'Stock, spares and supplies'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          // --- What the shelf is worth ---------------------------------
          Entrance(
            child: _ValueHero(split: split, lines: lines, lowCount: low.length),
          ),
          const SizedBox(height: Gap.md),

          // --- What is on it, by kind -----------------------------------
          // IntrinsicHeight: a ListView hands its children unbounded height,
          // and a Row cannot stretch into that. Without it the three cards
          // come out ragged the moment one blurb wraps.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Entrance(
                    index: 1,
                    child: _CountCard(
                      label: 'Lube'.tr,
                      count: lubes.length,
                      blurb: 'Oils on the shelf'.tr,
                      icon: Icons.water_drop_rounded,
                      tint: p.accent,
                      onTap: () => context.push('/inventory/master?kind=lube'),
                    ),
                  ),
                ),
                const SizedBox(width: Gap.sm + 2),
                Expanded(
                  child: Entrance(
                    index: 2,
                    child: _CountCard(
                      label: 'Spare'.tr,
                      count: spares.length,
                      blurb: low.isEmpty
                          ? 'Parts in stock'.tr
                          : '{0} running low'.trf([low.length]),
                      icon: Icons.settings_rounded,
                      tint: p.info,
                      alert: low.isNotEmpty,
                      onTap: () => context.push('/inventory/master?kind=spare'),
                    ),
                  ),
                ),
                const SizedBox(width: Gap.sm + 2),
                Expanded(
                  child: Entrance(
                    index: 3,
                    child: _CountCard(
                      label: 'Jobs'.tr,
                      count: jobs.length,
                      blurb: 'Labour rates'.tr,
                      icon: Icons.handyman_rounded,
                      tint: p.success,
                      onTap: () => context.push('/inventory/master?kind=job'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.md),

          // --- The one thing this page exists to make easy ---------------
          Entrance(index: 4, child: const _StockBanner()),

          // --- The paperwork --------------------------------------------
          GSectionHeader(
            title: 'Quick actions'.tr,
            subtitle: 'Move stock without opening a job card'.tr,
            icon: Icons.bolt_rounded,
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: Gap.md,
            crossAxisSpacing: Gap.md,
            childAspectRatio: 2.5,
            children: [
              _ActionPuck(
                label: 'Counter Sale'.tr,
                blurb: 'Quick billing'.tr,
                icon: Icons.storefront_rounded,
                tint: p.success,
                badge: sales.isEmpty ? null : '${sales.length}',
                onTap: () => context.push('/inventory/counter-sales'),
              ),
              _ActionPuck(
                label: 'Purchase Orders'.tr,
                blurb: 'Stock coming in'.tr,
                icon: Icons.receipt_long_rounded,
                tint: p.info,
                badge: pendingOrders == 0 ? null : '$pendingOrders',
                onTap: () => context.push('/inventory/purchase-orders'),
              ),
              _ActionPuck(
                label: 'Suppliers'.tr,
                blurb: 'Who you buy from'.tr,
                icon: Icons.local_shipping_rounded,
                tint: p.warning,
                badge: suppliers.isEmpty ? null : '${suppliers.length}',
                onTap: () => context.push('/inventory/suppliers'),
              ),
              _ActionPuck(
                label: 'All Masters'.tr,
                blurb: 'Every list at once'.tr,
                icon: Icons.category_rounded,
                tint: p.accent,
                onTap: () => context.push('/inventory/master'),
              ),
            ],
          ),

          // --- Anything actually running out -----------------------------
          if (low.isNotEmpty) ...[
            GSectionHeader(
              title: 'Running low'.tr,
              subtitle: 'Below the reorder mark'.tr,
              icon: Icons.trending_down_rounded,
              iconTint: p.danger,
              actionLabel: 'See all'.tr,
              onAction: () => context.push('/inventory/master?kind=spare'),
            ),
            for (final item in low.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: _LowRow(item: item),
              ),
          ],
        ],
      ),
    );
  }
}

/// What the shelf is worth, with the spare/lube split as a shape beside it.
class _ValueHero extends StatelessWidget {
  const _ValueHero({
    required this.split,
    required this.lines,
    required this.lowCount,
  });

  final ({double spare, double lube, double total}) split;

  /// How many distinct master lines the workshop keeps — not how many units.
  final int lines;

  final int lowCount;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final healthy = lowCount == 0;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: p.isDark
              ? [
                  Color.alphaBlend(p.accent.withValues(alpha: 0.16), p.surface),
                  p.surface,
                ]
              : [
                  Color.alphaBlend(
                    p.accent.withValues(alpha: 0.13),
                    Colors.white,
                  ),
                  Color.alphaBlend(
                    p.accent.withValues(alpha: 0.05),
                    Colors.white,
                  ),
                ],
        ),
        borderRadius: R.all(R.xl),
        border: Border.all(color: p.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Value on the shelf'.tr,
                  style: AppType.labelM.s(12.5).c(p.inkMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.money(split.total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.d1.s(29).c(p.ink).w(FontWeight.w900),
                ),
                const SizedBox(height: Gap.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: (healthy ? p.success : p.danger).withValues(
                      alpha: 0.14,
                    ),
                    borderRadius: R.all(R.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        healthy
                            ? Icons.check_circle_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: healthy ? p.success : p.danger,
                      ),
                      const SizedBox(width: 5),
                      // Flexible: the chip sits in the narrow half of a card
                      // whose other half is a 116px ring, and the phrase has
                      // to give before the tick does.
                      Flexible(
                        child: Text(
                          healthy
                              ? 'All stocked'.tr
                              : '{0} low'.trf([lowCount]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelS
                              .s(11)
                              .c(healthy ? p.success : p.danger)
                              .w(FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  Tr.plural(lines, '{0} line tracked', '{0} lines tracked'),
                  style: AppType.bodyS.s(11).c(p.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          SizedBox(
            height: 116,
            width: 116,
            child: _Donut(
              spare: split.spare,
              lube: split.lube,
              total: split.total,
            ),
          ),
        ],
      ),
    );
  }
}

/// One kind of stock, as a count rather than a value — the counter asks "how
/// many oils do we carry", not "what are the oils worth".
class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.blurb,
    required this.icon,
    required this.tint,
    required this.onTap,
    this.alert = false,
  });

  final String label;
  final int count;
  final String blurb;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  /// Paints the blurb in the warning colour. Used when the line is the reason
  /// somebody opened this page.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.isDark
              ? Color.alphaBlend(tint.withValues(alpha: 0.12), p.surface)
              : Color.alphaBlend(tint.withValues(alpha: 0.08), Colors.white),
          borderRadius: R.all(R.lg),
          border: Border.all(color: tint.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.18),
                    borderRadius: R.all(R.sm),
                  ),
                  child: Icon(icon, size: 18, color: tint),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 18, color: tint),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelM.s(12).c(p.ink).w(FontWeight.w700),
            ),
            Text('$count', style: AppType.d3.s(23).c(p.ink).w(FontWeight.w900)),
            Text(
              blurb,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodyS
                  .s(9.5)
                  .c(alert ? p.danger : p.inkMuted)
                  .copyWith(height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

/// The add-stock prompt. A banner rather than a floating button, because the
/// thing it does is the reason the page exists and it should read as an
/// invitation rather than as furniture.
class _StockBanner extends StatelessWidget {
  const _StockBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
      decoration: BoxDecoration(
        color: p.isDark
            ? Color.alphaBlend(p.accent.withValues(alpha: 0.10), p.surface)
            : Color.alphaBlend(p.accent.withValues(alpha: 0.10), Colors.white),
        borderRadius: R.all(R.xl),
        border: Border.all(color: p.accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const GArt(Art.stock, height: 76),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Never run out mid-job'.tr,
                  style: AppType.h2.s(15).c(p.ink).w(FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add spares, oil and labour rates once and bill them in a tap.'
                      .tr,
                  style: AppType.bodyS.s(11).c(p.inkMuted),
                ),
                const SizedBox(height: Gap.sm + 2),
                GButton.accent(
                  label: 'Add an item'.tr,
                  icon: Icons.add_rounded,
                  size: GButtonSize.sm,
                  expand: false,
                  onPressed: () => context.push('/inventory/master'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the four ways stock moves without a job card.
class _ActionPuck extends StatelessWidget {
  const _ActionPuck({
    required this.label,
    required this.blurb,
    required this.icon,
    required this.tint,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String blurb;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.isDark ? p.surface : Colors.white,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.isDark ? p.line : p.lineSoft),
          boxShadow: p.isDark ? null : Shadows.soft(p),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: p.isDark ? 0.18 : 0.12),
                borderRadius: R.all(R.sm),
              ),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: Gap.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelM.s(12.5).c(p.ink).w(FontWeight.w700),
                  ),
                  Text(
                    blurb,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodyS.s(10).c(p.inkMuted),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: R.all(R.pill),
                ),
                child: Text(
                  badge!,
                  style: AppType.labelS
                      .s(9.5)
                      .c(Colors.white)
                      .w(FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A line that has fallen below its reorder mark.
class _LowRow extends StatelessWidget {
  const _LowRow({required this.item});

  final MasterItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.sm + 2,
      ),
      decoration: BoxDecoration(
        color: p.isDark ? p.surface : Colors.white,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.isDark ? p.line : p.lineSoft),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: p.danger.withValues(alpha: 0.12),
              borderRadius: R.all(R.sm),
            ),
            child: Icon(Icons.inventory_2_rounded, size: 17, color: p.danger),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelM.s(12.5).c(p.ink).w(FontWeight.w600),
            ),
          ),
          Text(
            '{0} {1} left'.trf([Fmt.number(item.stock), item.unit]),
            style: AppType.labelS.s(11).c(p.danger).w(FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Spare and lube as two arcs of one ring, so the split reads as a shape
/// before it reads as a number.
class _Donut extends StatelessWidget {
  const _Donut({required this.spare, required this.lube, required this.total});

  final double spare;
  final double lube;
  final double total;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow,
      curve: Motion.enter,
      builder: (context, t, _) => CustomPaint(
        painter: _DonutPainter(
          spare: total == 0 ? 0 : spare / total,
          lube: total == 0 ? 0 : lube / total,
          progress: t,
          spareColor: p.info,
          lubeColor: p.accent,
          track: p.surfaceSunken,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Fmt.money(total * t), style: AppType.money.s(14).c(p.ink)),
              Text('on shelf'.tr, style: AppType.labelS.s(9.5).c(p.inkFaint)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.spare,
    required this.lube,
    required this.progress,
    required this.spareColor,
    required this.lubeColor,
    required this.track,
  });

  final double spare;
  final double lube;
  final double progress;
  final Color spareColor;
  final Color lubeColor;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(9, 9, size.width - 18, size.height - 18);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    if (spare + lube <= 0) return;

    var start = -math.pi / 2;
    void arc(double share, Color color) {
      if (share <= 0) return;
      final sweep = math.pi * 2 * share * progress;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }

    arc(spare, spareColor);
    arc(lube, lubeColor);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.spare != spare || old.lube != lube || old.progress != progress;
}
