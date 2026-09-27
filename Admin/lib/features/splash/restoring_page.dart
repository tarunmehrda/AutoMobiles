import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repo/auth_service.dart';
import '../../data/repo/garage_gateway.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';

/// Shown for the moment between a session appearing and the workshop behind
/// it arriving — and, if it never arrives, instead of the wrong screen.
///
/// It exists so the router never has to guess. Deciding whether this console
/// still needs registering, while the answer is halfway down the wire, is
/// what used to throw a returning owner at the registration form and then
/// pull them to the dashboard a beat later.
///
/// Every path out of here is a door. A screen that can only wait is worse
/// than the wrong screen, because the wrong screen at least moves.
class RestoringPage extends ConsumerStatefulWidget {
  const RestoringPage({super.key});

  @override
  ConsumerState<RestoringPage> createState() => _RestoringPageState();
}

class _RestoringPageState extends ConsumerState<RestoringPage> {
  /// The first attempt runs at cold start, when the network stack may not be
  /// up yet. One quiet retry costs a second and saves the owner a tap; more
  /// than one would just be a spinner wearing a button.
  bool _retried = false;

  Future<void> _retry() => attemptRestore(
    ref.read(adminProvider.notifier),
    setRestoring: (v) {
      if (mounted) ref.read(restoringProvider.notifier).state = v;
    },
    setFailed: (v) {
      if (mounted) ref.read(restoreFailedProvider.notifier).state = v;
    },
  );

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final failed = ref.watch(restoreFailedProvider);

    if (failed && !_retried) {
      _retried = true;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _retry();
      });
    }

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
                    if (failed) ..._stalled(p) else ..._waiting(p),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _waiting(AppPalette p) => [
    Text('Opening your workshop'.tr, style: AppType.h1.c(p.ink)),
    const SizedBox(height: Gap.sm),
    Text(
      'Fetching everything on the counter…'.tr,
      style: AppType.bodyM.c(p.inkMuted),
    ),
    const SizedBox(height: Gap.xl),
    SizedBox(
      width: 120,
      child: ClipRRect(
        borderRadius: R.all(R.pill),
        child: LinearProgressIndicator(
          minHeight: 4,
          backgroundColor: p.line,
          valueColor: AlwaysStoppedAnimation(p.accent),
        ),
      ),
    ),
  ];

  /// The lookup did not answer. This screen says so and offers a way on,
  /// rather than falling straight through to the registration form — an
  /// owner who is simply offline does not need to register the shop they
  /// already have, and letting them would open a second one on top of it.
  List<Widget> _stalled(AppPalette p) {
    final reason = ref.read(garageGatewayProvider).lastError;
    return [
      Text(
        'Could not reach your workshop'.tr,
        textAlign: TextAlign.center,
        style: AppType.h1.c(p.ink),
      ),
      const SizedBox(height: Gap.sm),
      Text(
        'Your account is signed in, but the counter is still on its way down. Nothing has been lost.'
            .tr,
        textAlign: TextAlign.center,
        style: AppType.bodyM.c(p.inkMuted),
      ),
      if (reason != null) ...[
        const SizedBox(height: Gap.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: R.all(R.md),
            border: Border.all(color: p.line),
          ),
          child: Text(
            reason,
            textAlign: TextAlign.center,
            style: AppType.bodyS.c(p.inkMuted),
          ),
        ),
      ],
      const SizedBox(height: Gap.h1),
      GButton.accent(
        label: 'Try again'.tr,
        trailingIcon: Icons.refresh_rounded,
        onPressed: _retry,
      ),
      const SizedBox(height: Gap.lg),
      // The door. If the workshop genuinely is not there — a project missing
      // its functions, an account that never finished registering — this is
      // the way on, and it is the owner's call to make, not a timeout's.
      GButton(
        label: 'Register a workshop instead'.tr,
        kind: GButtonKind.outline,
        onPressed: () {
          ref.read(restoreFailedProvider.notifier).state = false;
          context.go('/setup');
        },
      ),
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
    ];
  }
}
