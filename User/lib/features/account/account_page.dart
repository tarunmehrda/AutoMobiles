import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_surface.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

/// Who the customer is, how to reach them, and the two doors out: help, and
/// signing off.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final user = ref.watch(userProvider);
    final shop = ref.watch(workshopProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
          children: [
            // --- who ---------------------------------------------------
            Entrance(
              child: Container(
                padding: const EdgeInsets.all(Gap.lg),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: R.all(R.lg),
                  border: Border.all(color: p.line),
                  boxShadow: Shadows.soft(p),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 72,
                      width: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: p.accentGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        Fmt.initials(user?.name ?? '?'),
                        style: AppType.d3.c(p.onAccent),
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    Text(user?.name ?? 'Your profile',
                        style: AppType.h1.c(p.ink)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call_rounded, size: 14, color: p.inkMuted),
                        const SizedBox(width: 5),
                        Text(user?.phone ?? '',
                            style: AppType.bodyS.c(p.inkMuted)),
                      ],
                    ),
                    const SizedBox(height: Gap.lg),
                    GButton(
                      label: 'Edit Profile',
                      kind: GButtonKind.outline,
                      onPressed: () => context.push('/profile'),
                    ),
                  ],
                ),
              ),
            ),

            // --- how to reach them ------------------------------------
            const SizedBox(height: Gap.lg),
            Entrance(
              index: 1,
              child: Container(
                padding: const EdgeInsets.all(Gap.lg),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: R.all(R.lg),
                  border: Border.all(color: p.line),
                  boxShadow: Shadows.soft(p),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contact Information',
                        style: AppType.h2.c(p.ink)),
                    const SizedBox(height: Gap.md),
                    _Line(
                      icon: Icons.mail_outline_rounded,
                      value: (user?.email ?? '').isEmpty
                          ? 'No email on file'
                          : user!.email!,
                      muted: (user?.email ?? '').isEmpty,
                    ),
                    Divider(height: Gap.xl, color: p.lineSoft),
                    _Line(
                      icon: Icons.place_outlined,
                      value: shop.isLinked
                          ? shop.address
                          : 'No workshop linked yet',
                      muted: !shop.isLinked,
                    ),
                  ],
                ),
              ),
            ),

            // --- the doors out ----------------------------------------
            const SizedBox(height: Gap.lg),
            Entrance(
              index: 2,
              child: GTileGroup(
                children: [
                  GTile(
                    title: shop.isLinked ? 'Change workshop' : 'Find a workshop',
                    subtitle: shop.isLinked
                        ? shop.label
                        : 'Search the garages near you',
                    icon: Icons.storefront_rounded,
                    onTap: () => context.push('/search'),
                  ),
                  // For the customer who also runs a workshop. Worded as an
                  // invitation rather than a setting, because to almost
                  // everybody reading this screen it is neither.
                  GTile(
                    title: 'Register as a partner',
                    subtitle: 'Own a garage? List it with us',
                    icon: Icons.handshake_outlined,
                    onTap: () => context.push('/partner'),
                  ),
                  GTile(
                    title: 'Help & Support',
                    icon: Icons.help_outline_rounded,
                    onTap: () => context.push('/help'),
                  ),
                  GTile(
                    title: 'Privacy Policy',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () => context.push('/privacy'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.lg),
            Entrance(
              index: 3,
              child: GButton(
                label: 'Logout',
                kind: GButtonKind.outline,
                icon: Icons.logout_rounded,
                onPressed: () async {
                  final ok = await GFeedback.confirm(
                    context,
                    title: 'Sign out?',
                    message:
                        'Your vehicles and bookings stay with your account. '
                        'Sign back in with the same number to pick them up.',
                    confirmLabel: 'Sign out',
                    destructive: true,
                    icon: Icons.logout_rounded,
                  );
                  if (!ok) return;
                  await ref.read(appControllerProvider.notifier).signOut();
                },
              ),
            ),

            const SizedBox(height: Gap.xl),
            Center(
              child: Text('${AppConfig.appName} • v${AppConfig.version}',
                  style: AppType.labelS.c(p.inkFaint)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: p.inkMuted),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Text(
            value,
            style: muted
                ? AppType.bodyM.c(p.inkFaint)
                : AppType.bodyM.c(p.ink),
          ),
        ),
      ],
    );
  }
}
