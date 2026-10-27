import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro/core/router/app_router.dart';
import 'package:garagepro/core/theme/app_theme.dart';
import 'package:garagepro/data/models/directory.dart';
import 'package:garagepro/data/models/entities.dart';
import 'package:garagepro/data/models/enums.dart';
import 'package:garagepro/data/models/marketplace.dart';
import 'package:garagepro/data/models/workshop.dart';
import 'package:garagepro/data/repo/directory_gateway.dart';
import 'package:garagepro/data/repo/local_store.dart';
import 'package:garagepro/data/repo/marketplace_gateway.dart';
import 'package:garagepro/data/repo/partner_gateway.dart';
import 'package:garagepro/features/marketplace/widgets/listing_sheet.dart';
import 'package:garagepro/features/search/widgets/garage_sheet.dart';
import 'package:garagepro/features/workshop/widgets/booking_details_sheet.dart';
import 'package:garagepro/features/workshop/widgets/rate_sheet.dart';
import 'package:garagepro/features/workshop/widgets/workshop_details_sheet.dart';
import 'package:garagepro/state/app_state.dart';
import 'package:garagepro/state/auth_state.dart';

/// Opens every screen of the customer app at the sizes and font scales real
/// phones use, and fails on any "OVERFLOWED BY N PIXELS" stripe.
///
/// The customer this was written for runs a large system font on a ~412dp
/// wide phone, so every screen is pumped at 320x568, 360x640 and 412x915,
/// each at text scale 1.0 and 1.3 (the app clamps the device setting to
/// 1.25; 1.3 leaves a little headroom), and form screens again with the soft
/// keyboard up. The real Sora/Inter fonts are loaded, because the test font
/// draws every glyph a full em wide and would report overflows no phone has.
///
/// Overflows are collected rather than thrown, so one run lists all of them:
/// screen, size, scale, the message, and the widget that overflowed.
///
/// Run with `flutter test test/overflow_sweep_test.dart`.

// ---------------------------------------------------------------------------
// Sizes
// ---------------------------------------------------------------------------

const _sizes = [Size(320, 568), Size(360, 640), Size(412, 915)];
const _scales = [1.0, 1.3];
const _keyboard = 300.0;
const _dpr = 3.0;

class _Config {
  const _Config(this.size, this.scale, {this.keyboard = false});
  final Size size;
  final double scale;
  final bool keyboard;

  @override
  String toString() =>
      '${size.width.toInt()}x${size.height.toInt()} @${scale}x'
      '${keyboard ? ' +keyboard' : ''}';
}

List<_Config> _configs({required bool form}) => [
  for (final s in _sizes)
    for (final t in _scales) _Config(s, t),
  if (form)
    for (final s in _sizes) _Config(s, 1.3, keyboard: true),
];

// ---------------------------------------------------------------------------
// Fake backends
// ---------------------------------------------------------------------------

final _now = DateTime.now();

const _longGarage = 'Shri Balaji Automobiles Multi Brand Car Care Centre';

NearbyGarage _nearby(int i) => NearbyGarage(
  id: 'g$i',
  name: i == 0 ? _longGarage : 'Hanuman Motors $i',
  phone: '946215361$i',
  addressLine: 'Plot 42, Industrial Area Phase II, Near Old Bus Stand',
  city: 'Sri Ganganagar',
  state: 'Rajasthan',
  pin: '335001',
  verified: i.isEven,
  km: i * 3.7 + 0.4,
);

const _services = [
  WorkshopService(
    id: 's1',
    name: 'Comprehensive Periodic Service with Engine Flush',
    price: 124999,
    blurb:
        'Engine oil, oil filter, air filter, cabin filter, spark plugs, '
        'brake cleaning and a 50-point inspection of the whole car.',
    durationMins: 240,
  ),
  WorkshopService(id: 's2', name: 'Wheel Alignment', price: 800),
  WorkshopService(
    id: 's3',
    name: 'AC Gas Refill',
    price: 2499,
    blurb: 'Top up and leak test',
    durationMins: 90,
  ),
];

