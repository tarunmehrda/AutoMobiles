import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/repo/attendance_gate.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../shared/sign_out.dart';
import '../shared/support_sheet.dart';
import '../../core/widgets/brand_logo.dart';

class SettingsOptionsPage extends ConsumerWidget {
  const SettingsOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);
    final garage = data.garage;
    final ctrl = ref.read(adminProvider.notifier);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Options'.tr,
        subtitle: 'How the app behaves day to day'.tr,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.sm,
            Gap.page,
            Gap.h2,
          ),
          children: [
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
                        Text(
                          garage?.name ?? 'Workshop'.tr,
                          maxLines: 2,
                          style: AppType.h1.c(p.ink),
                        ),
                        Text(
                          garage?.phone ?? '',
                          style: AppType.bodyS.c(p.inkMuted),
                        ),
                        if (garage?.planExpiry != null) ...[
                          const SizedBox(height: 5),
                          GPill(
                            label: garage!.daysLeft <= 0
                                ? 'Plan expired'.tr
                                : '{0} days left • expires {1}'.trf([
                                    garage.daysLeft,
                                    Fmt.date(garage.planExpiry!),
                                  ]),
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
                  Icon(
                    Icons.chevron_right_rounded,
                    color: p.inkFaint,
                    size: 22,
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Workshop'.tr,
              children: [
                GTile(
                  title: 'Business details'.tr,
                  subtitle: 'Name, address, GSTIN, UPI and bill terms'.tr,
                  icon: Icons.storefront_rounded,
                  iconColor: p.accent,
                  onTap: () => context.push('/workshop'),
                ),
                GTile(
                  title: 'Mechanics'.tr,
                  subtitle: '{0} on the team'.trf([data.staff.length]),
                  icon: Icons.engineering_rounded,
                  iconColor: p.info,
                  onTap: () => context.push('/staff'),
                ),
                GTile(
                  title: 'Attendance'.tr,
                  subtitle: data.attendanceSite == null
                      ? 'No location set — nobody can punch in'.tr
                      : '{0} on the floor · within {1}'.trf([
                          data.onDuty.length,
                          AttendanceGate.metres(data.attendanceSite!.radiusM),
                        ]),
                  icon: Icons.how_to_reg_rounded,
                  iconColor: data.attendanceSite == null
                      ? p.inkFaint
                      : p.success,
                  onTap: () => context.push('/attendance'),
                ),
                GTile(
                  title: 'Contacts'.tr,
                  subtitle: 'Your phone book, with customers marked'.tr,
                  icon: Icons.contacts_rounded,
                  iconColor: p.info,
                  onTap: () => context.push('/contacts'),
                ),
                GTile(
                  title: 'Inventory masters'.tr,
                  subtitle: '{0} labour, spare and lube rows'.trf([
                    data.masters.length,
                  ]),
                  icon: Icons.inventory_2_rounded,
                  iconColor: p.warning,
                  onTap: () => context.push('/inventory'),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Customer messaging'.tr,
              children: [
                // There is no SMS gateway. The switch is the starting point
                // for each card's own SMS switch, and what it turns on is
                // the phone's SMS app opening with the message typed in.
                GTile(
                  title: 'Send SMS updates'.tr,
                  subtitle:
                      'Texts from this phone: your SMS app opens with the message when a card is opened, completed or closed, and you tap Send'
                          .tr,
                  icon: Icons.sms_rounded,
                  iconColor: p.success,
                  showChevron: false,
                  trailing: Switch(
                    value: data.smsEnabled,
                    onChanged: ctrl.setSmsEnabled,
                  ),
                ),
                GTile(
                  title: 'Offer WhatsApp'.tr,
                  subtitle: 'Show WhatsApp alongside call on customer rows'.tr,
                  icon: Icons.chat_rounded,
                  iconColor: p.success,
                  showChevron: false,
                  trailing: Switch(
                    value: data.whatsappEnabled,
                    onChanged: ctrl.setWhatsappEnabled,
                  ),
                ),
                GTile(
                  title: 'Reminder spacing'.tr,
                  subtitle: '{0} days either side of the service date'.trf([
                    data.reminderDaysBefore,
                  ]),
                  icon: Icons.event_repeat_rounded,
                  iconColor: p.info,
                  onTap: () => _reminderSheet(context, ref),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Billing'.tr,
              children: [
                GTile(
                  title: 'Default GST rate'.tr,
                  subtitle: data.defaultTaxRate == 0
                      ? 'No GST on new job cards'.tr
                      : '{0}% applied to new job cards'.trf([
                          (data.defaultTaxRate * 100).toStringAsFixed(0),
                        ]),
                  icon: Icons.percent_rounded,
                  onTap: () => _taxSheet(context, ref),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Appearance'.tr,
              children: [
                GTile(
                  title: 'Theme'.tr,
                  subtitle: switch (data.themeMode) {
                    ThemeMode.light => 'Always light'.tr,
                    ThemeMode.dark => 'Always dark'.tr,
                    ThemeMode.system => 'Follow the device'.tr,
                  },
                  icon: Icons.dark_mode_rounded,
                  onTap: () => _themeSheet(context, ref),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Data'.tr,
              children: [
                GTile(
                  title: 'Clear job cards'.tr,
                  subtitle: 'Keeps the workshop, staff and inventory'.tr,
                  icon: Icons.cleaning_services_rounded,
                  onTap: () async {
                    final ok = await GFeedback.confirm(
                      context,
                      title: 'Clear every job card?'.tr,
                      message:
                          'All job cards, bookings and reviews go. Customers, vehicles and inventory stay.'
                              .tr,
                      confirmLabel: 'Clear'.tr,
                      destructive: true,
                      icon: Icons.cleaning_services_rounded,
                    );
                    if (!ok || !context.mounted) return;
                    ctrl.clearJobCards();
                    GFeedback.success(context, 'Job cards cleared'.tr);
                  },
                ),
                GTile(
                  title: 'Sign out'.tr,
                  subtitle: 'Wipes this device and returns to sign in'.tr,
                  icon: Icons.logout_rounded,
                  iconColor: p.danger,
                  iconBg: p.dangerSoft,
                  onTap: () => confirmSignOut(context, ref),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            GTileGroup(
              title: 'Help'.tr,
              children: [
                GTile(
                  title: 'Contact support'.tr,
                  subtitle: 'WhatsApp or call the Balaji Automobiles team'.tr,
                  icon: Icons.headset_mic_rounded,
                  onTap: () => showSupportSheet(context),
                ),
                GTile(
                  title: 'About'.tr,
                  subtitle:
                      "${AppConfig.appName} ${AppConfig.version} • ${AppConfig.hasSupabase ? 'Cloud sync on' : 'On-device only'}",
                  icon: Icons.info_outline_rounded,
                  onTap: () => context.push('/support'),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            Center(
              child: Text(
                '{0} • v{1}'.trf([AppConfig.appName, AppConfig.version]),
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
      title: 'Theme'.tr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              GOptionRow(
                label: switch (mode) {
                  ThemeMode.system => 'Follow the device'.tr,
                  ThemeMode.light => 'Always light'.tr,
                  ThemeMode.dark => 'Always dark'.tr,
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
      title: 'Default GST'.tr,
      subtitle: 'Applied to new job cards. Existing cards keep their rate.'.tr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final rate in [0.0, 0.05, 0.12, 0.18, 0.28])
              GOptionRow(
                label: rate == 0
                    ? 'No GST'.tr
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
      title: 'Reminder spacing'.tr,
      subtitle: 'Three messages go out: before, on, and after the due date.'.tr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final days in [3, 5, 7, 10])
              GOptionRow(
                label: '{0} days either side'.trf([days]),
                subtitle: 'Reminders at -{0}, 0 and +{1} days'.trf([
                  days,
                  days,
                ]),
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
