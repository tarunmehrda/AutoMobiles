import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/i18n/app_language.dart';
import 'package:garagepro_admin/core/i18n/strings.dart';
import 'package:garagepro_admin/core/router/app_router.dart';
import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/core/widgets/g_badge.dart';
import 'package:garagepro_admin/core/widgets/g_feedback.dart';
import 'package:garagepro_admin/core/widgets/g_field.dart';
import 'package:garagepro_admin/core/widgets/pressable.dart';
import 'package:garagepro_admin/data/models/attendance.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/data/repo/platform_gateway.dart';
import 'package:garagepro_admin/features/auth/login_page.dart';
import 'package:garagepro_admin/features/auth/reset_password_page.dart';
import 'package:garagepro_admin/features/auth/setup_page.dart';
import 'package:garagepro_admin/features/auth/widgets/terms_sheet.dart';
import 'package:garagepro_admin/features/inventory/suppliers_page.dart';
import 'package:garagepro_admin/features/jobcard/billing/master_actions.dart';
import 'package:garagepro_admin/features/jobcard/panels/items_page.dart';
import 'package:garagepro_admin/features/jobcard/widgets/close_sheet.dart';
import 'package:garagepro_admin/features/jobcard/widgets/complete_sheet.dart';
import 'package:garagepro_admin/features/jobcard/widgets/ledger_tabs.dart';
import 'package:garagepro_admin/features/money/cashbook_page.dart';
import 'package:garagepro_admin/features/money/expenses_page.dart';
import 'package:garagepro_admin/features/onboarding/onboarding_page.dart';
import 'package:garagepro_admin/features/online/online_garage_page.dart';
import 'package:garagepro_admin/features/shared/support_sheet.dart';
import 'package:garagepro_admin/features/splash/blocked_page.dart';
import 'package:garagepro_admin/features/splash/restoring_page.dart';
import 'package:garagepro_admin/state/admin_state.dart';
import 'package:garagepro_admin/state/auth_state.dart';

/// Walks every screen, tab, and the main sheets of the console at the phone
/// sizes and font scales the floor actually uses, and fails on any
/// "OVERFLOWED BY N PIXELS" stripe.
///
/// The smoke test only catches screens that throw. An overflow does not
/// throw: it paints yellow and black and reports through FlutterError, so it
/// is collected here rather than failing on the first one, and the report
/// names the screen, the shape and the widget that overflowed.
///
/// Scale 1.3 is a large system font. The app clamps text to 1.25
/// (app.dart), and the host below does the same, so 1.3 here is exactly
/// what a phone set to "large" renders.

// --- shapes -----------------------------------------------------------------

typedef _Shape = ({double w, double h, double scale});

const _sizes = <Size>[Size(360, 640), Size(412, 915), Size(320, 568)];
const _scales = <double>[1.0, 1.3];

String _name(_Shape s) =>
    '${s.w.toInt()}x${s.h.toInt()} @${s.scale.toStringAsFixed(1)}';

// --- the fake platform ------------------------------------------------------

class _FakePlatform implements PlatformGateway {
  _FakePlatform({required this.head, required this.populated});

  final bool head;
  final bool populated;

  @override
  Future<bool> amPlatformAdmin() async => head;

  @override
  Future<bool?> checkPlatformAdmin() async => head;

  @override
  Future<List<PlatformHead>?> heads() async => populated
      ? const [
          PlatformHead(email: 'vjalaria@example.com', enabled: true, me: true),
          PlatformHead(
            email: 'balajiautomobiles088.very.long.address@example.com',
            enabled: false,
          ),
        ]
      : const [];

  @override
  Future<List<RegisteredGarage>?> garages() async => populated
      ? const [
          RegisteredGarage(
            id: 'g1',
            name: 'Shree Balaji Automobiles and Multi Brand Car Care',
            owner: 'Ramesh Chandra Sharma',
            phone: '9812345670',
            email: 'balaji.automobiles.longname@example.com',
            city: 'Sanganer',
            district: 'Jaipur',
            state: 'Rajasthan',
            pin: '302029',
            listed: true,
            verified: true,
            members: 12,
            cards: 1240,
          ),
          RegisteredGarage(
            id: 'g2',
            name: 'Vikas Automobiles',
            city: 'Jaipur',
            state: 'Rajasthan',
            pin: '302020',
            blocked: true,
          ),
        ]
      : const [];