class _FakeDirectory implements DirectoryGateway {
  _FakeDirectory({this.empty = false});
  final bool empty;

  @override
  Future<DirectoryResult> nearby({
    double? lat,
    double? lng,
    double? radiusKm,
    String query = '',
    int limit = 60,
  }) async => DirectoryResult(
    empty ? const [] : [for (var i = 0; i < 4; i++) _nearby(i)],
  );

  @override
  Future<GarageCard?> card(String garageId) async =>
      GarageCard(garage: _nearby(0), services: empty ? const [] : _services);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PartListing _listing(int i, ListingStatus s) => PartListing(
  id: 'pl$i',
  title: i == 0
      ? 'Front Bumper Assembly with Fog Lamp Housings (Original)'
      : 'Alternator $i',
  vehicleText: 'Maruti Suzuki Swift Dzire VXi AMT 2019',
  detail:
      'Barely used, no cracks. Taken off at 12,000 km when the car '
      'was upgraded. Pickup from the workshop or courier at cost.',
  partNo: '71711M79M00-799',
  condition: PartCondition.values[i % 3],
  price: 1234567,
  city: 'Sri Ganganagar',
  pin: '335001',
  status: s,
  rejectNote: s == ListingStatus.rejected
      ? 'Photos are blurry; please upload clear pictures of the part number.'
      : '',
  createdAt: _now.subtract(Duration(days: i)),
);

PartRequest _request(int i, RequestStatus s) => PartRequest(
  id: 'pr$i',
  code: 'PR-2026-00$i',
  vehicleText: 'Mercedes-Benz GLE 300d 4MATIC Coupe 2022',
  partName: 'Left Headlamp Assembly Adaptive LED with Washer',
  detail: 'Need genuine only',
  status: s,
  quote: s == RequestStatus.completed ? 245999 : null,
  note: s == RequestStatus.completed
      ? 'Genuine part, 7 days delivery, fitting included.'
      : '',
  createdAt: _now.subtract(Duration(days: i)),
);

class _FakeMarket implements MarketplaceGateway {
  _FakeMarket({this.empty = false});
  final bool empty;

  @override
  Future<List<PartListing>?> browse({
    String query = '',
    int limit = 60,
  }) async => empty
      ? const []
      : [for (var i = 0; i < 3; i++) _listing(i, ListingStatus.approved)];

  @override
  Future<List<PartListing>?> myListings() async => empty
      ? const []
      : [for (final (i, s) in ListingStatus.values.indexed) _listing(i, s)];

  @override
  Future<List<PartRequest>?> myRequests() async => empty
      ? const []
      : [for (final (i, s) in RequestStatus.values.indexed) _request(i, s)];

