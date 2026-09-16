import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../state/providers.dart';
import '../shared/support_sheet.dart';
import '../../core/widgets/brand_logo.dart';
import 'widgets/console_tile.dart';
import 'widgets/status_counters.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final garage = ref.watch(garageProvider);
    final total = ref.watch(jobCardsProvider).length;
    final due = ref.watch(serviceDueProvider);
    final bookings = ref.watch(openBookingsProvider);
    final low = ref.watch(lowStockProvider);
    final pendingTotal = ref.watch(pendingTotalProvider);
    final pendingCount = ref.watch(pendingBalanceProvider).length;
    final money = ref.watch(todayMoneyProvider);
    final rating = ref.watch(averageRatingProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface,
        displacement: 70,
        onRefresh: () async =>
            Future<void>.delayed(const Duration(milliseconds: 600)),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(
                name: garage?.name ?? 'Workshop',
                daysLeft: garage?.daysLeft ?? 0,
                expiry: garage?.planExpiry,
                expiringSoon: garage?.planExpiringSoon ?? false,
                totalCards: total,
                billedToday: money.billed,
                collectedToday: money.collected,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),
            const SliverToBoxAdapter(child: StatusCounters()),

            // --- front desk ------------------------------------------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, Gap.lg, Gap.page, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Entrance(
                        index: 3,
                        child: _DeskCard(
                          title: due.isEmpty
                              ? 'No service due'
                              : '${due.length} service${due.length == 1 ? '' : 's'} due',
                          blurb: due.isEmpty
                              ? 'Nothing on the reminder list today'
                              : 'Follow up with these customers',
                          icon: Icons.event_repeat_rounded,
                          tone: due.isEmpty ? GTone.success : GTone.warning,
                          onTap: () => context.push('/pending?tab=due'),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Entrance(
                        index: 4,
                        child: _DeskCard(
                          title: bookings.isEmpty
                              ? 'No new bookings'
                              : '${bookings.length} new booking${bookings.length == 1 ? '' : 's'}',
                          blurb: bookings.isEmpty
                              ? 'All clear'
                              : 'Waiting to be accepted',
                          icon: Icons.calendar_month_rounded,
                          tone:
                              bookings.isEmpty ? GTone.success : GTone.accent,
                          onTap: () => context.push('/bookings'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- pending balance -------------------------------------
            if (pendingCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.page, Gap.md, Gap.page, 0),
                  child: Entrance(
                    index: 5,
                    child: _PendingBanner(
                      amount: pendingTotal,
                      count: pendingCount,
                      onTap: () => context.push('/pending'),
                    ),
                  ),
                ),
              ),

            // --- the grid --------------------------------------------
            const SliverToBoxAdapter(
              child: GSectionHeader(
                eyebrow: 'Manage',
                title: 'Everything else',
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: Gap.md,
                  crossAxisSpacing: Gap.md,
                  // A fixed extent rather than a ratio, so the tile cannot
                  // overflow on a narrow phone.
                  childAspectRatio: 1,
                  children: [
                    ConsoleTile(
                      title: 'Inventory',
                      blurb: 'Labour, spare and lube master list and stock',
                      icon: Icons.inventory_2_rounded,
                      tone: GTone.info,
                      badge: low.isEmpty ? null : '${low.length} low',
                      onTap: () => context.go('/inventory'),
                    ),
                    ConsoleTile(
                      title: 'Pending balance',
                      blurb: 'Money still to collect across job cards',
                      icon: Icons.account_balance_wallet_rounded,
                      tone: pendingCount > 0 ? GTone.danger : GTone.success,
                      badge: pendingCount > 0 ? '$pendingCount' : null,
                      onTap: () => context.push('/pending'),
                    ),
                    ConsoleTile(
                      title: 'Customers',
                      blurb: 'Every customer, vehicle and visit history',
                      icon: Icons.people_alt_rounded,
                      tone: GTone.accent,
                      onTap: () => context.push('/customers'),
                    ),
                    ConsoleTile(
                      title: 'Reports',
                      blurb: 'Revenue, collection and workshop throughput',
                      icon: Icons.bar_chart_rounded,
                      tone: GTone.ink,
                      onTap: () => context.go('/reports'),
                    ),
                    ConsoleTile(
                      title: 'Bookings',
                      blurb: 'Slot requests coming in from customers',
                      icon: Icons.event_available_rounded,
                      tone: GTone.warning,
                      badge:
                          bookings.isEmpty ? null : '${bookings.length}',
                      onTap: () => context.push('/bookings'),
                    ),
                    ConsoleTile(
                      title: 'Feedback',
                      blurb: rating == 0
                          ? 'Ratings left against closed job cards'
                          : '${rating.toStringAsFixed(1)} average across ${ref.watch(reviewsProvider).length} reviews',
                      icon: Icons.star_rounded,
                      tone: GTone.volt,
                      onTap: () => context.push('/feedback'),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, Gap.xxl, Gap.page, 0),
                child: Entrance(
                  index: 6,
                  child: GCard(
                    onTap: () => showSupportSheet(context),
                    color: p.surfaceAlt,
                    child: Row(
                      children: [
                        Icon(Icons.headset_mic_rounded,
                            size: 20, color: p.inkSoft),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(
                            'Stuck on something? Talk to Balaji Automobiles support',
                            style: AppType.labelM.c(p.ink),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: p.inkFaint, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Clears the floating create button.
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

/// Dark header carrying the workshop identity, the plan countdown and the
/// day's money.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.name,
    required this.daysLeft,
    required this.expiry,
    required this.expiringSoon,
    required this.totalCards,
    required this.billedToday,
    required this.collectedToday,
  });

  final String name;
  final int daysLeft;
  final DateTime? expiry;
  final bool expiringSoon;
  final int totalCards;
  final double billedToday;
  final double collectedToday;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(gradient: p.inverseGradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BlueprintPainter(color: p.onInverse, opacity: 0.06),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.md, Gap.page, Gap.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandBadge(size: 38, onDark: true),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.h1.c(p.onInverse),
                            ),
                            Text(
                              '$totalCards job card${totalCards == 1 ? '' : 's'} on record',
                              style: AppType.bodyS
                                  .c(p.onInverse.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                      Pressable(
                        onTap: () => showSupportSheet(context),
                        scale: 0.9,
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: p.onInverse.withValues(alpha: 0.09),
                            borderRadius: R.all(R.md),
                          ),
                          child: Icon(Icons.headset_mic_rounded,
                              size: 19, color: p.onInverse),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),

                  // Plan countdown — the one thing an owner must not miss.
                  Row(
                    children: [
                      GPill(
                        label: daysLeft <= 0
                            ? 'Plan expired'
                            : '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                        tone: daysLeft <= 0
                            ? GTone.danger
                            : (expiringSoon ? GTone.warning : GTone.success),
                        dot: true,
                        pulse: expiringSoon,
                        compact: true,
                      ),
                      if (expiry != null) ...[
                        const SizedBox(width: Gap.sm),
                        Text(
                          'Expires ${Fmt.date(expiry!)}',
                          style: AppType.labelS
                              .c(p.onInverse.withValues(alpha: 0.55)),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: Gap.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroStat(
                          label: 'Billed today',
                          value: Fmt.money(billedToday),
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                      Container(
                        height: 34,
                        width: 1,
                        color: p.onInverse.withValues(alpha: 0.12),
                      ),
                      Expanded(
                        child: _HeroStat(
                          label: 'Collected today',
                          value: Fmt.money(collectedToday),
                          icon: Icons.payments_rounded,
                          tint: p.volt,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
    this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 13, color: p.onInverse.withValues(alpha: 0.5)),
              const SizedBox(width: 5),
              Text(label.toUpperCase(),
                  style: AppType.over
                      .s(9.5)
                      .c(p.onInverse.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: AppType.money.c(tint ?? p.onInverse)),
        ],
      ),
    );
  }
}

class _DeskCard extends StatelessWidget {
  const _DeskCard({
    required this.title,
    required this.blurb,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String title;
  final String blurb;
  final IconData icon;
  final GTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = toneOf(context, tone);
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration:
                  BoxDecoration(color: t.bg, borderRadius: R.all(R.sm)),
              child: Icon(icon, size: 18, color: t.fg),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelM.c(p.ink)),
                  const SizedBox(height: 1),
                  Text(blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.s(11).c(p.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({
    required this.amount,
    required this.count,
    required this.onTap,
  });

  final double amount;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: Gap.md),
        decoration: BoxDecoration(
          color: p.dangerSoft,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.danger.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded,
                size: 19, color: p.danger),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${Fmt.money(amount)} still to collect',
                      style: AppType.labelL.c(p.danger)),
                  Text(
                    'Across $count job card${count == 1 ? '' : 's'}',
                    style: AppType.bodyS.c(p.danger.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            GButton.ghost(
              label: 'Collect',
              size: GButtonSize.sm,
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
