import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repo/auth_service.dart';
import '../../data/repo/platform_gateway.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../shared/support_sheet.dart';

/// All a workshop the platform has blocked gets to see: why, and the
/// number that can undo it.
///
/// The router holds every blocked console here. Unblocking lands through
/// the resume refetch, realtime, or "Check again", and the router lets the
/// console back in by itself.
class BlockedPage extends ConsumerStatefulWidget {
  const BlockedPage({super.key});

  @override
  ConsumerState<BlockedPage> createState() => _BlockedPageState();
}

class _BlockedPageState extends ConsumerState<BlockedPage> {
  bool _checking = false;

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    await ref.read(adminProvider.notifier).resync();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final garage = ref.watch(garageProvider);
    // A partner head whose own workshop is blocked still needs the way to
    // unblock it.
    final platform = ref.watch(isPlatformAdminProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: p.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BlueprintPainter(color: p.ink, opacity: 0.04),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.page,
                  vertical: Gap.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandBadge(size: 64),
                    const SizedBox(height: Gap.xl),
                    Icon(Icons.block_rounded, size: 40, color: p.danger),
                    const SizedBox(height: Gap.md),
                    Text(
                      'Your workshop is blocked'.tr,
                      textAlign: TextAlign.center,
                      style: AppType.h1.c(p.ink),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      'The GaragePro team has blocked {0}. Call or WhatsApp support to get it unblocked.'
                          .trf([garage?.name ?? '']),
                      textAlign: TextAlign.center,
                      style: AppType.bodyM.c(p.inkMuted),
                    ),
                    const SizedBox(height: Gap.xl),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Gap.lg),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: R.all(R.lg),
                        border: Border.all(color: p.line),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Support'.tr,
                            style: AppType.labelM.c(p.inkMuted),
                          ),
                          const SizedBox(height: Gap.xs),
                          SelectableText(
                            '+91 ${AppConfig.supportPhone}',
                            style: AppType.h2.c(p.ink),
                          ),
                          const SizedBox(height: Gap.lg),
                          Row(
                            children: [
                              Expanded(
                                child: GButton.accent(
                                  label: 'Call'.tr,
                                  size: GButtonSize.md,
                                  icon: Icons.call_rounded,
                                  onPressed: () => launchDial(
                                    context,
                                    AppConfig.supportPhone,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Gap.md),
                              Expanded(
                                child: GButton(
                                  label: 'WhatsApp'.tr,
                                  kind: GButtonKind.outline,
                                  size: GButtonSize.md,
                                  icon: Icons.chat_rounded,
                                  onPressed: () => launchWhatsApp(
                                    context,
                                    AppConfig.supportWhatsapp,
                                    text:
                                        'My workshop {0} is blocked on GaragePro. Please unblock it.'
                                            .trf([garage?.name ?? '']),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                    GButton(
                      label: 'Check again'.tr,
                      kind: GButtonKind.outline,
                      trailingIcon: Icons.refresh_rounded,
                      loading: _checking,
                      onPressed: _checking ? null : _checkAgain,
                    ),
                    if (platform) ...[
                      const SizedBox(height: Gap.md),
                      GButton(
                        label: 'Open Platform'.tr,
                        kind: GButtonKind.ghost,
                        onPressed: () => context.push('/platform/admin'),
                      ),
                    ],
                    const SizedBox(height: Gap.md),
                    Pressable(
                      onTap: () async {
                        await ref.read(authServiceProvider).signOut();
                        if (!mounted) return;
                        ref.read(adminProvider.notifier).signOut();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.sm),
                        child: Text(
                          'Sign in as someone else'.tr,
                          style: AppType.labelL.c(p.inkMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