  @override
  Future<List<({String id, String name, String city})>?>
  listableGarages() async => [
    (id: 'g0', name: _longGarage, city: 'Sri Ganganagar'),
    (id: 'g1', name: 'Hanuman Motors', city: 'Jaipur'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePartner implements PartnerGateway {
  _FakePartner({this.registered = false});
  final bool registered;

  @override
  Future<PartnerGarage?> mine() async => registered
      ? const PartnerGarage(
          id: 'g0',
          name: _longGarage,
          phone: '9462153613',
          addressLine: 'Plot 42, Industrial Area Phase II',
          city: 'Sri Ganganagar',
          state: 'Rajasthan',
          pin: '335001',
          gstin: '08ABCDE1234F1Z5',
          lat: 29.9,
          lng: 73.8,
          listed: true,
          verified: true,
        )
      : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Accounts
// ---------------------------------------------------------------------------

enum _Stage { fresh, signedOut, restoring, noName, noVehicle, empty, full }

final _v1 = Vehicle(
  id: 'v1',
  brand: 'Maruti Suzuki',
  model: 'Swift Dzire VXi AMT',
  variant: 'VXi AMT Special Edition',
  regNumber: 'RJ18CC1390',
  fuel: FuelType.petrol,
  transmission: Transmission.automatic,
  year: 2014,
  odometerKm: 141250,
  insuranceExpiry: _now.add(const Duration(days: 3)),
  pucExpiry: _now.subtract(const Duration(days: 12)),
  lastServiceDate: _now.subtract(const Duration(days: 260)),
  lastServiceKm: 131000,
  isPrimary: true,
);

final _v2 = Vehicle(
  id: 'v2',
  brand: 'Mercedes-Benz',
  model: 'GLE 300d 4MATIC Coupe',
  regNumber: 'DL3CAB12345',
  fuel: FuelType.diesel,
  transmission: Transmission.automatic,
  year: 2022,
  odometerKm: 9800,
);

WorkshopCard _card(String id, String status, {int? stars}) =>
    WorkshopCard.fromJson({
      'id': id,
      'number': 'A0916-00${id.substring(1)}',
      'status': status,
      'opened_at': _now.subtract(const Duration(days: 2)).toIso8601String(),
      'promised_at': _now.add(const Duration(hours: 5)).toIso8601String(),
      if (status != 'open')
        'completed_at': _now
            .subtract(const Duration(hours: 3))
            .toIso8601String(),
      if (status == 'closed') 'closed_at': _now.toIso8601String(),
      'garage_id': 'g1',
      'garage_name': _longGarage,
      'garage_phone': '9462153613',
      'garage_address': 'Plot 42, Industrial Area Phase II, Near Bus Stand',
      'garage_city': 'Sri Ganganagar',
      'garage_state': 'Rajasthan',
      'garage_pin': '335001',
      'garage_gstin': '08ABCDE1234F1Z5',
      'garage_email': 'accounts.balajiautomobiles@example.com',
      'garage_terms':
          'Goods once sold will not be taken back. Warranty as per '
          'manufacturer terms only.',
      'reg_no': 'RJ18CC1390',
      'vehicle_title': 'Maruti Suzuki Swift Dzire VXi AMT',
      'mechanic': 'Rajendra Prasad Choudhary',
      'odometer_km': 141250,
      'fuel_percent': 40,
      'voices': [
        'Brake check',
        'Strange noise from the front left wheel at low speed over bumps',
      ],
      'accessories': ['Spare wheel', 'Jack', 'Music system'],
      'work_note': 'Customer wants the old parts back in the boot.',
      'items': [
        {
          'id': 'l1',
          'kind': 'job',
          'name': 'Carburettor setting and throttle body cleaning',
          'qty': 1,
          'rate': 70,
          'state': status == 'open' ? 'pending' : 'done',
        },
        {
          'id': 'l2',
          'kind': 'part',
          'name': 'Front brake pads (Bosch, ceramic, set of 4)',
          'qty': 2,
          'rate': 125000,
          'state': 'done',
        },
        {
          'id': 'l3',
          'kind': 'part',
          'name': 'Engine oil 5W-30',
          'qty': 3.5,
          'rate': 685.5,
          'state': 'skipped',
          'gst_rate': '0.28',
          'unit': 'Litre',
        },
      ],
      'discount': 1500,
      'tax_rate': 18,
      'paid': status == 'closed' ? 100000 : 25000,
      'next_service_at': _now.add(const Duration(days: 180)).toIso8601String(),
      'next_service_km': 151000,
      'my_stars': ?stars,
      'my_comment': stars == null ? '' : 'Quick and clean work.',
      // The 35_jobcard_intake.sql columns, at their longest.
      'vehicle_year': 2015,
      'insurer': 'The New India Assurance Company Limited',
      'policy_no': '3112003124P100987654-0001',
      'insurance_from': '2026-04-01',
      'insurance_expiry': '2027-03-31',
      'insurer_address': 'Divisional Office 3, Gole Bazar, Sri Ganganagar',
      'insurer_gstin': '08AAACN4165C1ZQ',
      'bill_name': 'Shree Balaji Transport Company Private Limited',
      'bill_phone': '9876543210',
      'bill_email': 'accounts.shreebalajitransport@example.com',
      'bill_address': '14-B, Transport Nagar, Hanumangarh Road, Sri Ganganagar',
      'bill_gstin': '08AAXCS1234K1Z9',
      'advance': 25000,
      'payment_list': [
        {
          'id': 'adv-1',
          'amount': 25000,
          'mode': 'netbanking',
          'at': _now.subtract(const Duration(days: 2)).toIso8601String(),
          'advance': true,
        },
        if (status == 'closed')
          {
            'id': 'p2',
            'amount': 75000,
            'mode': 'cheque',
            'at': _now.toIso8601String(),
            'advance': false,
          },
      ],
      'bank': {
        'name': 'State Bank of India',
        'holder': 'Balaji Automobiles and Multi Brand Car Care',
        'account_no': '000012345678901',
        'ifsc': 'SBIN0001234',
        'branch': 'Industrial Area, Sri Ganganagar',
        'upi_id': 'balajiautomobiles@okaxis',
      },
      'dents': [
        {
          'id': 'd1',
          'view': 'under',
          'label': 'Underbody',
          'severity': 'rust',
          'note': 'Floor pan rusted through near the rear left jacking point',
        },
        {'id': 'd2', 'part': 'Rear right quarter panel', 'severity': 'crack'},
        {'id': 'd3', 'label': 'Front bumper', 'severity': 'dent', 'dx': '0.4'},
      ],
    });

const _shop = Workshop(
  id: 'g1',
  name: _longGarage,
  phone: '9462153613',
  altPhone: '9414000000',
  email: 'accounts.balajiautomobiles@example.com',
  addressLine: 'Plot 42, Industrial Area Phase II, Near Old Bus Stand',
  city: 'Sri Ganganagar',
  state: 'Rajasthan',
  pin: '335001',
  gstin: '08ABCDE1234F1Z5',
  upiId: 'balajiautomobiles@okaxis',
  services: _services,
  rating: 4.5,
  reviewCount: 1170,
);

List<Override> _overrides({bool empty = false, bool partner = false}) => [
  directoryGatewayProvider.overrideWithValue(_FakeDirectory(empty: empty)),
  marketplaceGatewayProvider.overrideWithValue(_FakeMarket(empty: empty)),
  partnerGatewayProvider.overrideWithValue(_FakePartner(registered: partner)),
];

Future<ProviderContainer> _account(_Stage stage, {bool partner = false}) async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();

  final container = ProviderContainer(
    overrides: _overrides(empty: stage != _Stage.full, partner: partner),
  );
  final c = container.read(appControllerProvider.notifier);
  if (stage == _Stage.fresh) return container;
  c.completeOnboarding();
  if (stage == _Stage.signedOut) return container;

  c.adoptSession(id: 'auth-1', phone: '+919876543210');
  if (stage == _Stage.restoring) {
    container.read(restoringProvider.notifier).state = true;
    return container;
  }
  if (stage == _Stage.noName) return container;
  c.saveProfile(
    name: 'Tarun Kumar Venkataraman Sharma',
    email: 'tarun.kumar.venkataraman.sharma@example.com',
  );
  if (stage == _Stage.noVehicle) return container;
  c.addVehicle(_v1);
  if (stage == _Stage.empty) return container;

  c.addVehicle(_v2);
  c.setActiveVehicle('v1');
  for (final mode in [ServiceMode.garage, ServiceMode.pickup]) {
    c.createBooking(
      vehicleId: 'v1',
      garageId: 'g1',
      workshopName: _longGarage,
      mode: mode,
      slot: _now.add(Duration(days: mode.index + 1, hours: 3)),
      notes: 'Please call before starting any extra work over ₹5,000.',
      lines: const [
        CartLine(
          id: 's1',
          name: 'Comprehensive Periodic Service with Engine Flush',
          price: 124999,
          mrp: 139999,
          isAddOn: false,
          durationHours: 4,
        ),
        CartLine(
          id: 's2',
          name: 'Wheel Alignment',
          price: 800,
          mrp: 800,
          isAddOn: false,
          durationHours: 1,
        ),
      ],
    );
  }
  c.applyWorkshop([
    _card('j1', 'open'),
    _card('j2', 'complete'),
    _card('j3', 'closed', stars: 4),
  ], shop: _shop);
  final data = container.read(appControllerProvider);
  // ignore: invalid_use_of_protected_member
  c.state = data.copyWith(
    notifications: [
      for (final (i, k) in NotifyKind.values.indexed)
        AppNotification(
          id: 'n$i',
          kind: k,
          title: i == 0
              ? 'Your Maruti Suzuki Swift Dzire is ready for delivery at '
                    '$_longGarage'
              : '${k.name} update',
          body:
              'Job card A0916-001 has been updated by the workshop. Tap to see '
              'the estimate of ₹2,50,069 and approve the extra work.',
          at: _now.subtract(Duration(hours: i * 7)),
          read: i.isOdd,
          route: '/bookings',
        ),
    ],
  );
  return container;
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

typedef _Act =
    Future<void> Function(
      WidgetTester tester,
      ProviderContainer container,
      GoRouter router,
    );

class _Scenario {
  const _Scenario(
    this.name,
    this.stage,
    this.route, {
    this.act,
    this.form = false,
    this.partner = false,
  });
  final String name;
  final _Stage stage;
  final String route;
  final _Act? act;
  final bool form;
  final bool partner;
}

BuildContext _navContext(GoRouter router) =>
    router.routerDelegate.navigatorKey.currentContext!;

WidgetRef _ref(WidgetTester tester) =>
    find.byElementPredicate((e) => e is WidgetRef).evaluate().last as WidgetRef;

Future<void> _tapText(
  WidgetTester tester,
  String text, {
  bool rich = false,
}) async {
  final f = rich
      ? find.textContaining(text, findRichText: true)
      : find.text(text);
  // Lists build lazily, so something below the fold may not exist yet.
  for (var i = 0; i < 12 && f.evaluate().isEmpty; i++) {
    final lists = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    if (lists.evaluate().isEmpty) break;
    await tester.drag(lists.last, const Offset(0, -300), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
  }
  if (f.evaluate().isEmpty) {
    throw StateError('no "$text" on screen to tap');
  }
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first, warnIfMissed: false);
  await _frames(tester);
}

WorkshopCard _cardOf(ProviderContainer c, String id) =>
    c.read(appControllerProvider).workshopCards.firstWhere((e) => e.id == id);

final _scenarios = <_Scenario>[
  // ---- the gate -----------------------------------------------------------
  const _Scenario('onboarding', _Stage.fresh, '/onboarding'),
  _Scenario(
    'onboarding slide 2',
    _Stage.fresh,
    '/onboarding',
    act: (t, c, r) async {
      await t.fling(find.byType(PageView), const Offset(-600, 0), 2000);
      await _frames(t);
    },
  ),
  _Scenario(
    'onboarding slide 3',
    _Stage.fresh,
    '/onboarding',
    act: (t, c, r) async {
      for (var i = 0; i < 2; i++) {
        await t.fling(find.byType(PageView), const Offset(-600, 0), 2000);
        await _frames(t);
      }
    },
  ),
  const _Scenario('login', _Stage.signedOut, '/login'),
  _Scenario(
    'login with email',
    _Stage.signedOut,
    '/login',
    form: true,
    act: (t, c, r) => _tapText(t, 'Continue with email'),
  ),
  _Scenario(
    'sign up with email',
    _Stage.signedOut,
    '/login',
    form: true,
    act: (t, c, r) async {
      await _tapText(t, 'Continue with email');
      await _tapText(t, 'New here?', rich: true);
    },
  ),
  const _Scenario('restoring', _Stage.restoring, '/restoring'),
  const _Scenario('profile setup', _Stage.noName, '/profile-setup', form: true),
  const _Scenario(
    'add first vehicle',
    _Stage.noVehicle,
    '/vehicle/add',
    form: true,
  ),
  _Scenario(
    'add vehicle: model',
    _Stage.noVehicle,
    '/vehicle/add',
    act: (t, c, r) => _tapText(t, 'Maruti Suzuki'),
  ),
  _Scenario(
    'add vehicle: configuration',
    _Stage.noVehicle,
    '/vehicle/add',
    act: (t, c, r) async {
      await _tapText(t, 'Maruti Suzuki');
      await _tapText(t, 'Alto K10');
    },
  ),

  // ---- tabs, empty --------------------------------------------------------
  const _Scenario('home (empty)', _Stage.empty, '/home'),
  const _Scenario('bookings (empty)', _Stage.empty, '/bookings'),
  const _Scenario('garage (one car)', _Stage.empty, '/garage'),
  const _Scenario('account (empty)', _Stage.empty, '/account'),
  const _Scenario('notifications (empty)', _Stage.empty, '/notifications'),
  const _Scenario('search (no results)', _Stage.empty, '/search', form: true),
  const _Scenario('parts browse (empty)', _Stage.empty, '/parts'),
  _Scenario(
    'parts wanted (empty)',
    _Stage.empty,
    '/parts',
    act: (t, c, r) => _tapText(t, 'Wanted'),
  ),
  _Scenario(
    'parts selling (empty)',
    _Stage.empty,
    '/parts',
    act: (t, c, r) => _tapText(t, 'Selling'),
  ),
  const _Scenario(
    'partner (not registered)',
    _Stage.empty,
    '/partner',
    form: true,
  ),
  const _Scenario('book (empty)', _Stage.empty, '/book'),
  _Scenario(
    'book (empty): workshop',
    _Stage.empty,
    '/book',
    act: (t, c, r) => _tapText(t, 'Next'),
  ),
  _Scenario(
    'book at a garage with no services',
    _Stage.empty,
    '/book?vehicle=v1&garage=g0',
    act: (t, c, r) async {
      await _tapText(t, 'Next');
      await _tapText(t, 'Next');
    },
  ),
  const _Scenario(
    'workshop details sheet (unlinked)',
    _Stage.empty,
    '/home',
    act: _workshopSheet,
  ),

  // ---- tabs, populated ----------------------------------------------------
  const _Scenario('home', _Stage.full, '/home'),
  const _Scenario('bookings', _Stage.full, '/bookings'),
  _Scenario(
    'jobcard history',
    _Stage.full,
    '/bookings',
    act: (t, c, r) => _tapText(t, 'Jobcard History'),
  ),
  _Scenario(
    'jobcard history (empty)',
    _Stage.empty,
    '/bookings',
    act: (t, c, r) => _tapText(t, 'Jobcard History'),
  ),
  _Scenario(
    'reschedule sheet',
    _Stage.full,
    '/bookings',
    act: (t, c, r) => _tapText(t, 'Reschedule'),
  ),
  _Scenario(
    'cancel booking dialog',
    _Stage.full,
    '/bookings',
    act: (t, c, r) => _tapText(t, 'Cancel booking'),
  ),
  _Scenario(
    'sign out dialog',
    _Stage.full,
    '/account',
    act: (t, c, r) => _tapText(t, 'Logout'),
  ),
  _Scenario(
    'delete account dialog',
    _Stage.full,
    '/profile',
    act: (t, c, r) => _tapText(t, 'Delete my account'),
  ),
  _Scenario(
    'vehicle options sheet',
    _Stage.full,
    '/vehicle/v1',
    act: (t, c, r) async {
      await t.tap(find.byIcon(Icons.more_vert_rounded).first);
      await _frames(t);
    },
  ),
  _Scenario(
    'odometer sheet',
    _Stage.full,
    '/vehicle/v1',
    form: true,
    act: (t, c, r) => _tapText(t, 'Update'),
  ),
  _Scenario(
    'help, question open',
    _Stage.full,
    '/help',
    act: (t, c, r) async {
      await t.tap(find.byIcon(Icons.expand_more_rounded).first);
      await _frames(t);
    },
  ),
  const _Scenario('garage', _Stage.full, '/garage'),
  const _Scenario('account', _Stage.full, '/account'),
  const _Scenario('notifications', _Stage.full, '/notifications'),
  const _Scenario('search', _Stage.full, '/search', form: true),
  const _Scenario('search (pick)', _Stage.full, '/search?pick=1'),
  const _Scenario('parts browse', _Stage.full, '/parts'),
  _Scenario(
    'parts wanted',
    _Stage.full,
    '/parts',
    act: (t, c, r) => _tapText(t, 'Wanted'),
  ),
  _Scenario(
    'parts selling',
    _Stage.full,
    '/parts',
    act: (t, c, r) => _tapText(t, 'Selling'),
  ),
  const _Scenario('need a part', _Stage.full, '/parts/need', form: true),
  const _Scenario('sell a part', _Stage.full, '/parts/sell', form: true),
  const _Scenario(
    'partner (registered)',
    _Stage.full,
    '/partner',
    partner: true,
    form: true,
  ),
  const _Scenario('book', _Stage.full, '/book'),
  const _Scenario('book for a car', _Stage.full, '/book?vehicle=v1'),
  const _Scenario(
    'book at a garage',
    _Stage.full,
    '/book?vehicle=v1&garage=g0',
  ),
  for (final n in [1, 2, 3])
    _Scenario(
      'book at a garage: step ${n + 1}',
      _Stage.full,
      '/book?vehicle=v1&garage=g0',
      form: n == 3,
      act: (t, c, r) async {
        for (var i = 0; i < n; i++) {
          if (i == 2) {
            // Tick a service so the summary has something to add up. Best
            // effort, like Pick & Drop below: with the keyboard up on the
            // smallest phone the list has no room to bring it into view.
            try {
              await _tapText(t, 'Wheel Alignment');
            } on StateError catch (_) {}
          }
          await _tapText(t, 'Next');
        }
        if (n == 3) {
          // Best effort: with the keyboard up on the smallest phone there is
          // no room left to scroll the option into view, and the step is
          // still swept as it stands.
          try {
            await _tapText(t, 'Pick & Drop');
          } on StateError catch (_) {}
        }
      },
    ),
  const _Scenario('invoice (open)', _Stage.full, '/workshop/j1/invoice'),
  const _Scenario('invoice (closed)', _Stage.full, '/workshop/j3/invoice'),
  const _Scenario('vehicle detail', _Stage.full, '/vehicle/v1'),
  const _Scenario('vehicle detail (new car)', _Stage.full, '/vehicle/v2'),
  const _Scenario('add vehicle', _Stage.full, '/vehicle/add', form: true),
  const _Scenario(
    'edit vehicle',
    _Stage.full,
    '/vehicle/add?edit=v1',
    form: true,
  ),
  const _Scenario('profile', _Stage.full, '/profile', form: true),
  const _Scenario('privacy', _Stage.full, '/privacy'),
  const _Scenario('help', _Stage.full, '/help'),

  // ---- sheets -------------------------------------------------------------
  for (final id in ['j1', 'j2', 'j3'])
    _Scenario(
      'booking details sheet $id',
      _Stage.full,
      '/home',
      act: (t, c, r) async {
        showBookingDetailsSheet(_navContext(r), _cardOf(c, id));
        await _frames(t);
      },
    ),
  const _Scenario(
    'workshop details sheet',
    _Stage.full,
    '/home',
    act: _workshopSheet,
  ),
  _Scenario(
    'rate sheet',
    _Stage.full,
    '/home',
    form: true,
    act: (t, c, r) async {
      showRateSheet(_navContext(r), _ref(t), _cardOf(c, 'j3'));
      await _frames(t);
    },
  ),
  _Scenario(
    'garage sheet',
    _Stage.full,
    '/search',
    act: (t, c, r) async {
      showGarageSheet(_navContext(r), _nearby(0));
      await _frames(t);
    },
  ),
  _Scenario(
    'listing sheet',
    _Stage.full,
    '/parts',
    act: (t, c, r) async {
      showListingSheet(
        _navContext(r),
        _ref(t),
        _listing(0, ListingStatus.approved),
      );
      await _frames(t);
    },
  ),
];

Future<void> _workshopSheet(
  WidgetTester t,
  ProviderContainer c,
  GoRouter r,
) async {
  showWorkshopDetailsSheet(_navContext(r));
  await _frames(t);
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> assets) async {
    final loader = FontLoader(name);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await family('Sora', [
    for (final w in [400, 500, 600, 700, 800]) 'assets/fonts/Sora-$w.ttf',
  ]);
  await family('Inter', [
    for (final w in [400, 500, 600, 700]) 'assets/fonts/Inter-$w.ttf',
  ]);
  // Icons draw at their fixed size whatever the font, but a real glyph keeps
  // the report free of tofu-sized surprises.
  try {
    await family('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  } catch (_) {}
  // Roboto is what Android falls back to for anything outside the app fonts.
  final roboto = Directory(
    '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts',
  );
  if (roboto.existsSync()) {
    final loader = FontLoader('Roboto');
    for (final f in roboto.listSync().whereType<File>()) {
      if (f.path.contains('roboto-') && !f.path.contains('condensed')) {
        loader.addFont(f.readAsBytes().then((b) => ByteData.sublistView(b)));
      }
    }
    await loader.load();
  }
}

final _creator = RegExp(r'file:///\S*?/lib/(\S+?):(\d+):(\d+)');

String _describe(FlutterErrorDetails d) {
  final msg = d.exceptionAsString().split('\n').first.trim();
  final text = d.toString();
  final at = _creator.firstMatch(text);
  return at == null ? msg : '$msg  <- lib/${at[1]}:${at[2]}';
}

/// Everything found, across every scenario, for the summary at the end.
final _report = <String, Set<String>>{};

Future<List<String>> _sweep(WidgetTester tester, _Scenario s) async {
  final found = <String>{};
  final previous = FlutterError.onError;
  _Config? current;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed') || text.contains('RenderFlex')) {
      found.add('$current  ${_describe(details)}');
    } else if (!text.contains('HTTP request failed') &&
        !text.contains('NetworkImageLoadException') &&
        !text.contains('MissingPluginException')) {
      found.add('$current  ERROR ${_describe(details)}');
    }
  };

  try {
    for (final cfg in _configs(form: s.form)) {
      current = cfg;
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = cfg.size * _dpr;
      tester.view.viewInsets = cfg.keyboard
          ? const FakeViewPadding(bottom: _keyboard * _dpr)
          : FakeViewPadding.zero;
      tester.platformDispatcher.textScaleFactorTestValue = cfg.scale;

      final container = await _account(s.stage, partner: s.partner);
      final router = container.read(routerProvider);
      router.go(s.route);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,
          ),
        ),
      );
      await _frames(tester, 14);
      if (s.act != null) {
        try {
          await s.act!(tester, container, router);
          await _frames(tester, 6);
        } catch (e) {
          found.add('$cfg  ACT FAILED $e');
        }
      }
      // Scroll every scrollable to its end: an overflow inside a list item
      // further down is still an overflow.
      final scrollables = find.byType(Scrollable).evaluate().toList();
      for (final e in scrollables) {
        // Scrolling one list can rebuild another away.
        if (!e.mounted) continue;
        final state = (e as StatefulElement).state as ScrollableState;
        final pos = state.position;
        if (!pos.hasContentDimensions || pos.axis != Axis.vertical) continue;
        pos.jumpTo(pos.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 60));
      }
      await _frames(tester, 3);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
      container.dispose();
    }
  } finally {
    FlutterError.onError = previous;
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.reset();
  }
  if (found.isNotEmpty) _report[s.name] = found;
  return found.toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  for (final s in _scenarios) {
    testWidgets('no overflow: ${s.name}', (tester) async {
      final found = await _sweep(tester, s);
      expect(found, isEmpty, reason: '\n${found.join('\n')}');
    });
  }

  tearDownAll(() {
    final buf = StringBuffer('\n==== overflow sweep ====\n');
    if (_report.isEmpty) buf.writeln('no overflows on any screen');
    for (final e in _report.entries) {
      buf.writeln('-- ${e.key}');
      for (final line in e.value) {
        buf.writeln('   $line');
      }
    }
    // ignore: avoid_print
    print(buf);
  });
}
