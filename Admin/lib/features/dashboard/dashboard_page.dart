import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/attendance.dart';
import '../../features/shared/support_sheet.dart';
import '../../state/providers.dart';
import 'widgets/account_sheet.dart';
import 'widgets/action_tile.dart';
import 'widgets/status_counters.dart';
import 'widgets/workshop_car_hero.dart';

/// The warm canopy the dashboard opens on, and the colours everything in the
/// hero is measured against.
///
/// One place, because the hero is built out of four separately-painted layers
/// — a gradient, the reel, the reel's scrim, and a pane of frosted glass —
/// and they only read as a single sheet of orange if they are all mixing the
/// same pigment. The ramp is derived from the palette's accent rather than
/// hard-coded, so retinting the app retints the hero with it.
class _Canopy {
  const _Canopy._();

  static Color top(AppPalette p) => Color.lerp(p.accent, Colors.white, 0.10)!;
  static Color mid(AppPalette p) => Color.lerp(p.accent, Colors.black, 0.10)!;
  static Color bottom(AppPalette p) =>
      Color.lerp(p.accent, Colors.black, 0.30)!;

  /// What the footage is graded towards. Deeper than [mid], because a scrim
  /// that only matches the panel leaves the video sitting *on* the orange
  /// instead of *in* it.
  static Color scrim(AppPalette p) => Color.lerp(p.accent, Colors.black, 0.22)!;

  static LinearGradient gradient(AppPalette p) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [top(p), mid(p), bottom(p)],
    stops: const [0.0, 0.55, 1.0],
  );

  /// The hero's bottom-right sweep. The cards below run to a flat top edge,
  /// so the curve is what stops the two halves of the screen from meeting as
  /// a ruled line.
  static const BorderRadius corner = BorderRadius.only(
    bottomRight: Radius.circular(46),
  );
}

/// The workshop dashboard.
///
/// Reads top to bottom the way the morning does: who you are and how long the
/// plan has left, then the three job-card buckets, then the two things that
/// actually need chasing — reminders due and money outstanding — then the
/// tools, then the trial offer.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final garage = ref.watch(garageProvider);
    final total = ref.watch(jobCardsProvider).length;
    final due = ref.watch(serviceDueProvider);
    final bookings = ref.watch(openBookingsProvider);
    // The bell counts the alert feed, not the front desk. An
    // unaccepted booking from last week is still on the Bookings
    // screen and should not keep the dot lit once it has been seen.
    final unread = ref.watch(unreadCountProvider);
    final low = ref.watch(lowStockProvider);
    final pendingTotal = ref.watch(pendingTotalProvider);
    final pendingCount = ref.watch(pendingBalanceProvider).length;
    final rating = ref.watch(averageRatingProvider);
    final reviews = ref.watch(reviewsProvider).length;
    final expense = ref.watch(expenseTotalsProvider);
    final online = ref.watch(onlineGarageOnProvider);
    final onFloor = ref.watch(onFloorProvider).length;
    final blocked = ref
        .watch(blockedPunchesProvider)
        .where((e) => e.block.isAbuse)
        .length;

    return Scaffold(
      backgroundColor: p.canvas,
      body: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface,
        displacement: 70,
        onRefresh: () async =>
            Future<void>.delayed(const Duration(milliseconds: 600)),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // --- 1. The warm canopy -------------------------------------
            SliverToBoxAdapter(
              child: _GreetingHero(
                name: garage?.name ?? 'Workshop',
                daysLeft: garage?.daysLeft ?? 0,
                expiry: garage?.planExpiry,
                expiringSoon: garage?.planExpiringSoon ?? false,
                totalCards: total,
                alerts: unread,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),

            // --- 2. The three job-card buckets --------------------------
            const SliverToBoxAdapter(child: StatusCounters()),

            const SliverToBoxAdapter(child: SizedBox(height: Gap.md)),

            // --- 3. The two morning chases ------------------------------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                // A Row inside a sliver has no height to stretch its children
                // to, so the two cards are measured first and then matched.
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Entrance(
                          index: 4,
                          offset: 14,
                          child: _ChaseCard(
                            title: 'Due for Service'.tr,
                            value: '${due.length}',
                            blurb: due.isEmpty
                                ? 'Nobody to chase today'.tr
                                : 'Reminders ready to send'.tr,
                            icon: Icons.build_rounded,
                            watermark: Icons.calendar_month_rounded,
                            tone: GTone.accent,
                            onTap: () => context.push('/service-due'),
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Entrance(
                          index: 5,
                          offset: 14,
                          child: _ChaseCard(
                            title: 'Owed to You'.tr,
                            value: Fmt.money(pendingTotal),
                            blurb: pendingCount == 0
                                ? 'Books are square'.tr
                                : Tr.plural(
                                    pendingCount,
                                    '{0} invoice open',
                                    '{0} invoices open',
                                  ),
                            icon: Icons.account_balance_wallet_rounded,
                            watermark: Icons.savings_rounded,
                            tone: GTone.success,
                            onTap: () => context.push('/pending'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- 4. The toolbox -----------------------------------------
            const SliverToBoxAdapter(child: SizedBox(height: Gap.xxl + 4)),

            SliverToBoxAdapter(
              child: _ToolMatrix(
                lowStock: low.length,
                bookings: bookings.length,
                online: online,
                expensesDue: expense.pending > 0,
                rating: rating,
                reviews: reviews,
                onFloor: onFloor,
                blockedPunches: blocked,
              ),
            ),

            // --- 5. Trial offer -----------------------------------------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.xl + 4,
                  Gap.page,
                  0,
                ),
                child: Entrance(
                  index: 7,
                  offset: 16,
                  child: const _SuperchargeBanner(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: Gap.h3)),
          ],
        ),
      ),
    );
  }
}

