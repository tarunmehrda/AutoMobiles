import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/pressable.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import '../../state/providers.dart';
import 'company_sheet.dart';

/// The Play Store id this console ships under — for "Rate this app".
const _storeId = 'com.garagepro.garagepro_admin';

/// The business menu: every part of the workshop, in the order the owner
/// drew it — the company at the top, the daily work, Sales and Purchase
/// each opening onto their four documents, then the money, the settings,
/// growing the business and help.
///
/// The dashboard's grid has the same tools as tiles; this is the index,
/// for the owner who knows where they are going and wants it in one tap.
class BusinessDrawer extends ConsumerWidget {
  const BusinessDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final access = ref.watch(accessProvider);
    final garage = ref.watch(garageProvider);
    final data = ref.watch(adminProvider);
    final email = ref.watch(authUserProvider)?.email ?? '';

    // Shut the drawer, then go. Pushing first leaves the drawer open under
    // the new page, and it is still there on the way back.
    void go(String location) {
      Navigator.of(context).pop();
      context.push(location);
    }

    bool may(String location) => access.allows(location);

    _Item item(
      String location,
      String title,
      IconData icon, {
      String? trailing,
      Color? tint,
    }) => _Item(
      title: title,
      icon: icon,
      tint: tint,
      trailing: trailing,
      onTap: () => go(location),
    );

    final daily = <Widget>[
      if (may('/estimates'))
        _Group(
          title: 'Estimate'.tr,
          icon: Icons.request_quote_rounded,
          tint: p.accent,
          children: [
            ('New: Jobs / Parts / Labour'.tr, '/trade/new?kind=estimate'),
            ('All estimates'.tr, '/estimates'),
          ],
          onPick: go,
        ),
      if (access.openJobs)
        item('/job/new', 'Create Jobcard'.tr, Icons.add_card_rounded),
      if (may('/inventory'))
        item('/inventory', 'Inventory'.tr, Icons.inventory_2_rounded),
      if (may('/staff') || may('/attendance'))
        _Group(
          title: 'Staff & Attendance'.tr,
          icon: Icons.groups_rounded,
          tint: p.success,
          children: [
            if (may('/staff')) ('Staff'.tr, '/staff'),
            if (may('/attendance')) ('Attendance'.tr, '/attendance'),
            if (may('/attendance')) ('Register'.tr, '/attendance/register'),
          ],
          onPick: go,
        ),
      if (may('/expenses'))
        item('/expenses', 'Expenses'.tr, Icons.receipt_long_rounded),
      if (may('/contacts'))
        item('/contacts', 'Contacts'.tr, Icons.contacts_rounded),
    ];

    final more = <Widget>[
      if (may('/reports'))
        item('/reports', 'Report'.tr, Icons.description_rounded),
      if (may('/analytics'))
        item('/analytics', 'Analytics'.tr, Icons.insights_rounded),
      if (may('/platform'))
        item('/platform', 'Buy & Sell'.tr, Icons.storefront_rounded),
      if (may('/online-garage'))
        item('/online-garage', 'Online Garage'.tr, Icons.language_rounded),
      if (may('/bookings'))
        item('/bookings', 'Appointments'.tr, Icons.event_available_rounded),
      if (may('/cashbook'))
        item('/cashbook', 'CashBook'.tr, Icons.savings_rounded),
      if (may('/feedback'))
        item('/feedback', 'Feedback'.tr, Icons.reviews_rounded),
    ];

