import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/anim/entrance.dart';
import '../../core/config/app_config.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/repo/platform_gateway.dart';
import '../../state/providers.dart';
import '../shared/sign_out.dart';
import '../shared/support_sheet.dart';

/// The menu behind the last slot in the bar. It leads with who is signed in,
/// then the handful of things an owner actually reaches for, with the deep
/// settings one level down so they do not crowd the list.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final garage = ref.watch(garageProvider);
    final shareText = ref.watch(onlineShareTextProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.md,
            Gap.page,
            Gap.h2,
          ),
          children: [
            // --- who is signed in -------------------------------------
            Entrance(
              child: Row(
                children: [
                  const BrandBadge(size: 56),
                  const SizedBox(width: Gap.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          garage?.name ?? 'Workshop'.tr,
                          maxLines: 2,
                          style: AppType.h1.s(21).c(p.ink).w(FontWeight.w800),
                        ),
                        Text('Owner'.tr, style: AppType.bodyS.c(p.accentInk)),
                        if ((garage?.email ?? '').isNotEmpty)
                          Text(
                            garage!.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.bodyS.c(p.inkMuted),
                          ),
                        Text(
                          garage?.phone ?? '',
                          style: AppType.bodyS.c(p.inkMuted),
                        ),
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
                children: [
                  GTile(
                    title: 'Home'.tr,
                    subtitle: 'Back to the shop floor'.tr,
                    icon: Icons.dashboard_rounded,
                    iconColor: p.accent,
                    onTap: () => context.go('/home'),
                  ),
                  GTile(
                    title: 'Options'.tr,
                    subtitle: 'How the app behaves day to day'.tr,
                    icon: Icons.tune_rounded,
                    iconColor: p.info,
                    onTap: () => context.push('/settings/options'),
                  ),
                  // The same message the Online Garage screen shares. It used
                  // to be written here separately, with "https://" stuck on
                  // the front of a link that already had it and a promise
                  // that the link tracked a job card, which it did not.
                  // With the shopfront off there is nothing to book, so the
                  // counter is sent to switch it on instead.
                  GTile(
                    title: 'Share'.tr,
                    subtitle: 'Send customers your booking link'.tr,
                    icon: Icons.ios_share_rounded,
                    iconColor: p.success,
                    onTap: () {
                      if (shareText.isEmpty) {
                        GFeedback.toast(
                          context,
                          'Switch on Online Garage first, so customers can find and book you.'
                              .tr,
                          icon: Icons.storefront_rounded,
                          actionLabel: 'Open'.tr,
                          onAction: () => context.push('/online-garage'),
                          duration: const Duration(seconds: 5),
                        );
                        return;
                      }
                      SharePlus.instance.share(ShareParams(text: shareText));
                    },
                  ),
                  GTile(
                    title: 'Language'.tr,
                    subtitle: 'View the app in your language'.tr,
                    icon: Icons.translate_rounded,
                    iconColor: p.info,
                    onTap: () => context.push('/settings/language'),
                  ),
                  GTile(
                    title: 'Greetings & Offers'.tr,
                    subtitle: 'What goes out on a festival or a birthday'.tr,
                    icon: Icons.card_giftcard_rounded,
                    iconColor: p.warning,
                    onTap: () => context.push('/settings/greetings'),
                  ),
                  GTile(
                    title: 'Commission'.tr,
                    subtitle: 'What this workshop owes the platform'.tr,
                    icon: Icons.percent_rounded,
                    iconColor: p.warning,
                    onTap: () => context.push('/settings/commission'),
                  ),
                  // Only for the account that runs the register. Everybody
                  // else never learns the section exists — and if they
                  // reached it by URL, every list would come back empty
                  // because the database, not this line, is the guard.
                  if (ref.watch(isPlatformAdminProvider).valueOrNull ?? false)
                    GTile(
                      title: 'Platform',
                      subtitle: 'Partners, requests, listings',
                      icon: Icons.hub_rounded,
                      iconColor: p.accent,
                      onTap: () => context.push('/platform'),
                    ),
                  GTile(
                    title: 'Help & Support'.tr,
                    subtitle: 'Reach a human, or read the answers'.tr,
                    icon: Icons.headset_mic_rounded,
                    iconColor: p.accent,
                    onTap: () => showSupportSheet(context),
                  ),
                  GTile(
                    title: 'Privacy Policy'.tr,
                    subtitle: 'What this app keeps, and where'.tr,
                    icon: Icons.privacy_tip_rounded,
                    iconColor: p.inkMuted,
                    onTap: () => context.push('/settings/privacy'),
                  ),
                  // Reachable rather than buried: most of the vehicle
                  // photography is CC BY or CC BY-SA, and naming the
                  // photographer is a condition of those licences.
                  GTile(
                    title: 'Image credits'.tr,
                    subtitle: 'Who took the photographs in this app'.tr,
                    icon: Icons.photo_library_rounded,
                    iconColor: p.inkMuted,
                    onTap: () => context.push('/settings/credits'),
                  ),
                  GTile(
                    title: 'Sign Out'.tr,
                    subtitle: 'Clears everything on this device'.tr,
                    icon: Icons.logout_rounded,
                    iconColor: p.danger,
                    onTap: () => confirmSignOut(context, ref),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.xxl),
            Center(
              child: Text(
                'App Version: {0}'.trf([AppConfig.version]),
                style: AppType.labelS.c(p.inkFaint),
              ),
            ),
            const SizedBox(height: Gap.md),
            Container(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
              decoration: BoxDecoration(
                color: p.successSoft,
                borderRadius: R.all(R.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_rounded, size: 17, color: p.success),
                  const SizedBox(width: Gap.sm),
                  Text(
                    '100% Safe and Secure'.tr,
                    style: AppType.labelL.c(p.success),
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
