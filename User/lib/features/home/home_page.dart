import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anim/entrance.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_image.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/seed/catalog_seed.dart';
import '../../data/seed/media.dart';
import '../../state/providers.dart';
import '../catalog/widgets/category_tile.dart';
import '../catalog/widgets/package_card.dart';
import '../vehicle/widgets/vehicle_selector.dart';
import '../workshop/widgets/workshop_live_card.dart';
import 'widgets/live_job_card.dart';
import 'widgets/offer_carousel.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final user = ref.watch(userProvider);
    final vehicle = ref.watch(activeVehicleProvider);
    final spotlight = ref.watch(spotlightBookingProvider);
    final workshop = ref.watch(liveWorkshopCardProvider);
    final alerts = ref.watch(dueAlertsProvider);
    final recommended = ref.watch(recommendedProvider);
    final unread = ref.watch(unreadCountProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface,
        displacement: 70,
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 700));
        },
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              name: user?.name ?? '',
              unread: unread,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.md, Gap.page, Gap.lg),
              child: Entrance(
                child: GSearchBar(
                  hint: 'Search services, parts or symptoms',
                  readOnly: true,
                  onTap: () => context.push('/search'),
                ),
              ),
            ),
          ),
          // The workshop's own card outranks a booking: it is the car that
          // is actually on a ramp right now.
          if (workshop != null)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
                child: Entrance(
                  index: 1,
                  child: WorkshopLiveCard(card: workshop),
                ),
              ),
            ),
          if (spotlight != null)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
                child: Entrance(
                  index: 1,
                  child: LiveJobCard(booking: spotlight, vehicle: vehicle),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
                child: Entrance(index: 1, child: const _NoJobCard()),
              ),
            ),
          if (alerts.isNotEmpty)
            SliverToBoxAdapter(
              child: Entrance(index: 2, child: _AlertRail(alerts: alerts)),
            ),

          // --- categories ---------------------------------------------
          SliverToBoxAdapter(
            child: GSectionHeader(
              eyebrow: 'Book a service',
              title: 'What does it need?',
              actionLabel: 'All services',
              onAction: () => context.go('/book'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: Gap.md,
                  crossAxisSpacing: Gap.md,
                  // Fixed extent rather than a ratio: the tile is a known
                  // height, so it can't overflow on a narrow phone.
                  mainAxisExtent: 106,
                ),
                itemCount: 8,
                itemBuilder: (context, i) => CategoryQuickTile(
                  category: categories[i],
                  index: i,
                ),
              ),
            ),
          ),

          // --- recommended --------------------------------------------
          SliverToBoxAdapter(
            child: GSectionHeader(
              eyebrow: vehicle == null ? 'Popular' : 'For your ${vehicle.model}',
              title: 'Recommended next',
              subtitle: vehicle == null
                  ? null
                  : 'Based on ${Fmt.km(vehicle.odometerKm)} and ${DateTime.now().year - vehicle.year} years on the road',
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                itemCount: recommended.length,
                separatorBuilder: (_, _) => const SizedBox(width: Gap.md),
                itemBuilder: (context, i) =>
                    PackageRailCard(package: recommended[i], index: i),
              ),
            ),
          ),

          // --- offers --------------------------------------------------
          SliverToBoxAdapter(
            child: GSectionHeader(
              eyebrow: 'Save more',
              title: 'Offers running now',
              actionLabel: 'See all',
              onAction: () => context.push('/offers'),
            ),
          ),
          const SliverToBoxAdapter(child: OfferCarousel()),

          // --- promise -------------------------------------------------
          const SliverToBoxAdapter(child: _PromiseStrip()),

          SliverToBoxAdapter(
            child: GSectionHeader(
              eyebrow: 'Your workshop',
              title: Seed.garage.name,
            ),
          ),
            const SliverToBoxAdapter(child: _GarageCard()),
            const SliverToBoxAdapter(child: SizedBox(height: Gap.h2)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  const _Header({required this.name, required this.unread});

  final String name;
  final int unread;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final first = name.split(' ').first;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting, style: AppType.bodyS.c(p.inkMuted)),
                      const SizedBox(height: 1),
                      Text(
                        first.isEmpty ? 'Welcome' : first,
                        style: AppType.d3.c(p.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GIconButton(
                  icon: Icons.notifications_none_rounded,
                  badgeCount: unread,
                  onTap: () => context.push('/notifications'),
                ),
                const SizedBox(width: Gap.sm),
                Pressable(
                  onTap: () => context.go('/account'),
                  scale: 0.9,
                  child: GAvatar(
                    initials: Fmt.initials(name.isEmpty ? 'G' : name),
                    size: 42,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                const VehiclePill(),
                const SizedBox(width: Gap.sm),
                Flexible(
                  child: Pressable(
                    onTap: () => GFeedback.info(context,
                        'Serving ${Seed.garage.address.split(',').last.trim()} and ${AppConfig.pickupRadiusKm} km around it'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.place_rounded,
                            size: 15, color: p.inkMuted),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            'Mohali, PB',
                            style: AppType.labelM.c(p.inkMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _NoJobCard extends ConsumerWidget {
  const _NoJobCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final vehicle = ref.watch(activeVehicleProvider);
    final due = vehicle?.daysToService ?? 0;

    return GCard(
      padding: EdgeInsets.zero,
      clip: true,
      onTap: () => context.go('/book'),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: p.isDark ? 0.22 : 0.14,
              child: Image.asset(Media.heroGarage, fit: BoxFit.cover),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [p.surface, p.surface.withValues(alpha: 0.55)],
              ),
            ),
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GPill(
                  label: due <= 0 ? 'SERVICE OVERDUE' : 'NO ACTIVE JOB',
                  tone: due <= 0 ? GTone.danger : GTone.neutral,
                  compact: true,
                ),
                const SizedBox(height: Gap.md),
                Text(
                  vehicle == null
                      ? 'Add a car to get started'
                      : (due <= 0
                          ? 'Your ${vehicle.model} is due a service'
                          : 'Everything is up to date'),
                  style: AppType.h1.c(p.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  vehicle == null
                      ? 'Prices and parts are matched to your exact model.'
                      : (due <= 0
                          ? 'Book a slot and we will collect it from your door.'
                          : 'Next service in $due days. Book early for the slot you want.'),
                  style: AppType.bodyM.c(p.inkMuted),
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    GButton.accent(
                      label: 'Book a service',
                      size: GButtonSize.md,
                      expand: false,
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: () => context.go('/book'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AlertRail extends StatelessWidget {
  const _AlertRail({required this.alerts});

  final List<DueAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.page),
        itemCount: alerts.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, i) {
          final a = alerts[i];
          final tone = a.critical ? p.danger : p.warning;
          final bg = a.critical ? p.dangerSoft : p.warningSoft;
          return Pressable(
            onTap: () => context.push(a.route),
            scale: 0.96,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md, vertical: Gap.sm),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: R.all(R.md),
                border: Border.all(color: tone.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  Icon(a.icon, size: 19, color: tone),
                  const SizedBox(width: Gap.sm),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: AppType.labelM.c(tone)),
                      Text(a.subtitle,
                          style: AppType.labelS
                              .s(10.5)
                              .c(tone.withValues(alpha: 0.8))),
                    ],
                  ),
                  const SizedBox(width: Gap.sm),
                  Icon(Icons.chevron_right_rounded, size: 17, color: tone),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PromiseStrip extends StatelessWidget {
  const _PromiseStrip();

  static const _items = [
    (Icons.verified_user_rounded, 'Genuine parts', 'OEM or OES, always stated upfront'),
    (Icons.how_to_reg_rounded, 'Approve first', 'No extra work without your yes'),
    (Icons.currency_rupee_rounded, 'Estimate = bill', 'The quote is what you pay'),
    (Icons.workspace_premium_rounded, 'Warranty backed', 'Up to 1 year on parts fitted'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.h1, Gap.page, 0),
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surfaceSunken,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('THE GARAGEPRO PROMISE',
                style: AppType.over.c(p.inkFaint)),
            const SizedBox(height: Gap.lg),
            for (var i = 0; i < _items.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_items[i].$1, size: 19, color: p.accentInk),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_items[i].$2, style: AppType.labelM.c(p.ink)),
                        Text(_items[i].$3,
                            style: AppType.bodyS.c(p.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              if (i != _items.length - 1) const SizedBox(height: Gap.lg),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _GarageCard extends StatelessWidget {
  const _GarageCard();

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final g = Seed.garage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: GCard(
        padding: EdgeInsets.zero,
        clip: true,
        child: Column(
          children: [
            Stack(
              children: [
                GImage(
                  url: Media.heroGarage,
                  height: 130,
                  width: double.infinity,
                  radius: 0,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: Gap.lg,
                  right: Gap.lg,
                  bottom: Gap.md,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.name,
                                style: AppType.h2.c(Colors.white)),
                            Text(g.openHours,
                                style: AppType.labelS
                                    .c(Colors.white.withValues(alpha: 0.75))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.sm, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: R.all(R.xs),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 13, color: Color(0xFFFFC53D)),
                            const SizedBox(width: 3),
                            Text('${g.rating}',
                                style: AppType.labelS.c(Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place_outlined, size: 17, color: p.inkMuted),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(g.address,
                            style: AppType.bodyS.c(p.inkMuted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),
                  Row(
                    children: [
                      Expanded(
                        child: GButton.outline(
                          label: 'Call',
                          icon: Icons.call_rounded,
                          expand: true,
                          onPressed: () => _launch('tel:${g.phone}'),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: GButton.outline(
                          label: 'WhatsApp',
                          icon: Icons.chat_rounded,
                          expand: true,
                          onPressed: () =>
                              _launch('https://wa.me/${g.whatsapp}'),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: GButton.outline(
                          label: 'Directions',
                          icon: Icons.navigation_rounded,
                          expand: true,
                          onPressed: () => _launch(
                              'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(g.address)}'),
                        ),
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
