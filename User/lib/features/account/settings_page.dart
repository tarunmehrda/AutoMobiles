import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../state/app_state.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final data = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: const GHeader(title: 'App settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          Entrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('APPEARANCE', style: AppType.over.c(p.inkFaint)),
                const SizedBox(height: Gap.sm),
                GCard(
                  child: Row(
                    children: [
                      for (final mode in ThemeMode.values) ...[
                        Expanded(
                          child: _ThemeOption(
                            mode: mode,
                            selected: data.themeMode == mode,
                            onTap: () => controller.setThemeMode(mode),
                          ),
                        ),
                        if (mode != ThemeMode.values.last)
                          const SizedBox(width: Gap.sm),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.xl),
          Entrance(
            index: 1,
            child: GTileGroup(
              title: 'Notifications',
              children: [
                _SwitchTile(
                  title: 'Push notifications',
                  subtitle: 'Job updates, approvals and reminders',
                  icon: Icons.notifications_active_rounded,
                  value: data.pushEnabled,
                  onChanged: (v) => controller.setPrefs(push: v),
                ),
                _SwitchTile(
                  title: 'WhatsApp updates',
                  subtitle: 'Status messages on ${data.user?.phone ?? 'your number'}',
                  icon: Icons.chat_rounded,
                  value: data.whatsappEnabled,
                  onChanged: (v) => controller.setPrefs(whatsapp: v),
                ),
                _SwitchTile(
                  title: 'Email',
                  subtitle: 'Invoices and receipts',
                  icon: Icons.mail_rounded,
                  value: data.emailEnabled,
                  onChanged: (v) => controller.setPrefs(email: v),
                ),
                _SwitchTile(
                  title: 'Service reminders',
                  subtitle: 'Due by date, mileage, insurance and PUC',
                  icon: Icons.event_repeat_rounded,
                  value: data.serviceRemindersEnabled,
                  onChanged: (v) => controller.setPrefs(reminders: v),
                ),
                _SwitchTile(
                  title: 'Offers & promotions',
                  subtitle: 'Seasonal discounts and coupons',
                  icon: Icons.local_offer_rounded,
                  value: data.offersEnabled,
                  onChanged: (v) => controller.setPrefs(offers: v),
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.xl),
          Entrance(
            index: 2,
            child: GTileGroup(
              title: 'Data',
              children: [
                GTile(
                  title: 'Clear notifications',
                  subtitle: '${data.notifications.length} stored',
                  icon: Icons.clear_all_rounded,
                  showChevron: false,
                  onTap: () {
                    controller.clearNotifications();
                    GFeedback.info(context, 'Notifications cleared');
                  },
                ),
                GTile(
                  title: 'Clear search history',
                  subtitle: '${data.recentSearches.length} recent searches',
                  icon: Icons.history_toggle_off_rounded,
                  showChevron: false,
                  onTap: () {
                    controller.clearSearches();
                    GFeedback.info(context, 'Search history cleared');
                  },
                ),
                GTile(
                  title: 'Reset sample data',
                  subtitle:
                      'Restore the demo bookings, inspection and invoices',
                  icon: Icons.restore_rounded,
                  showChevron: false,
                  onTap: () {
                    controller.restoreDemoData();
                    GFeedback.success(context, 'Sample data restored');
                  },
                ),
                GTile(
                  title: 'Remove sample data',
                  subtitle: 'Keeps your account and vehicles',
                  icon: Icons.delete_sweep_rounded,
                  iconColor: p.danger,
                  showChevron: false,
                  onTap: () async {
                    final ok = await GFeedback.confirm(
                      context,
                      title: 'Remove sample data?',
                      message:
                          'The demo bookings, inspection report and invoices '
                          'will be deleted. Your account and vehicles stay.',
                      confirmLabel: 'Remove',
                      destructive: true,
                      icon: Icons.delete_sweep_rounded,
                    );
                    if (!ok || !context.mounted) return;
                    controller.clearDemoData();
                    GFeedback.info(context, 'Sample data removed');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.xl),
          Entrance(
            index: 3,
            child: GCard(
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppConfig.hasSupabase
                          ? p.successSoft
                          : p.warningSoft,
                      borderRadius: R.all(R.sm),
                    ),
                    child: Icon(
                      AppConfig.hasSupabase
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      size: 20,
                      color:
                          AppConfig.hasSupabase ? p.success : p.warning,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConfig.hasSupabase
                              ? 'Backend connected'
                              : 'Running on this device',
                          style: AppType.labelL.c(p.ink),
                        ),
                        Text(
                          AppConfig.hasSupabase
                              ? 'Bookings sync with the workshop in real time'
                              : 'Everything works offline. Add Supabase keys to sync '
                                  'with the workshop.',
                          style: AppType.bodyS.c(p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Gap.xl),
          Entrance(
            index: 4,
            child: GTileGroup(
              title: 'About',
              children: [
                GTile(
                  title: 'Version',
                  subtitle: '${AppConfig.appName} ${AppConfig.version}',
                  icon: Icons.info_outline_rounded,
                  showChevron: false,
                ),
                GTile(
                  title: 'Help centre',
                  icon: Icons.help_outline_rounded,
                  onTap: () => context.push('/help'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  (String, IconData) get _meta => switch (mode) {
        ThemeMode.system => ('System', Icons.brightness_auto_rounded),
        ThemeMode.light => ('Light', Icons.light_mode_rounded),
        ThemeMode.dark => ('Dark', Icons.dark_mode_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surfaceSunken,
          borderRadius: R.all(R.md),
          border: Border.all(color: selected ? p.accent : p.line),
        ),
        child: Column(
          children: [
            Icon(_meta.$2,
                size: 20, color: selected ? p.accentInk : p.inkMuted),
            const SizedBox(height: 6),
            Text(_meta.$1,
                style: AppType.labelM
                    .c(selected ? p.accentInk : p.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showChevron: false,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
