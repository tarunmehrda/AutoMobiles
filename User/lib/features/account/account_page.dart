import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/anim/entrance.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import '../workshop/widgets/link_workshop_sheet.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final user = ref.watch(userProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final bookings = ref.watch(bookingsProvider);
    final addresses = ref.watch(addressesProvider);
    final stats = ref.watch(garageStatsProvider);
    final workshopCount = ref.watch(workshopCardsProvider).length;
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: CustomScrollView(
        slivers: [
          const GSliverHeader(title: 'Account'),

          // --- profile --------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
              child: Entrance(
                child: GCard(
                  onTap: () => context.push('/profile'),
                  child: Row(
                    children: [
                      GAvatar(
                        initials: Fmt.initials(user?.name ?? 'G'),
                        size: 56,
                        tone: GTone.accent,
                      ),
                      const SizedBox(width: Gap.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? 'Guest',
                                style: AppType.h1.c(p.ink),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(user?.phone ?? '',
                                style: AppType.bodyM.c(p.inkMuted)),
                            if (user?.email != null)
                              Text(user!.email!,
                                  style: AppType.bodyS.c(p.inkFaint),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.inkFaint),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- referral -------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
              child: Entrance(
                index: 1,
                child: _ReferralCard(code: user?.referralCode ?? 'GARAGE'),
              ),
            ),
          ),

          // --- quick grid ------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
              child: Entrance(
                index: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickTile(
                        icon: Icons.garage_rounded,
                        value: '${vehicles.length}',
                        label: 'Vehicles',
                        onTap: () => context.go('/garage'),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _QuickTile(
                        icon: Icons.receipt_long_rounded,
                        value: '${bookings.length}',
                        label: 'Bookings',
                        onTap: () => context.push('/bookings'),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _QuickTile(
                        icon: Icons.savings_rounded,
                        value: Fmt.money(stats.saved),
                        label: 'Saved',
                        onTap: () => context.push('/offers'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- account group ----------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.lg),
              child: GTileGroup(
                title: 'Your account',
                children: [
                  GTile(
                    title: 'Profile',
                    subtitle: 'Name, email, date of birth',
                    icon: Icons.person_outline_rounded,
                    onTap: () => context.push('/profile'),
                  ),
                  GTile(
                    title: 'My vehicles',
                    subtitle: '${vehicles.length} in your garage',
                    icon: Icons.directions_car_outlined,
                    onTap: () => context.go('/garage'),
                  ),
                  GTile(
                    title: 'Link your workshop',
                    subtitle: workshopCount == 0
                        ? 'Enter the code from the counter'
                        : '$workshopCount job card'
                            '${workshopCount == 1 ? '' : 's'} from the workshop',
                    icon: Icons.handyman_outlined,
                    onTap: () => LinkWorkshopSheet.open(context),
                  ),
                  GTile(
                    title: 'Service history',
                    subtitle: '${stats.services} completed jobs',
                    icon: Icons.history_rounded,
                    onTap: () => context.push('/history'),
                  ),
                  GTile(
                    title: 'Addresses',
                    subtitle: addresses.isEmpty
                        ? 'Add a pickup address'
                        : '${addresses.length} saved',
                    icon: Icons.place_outlined,
                    onTap: () => context.push('/addresses'),
                  ),
                  GTile(
                    title: 'Offers & coupons',
                    subtitle: 'See what you can save on',
                    icon: Icons.local_offer_outlined,
                    onTap: () => context.push('/offers'),
                  ),
                ],
              ),
            ),
          ),

          // --- preferences -------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
              child: GTileGroup(
                title: 'Preferences',
                children: [
                  GTile(
                    title: 'Notifications',
                    subtitle: unread == 0
                        ? 'All caught up'
                        : '$unread unread',
                    icon: Icons.notifications_none_rounded,
                    trailing: unread == 0
                        ? null
                        : GPill(label: '$unread', tone: GTone.accent, compact: true),
                    onTap: () => context.push('/notifications'),
                  ),
                  GTile(
                    title: 'App settings',
                    subtitle: 'Theme, alerts and data',
                    icon: Icons.tune_rounded,
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
          ),

          // --- support -----------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
              child: GTileGroup(
                title: 'Support & legal',
                children: [
                  GTile(
                    title: 'Help centre',
                    subtitle: 'FAQs and guides',
                    icon: Icons.help_outline_rounded,
                    onTap: () => context.push('/help'),
                  ),
                  GTile(
                    title: 'Complaints & tickets',
                    icon: Icons.support_agent_rounded,
                    onTap: () => context.push('/tickets'),
                  ),
                  GTile(
                    title: 'Terms of service',
                    icon: Icons.gavel_rounded,
                    onTap: () => _legal(context, 'Terms of service'),
                  ),
                  GTile(
                    title: 'Privacy policy',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () => _legal(context, 'Privacy policy'),
                  ),
                ],
              ),
            ),
          ),

          // --- sign out ------------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
              child: GButton(
                label: 'Log out',
                kind: GButtonKind.danger,
                icon: Icons.logout_rounded,
                onPressed: () async {
                  final ok = await GFeedback.confirm(
                    context,
                    title: 'Log out?',
                    message:
                        'Your bookings and history stay safe against your phone '
                        'number. Sign back in any time.',
                    confirmLabel: 'Log out',
                    destructive: true,
                    icon: Icons.logout_rounded,
                  );
                  if (!ok || !context.mounted) return;
                  await ref.read(appControllerProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h3),
              child: Column(
                children: [
                  Text('${AppConfig.appName} v${AppConfig.version}',
                      style: AppType.labelS.c(p.inkFaint)),
                  const SizedBox(height: 2),
                  Text(
                    AppConfig.hasSupabase
                        ? 'Connected to your workshop backend'
                        : 'Running on this device — backend not connected yet',
                    style: AppType.labelS.s(10).c(p.inkFaint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _legal(BuildContext context, String title) {
    GFeedback.sheet<void>(
      context,
      title: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: SingleChildScrollView(
          child: Text(
            title == 'Privacy policy'
                ? 'We collect only what is needed to service your vehicle: your name, '
                    'mobile number, optional email, vehicle details and the addresses you '
                    'save for pickup.\n\n'
                    'Your data is shared with the workshop handling your booking and with '
                    'the payment gateway when you pay. It is never sold.\n\n'
                    'Inspection photos and job records are kept as part of your vehicle '
                    'history so future technicians can see what was done before.\n\n'
                    'You can request deletion of your account at any time from Support; '
                    'invoices are retained for the period tax law requires.'
                : 'These terms cover your use of the app and any service you book through it.\n\n'
                    'Quoted prices are estimates based on the vehicle details you provide. '
                    'The final invoice may differ only for work you have explicitly approved '
                    'in the app.\n\n'
                    'No chargeable work beyond the booked package begins without your '
                    'recorded approval. Every approval is timestamped.\n\n'
                    'Warranty on parts and labour is as stated on each package and on your '
                    'invoice. Consumables and wear items are excluded.\n\n'
                    'Bookings can be cancelled free of charge until the vehicle is received '
                    'at the workshop.',
            style: AppType.bodyM.c(context.c.inkSoft),
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
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
            Icon(icon, size: 20, color: p.inkMuted),
            const SizedBox(height: Gap.sm),
            Text(value,
                style: AppType.money.s(15).c(p.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label.toUpperCase(),
                style: AppType.over.s(8.5).c(p.inkFaint)),
          ],
        ),
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(
        gradient: p.inverseGradient,
        borderRadius: R.all(R.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BlueprintPainter(
                  color: p.onInverse, spacing: 20, opacity: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded,
                        size: 18, color: p.volt),
                    const SizedBox(width: Gap.sm),
                    Text('REFER & EARN',
                        style: AppType.over.c(p.volt)),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Text('Give ₹500, get ₹500',
                    style: AppType.d3.s(20).c(p.onInverse)),
                const SizedBox(height: 3),
                Text(
                  'They save on their first service, you get credit on your next one.',
                  style:
                      AppType.bodyS.c(p.onInverse.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md, vertical: Gap.md),
                        decoration: BoxDecoration(
                          color: p.onInverse.withValues(alpha: 0.08),
                          borderRadius: R.all(R.sm),
                          border: Border.all(
                              color: p.onInverse.withValues(alpha: 0.14)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(code,
                                  style: AppType.money
                                      .c(p.onInverse)
                                      .copyWith(letterSpacing: 1.4)),
                            ),
                            Pressable(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: code));
                                GFeedback.toast(context, 'Referral code copied',
                                    icon: Icons.content_copy_rounded);
                              },
                              child: Icon(Icons.content_copy_rounded,
                                  size: 17, color: p.onInverse),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    GButton(
                      label: 'Share',
                      kind: GButtonKind.volt,
                      size: GButtonSize.md,
                      expand: false,
                      icon: Icons.ios_share_rounded,
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(
                          text:
                              'I use Balaji Automobiles for my car service — transparent estimates, '
                              'photos from the workshop and no surprise bills. Use my code '
                              '$code and we both get ₹500 off.',
                        ),
                      ),
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
