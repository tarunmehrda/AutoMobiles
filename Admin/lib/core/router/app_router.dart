import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/setup_page.dart';
import '../../features/bookings/bookings_page.dart';
import '../../features/customers/customer_detail_page.dart';
import '../../features/customers/customers_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/feedback/feedback_page.dart';
import '../../features/inventory/inventory_page.dart';
import '../../features/jobcard/create_jobcard_page.dart';
import '../../features/jobcard/jobcard_detail_page.dart';
import '../../features/jobcard/jobcard_list_page.dart';
import '../../features/jobcard/panels/accessories_page.dart';
import '../../features/jobcard/panels/dents_page.dart';
import '../../features/jobcard/panels/items_page.dart';
import '../../features/jobcard/panels/photos_page.dart';
import '../../features/jobcard/panels/voices_page.dart';
import '../../features/jobcard/panels/work_note_page.dart';
import '../../features/money/pending_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/reports/reports_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/staff_page.dart';
import '../../features/settings/workshop_page.dart';
import '../../features/splash/splash_page.dart';
import '../../features/support/support_page.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import '../theme/app_tokens.dart';
import 'app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Rebuilds the redirect whenever the gate changes — either the Supabase
/// session or, with no backend configured, the on-device flag.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(adminProvider, (prev, next) {
      final changed = prev?.signedIn != next.signedIn ||
          prev?.onboarded != next.onboarded ||
          (prev?.garage == null) != (next.garage == null);
      if (changed) notifyListeners();
    });
    ref.listen(signedInProvider, (prev, next) {
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
      final data = ref.read(adminProvider);
      final loc = state.matchedLocation;

      if (loc == '/splash') return null;

      if (!data.onboarded) {
        return loc == '/onboarding' ? null : '/onboarding';
      }
      if (!ref.read(signedInProvider)) {
        const authRoutes = {'/login'};
        return authRoutes.contains(loc) ? null : '/login';
      }
      if (data.garage == null) {
        return loc == '/setup' ? null : '/setup';
      }
      const gateRoutes = {'/login', '/onboarding', '/setup'};
      if (gateRoutes.contains(loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/setup', builder: (_, _) => const SetupPage()),

      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const DashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/jobs',
              builder: (_, state) => JobCardListPage(
                initial: JobStatusX.parse(
                    state.uri.queryParameters['status'] ?? 'open'),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/inventory', builder: (_, _) => const InventoryPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/reports', builder: (_, _) => const ReportsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          ]),
        ],
      ),

      // --- job card ---------------------------------------------------
      GoRoute(
        path: '/job/new',
        builder: (_, state) => CreateJobCardPage(
          bookingId: state.uri.queryParameters['booking'],
          vehicleId: state.uri.queryParameters['vehicle'],
        ),
      ),
      GoRoute(
        path: '/job/:id',
        builder: (_, state) => JobCardDetailPage(
          id: state.pathParameters['id']!,
          initialDoc:
              DocKindX.parse(state.uri.queryParameters['doc'] ?? 'estimate'),
        ),
        routes: [
          GoRoute(
            path: 'items',
            builder: (_, state) => ItemsPage(
              id: state.pathParameters['id']!,
              initial: LineKindX.parse(
                  state.uri.queryParameters['kind'] ?? 'job'),
            ),
          ),
          GoRoute(
            path: 'voices',
            builder: (_, state) =>
                VoicesPage(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'accessories',
            builder: (_, state) =>
                AccessoriesPage(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'note',
            builder: (_, state) =>
                WorkNotePage(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'dents',
            builder: (_, state) => DentsPage(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'photos',
            builder: (_, state) => PhotosPage(id: state.pathParameters['id']!),
          ),
        ],
      ),

      // --- front desk -------------------------------------------------
      GoRoute(path: '/bookings', builder: (_, _) => const BookingsPage()),
      GoRoute(path: '/pending', builder: (_, _) => const PendingPage()),
      GoRoute(path: '/feedback', builder: (_, _) => const FeedbackPage()),
      GoRoute(path: '/customers', builder: (_, _) => const CustomersPage()),
      GoRoute(
        path: '/customer/:id',
        builder: (_, state) =>
            CustomerDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/support', builder: (_, _) => const SupportPage()),
      GoRoute(path: '/workshop', builder: (_, _) => const WorkshopPage()),
      GoRoute(path: '/staff', builder: (_, _) => const StaffPage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.page),
          child: Text('No screen at ${state.uri}'),
        ),
      ),
    ),
  );
});