/// The hero: a greeting over the reel, the workshop you are standing in, how
/// long its plan has left, and the one number that sums the place up.
class _GreetingHero extends StatelessWidget {
  const _GreetingHero({
    required this.name,
    required this.daysLeft,
    required this.expiry,
    required this.expiringSoon,
    required this.totalCards,
    required this.alerts,
  });

  final String name;
  final int daysLeft;
  final DateTime? expiry;
  final bool expiringSoon;
  final int totalCards;

  /// Anything waiting on the owner. Drives the dot on the bell — a bell with
  /// a permanent dot is a bell nobody presses.
  final int alerts;

  /// Morning, afternoon or evening, from the phone's own clock.
  static String greeting(DateTime now) {
    if (now.hour < 12) return 'Morning, boss';
    if (now.hour < 17) return 'Afternoon, boss';
    return 'Evening, boss';
  }

  /// The colour of the plan dot: green with room to spare, amber when the
  /// renewal is close, red once it has gone.
  Color _planTint(AppPalette p) {
    if (daysLeft <= 0) return const Color(0xFFFF6B6B);
    if (expiringSoon) return const Color(0xFFFFC53D);
    return const Color(0xFF3DDC84);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final planTint = _planTint(p);

    return ClipRRect(
      borderRadius: _Canopy.corner,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: _Canopy.gradient(p)),
        child: WorkshopCarHero(
          primaryColor: _Canopy.top(p),
          accentColor: p.volt,
          scrimColor: _Canopy.scrim(p),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.sm,
                Gap.page,
                Gap.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting, and the bell.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting(DateTime.now()),
                              style: AppType.d2
                                  .s(27)
                                  .c(Colors.white)
                                  .w(FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Here's the shop at a glance".tr,
                              style: AppType.bodyM
                                  .s(12.5)
                                  .c(Colors.white.withValues(alpha: 0.86)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      _BellButton(alerts: alerts),
                    ],
                  ),

                  const SizedBox(height: Gap.lg),

                  // Identity and plan on the left, the headline count on the
                  // right, so the eye lands on the number without the plan
                  // line having to compete with it.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _WorkshopPill(name: name),
                            const SizedBox(height: Gap.md),
                            Row(
                              children: [
                                Container(
                                  height: 10,
                                  width: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: planTint,
                                    boxShadow: [
                                      BoxShadow(
                                        color: planTint.withValues(alpha: 0.7),
                                        blurRadius: 7,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Gap.sm),
                                Flexible(
                                  child: Text(
                                    daysLeft <= 0
                                        ? 'Plan lapsed'.tr
                                        : Tr.plural(
                                            daysLeft,
                                            '{0} day of cover',
                                            '{0} days of cover',
                                          ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.h2
                                        .s(16)
                                        .c(Colors.white)
                                        .w(FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                            if (expiry != null) ...[
                              const SizedBox(height: Gap.xs + 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_rounded,
                                    size: 15,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Renews {0}'.trf([Fmt.date(expiry!)]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.bodyM
                                          .s(12.5)
                                          .c(
                                            Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      _TotalCardsPane(total: totalCards),
                    ],
                  ),

                  const SizedBox(height: Gap.lg),

                  // The shop's own line, in the corner, the way it would be
                  // painted on the wall above the bay.
                  Align(
                    alignment: Alignment.centerRight,
                    child: _CanopyScript(accent: p.volt),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The notification bell, with a dot only when something is actually waiting.
class _BellButton extends StatelessWidget {
  const _BellButton({required this.alerts});

  final int alerts;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push('/notifications'),
      scale: 0.9,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.32),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              size: 21,
              color: Colors.white,
            ),
          ),
          if (alerts > 0)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                height: 11,
                width: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFC53D),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The workshop switcher: a white lozenge, because on an orange panel white
/// is the one fill that cannot be mistaken for decoration.
class _WorkshopPill extends StatelessWidget {
  const _WorkshopPill({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
        showAccountSheet(context);
      },
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.sm, 7, Gap.md, 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: R.all(R.pill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.12),
                borderRadius: R.all(R.sm),
              ),
              child: Icon(Icons.storefront_rounded, size: 18, color: p.accent),
            ),
            const SizedBox(width: Gap.sm),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppType.h2
                    .s(17)
                    .c(const Color(0xFF101418))
                    .w(FontWeight.w800),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 21,
              color: const Color(0xFF101418).withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

/// The headline count, on smoked glass so the reel keeps showing through it.
class _TotalCardsPane extends StatelessWidget {
  const _TotalCardsPane({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push('/jobs'),
      scale: 0.96,
      child: Container(
        width: 164,
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0F09).withValues(alpha: 0.46),
          borderRadius: R.all(R.md),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: R.all(R.sm),
              ),
              child: const Icon(
                Icons.layers_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cards opened'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelM
                        .s(11.5)
                        .c(Colors.white.withValues(alpha: 0.9))
                        .w(FontWeight.w600),
                  ),
                  AnimatedCount(
                    value: total.toDouble(),
                    builder: (context, v) => Text(
                      v.round().toString(),
                      style: AppType.d1
                          .s(30)
                          .c(Colors.white)
                          .w(FontWeight.w900)
                          .copyWith(height: 1.1),
                    ),
                  ),
                  Text(
                    'Since day one'.tr,
                    style: AppType.bodyS
                        .s(10.5)
                        .c(Colors.white.withValues(alpha: 0.7)),
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

/// The shop's own line, set the way it would be hand-painted on the wall
/// above the bay.
class _CanopyScript extends StatelessWidget {
  const _CanopyScript({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final line = AppType.h3
        .s(17)
        .c(Colors.white.withValues(alpha: 0.95))
        .copyWith(fontStyle: FontStyle.italic, height: 1.05);

    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Every'.tr, style: line),
          Text('Bay'.tr, style: line),
          Text('Earning'.tr, style: line),
          const SizedBox(height: 4),
          Container(
            height: 2.5,
            width: 54,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: R.all(R.pill),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two things worth chasing before lunch.
///
/// The oversized glyph behind the text is deliberately near-invisible: it
/// gives the card a subject at a glance, from across a counter, without
/// stealing a single point of contrast from the number.
class _ChaseCard extends StatelessWidget {
  const _ChaseCard({
    required this.title,
    required this.value,
    required this.blurb,
    required this.icon,
    required this.watermark,
    required this.tone,
    required this.onTap,
  });

  final String title;
  final String value;
  final String blurb;
  final IconData icon;
  final IconData watermark;
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
        decoration: BoxDecoration(
          color: p.isDark
              ? Color.alphaBlend(t.bg.withValues(alpha: 0.5), p.surface)
              : t.bg,
          borderRadius: R.all(R.lg),
          border: Border.all(
            color: t.fg.withValues(alpha: p.isDark ? 0.24 : 0.14),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              top: 6,
              child: Icon(
                watermark,
                size: 92,
                color: t.fg.withValues(alpha: 0.09),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: p.isDark
                          ? t.fg.withValues(alpha: 0.16)
                          : Colors.white,
                      borderRadius: R.all(R.sm),
                      boxShadow: p.isDark
                          ? null
                          : [
                              BoxShadow(
                                color: t.fg.withValues(alpha: 0.14),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Icon(icon, size: 21, color: t.fg),
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.s(13.5).c(p.ink).w(FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.d3.s(26).c(p.ink).w(FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          blurb,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyS.s(11).c(p.inkMuted),
                        ),
                      ),
                      const SizedBox(width: Gap.xs),
                      _Chevron(tint: t.fg, filled: true),
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

/// The small round "go" affordance repeated on every card on this page.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.tint, this.filled = false});

  final Color tint;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      height: 24,
      width: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? tint.withValues(alpha: p.isDark ? 0.22 : 0.14)
            : (p.isDark ? p.surfaceSunken : p.canvas),
      ),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 17,
        color: filled ? tint : p.inkMuted,
      ),
    );
  }
}

/// The toolbox, and the control that decides how much of it is on show.
///
/// Six tiles fit above the fold on a phone; the remaining three are the ones
/// a workshop opens weekly rather than hourly, so they start folded away
/// instead of pushing the trial banner off the bottom of a long scroll.
class _ToolMatrix extends StatefulWidget {
  const _ToolMatrix({
    required this.lowStock,
    required this.bookings,
    required this.online,
    required this.expensesDue,
    required this.rating,
    required this.reviews,
    required this.onFloor,
    required this.blockedPunches,
  });

  final int lowStock;
  final int bookings;
  final bool online;
  final bool expensesDue;
  final double rating;
  final int reviews;

  /// How many of the team are punched in right now.
  final int onFloor;

  /// Punches refused as faked locations — the only count on this grid that
  /// is bad news rather than volume.
  final int blockedPunches;

  @override
  State<_ToolMatrix> createState() => _ToolMatrixState();
}

class _ToolMatrixState extends State<_ToolMatrix> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    final tiles = <Widget>[
      ActionTile(
        title: 'Inventory'.tr,
        blurb: 'Parts & stock levels'.tr,
        icon: Icons.inventory_2_rounded,
        tone: GTone.warning,
        badge: widget.lowStock == 0 ? null : '${widget.lowStock} LOW',
        onTap: () => context.push('/inventory'),
      ),
      ActionTile(
        title: 'Report'.tr,
        blurb: 'Takings & ledgers'.tr,
        icon: Icons.description_rounded,
        tone: GTone.danger,
        onTap: () => context.push('/reports'),
      ),
      ActionTile(
        title: 'Analytics'.tr,
        blurb: 'Trends and charts'.tr,
        icon: Icons.insights_rounded,
        tone: GTone.info,
        onTap: () => context.push('/analytics'),
      ),
      // Buy and sell: the part listings and part requests raised in the
      // customer app. The screen itself is the platform back office, and
      // the database still decides what comes back — an account without
      // the `platform` role sees only its own listings, and the pending
      // ones it would review stay invisible.
      ActionTile(
        title: 'Buy & Sell'.tr,
        blurb: 'Listings & part requests'.tr,
        icon: Icons.storefront_rounded,
        tone: GTone.volt,
        onTap: () => context.push('/platform'),
      ),
      ActionTile(
        title: 'Online Garage'.tr,
        blurb: widget.online
            ? 'Live & taking orders'.tr
            : 'Shopfront is off'.tr,
        icon: Icons.storefront_rounded,
        tone: GTone.info,
        badge: widget.online ? 'LIVE' : null,
        onTap: () => context.push('/online-garage'),
      ),
      ActionTile(
        title: 'Staff'.tr,
        blurb: 'The team on the floor'.tr,
        icon: Icons.groups_rounded,
        tone: GTone.success,
        onTap: () => context.push('/staff'),
      ),
      ActionTile(
        title: 'Attendance'.tr,
        blurb: widget.onFloor == 0
            ? 'Punch in & out'.tr
            : '{0} on the floor'.trf([widget.onFloor]),
        icon: Icons.how_to_reg_rounded,
        tone: widget.blockedPunches > 0 ? GTone.danger : GTone.info,
        // The badge is the refusals, not the headcount. A number that only
        // ever says "4 people are here" is a number nobody looks at twice;
        // one that says somebody was turned away for a faked location is
        // the reason to open the screen.
        badge: widget.blockedPunches > 0
            ? '${widget.blockedPunches} BLOCKED'
            : (widget.onFloor == 0 ? null : '${widget.onFloor}'),
        onTap: () => context.push('/attendance'),
      ),
      ActionTile(
        title: 'Appointment'.tr,
        blurb: widget.bookings == 0
            ? 'Diary & requests'.tr
            : '{0} waiting'.trf([widget.bookings]),
        icon: Icons.event_available_rounded,
        tone: GTone.warning,
        badge: widget.bookings == 0 ? null : '${widget.bookings}',
        onTap: () => context.push('/bookings'),
      ),
      ActionTile(
        title: 'Expenses'.tr,
        blurb: widget.expensesDue
            ? 'Unpaid invoices'.tr
            : 'Daily shop spend'.tr,
        icon: Icons.receipt_long_rounded,
        tone: widget.expensesDue ? GTone.danger : GTone.accent,
        badge: widget.expensesDue ? 'DUE' : null,
        onTap: () => context.push('/expenses'),
      ),
      ActionTile(
        title: 'Feedback'.tr,
        blurb: widget.rating == 0
            ? 'Customer ratings'.tr
            : '{0} verified'.trf([widget.reviews]),
        icon: Icons.star_rounded,
        tone: GTone.warning,
        badge: widget.rating > 0
            ? '★ ${widget.rating.toStringAsFixed(1)}'
            : null,
        onTap: () => context.push('/feedback'),
      ),
      ActionTile(
        title: 'CashBook'.tr,
        blurb: 'Cash in & out'.tr,
        icon: Icons.savings_rounded,
        tone: GTone.success,
        onTap: () => context.push('/cashbook'),
      ),
      ActionTile(
        title: 'Contacts'.tr,
        blurb: 'Your phone book'.tr,
        icon: Icons.contacts_rounded,
        tone: GTone.accent,
        onTap: () => context.push('/contacts'),
      ),
    ];

    final shown = _all ? tiles : tiles.take(6).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Run the shop'.tr,
                      style: AppType.d3.s(21).c(p.ink).w(FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Every tool on one shelf'.tr,
                      style: AppType.bodyS.s(12).c(p.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Pressable(
                onTap: () => setState(() => _all = !_all),
                scale: 0.94,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(Gap.md, 9, Gap.sm + 2, 9),
                  decoration: BoxDecoration(
                    color: p.isDark ? p.surface : Colors.white,
                    borderRadius: R.all(R.pill),
                    border: Border.all(color: p.line),
                    boxShadow: p.isDark ? null : Shadows.soft(p),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _all ? 'Fewer'.tr : 'Show all'.tr,
                        style: AppType.labelM
                            .s(12.5)
                            .c(p.ink)
                            .w(FontWeight.w600),
                      ),
                      const SizedBox(width: 2),
                      AnimatedRotation(
                        turns: _all ? 0.25 : 0,
                        duration: Motion.fast,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 19,
                          color: p.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          // The aspect ratio is derived rather than fixed. A tile's content
          // has a height it simply needs — glyph, two lines of title, two of
          // blurb — and that height does not shrink when the phone does. A
          // constant ratio meant the tiles were 9 pixels short on a 360pt
          // handset, which is most of the cheap Android market.
          LayoutBuilder(
            builder: (context, c) {
              const columns = 3;
              const spacing = Gap.md;
              const needed = 126.0;
              final cell = (c.maxWidth - spacing * (columns - 1)) / columns;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: cell / needed,
                children: shown,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// VIP Supercharge Turbo Pass: high-end metallic card with glowing embers.
class _SuperchargeBanner extends StatelessWidget {
  const _SuperchargeBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    return Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
        showSupportSheet(context);
      },
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: p.isDark
                ? const [
                    Color(0xFF161C26),
                    Color(0xFF221612),
                    Color(0xFF1A1F29),
                  ]
                : const [
                    Color(0xFF181F2C),
                    Color(0xFF261914),
                    Color(0xFF1A2230),
                  ],
          ),
          borderRadius: R.all(R.xl),
          border: Border.all(
            color: p.accent.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: p.accent.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Holographic Ember Icon Pod
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                gradient: p.accentGradient,
                borderRadius: R.all(R.md),
                boxShadow: [
                  BoxShadow(
                    color: p.accent.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '100 DAYS VIP PASS'.tr,
                        style: AppType.over
                            .s(9.5)
                            .c(p.accent)
                            .w(FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: p.volt.withValues(alpha: 0.2),
                          borderRadius: R.all(R.pill),
                        ),
                        child: Text(
                          'BONUS',
                          style: AppType.over.s(8).c(p.volt).w(FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Extend Your Workshop Trial'.tr,
                    style: AppType.labelL
                        .s(14)
                        .c(Colors.white)
                        .w(FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Create unlimited job cards with full telemetry.'.tr,
                    style: AppType.bodyS
                        .s(10.5)
                        .c(Colors.white.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: R.all(R.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Text(
                'CLAIM',
                style: AppType.labelS.s(10).c(Colors.white).w(FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
