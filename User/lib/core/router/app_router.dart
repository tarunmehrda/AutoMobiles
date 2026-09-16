import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_page.dart';
import '../../features/account/addresses_page.dart';
import '../../features/account/profile_page.dart';
import '../../features/account/settings_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/profile_setup_page.dart';
import '../../features/booking/cart_page.dart';
import '../../features/booking/checkout_page.dart';
import '../../features/booking/success_page.dart';
import '../../features/catalog/book_page.dart';
import '../../features/catalog/category_page.dart';
import '../../features/catalog/search_page.dart';
import '../../features/catalog/service_detail_page.dart';
import '../../features/estimate/estimate_page.dart';
import '../../features/history/bookings_page.dart';
import '../../features/history/history_page.dart';
import '../../features/home/home_page.dart';
import '../../features/invoice/invoice_page.dart';
import '../../features/jobcard/job_card_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/offers/offers_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/payment/payment_page.dart';
import '../../features/payment/payment_success_page.dart';
import '../../features/splash/splash_page.dart';
import '../../features/support/chat_page.dart';
import '../../features/support/help_page.dart';
import '../../features/support/support_page.dart';
import '../../features/support/tickets_page.dart';
import '../../features/tracking/inspection_page.dart';
import '../../features/tracking/review_page.dart';
import '../../features/tracking/tracking_page.dart';
import '../../features/workshop/workshop_card_page.dart';
import '../../features/vehicle/add_vehicle_page.dart';
import '../../features/vehicle/garage_page.dart';
import '../../features/vehicle/vehicle_detail_page.dart';
import '../../state/app_state.dart';
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
      if (!profileDone) {
        return loc == '/profile-setup' ? null : '/profile-setup';
      }
      if (!hasVehicle) {
        return loc == '/vehicle/add' ? null : '/vehicle/add';
      }
      const gateRoutes = {'/login', '/onboarding', '/profile-setup'};
      if (gateRoutes.contains(loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
          path: '/profile-setup', builder: (_, __) => const ProfileSetupPage()),
      GoRoute(
        path: '/vehicle/add',
        builder: (_, state) => AddVehiclePage(
          editingId: state.uri.queryParameters['edit'],
        ),
      ),

      // ---- tab shell -----------------------------------------------------
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _shellKey, routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/book', builder: (_, __) => const BookPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/garage', builder: (_, __) => const GaragePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/support', builder: (_, __) => const SupportPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, __) => const AccountPage()),
          ]),
        ],
      ),

      // ---- catalogue -----------------------------------------------------
      GoRoute(
        path: '/search',
        pageBuilder: (_, state) => _fadeUp(
            state,
            SearchPage(initialQuery: state.uri.queryParameters['q']),
          ),
      ),
      GoRoute(
        path: '/category/:id',
        builder: (_, state) =>
            CategoryPage(categoryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/service/:id',
        builder: (_, state) =>
            ServiceDetailPage(packageId: state.pathParameters['id']!),
      ),

      // ---- booking flow --------------------------------------------------
      GoRoute(
        path: '/cart',
        pageBuilder: (_, state) => _fadeUp(state, const CartPage()),
      ),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutPage()),
      GoRoute(
        path: '/booking-success/:id',
        pageBuilder: (_, state) =>
            _fadeUp(state, SuccessPage(bookingId: state.pathParameters['id']!)),
      ),

      // ---- the workshop's own job cards ----------------------------------
      GoRoute(
        path: '/workshop/:id',
        builder: (_, state) =>
            WorkshopCardPage(id: state.pathParameters['id']!),
      ),

      // ---- bookings ------------------------------------------------------
      GoRoute(path: '/bookings', builder: (_, __) => const BookingsPage()),
      GoRoute(
        path: '/booking/:id',
        builder: (_, state) =>
            TrackingPage(bookingId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'jobcard',
            builder: (_, state) =>
                JobCardPage(bookingId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'inspection',
            builder: (_, state) =>
                InspectionPage(bookingId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'estimate',
            builder: (_, state) =>
                EstimatePage(bookingId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'invoice',
            builder: (_, state) =>
                InvoicePage(bookingId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'pay',
            builder: (_, state) =>
                PaymentPage(bookingId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'paid',
            pageBuilder: (_, state) => _fadeUp(
                state, PaymentSuccessPage(bookingId: state.pathParameters['id']!)),
          ),
          GoRoute(
            path: 'review',
            pageBuilder: (_, state) => _fadeUp(
                state, ReviewPage(bookingId: state.pathParameters['id']!)),
          ),
        ],
      ),

      // ---- garage --------------------------------------------------------
      GoRoute(
        path: '/vehicle/:id',
        builder: (_, state) =>
            VehicleDetailPage(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/history', builder: (_, __) => const HistoryPage()),

      // ---- support -------------------------------------------------------
      GoRoute(path: '/chat', builder: (_, __) => const ChatPage()),
      GoRoute(path: '/help', builder: (_, __) => const HelpPage()),
      GoRoute(path: '/tickets', builder: (_, __) => const TicketsPage()),
      // ---- account -------------------------------------------------------
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(path: '/addresses', builder: (_, __) => const AddressesPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(
          path: '/notifications', builder: (_, __) => const NotificationsPage()),
      GoRoute(path: '/offers', builder: (_, __) => const OffersPage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Nothing here: ${state.uri}')),
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
