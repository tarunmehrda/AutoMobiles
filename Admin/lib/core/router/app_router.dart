import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../data/models/enums.dart';
import '../../features/analytics/analytics_page.dart';
import '../../features/analytics/revenue_analytics_page.dart';
import '../../features/analytics/vehicle_analytics_page.dart';
import '../../features/attendance/attendance_page.dart';
import '../../features/attendance/attendance_register_page.dart';
import '../../features/attendance/attendance_site_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/reset_password_page.dart';
import '../../features/auth/setup_page.dart';
import '../../features/bookings/bookings_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/contacts/contacts_page.dart';
import '../../features/customers/customer_detail_page.dart';
import '../../features/customers/customers_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/feedback/feedback_page.dart';
import '../../features/inventory/counter_sale_page.dart';
import '../../features/inventory/inventory_dashboard_page.dart';
import '../../features/inventory/master_list_page.dart';
import '../../features/inventory/purchase_orders_page.dart';
import '../../features/inventory/suppliers_page.dart';
import '../../features/jobcard/create_jobcard_page.dart';
import '../../features/jobcard/jobcard_detail_page.dart';
import '../../features/jobcard/jobcard_list_page.dart';
import '../../features/jobcard/panels/accessories_page.dart';
import '../../features/jobcard/panels/dents_page.dart';
import '../../features/jobcard/panels/items_page.dart';
import '../../features/jobcard/panels/mechanics_page.dart';
import '../../features/jobcard/panels/photos_page.dart';
import '../../features/jobcard/panels/voices_page.dart';
import '../../features/jobcard/panels/work_note_page.dart';
import '../../features/money/cashbook_page.dart';
import '../../features/money/account_statement_page.dart';
import '../../features/money/bank_accounts_page.dart';
import '../../features/business/grow_business_page.dart';
import '../../features/settings/sync_share_page.dart';
import '../../features/trade/estimates_page.dart';
import '../../features/trade/purchase_page.dart';
import '../../features/trade/sales_page.dart';
import '../../features/trade/trade_detail_page.dart';
import '../../features/trade/trade_form_page.dart';
import '../../data/models/books.dart';
import '../../features/money/expenses_page.dart';
import '../../features/money/pending_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/platform/platform_page.dart';
import '../../features/online/online_garage_page.dart';
import '../../features/reminders/service_due_page.dart';
import '../../features/reports/counter_sales_report_page.dart';
import '../../features/reports/general_report_page.dart';
import '../../features/reports/mechanic_report_page.dart';
import '../../features/reports/report_summary_page.dart';
import '../../features/reports/sale_report_page.dart';
import '../../features/reports/sms_report_page.dart';
import '../../features/reports/stock_jobs_report_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/commission_page.dart';
import '../../features/settings/greetings_page.dart';
import '../../features/settings/language_page.dart';
import '../../features/settings/credits_page.dart';
import '../../features/settings/privacy_page.dart';
import '../../features/settings/settings_options_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/staff_page.dart';
import '../../features/settings/workshop_page.dart';
import '../../features/splash/blocked_page.dart';
import '../../features/splash/restoring_page.dart';
import '../../features/splash/splash_page.dart';
import '../../features/support/support_page.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import '../../state/providers.dart';
import '../theme/app_tokens.dart';
import 'app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Rebuilds the redirect whenever the gate changes — either the Supabase
/// session or, with no backend configured, the on-device flag.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(adminProvider, (prev, next) {
      final changed =
          prev?.signedIn != next.signedIn ||
          prev?.onboarded != next.onboarded ||
          (prev?.garage == null) != (next.garage == null) ||
          prev?.garage?.blocked != next.garage?.blocked;
      if (changed) notifyListeners();
    });
    ref.listen(signedInProvider, (prev, next) {
      if (prev != next) notifyListeners();
    });
    // The gate also waits on the workshop arriving, so it has to re-run when
    // that lands.
    ref.listen(restoringProvider, (prev, next) {
      if (prev != next) notifyListeners();
    });
    // A restore that failed and a password reset link both change where the
    // gate sends somebody, so both have to wake it.
    ref.listen(restoreFailedProvider, (prev, next) {
      if (prev != next) notifyListeners();
    });
    ref.listen(passwordRecoveryProvider, (prev, next) {
      if (prev != next) notifyListeners();
    });
    // A role that changes under an open screen (the owner made a manager a
    // mechanic) has to be able to send that screen home.
    ref.listen(accessProvider, (prev, next) {
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

      // A reset link comes in with a session of its own, so this has to be
      // checked before anything that would let it pass for a normal one.
      // Nothing else in the console is reachable until the new password is
      // saved, or the old one silently stays in force.
      if (ref.read(passwordRecoveryProvider)) {
        return loc == '/reset-password' ? null : '/reset-password';
      }

      if (!data.onboarded) {
        return loc == '/onboarding' ? null : '/onboarding';
      }
      if (!ref.read(signedInProvider)) {
        const authRoutes = {'/login'};
        return authRoutes.contains(loc) ? null : '/login';
      }
      // Signed in, but we do not yet know whether this account already has a
      // workshop. Deciding now is what used to flash the registration form at
      // an owner who was simply signing back in.
      if (ref.read(restoringProvider)) {
        return loc == '/restoring' ? null : '/restoring';
      }
      if (data.garage == null) {
        // A workshop we could not reach is not a workshop that does not
        // exist. Signing out clears it from the device, so after a sign-in
        // the backend is the only thing that knows this account already has
        // one — and handing somebody the registration form because the
        // network blinked is how the same shop gets registered twice.
        //
        // But only where a workshop was actually registered here. On a first
        // run there is nothing to wait for, and holding somebody at a retry
        // screen for a shop they have never opened is a wall with no door.
        if (ref.read(restoreFailedProvider) && localStore.everRegistered) {
          return loc == '/restoring' ? null : '/restoring';
        }
        return loc == '/setup' ? null : '/setup';
      }
      // Blocked by the platform: nothing but the way to support. Platform
      // stays reachable for a partner head whose own workshop this is; it
      // shows nothing to anybody else.
      if (data.garage!.blocked) {
        const open = {'/blocked', '/platform', '/platform/admin'};
        return open.contains(loc) ? null : '/blocked';
      }
      const gateRoutes = {
        '/login',
        '/onboarding',
        '/setup',
        '/restoring',
        '/blocked',
      };
      if (gateRoutes.contains(loc)) return '/home';
      // A tile the role does not get is hidden; this is for the link, the
      // notification tap or the back stack that still leads there.
      if (!ref.read(accessProvider).allows(loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/setup', builder: (_, _) => const SetupPage()),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordPage(),
      ),
      GoRoute(path: '/restoring', builder: (_, _) => const RestoringPage()),
      GoRoute(path: '/blocked', builder: (_, _) => const BlockedPage()),

      // The bar carries five slots but only three are pages: Create is a
      // push and Support is a sheet.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const DashboardPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/search', builder: (_, _) => const SearchPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),

      // --- job card ---------------------------------------------------
      GoRoute(
        path: '/jobs',
        builder: (_, state) => JobCardListPage(
          initial: JobStatusX.parse(
            state.uri.queryParameters['status'] ?? 'open',
          ),
        ),
      ),
      GoRoute(
        path: '/job/new',
        builder: (_, state) => CreateJobCardPage(
          bookingId: state.uri.queryParameters['booking'],
          vehicleId: state.uri.queryParameters['vehicle'],
          estimateId: state.uri.queryParameters['estimate'],
        ),
      ),
      GoRoute(
        path: '/job/:id',
        builder: (_, state) => JobCardDetailPage(
          id: state.pathParameters['id']!,
          initialDoc: DocKindX.parse(
            state.uri.queryParameters['doc'] ?? 'estimate',
          ),
        ),
        routes: [
          GoRoute(
            path: 'items',
            builder: (_, state) => ItemsPage(
              id: state.pathParameters['id']!,
              initial: LineKindX.parse(
                state.uri.queryParameters['kind'] ?? 'job',
              ),
            ),
          ),
          GoRoute(
            path: 'voices',
            builder: (_, state) => VoicesPage(id: state.pathParameters['id']!),
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
          GoRoute(
            path: 'mechanics',
            builder: (_, state) =>
                MechanicsPage(id: state.pathParameters['id']!),
          ),
        ],
      ),

      // --- the console grid -------------------------------------------
      GoRoute(
        path: '/inventory',
        builder: (_, _) => const InventoryDashboardPage(),
      ),
      GoRoute(
        path: '/inventory/master',
        builder: (_, state) => MasterListPage(
          initial: LineKindX.parse(
            state.uri.queryParameters['kind'] ?? 'spare',
          ),
        ),
      ),
      GoRoute(
        path: '/inventory/suppliers',
        builder: (_, _) => const SuppliersPage(),
      ),
      GoRoute(
        path: '/inventory/counter-sales',
        builder: (_, _) => const CounterSaleListPage(),
      ),
      GoRoute(
        path: '/inventory/counter-sale/new',
        builder: (_, _) => const CounterSalePage(),
      ),
      GoRoute(
        path: '/inventory/purchase-orders',
        builder: (_, _) => const PurchaseOrdersPage(),
      ),
      GoRoute(
        path: '/inventory/purchase-order/new',
        builder: (_, _) => const CreatePurchaseOrderPage(),
      ),
      // The platform back office. Reachable by URL for anybody, and
      // deliberately so: every list it shows comes back empty and every
      // write it attempts is refused unless the account holds the
      // `platform` role. The guard is the database, not this table.
      GoRoute(path: '/platform', builder: (_, _) => const PlatformPage()),
      GoRoute(
        path: '/platform/admin',
        builder: (_, s) => PlatformPage(
          admin: true,
          initialTab: s.uri.queryParameters['tab'] == 'media'
              ? PlatformTab.content
              : null,
        ),
      ),
      GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsPage()),
      GoRoute(
        path: '/analytics/revenue',
        builder: (_, _) => const RevenueAnalyticsPage(),
      ),
      GoRoute(
        path: '/analytics/vehicle',
        builder: (_, _) => const VehicleAnalyticsPage(),
      ),
      GoRoute(
        path: '/online-garage',
        builder: (_, _) => const OnlineGaragePage(),
      ),
      GoRoute(path: '/expenses', builder: (_, _) => const ExpensesPage()),
      GoRoute(path: '/cashbook', builder: (_, _) => const CashBookPage()),

      // --- sales, purchase, estimates, bank -----------------------------
      GoRoute(
        path: '/sales',
        builder: (_, st) => SalesPage(tab: st.uri.queryParameters['tab']),
      ),
      GoRoute(
        path: '/purchase',
        builder: (_, st) => PurchasePage(tab: st.uri.queryParameters['tab']),
      ),
      GoRoute(path: '/estimates', builder: (_, _) => const EstimatesPage()),
      GoRoute(
        path: '/trade/new',
        builder: (_, st) => TradeFormPage(
          kind: TradeKindX.parse(st.uri.queryParameters['kind']),
          fromId: st.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: '/trade/:id',
        builder: (_, st) => TradeDetailPage(id: st.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bank-accounts',
        builder: (_, _) => const BankAccountsPage(),
      ),
      GoRoute(
        path: '/bank-accounts/:id',
        builder: (_, st) => AccountStatementPage(id: st.pathParameters['id']!),
      ),
      GoRoute(
        path: '/grow-business',
        builder: (_, _) => const GrowBusinessPage(),
      ),
      GoRoute(
        path: '/settings/sync-share',
        builder: (_, _) => const SyncSharePage(),
      ),
      GoRoute(path: '/service-due', builder: (_, _) => const ServiceDuePage()),

      // --- reports ----------------------------------------------------
      GoRoute(path: '/reports', builder: (_, _) => const ReportSummaryPage()),
      GoRoute(path: '/reports/sms', builder: (_, _) => const SmsReportPage()),
      GoRoute(
        path: '/reports/stock',
        builder: (_, _) => const StockJobsReportPage(),
      ),
      GoRoute(path: '/reports/sale', builder: (_, _) => const SaleReportPage()),
      GoRoute(
        path: '/reports/counter-sales',
        builder: (_, _) => const CounterSalesReportPage(),
      ),
      GoRoute(
        path: '/reports/general',
        builder: (_, _) => const GeneralReportPage(),
      ),
      GoRoute(
        path: '/reports/customer',
        builder: (_, _) => SaleReportPage(title: 'Customer Report'.tr),
      ),
      GoRoute(
        path: '/reports/mechanic',
        builder: (_, _) => const MechanicReportPage(),
      ),

      // --- front desk -------------------------------------------------
      GoRoute(
        path: '/bookings',
        builder: (_, state) =>
            BookingsPage(focusId: state.uri.queryParameters['open']),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(path: '/pending', builder: (_, _) => const PendingPage()),
      GoRoute(path: '/feedback', builder: (_, _) => const FeedbackPage()),
      GoRoute(path: '/customers', builder: (_, _) => const CustomersPage()),
      GoRoute(
        path: '/customer/:id',
        builder: (_, state) =>
            CustomerDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings/options',
        builder: (_, _) => const SettingsOptionsPage(),
      ),
      GoRoute(
        path: '/settings/language',
        builder: (_, _) => const LanguagePage(),
      ),
      GoRoute(
        path: '/settings/greetings',
        builder: (_, _) => const GreetingsPage(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, _) => const PrivacyPage(),
      ),
      GoRoute(
        path: '/settings/credits',
        builder: (_, _) => const CreditsPage(),
      ),
      GoRoute(
        path: '/settings/commission',
        builder: (_, _) => const CommissionPage(),
      ),

      // --- the team ---------------------------------------------------
      GoRoute(path: '/attendance', builder: (_, _) => const AttendancePage()),
      GoRoute(
        path: '/attendance/register',
        builder: (_, _) => const AttendanceRegisterPage(),
      ),
      GoRoute(
        path: '/attendance/site',
        builder: (_, _) => const AttendanceSitePage(),
      ),
      GoRoute(path: '/contacts', builder: (_, _) => const ContactsPage()),

      GoRoute(path: '/support', builder: (_, _) => const SupportPage()),
      GoRoute(path: '/workshop', builder: (_, _) => const WorkshopPage()),
      GoRoute(path: '/staff', builder: (_, _) => const StaffPage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.page),
          child: Text('No screen at {0}'.trf([state.uri])),
        ),
      ),
    ),
  );
});