  @override
  Future<List<PlatformRequest>?> requests({
    String? status,
    String? garageId,
  }) async => populated
      ? [
          PlatformRequest(
            id: 'r1',
            code: 'REQ-000123',
            vehicleText: 'Maruti Suzuki Swift Dzire VXI 2019 Petrol',
            partName: 'Front bumper assembly with fog lamp housing',
            detail: 'Customer wants the original part, not aftermarket.',
            quote: 125000,
            garageId: 'g1',
            createdAt: DateTime(2026, 9, 1),
          ),
          PlatformRequest(
            id: 'r2',
            code: 'REQ-000124',
            partName: 'Clutch plate',
            status: 'approved',
            createdAt: DateTime(2026, 9, 2),
          ),
        ]
      : const [];

  @override
  Future<List<PlatformListing>?> listings({
    String? status,
    String? garageId,
  }) async => populated
      ? [
          PlatformListing(
            id: 'l1',
            title: 'Hyundai Creta headlamp assembly left side OEM',
            detail: 'Barely used, no scratches, includes wiring.',
            partNo: '92101-M0000-LONG',
            price: 1250000,
            vehicleText: 'Hyundai Creta SX 2021 Diesel',
            city: 'Jaipur',
            createdAt: DateTime(2026, 9, 3),
          ),
        ]
      : const [];

  @override
  Future<PlatformSettings> settings() async => const PlatformSettings(
    introVideoUrl: 'https://example.com/a/very/long/video/url/intro.mp4',
    introVideoOn: true,
  );

  @override
  Future<List<GarageCommission>?> commissionSummary() async => populated
      ? const [
          GarageCommission(
            garageId: 'g1',
            name: 'Shree Balaji Automobiles and Multi Brand Car Care',
            phone: '9812345670',
            customRate: 4.5,
            rate: 4.5,
            lines: 120,
            billed: 12500000,
            accrued: 562500,
            invoiced: 125000,
            settled: 9999999,
          ),
        ]
      : const [];

  @override
  Future<List<CommissionLine>?> commissions(String garageId) async => populated
      ? [
          CommissionLine(
            id: 'c1',
            garageId: garageId,
            amount: 1250000,
            pct: 4.5,
            fee: 56250,
            note: 'Job card JC-000123 closed, full service and body work',
            at: DateTime(2026, 9, 1),
            jobCardId: 'jc1',
          ),
        ]
      : const [];