    return Drawer(
      backgroundColor: p.canvas,
      width: (MediaQuery.sizeOf(context).width * 0.86).clamp(280.0, 360.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _Masthead(
            name: garage?.name ?? 'Workshop'.tr,
            email: email,
            role: access.role.label,
            onSwitch: () {
              Navigator.of(context).pop();
              showCompanySheet(context);
            },
          ),
          Expanded(
            child: ListView(
              // Clear of the app's bottom bar, which the drawer sits under.
              padding: EdgeInsets.fromLTRB(
                Gap.md,
                Gap.md,
                Gap.md,
                Gap.xl + 96 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                // --- the company -----------------------------------------
                _Section(
                  title: 'Company'.tr,
                  children: [
                    _Item(
                      title: 'Switch company'.tr,
                      icon: Icons.swap_horiz_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        showCompanySheet(context);
                      },
                    ),
                    if (may('/workshop'))
                      item('/workshop', 'Manage company'.tr,
                          Icons.edit_note_rounded),
                    _Item(
                      title: 'Add company'.tr,
                      icon: Icons.add_business_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        showCompanySheet(context);
                      },
                    ),
                  ],
                ),

                if (daily.isNotEmpty)
                  _Section(title: 'Daily work'.tr, children: daily),

                // --- sales and purchase ----------------------------------
                if (may('/sales') || may('/purchase'))
                  _Section(
                    title: 'Sales & Purchase'.tr,
                    children: [
                      if (may('/sales'))
                        _Group(
                          title: 'Sales'.tr,
                          icon: Icons.point_of_sale_rounded,
                          tint: p.success,
                          children: [
                            ('Sale Invoice'.tr, '/sales?tab=invoice'),
                            ('Sale Return'.tr, '/sales?tab=return'),
                            ('Sale Order'.tr, '/sales?tab=order'),
                            ('Payment-In'.tr, '/sales?tab=paymentIn'),
                          ],
                          onPick: go,
                        ),
                      if (may('/purchase'))
                        _Group(
                          title: 'Purchase'.tr,
                          icon: Icons.shopping_cart_rounded,
                          tint: p.info,
                          children: [
                            ('Purchase Bill'.tr, '/purchase?tab=bill'),
                            ('Pay-Out'.tr, '/purchase?tab=payOut'),
                            ('Purchase Return'.tr, '/purchase?tab=return'),
                            ('Purchase Order'.tr, '/purchase?tab=order'),
                          ],
                          onPick: go,
                        ),
                    ],
                  ),

                if (more.isNotEmpty)
                  _Section(title: 'Run the shop'.tr, children: more),

                // --- the money -------------------------------------------
                if (may('/bank-accounts'))
                  _Section(
                    title: 'Money'.tr,
                    children: [
                      item(
                        '/bank-accounts',
                        'Bank Accounts'.tr,
                        Icons.account_balance_rounded,
                        trailing: data.banks.isEmpty
                            ? null
                            : '${data.banks.length}',
                      ),
                      item(
                        '/bank-accounts?tab=cash',
                        'Cash in Hand'.tr,
                        Icons.payments_rounded,
                        trailing: Fmt.money(data.balanceOf(data.cashAccount)),
                      ),
                    ],
                  ),

                // --- settings --------------------------------------------
                _Section(
                  title: 'Settings'.tr,
                  children: [
                    if (may('/settings/sync-share'))
                      item('/settings/sync-share', 'Sync & Share'.tr,
                          Icons.sync_rounded),
                    _Item(
                      title: 'Settings'.tr,
                      icon: Icons.settings_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go('/settings');
                      },
                    ),
                  ],
                ),

                _Section(
                  title: 'More'.tr,
                  children: [
                    item(
                      '/grow-business',
                      'Grow your business'.tr,
                      Icons.campaign_rounded,
                      tint: p.accent,
                    ),
                    item('/support', 'Help & Support'.tr,
                        Icons.support_agent_rounded),
                    _Item(
                      title: 'Rate this app'.tr,
                      icon: Icons.star_rate_rounded,
                      tint: const Color(0xFFF2B01E),
                      onTap: () {
                        Navigator.of(context).pop();
                        rateApp(context);
                      },
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

/// Opens this app's store page, in the Play Store app where there is one.
Future<void> rateApp(BuildContext context) async {
  final market = Uri.parse('market://details?id=$_storeId');
  final web = Uri.parse(
    'https://play.google.com/store/apps/details?id=$_storeId',
  );
  try {
    if (await launchUrl(market, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // No Play Store app — the browser below does the same job.
  }
  final ok = await launchUrl(web, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    GFeedback.error(context, 'Could not open the store'.tr);
  }
}

/// The company, on the accent, with the switch beside it.
class _Masthead extends StatelessWidget {
  const _Masthead({
    required this.name,
    required this.email,
    required this.role,
    required this.onSwitch,
  });

  final String name;
  final String email;
  final String role;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(p.accent, Colors.white, 0.08)!,
            Color.lerp(p.accent, Colors.black, 0.28)!,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: R.all(R.md),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: p.accent,
                  size: 26,
                ),
              ),
              const SizedBox(height: Gap.md),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.h1.s(20).c(Colors.white).w(FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                [role, if (email.isNotEmpty) email].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.bodyS.c(Colors.white.withValues(alpha: 0.86)),
              ),
              const SizedBox(height: Gap.md),
              Pressable(
                onTap: onSwitch,
                scale: 0.96,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: Gap.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: R.all(R.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.swap_horiz_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: Gap.xs),
                      Text(
                        'Switch · Manage · Add company'.tr,
                        style: AppType.labelS.c(Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, 0, Gap.xs),
            child: Text(title.toUpperCase(), style: AppType.over.c(p.inkFaint)),
          ),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: R.all(R.lg),
              border: Border.all(color: p.lineSoft),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.title,
    required this.icon,
    required this.onTap,
    this.tint,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = tint ?? p.accentInk;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm + 2,
        ),
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: t.withValues(alpha: p.isDark ? 0.18 : 0.11),
                borderRadius: R.all(R.sm),
              ),
              child: Icon(icon, size: 18, color: t),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.labelL.c(p.ink),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: Gap.sm),
                child: Text(trailing!, style: AppType.labelS.c(p.inkMuted)),
              ),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Sales or Purchase: one row that opens onto its four documents.
class _Group extends StatefulWidget {
  const _Group({
    required this.title,
    required this.icon,
    required this.tint,
    required this.children,
    required this.onPick,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final List<(String, String)> children;
  final ValueChanged<String> onPick;

  @override
  State<_Group> createState() => _GroupState();
}

class _GroupState extends State<_Group> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      children: [
        Pressable(
          onTap: () => setState(() => _open = !_open),
          scale: 0.99,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm + 2,
            ),
            child: Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: widget.tint.withValues(alpha: p.isDark ? 0.18 : 0.11),
                    borderRadius: R.all(R.sm),
                  ),
                  child: Icon(widget.icon, size: 18, color: widget.tint),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(widget.title, style: AppType.labelL.c(p.ink)),
                ),
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: Motion.fast,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: p.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.emphasized,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(58, 0, Gap.md, Gap.sm),
                  child: Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      for (final (label, location) in widget.children)
                        Pressable(
                          onTap: () => widget.onPick(location),
                          scale: 0.95,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Gap.md,
                              vertical: Gap.sm,
                            ),
                            decoration: BoxDecoration(
                              color: widget.tint.withValues(alpha: 0.08),
                              borderRadius: R.all(R.pill),
                              border: Border.all(
                                color: widget.tint.withValues(alpha: 0.32),
                              ),
                            ),
                            child: Text(
                              label,
                              style: AppType.labelS.c(p.ink),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
