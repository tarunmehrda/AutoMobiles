import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_page.dart';
import '../../features/account/privacy_page.dart';
import '../../features/account/profile_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/profile_setup_page.dart';
import '../../features/booking/appointment_page.dart';
import '../../features/history/bookings_page.dart';
import '../../features/home/home_page.dart';
import '../../features/invoice/invoice_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/marketplace/marketplace_page.dart';
import '../../features/marketplace/need_part_page.dart';
import '../../features/marketplace/sell_part_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/partner/partner_page.dart';
import '../../features/search/garage_search_page.dart';
import '../../features/splash/restoring_page.dart';
import '../../features/splash/splash_page.dart';
import '../../features/support/help_page.dart';
import '../../features/vehicle/add_vehicle_page.dart';
import '../../features/vehicle/garage_page.dart';
import '../../features/vehicle/vehicle_detail_page.dart';
import '../../state/app_state.dart';
import '../../state/auth_state.dart';
import '../theme/app_tokens.dart';
import 'app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Rebuilds the router's redirect whenever the session or vehicle list changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(appControllerProvider, (prev, next) {
      final changed = prev?.user?.id != next.user?.id ||
          (prev?.user?.name.trim().isEmpty ?? true) !=
              (next.user?.name.trim().isEmpty ?? true) ||
          prev?.onboarded != next.onboarded ||
          (prev?.vehicles.isEmpty ?? true) != next.vehicles.isEmpty;
      if (changed) notifyListeners();
    });
    // The gate also waits on the account arriving, so it has to re-run when
    // that lands.
    ref.listen(restoringProvider, (prev, next) {
      if (prev != next) notifyListeners();
    });
  }

  final Ref ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final data = ref.read(appControllerProvider);
      final loc = state.matchedLocation;

      if (loc == '/splash') return null;

      final signedIn = data.user != null;
      final profileDone = signedIn && data.user!.name.trim().isNotEmpty;
      final hasVehicle = data.vehicles.isNotEmpty;

      if (!data.onboarded) {
        return loc == '/onboarding' ? null : '/onboarding';
      }
      if (!signedIn) {
        const authRoutes = {'/login'};
        return authRoutes.contains(loc) ? null : '/login';
      }
      // Signed in, but the account is still on its way down. Deciding now is
      // what used to skip the sign-up steps for somebody signing back in.
      if (ref.read(restoringProvider)) {
        return loc == '/restoring' ? null : '/restoring';
      }
      if (!profileDone) {
        return loc == '/profile-setup' ? null : '/profile-setup';
      }
      if (!hasVehicle) {
        return loc == '/vehicle/add' ? null : '/vehicle/add';
      }
      const gateRoutes = {
        '/login',
        '/onboarding',
        '/profile-setup',
        '/restoring',
      };
      if (gateRoutes.contains(loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/restoring', builder: (_, _) => const RestoringPage()),
      GoRoute(
          path: '/profile-setup', builder: (_, _) => const ProfileSetupPage()),
      GoRoute(
        path: '/vehicle/add',
        builder: (_, state) => AddVehiclePage(
          editingId: state.uri.queryParameters['edit'],
        ),
      ),

      // ---- the four tabs -------------------------------------------------
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _shellKey, routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/bookings',
              builder: (_, state) =>
                  BookingsPage(focusId: state.uri.queryParameters['open']),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/garage', builder: (_, _) => const GaragePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
          ]),
        ],
      ),

      // ---- booking a slot ------------------------------------------------
      GoRoute(
        path: '/book',
        pageBuilder: (_, state) => _fadeUp(
          state,
          AppointmentPage(
            vehicleId: state.uri.queryParameters['vehicle'],
            garageId: state.uri.queryParameters['garage'],
          ),
        ),
      ),

      // ---- finding a workshop --------------------------------------------
      // Outside the tabs on purpose: searching is something a customer does
      // occasionally, and it should not cost a permanent tab that the
      // customer who already has a workshop would never press.
      GoRoute(
        path: '/search',
        pageBuilder: (_, state) => _fadeUp(
          state,
          GarageSearchPage(pick: state.uri.queryParameters['pick'] == '1'),
        ),
      ),

      // ---- parts, bought and sold ----------------------------------------
      GoRoute(
        path: '/parts',
        pageBuilder: (_, state) => _fadeUp(state, const MarketplacePage()),
        routes: [
          // Children of /parts so that popping either form lands back on the
          // list it was started from, rather than on whatever screen the
          // customer happened to be on before.
          GoRoute(
            path: 'need',
            parentNavigatorKey: _rootKey,
            builder: (_, _) => const NeedPartPage(),
          ),
          GoRoute(
            path: 'sell',
            parentNavigatorKey: _rootKey,
            builder: (_, _) => const SellPartPage(),
          ),
        ],
      ),

      // ---- the workshop's own job cards ----------------------------------
      // The detail lives in the booking sheet; this is the printable bill.
      GoRoute(
        path: '/workshop/:id/invoice',
        builder: (_, state) =>
            InvoicePage(cardId: state.pathParameters['id']!),
      ),

      // ---- garage --------------------------------------------------------
      GoRoute(
        path: '/vehicle/:id',
        builder: (_, state) =>
            VehicleDetailPage(vehicleId: state.pathParameters['id']!),
      ),

      // ---- account -------------------------------------------------------
      GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyPage()),
      GoRoute(path: '/help', builder: (_, _) => const HelpPage()),
      // Registering a workshop. Reached from the account screen, not the
      // tabs: most customers are not garage owners.
      GoRoute(path: '/partner', builder: (_, _) => const PartnerPage()),
      GoRoute(
          path: '/notifications', builder: (_, _) => const NotificationsPage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.page),
          child: Text('Nothing here: ${state.uri}'),
        ),
      ),
    ),
  );
});

/// Sheet-like entrance for pages that behave as overlays.
CustomTransitionPage<void> _fadeUp(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: Motion.base,
    reverseTransitionDuration: Motion.fast,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Motion.emphasized);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}
