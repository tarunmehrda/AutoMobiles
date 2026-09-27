import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/alert_host.dart';
import 'features/intro/intro_overlay.dart';
import 'state/auth_state.dart';
import 'state/providers.dart';

class BalajiApp extends ConsumerWidget {
  const BalajiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Mirrors the Supabase session into the local snapshot. Watched here so
    // it survives a Google round trip that disposes the sign-in screen.
    ref.watch(sessionSyncProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        // Keep typography predictable regardless of the device font setting,
        // while still respecting accessibility within a sane range.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25),
          ),
          child: ScrollConfiguration(
            behavior: const _AppScrollBehavior(),
            // The welcome video lives above the router rather than inside a
            // screen, so it keeps playing while the customer navigates. It
            // draws nothing at all until there is something to play.
            // Above the router, so an update from the workshop is
            // announced over whatever route is on top -- including a
            // full-screen sheet. Below the intro video, which owns the
            // screen outright while it plays.
            child: Stack(
              children: [
                AlertHost(child: child ?? const SizedBox.shrink()),
                const IntroOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bouncy, overscroll-glow-free scrolling on every platform.
class _AppScrollBehavior extends ScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