  @override
  Future<({bool ok, GarageCommission? mine})> myCommission(
    String garageId,
  ) async => (
    ok: true,
    mine: GarageCommission(
      garageId: garageId,
      name: 'Vikas Automobiles',
      lines: populated ? 3 : 0,
      billed: populated ? 12500000 : 0,
      accrued: populated ? 562500 : 0,
      settled: populated ? 9999999 : 0,
      recent: populated
          ? [
              CommissionLine(
                id: 'c1',
                garageId: garageId,
                amount: 1250000,
                pct: 4.5,
                fee: 56250,
                note: 'Job card closed',
                at: DateTime(2026, 9, 1),
                jobCardId: 'jc1',
              ),
            ]
          : const [],
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// --- the workshop -----------------------------------------------------------

Future<ProviderContainer> _shop({
  required bool seeded,
  required bool head,
}) async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();

  final fake = _FakePlatform(head: head, populated: seeded);
  final container = ProviderContainer(
    overrides: [
      signedInProvider.overrideWithValue(true),
      platformGatewayProvider.overrideWithValue(fake),
      isPlatformAdminProvider.overrideWith((_) async => head),
    ],
  );
  final c = container.read(adminProvider.notifier);

  c.completeOnboarding();
  c.saveGarage(
    const Garage(
      id: 'garage-test',
      name: 'Shree Balaji Automobiles and Multi Brand Car Care',
      phone: '9000000000',
      email: 'balaji.automobiles.longname@example.com',
      addressLine: 'Plot 14, Behind Petrol Pump, Tonk Road Industrial Area',
      city: 'Jaipur',
      state: 'Rajasthan',
      pin: '302020',
      upiId: 'balajiautomobiles088@okhdfcbank',
    ),
  );
  if (!seeded) return container;

  c.addMaster(kind: LineKind.job, name: 'General Service Labour', rate: 900);
  c.addMaster(
    kind: LineKind.spare,
    name: 'Front Bumper Assembly with Fog Lamp Housing (OEM)',
    partNo: 'OF-11-LONG-PART-NUMBER',
    rate: 125000,
    stock: 6,
  );
  c.addMaster(
    kind: LineKind.lube,
    name: 'Engine Oil 5W30',
    rate: 620,
    stock: 1,
  );
  final staff = c.addStaff(
    name: 'Ramesh Kumar Chandrashekhar',
    phone: '9812345670',
    skill: 'Engine and Transmission',
  );

  final customer = c.upsertCustomer(
    name: 'Tarun Sharma Venkataraghavan',
    phone: '9462153613',
  );
  final vehicle = c.upsertVehicle(
    customerId: customer.id,
    regNo: 'RJ18CC1390',
    brand: 'Maruti Suzuki',
    model: 'Swift Dzire VXI',
  );

  final card = c.createJobCard(
    customerId: customer.id,
    vehicleId: vehicle.id,
    odometerKm: 141000,
    fuelPercent: 60,
    mechanicIds: [staff.id],
    voices: const ['Brake Check', 'AC not cooling in the rear cabin at all'],
    accessories: const ['Tool kit', 'Spare wheel'],
  );
  c.addItem(card.id, kind: LineKind.job, name: 'Carburator Setting', rate: 70);
  c.addItem(
    card.id,
    kind: LineKind.spare,
    name: 'Front Bumper Assembly with Fog Lamp Housing (OEM)',
    rate: 125000,
  );
  c.addPayment(card.id, amount: 20, mode: PayMode.cash);
  c.addExpense(title: 'Shop rent for the month', amount: 128000, paid: 8000);
  c.addCash(party: 'Walk-in', amount: 1250000, inward: true, reason: 'Counter');
  c.addSupplier(name: 'Sharma Spares and Accessories', phone: '9812300000');
  c.setOnlineGarage(true);
  c.addOnlineService(name: 'General Servicing and Washing', price: 12000);
  c.setAttendanceSite(
    const AttendanceSite(
      lat: 26.912434,
      lng: 75.787270,
      label: 'Main workshop',
    ),
  );
  c.addBooking(
    Booking(
      id: 'bk-1',
      name: 'Amit Verma Subramanian',
      phone: '9001122334',
      at: DateTime.now().add(const Duration(hours: 2)),
      regNo: 'RJ14CX4455',
      vehicle: 'Hyundai Creta SX Diesel',
      note: 'General service, Wheel alignment, AC gas top-up',
      brand: 'Hyundai',
      model: 'Creta',
      variant: 'SX',
      fuel: FuelType.diesel,
      transmission: Transmission.manual,
      year: 2021,
      odometerKm: 42000,
      customerNote: 'AC not cooling',
    ),
  );
  return container;
}

List<String> _routes(ProviderContainer container) {
  final data = container.read(adminProvider);
  final card = data.jobCards.isEmpty ? null : data.jobCards.first;
  final customer = data.customers.isEmpty ? null : data.customers.first;
  return [
    '/home',
    '/search',
    '/settings',
    '/settings/options',
    '/settings/language',
    '/settings/greetings',
    '/settings/privacy',
    '/settings/credits',
    '/settings/commission',
    '/jobs?status=open',
    '/jobs?status=complete',
    '/jobs?status=closed',
    '/job/new',
    if (card != null) ...[
      '/job/${card.id}',
      '/job/${card.id}?doc=invoice',
      '/job/${card.id}/items?kind=job',
      '/job/${card.id}/items?kind=spare',
      '/job/${card.id}/items?kind=lube',
      '/job/${card.id}/voices',
      '/job/${card.id}/accessories',
      '/job/${card.id}/note',
      '/job/${card.id}/dents',
      '/job/${card.id}/photos',
      '/job/${card.id}/mechanics',
    ],
    '/inventory',
    '/inventory/master?kind=spare',
    '/inventory/master?kind=lube',
    '/inventory/master?kind=job',
    '/inventory/suppliers',
    '/inventory/counter-sales',
    '/inventory/counter-sale/new',
    '/inventory/purchase-orders',
    '/inventory/purchase-order/new',
    '/platform',
    '/platform/admin',
    '/analytics',
    '/analytics/revenue',
    '/analytics/vehicle',
    '/online-garage',
    '/expenses',
    '/cashbook',
    '/sales?tab=invoice',
    '/sales?tab=return',
    '/sales?tab=order',
    '/sales?tab=paymentIn',
    '/purchase?tab=bill',
    '/purchase?tab=payOut',
    '/purchase?tab=return',
    '/purchase?tab=order',
    '/estimates',
    '/trade/new?kind=estimate',
    '/trade/new?kind=purchaseBill',
    '/trade/new?kind=saleOrder',
    '/bank-accounts',
    '/bank-accounts/cash-in-hand',
    '/grow-business',
    '/settings/sync-share',
    if (card != null) '/job/${card.id}?doc=mechanicCopy',
    '/service-due',
    '/reports',
    '/reports/sms',
    '/reports/stock',
    '/reports/sale',
    '/reports/counter-sales',
    '/reports/general',
    '/reports/customer',
    '/reports/mechanic',
    '/bookings',
    '/notifications',
    '/pending',
    '/feedback',
    '/customers',
    if (customer != null) '/customer/${customer.id}',
    '/support',
    '/workshop',
    '/staff',
    '/attendance',
    '/attendance/register',
    '/attendance/site',
    '/contacts',
  ];
}

/// Screens with a text field that the keyboard comes up over.
bool _hasForm(String route) =>
    route == '/job/new' ||
    route.endsWith('/note') ||
    route.endsWith('/voices') ||
    route.endsWith('/accessories') ||
    route.contains('/new') ||
    route == '/workshop' ||
    route == '/search' ||
    route == '/settings/greetings' ||
    route == '/staff';

/// Gate pages and sheets with a text field, so the keyboard can come up.
const _gateFields = {'login', 'setup', 'reset-password'};
const _sheetFields = {
  'supplier',
  'cash in',
  'expense',
  'online service',
  'line editor',
  'line editor (edit)',
  'collect',
  'complete',
  'close',
};

/// Custom tab labels that are not a [GSegmented], [GChoiceChips] or [Tab].
const _labelTabs = <String, List<String>>{
  '/platform': ['Requests', 'Listings'],
  '/platform/admin': ['Partners', 'Media', 'Heads'],
};

// --- the collector ----------------------------------------------------------

/// `--dart-define=SWEEP_DEBUG=<text>` prints the whole error for any hit
/// whose screen or location contains that text.
const _debug = String.fromEnvironment('SWEEP_DEBUG');

final _fileRef = RegExp(r'file:///[^\s)]*?/lib/[^\s):]+:\d+:\d+');

class _Collector {
  final hits = <String, Set<String>>{};
  final other = <String, Set<String>>{};
  String where = '';

  void call(FlutterErrorDetails d) {
    final text = d.toString();
    final head = d.exceptionAsString().split('\n').first.trim();
    final refs = _fileRef
        .allMatches(text)
        .map((m) => m.group(0)!.replaceFirst(RegExp(r'.*/lib/'), 'lib/'))
        .toSet()
        .take(2)
        .join(' <- ');
    final overflow =
        text.contains('overflowed') ||
        text.contains('OVERFLOWING') ||
        head.contains('overflow');
    final shape = head.replaceAll(RegExp(r'[\d.]+ pixels'), 'N pixels');
    final key = '$shape @ ${refs.isEmpty ? '(no creator)' : refs}';
    (overflow ? hits : other).putIfAbsent(key, () => {}).add('$where ($head)');
    if (_debug.isNotEmpty && '$where $key'.contains(_debug)) {
      // ignore: avoid_print
      print('---- $where\n$text');
    }
  }

  String report() {
    final b = StringBuffer();
    void dump(String title, Map<String, Set<String>> m) {
      if (m.isEmpty) return;
      b.writeln('==== $title: ${m.length} distinct');
      for (final e in m.entries) {
        b.writeln('* ${e.key}');
        for (final w in e.value.take(6)) {
          b.writeln('    $w');
        }
        if (e.value.length > 6) b.writeln('    ... +${e.value.length - 6}');
      }
    }

    dump('OVERFLOWS', hits);
    dump('OTHER ERRORS', other);
    return b.toString();
  }
}

// --- the host ---------------------------------------------------------------

/// The same text clamp app.dart applies, so a large system font renders here
/// exactly as it does on the phone.
Widget _clamp(BuildContext context, Widget? child) {
  final mq = MediaQuery.of(context);
  return MediaQuery(
    data: mq.copyWith(
      textScaler: mq.textScaler.clamp(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.25,
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}

void _setShape(WidgetTester tester, _Shape s, {bool keyboard = false}) {
  const dpr = 3.0;
  tester.view.physicalSize = Size(s.w * dpr, s.h * dpr);
  tester.view.devicePixelRatio = dpr;
  // A punch-hole status bar and gesture navigation, as on the phone this
  // came from.
  tester.view.padding = const FakeViewPadding(top: 40 * dpr);
  tester.view.viewPadding = const FakeViewPadding(top: 40 * dpr);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard ? 300 * dpr : 0);
  tester.platformDispatcher.textScaleFactorTestValue = s.scale;
}

void _reset(WidgetTester tester) {
  tester.view.reset();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
}

Future<void> _settle(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Finder _tabTargets() {
  final segments = find.descendant(
    of: find.byWidgetPredicate((w) => w is GSegmented || w is GChoiceChips),
    matching: find.byType(Pressable),
  );
  return find
          .byWidgetPredicate((w) => w is Tab)
          .hitTestable()
          .evaluate()
          .isNotEmpty
      ? find.byWidgetPredicate((w) => w is Tab).hitTestable()
      : segments.hitTestable();
}

Future<void> _walkTabs(
  WidgetTester tester,
  _Collector col,
  String base,
  String route,
) async {
  final labels = _labelTabs[route] ?? const [];
  for (final label in labels) {
    final f = find.text(label).hitTestable();
    if (f.evaluate().isEmpty) continue;
    col.where = '$base tab "$label"';
    await tester.tap(f.first, warnIfMissed: false);
    await _settle(tester, 6);
    tester.takeException();
  }
  final count = _tabTargets().evaluate().length;
  for (var i = 0; i < count && i < 8; i++) {
    final f = _tabTargets();
    if (f.evaluate().length <= i) break;
    col.where = '$base tab #$i';
    await tester.tap(f.at(i), warnIfMissed: false);
    await _settle(tester, 6);
    tester.takeException();
  }
}

Future<void> _app(
  WidgetTester tester,
  ProviderContainer container, {
  Widget? home,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: home == null
          ? MaterialApp.router(
              routerConfig: container.read(routerProvider),
              theme: AppTheme.light(),
              debugShowCheckedModeBanner: false,
              builder: _clamp,
            )
          : MaterialApp(
              theme: AppTheme.light(),
              debugShowCheckedModeBanner: false,
              builder: _clamp,
              home: home,
            ),
    ),
  );
}

Future<void> _sweepRoutes(
  WidgetTester tester,
  _Collector col,
  _Shape shape, {
  required bool seeded,
  required bool head,
}) async {
  final container = await _shop(seeded: seeded, head: head);
  addTearDown(container.dispose);
  _setShape(tester, shape);
  await _app(tester, container);

  final router = container.read(routerProvider);
  final state = '${seeded ? 'seeded' : 'empty'}${head ? ', head' : ''}';
  for (final route in _routes(container)) {
    final base = '[${_name(shape)} $state] $route';
    col.where = base;
    _setShape(tester, shape);
    router.go(route);
    await _settle(tester);
    tester.takeException();
    await _walkTabs(tester, col, base, route);

    if (_hasForm(route) && shape.w == 360 && shape.scale > 1) {
      col.where = '$base +keyboard';
      router.go('/home');
      await _settle(tester, 2);
      router.go(route);
      await _settle(tester, 2);
      _setShape(tester, shape, keyboard: true);
      await _settle(tester, 4);
      tester.takeException();
      _setShape(tester, shape);
    }
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester, 2);
}

Future<void> _sweepGates(
  WidgetTester tester,
  _Collector col,
  _Shape shape,
) async {
  final pages = <String, Widget>{
    'onboarding': const OnboardingPage(),
    'login': const LoginPage(),
    'setup': const SetupPage(),
    'reset-password': const ResetPasswordPage(),
    'restoring': const RestoringPage(),
    'blocked': const BlockedPage(),
  };
  for (final e in pages.entries) {
    for (final keyboard in [false, true]) {
      // Only where there is something to type into (the login's email form
      // is a sheet over the page, so the page sees the keyboard too).
      if (keyboard && !_gateFields.contains(e.key)) continue;
      final container = await _shop(seeded: false, head: false);
      col.where =
          '[${_name(shape)}] gate /${e.key}'
          '${keyboard ? ' +keyboard' : ''}';
      _setShape(tester, shape, keyboard: keyboard);
      await _app(tester, container, home: e.value);
      await _settle(tester);
      tester.takeException();
      await tester.pumpWidget(const SizedBox.shrink());
      await _settle(tester, 2);
      container.dispose();
    }
  }
}

/// Opens each of the main sheets over a seeded workshop and closes it again.
Future<void> _sweepSheets(
  WidgetTester tester,
  _Collector col,
  _Shape shape,
) async {
  final container = await _shop(seeded: true, head: false);
  addTearDown(container.dispose);
  _setShape(tester, shape);
  await _app(tester, container);
  final router = container.read(routerProvider);
  final data = container.read(adminProvider);
  final card = data.jobCards.first;

  router.go('/job/${card.id}');
  await _settle(tester);
  tester.takeException();

  BuildContext ctx() => tester.element(find.byType(Scaffold).first);
  WidgetRef ref() =>
      tester.element(
            find.byWidgetPredicate((w) => w is ConsumerStatefulWidget).last,
          )
          as WidgetRef;

  final sheets = <String, void Function()>{
    'support': () => showSupportSheet(ctx()),
    'supplier': () => showSupplierSheet(ctx()),
    'cash in': () => showCashSheet(ctx(), inward: true),
    'expense': () => showExpenseSheet(ctx()),
    'online service': () => showAddServiceSheet(ctx()),
    'terms': () => showTermsSheet(ctx()),
    'line editor': () =>
        showLineEditor(ctx(), kind: LineKind.spare, staff: data.staff),
    'line editor (edit)': () => showLineEditor(
      ctx(),
      kind: LineKind.spare,
      staff: data.staff,
      existing: card.items.last,
    ),
    'collect': () => showCollectSheet(ctx(), ref(), card),
    'complete': () => showCompleteSheet(ctx(), ref(), card),
    'close': () => showCloseSheet(ctx(), ref(), card),
    'master actions': () => showMasterActions(
      ctx(),
      ref(),
      data.masters.firstWhere((m) => m.kind == LineKind.spare),
      tint: Colors.teal,
    ),
    'confirm': () => GFeedback.confirm(
      ctx(),
      title: 'Delete this job card for good?',
      message:
          'The card, its items and its payments are removed. This '
          'cannot be undone.',
      confirmLabel: 'Delete permanently',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    ),
  };

  for (final e in sheets.entries) {
    for (final keyboard in [false, true]) {
      if (keyboard && !_sheetFields.contains(e.key)) continue;
      col.where =
          '[${_name(shape)}] sheet "${e.key}"'
          '${keyboard ? ' +keyboard' : ''}';
      _setShape(tester, shape, keyboard: keyboard);
      await _settle(tester, 2);
      final before = tester.state<NavigatorState>(find.byType(Navigator).first);
      e.value();
      await _settle(tester, 6);
      tester.takeException();
      // Close whatever opened, however many layers deep.
      before.popUntil((r) => r is! PopupRoute);
      await _settle(tester, 4);
      tester.takeException();
    }
  }
  _setShape(tester, shape);
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester, 2);
}

/// The app's own typefaces, so a line of text is as wide here as it is on
/// the phone. The test default draws every glyph as a full-em square, which
/// overstates widths by half again and would flag layouts that fit.
Future<void> _loadFonts() async {
  const families = {
    'Sora': [400, 500, 600, 700, 800],
    'Inter': [400, 500, 600, 700],
    'NotoDeva': [400, 500, 600],
  };
  for (final f in families.entries) {
    final loader = FontLoader(f.key);
    for (final w in f.value) {
      loader.addFont(rootBundle.load('assets/fonts/${f.key}-$w.ttf'));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting();
    // `--dart-define=SWEEP_AHEM=true` keeps the square test font: a
    // harsher run, roughly what a wide script or a long name does.
    if (!const bool.fromEnvironment('SWEEP_AHEM')) await _loadFonts();
  });

  for (final size in _sizes) {
    for (final scale in _scales) {
      final shape = (w: size.width, h: size.height, scale: scale);
      testWidgets('no overflow anywhere at ${_name(shape)}', (tester) async {
        Tr.use(AppLanguage.en);
        final col = _Collector();
        final previous = FlutterError.onError;
        FlutterError.onError = col.call;
        try {
          for (final seeded in [true, false]) {
            await _sweepRoutes(tester, col, shape, seeded: seeded, head: false);
          }
          // A partner head sees the Platform tabs and the commission ledger.
          for (final seeded in [true, false]) {
            await _sweepRoutes(tester, col, shape, seeded: seeded, head: true);
          }
          await _sweepGates(tester, col, shape);
          await _sweepSheets(tester, col, shape);
        } finally {
          FlutterError.onError = previous;
          _reset(tester);
        }
        final report = col.report();
        // ignore: avoid_print
        if (report.isNotEmpty) print(report);
        expect(col.hits, isEmpty, reason: report);
      });
    }
  }
}
