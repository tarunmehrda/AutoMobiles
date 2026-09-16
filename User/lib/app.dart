import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
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
            child: child ?? const SizedBox.shrink(),
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
