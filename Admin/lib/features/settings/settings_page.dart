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
import '../../state/auth_state.dart';
import '../../state/providers.dart';
import '../business/business_drawer.dart' show rateApp;
import '../business/company_sheet.dart';
import '../shared/delete_account.dart';
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
    final access = ref.watch(accessProvider);
    // Staff sign in with their own email, so that is the one to show them;
    // the workshop's email is the owner's.
    final signedInAs = access.isOwner
        ? (garage?.email ?? '')
        : (ref.watch(authUserProvider)?.email ?? '');

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
                        Text(
                          access.role.label,
                          style: AppType.bodyS.c(p.accentInk),
                        ),
                        if (signedInAs.isNotEmpty)
                          Text(
                            signedInAs,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.bodyS.c(p.inkMuted),
                          ),
                        if (access.isOwner)
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
                    title: 'Switch or add company'.tr,
                    subtitle: 'Your other workshops on this phone'.tr,
                    icon: Icons.swap_horiz_rounded,
                    iconColor: p.accent,
                    onTap: () => showCompanySheet(context),
                  ),
                  if (access.allows('/bank-accounts'))
                    GTile(
                      title: 'Bank & Cash'.tr,
                      subtitle: 'Accounts, cash in hand, invoice bank details'
                          .tr,
                      icon: Icons.account_balance_rounded,
                      iconColor: p.success,
                      onTap: () => context.push('/bank-accounts'),
                    ),
                  if (access.allows('/settings/sync-share'))
                    GTile(
                      title: 'Sync & Share'.tr,
                      subtitle: 'Staff access and more devices'.tr,
                      icon: Icons.sync_rounded,
                      iconColor: p.info,
                      onTap: () => context.push('/settings/sync-share'),
                    ),
                  if (access.workshopSettings)
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
                          actionLabel: access.workshopSettings
                              ? 'Open'.tr
                              : null,
                          onAction: access.workshopSettings
                              ? () => context.push('/online-garage')
                              : null,
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
                  // Moved here from the home grid.
                  if (access.allows('/feedback'))
                    GTile(
                      title: 'Feedback'.tr,
                      subtitle: 'Customer ratings'.tr,
                      icon: Icons.star_rounded,
                      iconColor: p.warning,
                      onTap: () => context.push('/feedback'),
                    ),
                  if (access.allows('/settings/greetings'))
                    GTile(
                      title: 'Greetings & Offers'.tr,
                      subtitle: 'What goes out on a festival or a birthday'.tr,
                      icon: Icons.card_giftcard_rounded,
                      iconColor: p.warning,
                      onTap: () => context.push('/settings/greetings'),
                    ),
                  if (access.isOwner)
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
                  if (ref.watch(isPlatformAdminProvider).valueOrNull ??
                      false) ...[
                    GTile(
                      title: 'Platform',
                      subtitle: 'Partners, media, heads',
                      icon: Icons.hub_rounded,
                      iconColor: p.accent,
                      onTap: () => context.push('/platform/admin'),
                    ),
                    GTile(
                      title: 'Media',
                      subtitle: 'The welcome video both apps play',
                      icon: Icons.play_circle_outline_rounded,
                      iconColor: p.info,
                      onTap: () => context.push('/platform/admin?tab=media'),
                    ),
                  ],
                  GTile(
                    title: 'Grow your business'.tr,
                    subtitle: 'Social media, reviews and offers'.tr,
                    icon: Icons.campaign_rounded,
                    iconColor: p.accent,
                    onTap: () => context.push('/grow-business'),
                  ),
                  GTile(
                    title: 'Rate this app'.tr,
                    subtitle: 'Tell us how we are doing on the Play Store'.tr,
                    icon: Icons.star_rate_rounded,
                    iconColor: const Color(0xFFF2B01E),
                    onTap: () => rateApp(context),
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
                  if (AppConfig.hasSupabase)
                    GTile(
                      title: 'Delete account'.tr,
                      subtitle: access.isOwner
                          ? 'Erase the workshop and everything in it'.tr
                          : 'Remove your login from this workshop'.tr,
                      icon: Icons.delete_forever_rounded,
                      iconColor: p.danger,
                      onTap: () => confirmDeleteAccount(context, ref),
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
