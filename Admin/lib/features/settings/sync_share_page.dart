import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_surface.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import '../../state/providers.dart';

/// Sync & Share: the workshop on more than one phone.
///
/// Two different things that owners ask for in the same breath — "my
/// mechanic needs the app" and "I want it on my second phone too" — and they
/// are answered differently: staff get their own login with a role, the
/// owner signs in with the same email on the other device.
class SyncSharePage extends ConsumerStatefulWidget {
  const SyncSharePage({super.key});

  @override
  ConsumerState<SyncSharePage> createState() => _SyncSharePageState();
}

class _SyncSharePageState extends ConsumerState<SyncSharePage> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await ref.read(adminProvider.notifier).resync();
      if (!mounted) return;
      final issues = ref.read(adminProvider.notifier).syncIssues.value;
      if (issues.isEmpty) {
        GFeedback.success(context, 'Everything is in sync'.tr);
      } else {
        GFeedback.error(context, issues.values.first);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final email = ref.watch(authUserProvider)?.email ?? '';
    final garage = ref.watch(garageProvider);
    final access = ref.watch(accessProvider);
    final online = AppConfig.hasSupabase;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Sync & Share'.tr,
        subtitle: garage?.name,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
        children: [
          // --- is it syncing --------------------------------------------
          ValueListenableBuilder<Map<String, String>>(
            valueListenable: ref.read(adminProvider.notifier).syncIssues,
            builder: (context, issues, _) {
              final ok = online && issues.isEmpty;
              final tint = !online
                  ? p.inkMuted
                  : (ok ? p.success : p.warning);
              return Container(
                padding: const EdgeInsets.all(Gap.lg),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: p.isDark ? 0.16 : 0.08),
                  borderRadius: R.all(R.lg),
                  border: Border.all(color: tint.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          !online
                              ? Icons.cloud_off_rounded
                              : (ok
                                    ? Icons.cloud_done_rounded
                                    : Icons.sync_problem_rounded),
                          color: tint,
                          size: 28,
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                !online
                                    ? 'This phone only'.tr
                                    : (ok
                                          ? 'Synced to the cloud'.tr
                                          : 'Some changes are waiting'.tr),
                                style: AppType.h2.c(p.ink),
                              ),
                              Text(
                                !online
                                    ? 'No server is set up in this build, so nothing leaves this phone.'
                                          .tr
                                    : (ok
                                          ? 'Job cards, bills, stock and books are saved online and reach every signed-in device.'
                                                .tr
                                          : issues.entries
                                                .map((e) => '${e.key}: ${e.value}')
                                                .join('\n')),
                                style: AppType.bodyS.c(p.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (online) ...[
                      const SizedBox(height: Gap.md),
                      GButton(
                        label: _syncing ? 'Syncing…'.tr : 'Sync now'.tr,
                        icon: Icons.sync_rounded,
                        kind: GButtonKind.outline,
                        size: GButtonSize.md,
                        loading: _syncing,
                        onPressed: _syncNow,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: Gap.xl),

          // --- staff ----------------------------------------------------
          GTileGroup(
            title: 'Give access to staff'.tr,
            children: [
              GTile(
                icon: Icons.badge_rounded,
                iconColor: p.accent,
                title: 'Invite staff to the app'.tr,
                subtitle:
                    'Each person signs in with their own email and sees only what their role allows — Manager, Mechanic, Counter or Accountant.'
                        .tr,
                onTap: access.team ? () => context.push('/staff') : null,
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),

          // --- more devices --------------------------------------------
          GTileGroup(
            title: 'Connect multiple devices'.tr,
            children: [
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, step) in [
                      'Install this app on the other phone or tablet.'.tr,
                      'Sign in with the same email as this phone.'.tr,
                      'The workshop opens with everything on it, and stays in step with this phone as you work.'
                          .tr,
                    ].indexed) ...[
                      if (i > 0) const SizedBox(height: Gap.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 24,
                            width: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: AppType.labelS.c(Colors.white),
                            ),
                          ),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Text(step, style: AppType.bodyM.c(p.ink)),
                          ),
                        ],
                      ),
                    ],
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: Gap.lg),
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                          Gap.md,
                          Gap.sm,
                          Gap.xs,
                          Gap.sm,
                        ),
                        decoration: BoxDecoration(
                          color: p.surfaceAlt,
                          borderRadius: R.all(R.md),
                          border: Border.all(color: p.line),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.alternate_email_rounded,
                              size: 18,
                              color: p.inkMuted,
                            ),
                            const SizedBox(width: Gap.sm),
                            Expanded(
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.labelL.c(p.ink),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy'.tr,
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: email),
                                );
                                if (context.mounted) {
                                  GFeedback.success(context, 'Email copied'.tr);
                                }
                              },
                              icon: Icon(
                                Icons.copy_rounded,
                                size: 18,
                                color: p.accentInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
