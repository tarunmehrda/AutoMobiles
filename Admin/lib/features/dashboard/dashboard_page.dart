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
import '../../data/models/access.dart';
import '../../data/models/attendance.dart';
import '../../features/business/business_drawer.dart';
import '../../features/business/company_sheet.dart';
import '../../features/shared/support_sheet.dart';
import '../../state/auth_state.dart';
import '../../state/providers.dart';
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
/// Reads top to bottom the way the morning does: who you are and which
/// workshop, then the three job-card buckets, then the two things that
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
    final expense = ref.watch(expenseTotalsProvider);
    final online = ref.watch(onlineGarageOnProvider);
    final access = ref.watch(accessProvider);
    final onFloor = ref.watch(onFloorProvider).length;
    final blocked = ref
        .watch(blockedPunchesProvider)
        .where((e) => e.block.isAbuse)
        .length;

    return Scaffold(
      backgroundColor: p.canvas,
      drawer: const BusinessDrawer(),
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
                person: personName(ref.watch(authUserProvider)?.userMetadata),
                name: garage?.name ?? 'Workshop',
                totalCards: total,
                alerts: unread,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),

            // --- 2. The three job-card buckets --------------------------
            const SliverToBoxAdapter(child: StatusCounters()),

            const SliverToBoxAdapter(child: SizedBox(height: Gap.md)),

            // --- 3. The two morning chases ------------------------------
            // Each only for a role that can act on it: a mechanic has no
            // reminders to send and no money to chase.
            if (access.people || access.books)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                  // A Row inside a sliver has no height to stretch its children
                  // to, so the two cards are measured first and then matched.
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (access.people)
                          Expanded(
                            child: Entrance(
                              index: 4,
                              offset: 14,
                              child: _ChaseCard(
                                title: 'Due for Service'.tr,
                                value: '${due.length}',
                                blurb: due.isEmpty
                                    ? ''
                                    : 'Reminders ready to send'.tr,
                                icon: Icons.build_rounded,
                                watermark: Icons.calendar_month_rounded,
                                tone: GTone.accent,
                                onTap: () => context.push('/service-due'),
                              ),
                            ),
                          ),
                        if (access.people && access.books)
                          const SizedBox(width: Gap.md),
                        if (access.books)
                          Expanded(
                            child: Entrance(
                              index: 5,
                              offset: 14,
                              child: _ChaseCard(
                                title: 'Owed to You'.tr,
                                value: Fmt.money(pendingTotal),
                                blurb: pendingCount == 0
                                    ? ''
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
            const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),

            SliverToBoxAdapter(
              child: _ToolMatrix(
                lowStock: low.length,
                bookings: bookings.length,
                online: online,
                expensesDue: expense.pending > 0,
                onFloor: onFloor,
                blockedPunches: blocked,
                access: access,
              ),
            ),

            // --- 5. Trial offer -----------------------------------------
            // The plan is the owner's to buy.
            if (access.isOwner)
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

/// The signed-in person's name from their account, or empty when it has
/// none. Email sign-up stores `full_name`; Google stores `full_name` and
/// `name`.
String personName(Map<String, dynamic>? meta) {
  for (final key in const ['full_name', 'name']) {
    final v = meta?[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

/// The hero: a greeting over the reel, the workshop you are standing in, and
/// the one number that sums the place up.
class _GreetingHero extends StatelessWidget {
  const _GreetingHero({
    required this.person,
    required this.name,
    required this.totalCards,
    required this.alerts,
  });

  /// Who is signed in; empty when the account carries no name.
  final String person;
  final String name;
  final int totalCards;

  /// Anything waiting on the owner. Drives the dot on the bell — a bell with
  /// a permanent dot is a bell nobody presses.
  final int alerts;

  /// Morning, afternoon or evening, from the phone's own clock, to the
  /// person signed in.
  static String greeting(DateTime now, String person) {
    final part = now.hour < 12
        ? 'Morning'
        : now.hour < 17
            ? 'Afternoon'
            : 'Evening';
    return person.isEmpty ? part : '$part, $person';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;

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
                      const _MenuButton(),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // Accounts whose "name" is the workshop's own
                              // would read it twice; the pill below has it.
                              greeting(
                                DateTime.now(),
                                person.toLowerCase() == name.trim().toLowerCase()
                                    ? ''
                                    : person,
                              ),
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

                  // The workshop on the left, the headline count on the right.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _WorkshopPill(name: name),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      _TotalCardsPane(total: totalCards),
                    ],
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

/// Opens the business menu — every part of the workshop, as an index.
class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Scaffold.of(context).openDrawer(),
      scale: 0.9,
      child: Container(
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
        child: const Icon(Icons.menu_rounded, size: 22, color: Colors.white),
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

/// The workshop name: a white lozenge, because on an orange panel white
/// is the one fill that cannot be mistaken for decoration. The name is shown
/// whole, wrapping onto another line rather than being cut short.
class _WorkshopPill extends StatelessWidget {
  const _WorkshopPill({required this.name});

  final String name;

  /// 17px, stepped down until the longest word fits on a line, so a name
  /// wraps between words ("Balaji / Automobiles") and never inside one.
  static TextStyle _fit(String name, double width, BuildContext context) {
    final words = name.split(RegExp(r'\s+'));
    final scaler = MediaQuery.textScalerOf(context);
    for (double size = 17; ; size -= 0.5) {
      final style = AppType.h2
          .s(size)
          .c(const Color(0xFF101418))
          .w(FontWeight.w800);
      if (size <= 12) return style;
      final fits = words.every((w) {
        final tp = TextPainter(
          text: TextSpan(text: w, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final ok = tp.width <= width;
        tp.dispose();
        return ok;
      });
      if (fits) return style;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    // Tapping the name is how the owner of more than one workshop gets to
    // the others — Switch, Manage and Add company.
    return Pressable(
      onTap: () => showCompanySheet(context),
      scale: 0.97,
      child: _pill(context, p),
    );
  }

  Widget _pill(BuildContext context, AppPalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.sm, 7, Gap.sm, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: R.all(R.xl),
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
            child: LayoutBuilder(
              builder: (context, box) =>
                  Text(name, style: _fit(name, box.maxWidth, context)),
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.unfold_more_rounded, size: 18, color: p.inkMuted),
        ],
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
                    'Job Cards'.tr,
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
                ],
              ),
            ),
          ],
        ),
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
            // Low and right, clear of the chevron in the top corner.
            Positioned(
              right: -14,
              bottom: -14,
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
                  Row(
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
                      const Spacer(),
                      _Chevron(tint: t.fg, filled: true),
                    ],
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
                  // No blurb, no row: an empty line here left a blank strip
                  // across the foot of the card whenever nothing was due.
                  if (blurb.isNotEmpty)
                    Text(
                      blurb,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.s(11).c(p.inkMuted),
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

/// The toolbox: every tool this person's role opens, all on show.
class _ToolMatrix extends StatelessWidget {
  const _ToolMatrix({
    required this.lowStock,
    required this.bookings,
    required this.online,
    required this.expensesDue,
    required this.onFloor,
    required this.blockedPunches,
    required this.access,
  });

  final Access access;
  final int lowStock;
  final int bookings;
  final bool online;
  final bool expensesDue;

  /// How many of the team are punched in right now.
  final int onFloor;

  /// Punches refused as faked locations — the only count on this grid that
  /// is bad news rather than volume.
  final int blockedPunches;

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    // Only what this person's role opens. The same rule the router holds
    // the screens to, so a tile never leads somewhere that sends you home.
    // In the order the owner listed them: the day's work first (estimate,
    // job card, stock, people, spend, contacts), then the books (sales,
    // purchase, money), then the reports and the extras.
    final entries = <(String, Widget)>[
      (
        '/estimates',
        ActionTile(
          title: 'Estimate'.tr,
          blurb: 'Jobs, parts & labour'.tr,
          icon: Icons.request_quote_rounded,
          tone: GTone.accent,
          onTap: () => context.push('/estimates'),
        ),
      ),
      (
        '/job/new',
        ActionTile(
          title: 'Create Jobcard'.tr,
          blurb: 'Check a vehicle in'.tr,
          icon: Icons.add_card_rounded,
          tone: GTone.volt,
          onTap: () => context.push('/job/new'),
        ),
      ),
      (
        '/inventory',
        ActionTile(
          title: 'Inventory'.tr,
          blurb: 'Parts & stock levels'.tr,
          icon: Icons.inventory_2_rounded,
          tone: GTone.warning,
          badge: lowStock == 0 ? null : '$lowStock LOW',
          onTap: () => context.push('/inventory'),
        ),
      ),
      (
        '/staff',
        ActionTile(
          title: 'Staff'.tr,
          blurb: 'The team on the floor'.tr,
          icon: Icons.groups_rounded,
          tone: GTone.success,
          onTap: () => context.push('/staff'),
        ),
      ),
      (
        '/attendance',
        ActionTile(
          title: 'Attendance'.tr,
          blurb: onFloor == 0
              ? 'Punch in & out'.tr
              : '{0} on the floor'.trf([onFloor]),
          icon: Icons.how_to_reg_rounded,
          tone: blockedPunches > 0 ? GTone.danger : GTone.info,
          // The badge is the refusals, not the headcount. A number that only
          // ever says "4 people are here" is a number nobody looks at twice;
          // one that says somebody was turned away for a faked location is
          // the reason to open the screen.
          badge: blockedPunches > 0
              ? '$blockedPunches BLOCKED'
              : (onFloor == 0 ? null : '$onFloor'),
          onTap: () => context.push('/attendance'),
        ),
      ),
      (
        '/expenses',
        ActionTile(
          title: 'Expenses'.tr,
          blurb: expensesDue
              ? 'Unpaid invoices'.tr
              : 'Daily shop spend'.tr,
          icon: Icons.receipt_long_rounded,
          tone: expensesDue ? GTone.danger : GTone.accent,
          badge: expensesDue ? 'DUE' : null,
          onTap: () => context.push('/expenses'),
        ),
      ),
      (
        '/contacts',
        ActionTile(
          title: 'Contacts'.tr,
          blurb: 'Your phone book'.tr,
          icon: Icons.contacts_rounded,
          tone: GTone.accent,
          onTap: () => context.push('/contacts'),
        ),
      ),
      (
        '/sales',
        ActionTile(
          title: 'Sales'.tr,
          blurb: 'Invoices, returns, orders'.tr,
          icon: Icons.point_of_sale_rounded,
          tone: GTone.success,
          onTap: () => context.push('/sales'),
        ),
      ),
      (
        '/purchase',
        ActionTile(
          title: 'Purchase'.tr,
          blurb: 'Bills, pay-out, returns'.tr,
          icon: Icons.shopping_cart_rounded,
          tone: GTone.info,
          onTap: () => context.push('/purchase'),
        ),
      ),
      (
        '/bank-accounts',
        ActionTile(
          title: 'Bank & Cash'.tr,
          blurb: 'Accounts & cash in hand'.tr,
          icon: Icons.account_balance_rounded,
          tone: GTone.ink,
          onTap: () => context.push('/bank-accounts'),
        ),
      ),
      (
        '/reports',
        ActionTile(
          title: 'Report'.tr,
          blurb: 'Takings & ledgers'.tr,
          icon: Icons.description_rounded,
          tone: GTone.danger,
          onTap: () => context.push('/reports'),
        ),
      ),
      (
        '/analytics',
        ActionTile(
          title: 'Analytics'.tr,
          blurb: 'Trends and charts'.tr,
          icon: Icons.insights_rounded,
          tone: GTone.info,
          onTap: () => context.push('/analytics'),
        ),
      ),
      // Buy and sell: the part listings and part requests raised in the
      // customer app. The screen itself is the platform back office, and
      // the database still decides what comes back — an account without
      // the `platform` role sees only its own listings, and the pending
      // ones it would review stay invisible.
      (
        '/platform',
        ActionTile(
          title: 'Buy & Sell'.tr,
          blurb: 'Listings & part requests'.tr,
          icon: Icons.storefront_rounded,
          tone: GTone.volt,
          onTap: () => context.push('/platform'),
        ),
      ),
      (
        '/online-garage',
        ActionTile(
          title: 'Online Garage'.tr,
          blurb: online
              ? 'Live & taking orders'.tr
              : 'Shopfront is off'.tr,
          icon: Icons.language_rounded,
          tone: GTone.info,
          badge: online ? 'LIVE' : null,
          onTap: () => context.push('/online-garage'),
        ),
      ),
      (
        '/bookings',
        ActionTile(
          title: 'Appointment'.tr,
          blurb: bookings == 0
              ? 'Diary & requests'.tr
              : '{0} waiting'.trf([bookings]),
          icon: Icons.event_available_rounded,
          tone: GTone.warning,
          badge: bookings == 0 ? null : '$bookings',
          onTap: () => context.push('/bookings'),
        ),
      ),
      (
        '/cashbook',
        ActionTile(
          title: 'CashBook'.tr,
          blurb: 'Cash in & out'.tr,
          icon: Icons.savings_rounded,
          tone: GTone.success,
          onTap: () => context.push('/cashbook'),
        ),
      ),
      (
        '/feedback',
        ActionTile(
          title: 'Feedback'.tr,
          blurb: 'What customers said'.tr,
          icon: Icons.reviews_rounded,
          tone: GTone.warning,
          onTap: () => context.push('/feedback'),
        ),
      ),
      (
        '/grow-business',
        ActionTile(
          title: 'Grow Business'.tr,
          blurb: 'Social media & reviews'.tr,
          icon: Icons.campaign_rounded,
          tone: GTone.accent,
          onTap: () => context.push('/grow-business'),
        ),
      ),
    ];
    final tiles = [
      for (final e in entries)
        if (access.allows(e.$1)) e.$2,
    ];

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
            ],
          ),
          const SizedBox(height: Gap.md),
          // Rows of three, each as tall as its tallest tile. A GridView forced
          // one fixed cell height on every tile — short titles sat on a hole
          // under the glyph — and quietly padded itself by the status and
          // navigation bar insets, which opened a gap above the whole grid.
          for (var r = 0; r < tiles.length; r += 3) ...[
            if (r > 0) const SizedBox(height: Gap.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = r; i < r + 3; i++) ...[
                    if (i > r) const SizedBox(width: Gap.md),
                    Expanded(
                      child: i < tiles.length
                          ? Entrance(
                              index: 6 + i,
                              offset: 14,
                              scaleFrom: 0.94,
                              stagger: const Duration(milliseconds: 40),
                              child: tiles[i],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
