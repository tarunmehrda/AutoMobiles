import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/repo/auth_service.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../shared/support_sheet.dart';
import '../../core/widgets/brand_logo.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);
    final garage = data.garage;
    final ctrl = ref.read(adminProvider.notifier);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 110),
          children: [
            Text('Settings', style: AppType.d2.c(p.ink)),
            const SizedBox(height: Gap.lg),

            // --- the workshop ------------------------------------------
            GCard(
              onTap: () => context.push('/workshop'),
              child: Row(
                children: [
                  const BrandBadge(size: 44),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(garage?.name ?? 'Workshop',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.h1.c(p.ink)),
                        Text(garage?.phone ?? '',
                            style: AppType.bodyS.c(p.inkMuted)),
                        if (garage?.planExpiry != null) ...[
                          const SizedBox(height: 5),
                          GPill(
                            label: garage!.daysLeft <= 0
                                ? 'Plan expired'
                                : '${garage.daysLeft} days left • '
                                    'expires ${Fmt.date(garage.planExpiry!)}',
                            tone: garage.daysLeft <= 0
                                ? GTone.danger
                                : garage.planExpiringSoon
                                    ? GTone.warning
                                    : GTone.success,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: p.inkFaint, size: 22),
                ],
              ),
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Workshop',
              children: [
                GTile(
                  title: 'Business details',
                  subtitle: 'Name, address, GSTIN, UPI and bill terms',
                  icon: Icons.storefront_rounded,
                  onTap: () => context.push('/workshop'),
                ),
                GTile(
                  title: 'Mechanics',
                  subtitle: '${data.staff.length} on the team',
                  icon: Icons.engineering_rounded,
                  onTap: () => context.push('/staff'),
                ),
                GTile(
                  title: 'Inventory masters',
                  subtitle: '${data.masters.length} labour, spare and lube '
                      'rows',
                  icon: Icons.inventory_2_rounded,
                  onTap: () => context.go('/inventory'),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Customer messaging',
              children: [
                GTile(
                  title: 'Send SMS updates',
                  subtitle: 'Job card opened, work complete, invoice closed',
                  icon: Icons.sms_rounded,
                  showChevron: false,
                  trailing: Switch(
                    value: data.smsEnabled,
                    onChanged: ctrl.setSmsEnabled,
                  ),
                ),
                GTile(
                  title: 'Offer WhatsApp',
                  subtitle: 'Show WhatsApp alongside call on customer rows',
                  icon: Icons.chat_rounded,
                  showChevron: false,
                  trailing: Switch(
                    value: data.whatsappEnabled,
                    onChanged: ctrl.setWhatsappEnabled,
                  ),
                ),
                GTile(
                  title: 'Reminder spacing',
                  subtitle:
                      '${data.reminderDaysBefore} days either side of the '
                      'service date',
                  icon: Icons.event_repeat_rounded,
                  onTap: () => _reminderSheet(context, ref),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Billing',
              children: [
                GTile(
                  title: 'Default GST rate',
                  subtitle: data.defaultTaxRate == 0
                      ? 'No GST on new job cards'
                      : '${(data.defaultTaxRate * 100).toStringAsFixed(0)}% '
                          'applied to new job cards',
                  icon: Icons.percent_rounded,
                  onTap: () => _taxSheet(context, ref),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Appearance',
              children: [
                GTile(
                  title: 'Theme',
                  subtitle: switch (data.themeMode) {
                    ThemeMode.light => 'Always light',
                    ThemeMode.dark => 'Always dark',
                    ThemeMode.system => 'Follow the device',
                  },
                  icon: Icons.dark_mode_rounded,
                  onTap: () => _themeSheet(context, ref),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Data',
              children: [
                GTile(
                  title: 'Clear job cards',
                  subtitle: 'Keeps the workshop, staff and inventory',
                  icon: Icons.cleaning_services_rounded,
                  onTap: () async {
                    final ok = await GFeedback.confirm(
                      context,
                      title: 'Clear every job card?',
                      message:
                          'All job cards, bookings and reviews go. Customers, '
                          'vehicles and inventory stay.',
                      confirmLabel: 'Clear',
                      destructive: true,
                      icon: Icons.cleaning_services_rounded,
                    );
                    if (!ok || !context.mounted) return;
                    ctrl.clearJobCards();
                    GFeedback.success(context, 'Job cards cleared');
                  },
                ),
                GTile(
                  title: 'Sign out',
                  subtitle: 'Wipes this device and returns to sign in',
                  icon: Icons.logout_rounded,
                  iconColor: p.danger,
                  iconBg: p.dangerSoft,
                  onTap: () async {
                    final ok = await GFeedback.confirm(
                      context,
                      title: 'Sign out?',
                      message:
                          'Everything on this device is cleared. With no '
                          'backend configured, there is no copy elsewhere.',
                      confirmLabel: 'Sign out',
                      destructive: true,
                      icon: Icons.logout_rounded,
                    );
                    if (!ok || !context.mounted) return;
                    await ref.read(authServiceProvider).signOut();
                    await localStore.clear();
                    ctrl.signOut();
                  },
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Help',
              children: [
                GTile(
                  title: 'Contact support',
                  subtitle: 'WhatsApp or call the Balaji Automobiles team',
                  icon: Icons.headset_mic_rounded,
                  onTap: () => showSupportSheet(context),
                ),
                GTile(
                  title: 'About',
                  subtitle:
                      '${AppConfig.appName} ${AppConfig.version} • '
                      '${AppConfig.hasSupabase ? 'Cloud sync on' : 'On-device only'}',
                  icon: Icons.info_outline_rounded,
                  onTap: () => context.push('/support'),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            Center(
              child: Text(
                '${AppConfig.appName} • v${AppConfig.version}',
                style: AppType.labelS.c(p.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _themeSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(adminProvider).themeMode;
    GFeedback.sheet<void>(
      context,
      title: 'Theme',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              GOptionRow(
                label: switch (mode) {
                  ThemeMode.system => 'Follow the device',
                  ThemeMode.light => 'Always light',
                  ThemeMode.dark => 'Always dark',
                },
                icon: switch (mode) {
                  ThemeMode.system => Icons.brightness_auto_rounded,
                  ThemeMode.light => Icons.light_mode_rounded,
                  ThemeMode.dark => Icons.dark_mode_rounded,
                },
                selected: current == mode,
                onTap: () {
                  ref.read(adminProvider.notifier).setThemeMode(mode);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _taxSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(adminProvider).defaultTaxRate;
    GFeedback.sheet<void>(
      context,
      title: 'Default GST',
      subtitle: 'Applied to new job cards. Existing cards keep their rate.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final rate in [0.0, 0.05, 0.12, 0.18, 0.28])
              GOptionRow(
                label: rate == 0
                    ? 'No GST'
                    : '${(rate * 100).toStringAsFixed(0)}%',
                selected: (current - rate).abs() < 0.001,
                onTap: () {
                  ref.read(adminProvider.notifier).setDefaultTaxRate(rate);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _reminderSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(adminProvider).reminderDaysBefore;
    GFeedback.sheet<void>(
      context,
      title: 'Reminder spacing',
      subtitle: 'Three messages go out: before, on, and after the due date.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final days in [3, 5, 7, 10])
              GOptionRow(
                label: '$days days either side',
                subtitle: 'Reminders at -$days, 0 and +$days days',
                selected: current == days,
                onTap: () {
                  ref.read(adminProvider.notifier).setReminderDays(days);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
