import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/i18n/app_language.dart';
import 'core/i18n/strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/alert_host.dart';
import 'features/intro/intro_overlay.dart';
import 'state/auth_state.dart';
import 'state/providers.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);

    // Keep the dictionary in step with the snapshot. `setLanguage` already
    // does this, but a language restored from disk or arriving from another
    // device lands here instead.
    Tr.use(language);

    // Joins the console to its workshop upstream and keeps it joined for as
    // long as the app is alive.
    ref.watch(backendSyncProvider);

    // A password reset link can come back long after the login sheet is
    // gone, so the listener lives here rather than on that screen.
    ref.watch(passwordRecoveryWatchProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: language.locale,
      supportedLocales: AppLanguage.values.map((l) => l.locale),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Keep typography predictable regardless of the device font setting,
        // while still respecting accessibility within a sane range.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.25,
            ),
          ),
          child: ScrollConfiguration(
            behavior: const _AppScrollBehavior(),
            // Most of this console's copy is built by `const` widgets, which
            // Flutter is free to skip rebuilding — so swapping the dictionary
            // alone would leave half the screen in the old language. Keying
            // the subtree on the language tears the tree down and builds it
            // again, once, on the only event where that cost is invisible.
            // Above the navigator, so an alert is announced over whatever
            // route is on top — including a full-screen sheet. Outside the
            // KeyedSubtree as well: a language change tears the whole tree
            // down and rebuilds it, and a banner mid-flight should survive
            // that rather than blink out of existence.
            //
            // The welcome video sits beside it for the same reason: above
            // the router, so it keeps playing while the counter moves
            // between screens. It draws nothing until there is a video.
            child: Stack(
              children: [
                AlertHost(
                  child: KeyedSubtree(
                    key: ValueKey(language),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
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
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
