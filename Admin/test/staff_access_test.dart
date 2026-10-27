import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/router/app_router.dart';
import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/data/models/access.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/models/team.dart';
import 'package:garagepro_admin/data/repo/garage_gateway.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/features/jobcard/jobcard_detail_page.dart';
import 'package:garagepro_admin/features/settings/settings_page.dart';
import 'package:garagepro_admin/state/admin_state.dart';
import 'package:garagepro_admin/state/auth_state.dart';

/// Owner, and the four roles an owner can invite (31_staff_logins.sql).
///
/// The database is the boundary; these pin what the app draws on top of it,
/// so a mechanic is never shown a Cash Book the server will only ever hand
/// back empty, or a Close button whose save it will refuse.
///
/// The grids are `my_access()` answers, copied from `role_grid()` in
/// 04_roles.sql, so a change there that is not made here shows up.
Access _as(String role) => Access.fromJson({
  'role': role,
  'staff_id': role == 'mechanic' ? 'st-mech' : '',
  'permissions': switch (role) {
    'manager' => {
      'jobCards': 'vced',
      'inventory': 'vce',
      'customers': 'vced',
      'vehicles': 'vced',
      'reports': 'v',
      'users': 'v',
      'insurance': 'vce',
      'leaves': 'vce',
      'attendance': 'vce',
      'jobCardPresets': 'vce',
      'counterSale': 'vce',
      'purchases': 'vce',
      'finance': 'vce',
    },
    'mechanic' => {
      'jobCards': 've',
      'inventory': 'v',
      'vehicles': 'v',
      'customers': 'v',
      'attendance': 'v',
      'leaves': 'vc',
    },
    'counter' => {
      'jobCards': 'vce',
      'inventory': 'vced',
      'customers': 'vce',
      'vehicles': 'vce',
      'counterSale': 'vced',
      'purchases': 'vce',
      'attendance': 'v',
    },
    'accountant' => {
      'jobCards': 'v',
      'customers': 'v',
      'inventory': 'v',
      'reports': 'v',
      'insurance': 'v',
      'finance': 'vced',
      'purchases': 'vce',
      'attendance': 'v',
    },
    _ => <String, String>{},
  },
  'sees_cost': role != 'mechanic',
  'own_jobs_only': role == 'mechanic',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => GarageGateway.instance.access.value = Access.owner);

  group('which screens each role opens', () {
    final owner = Access.owner;
    final manager = _as('manager');
    final mechanic = _as('mechanic');
    final counter = _as('counter');
    final accountant = _as('accountant');

    test('the owner opens everything', () {
      for (final loc in [
        '/expenses',
        '/job/new',
        '/job/x/items',
        '/settings/commission',
        '/online-garage',
        '/staff',
        '/attendance/site',
        '/workshop',
      ]) {
        expect(owner.allows(loc), isTrue, reason: loc);
      }
    });

    test('a mechanic: their cards, their attendance, nothing else', () {
      expect(mechanic.allows('/home'), isTrue);
      expect(mechanic.allows('/jobs'), isTrue);
      expect(mechanic.allows('/job/abc'), isTrue);
      expect(mechanic.allows('/job/abc/photos'), isTrue);
      expect(mechanic.allows('/attendance'), isTrue);
      expect(mechanic.allows('/bookings'), isTrue);
      for (final loc in [
        '/job/new',
        '/job/abc/items',
        '/expenses',
        '/cashbook',
        '/pending',
        '/inventory',
        '/reports',
        '/analytics',
        '/staff',
        '/workshop',
        '/online-garage',
        '/settings/options',
        '/settings/commission',
        '/attendance/site',
        '/platform',
      ]) {
        expect(mechanic.allows(loc), isFalse, reason: loc);
      }
    });

    test('a manager runs the floor but not the workshop settings', () {
      for (final loc in [
        '/job/new',
        '/job/abc/items',
        '/expenses',
        '/inventory',
        '/staff',
        '/reports',
        '/customers',
        '/settings/greetings',
      ]) {
        expect(manager.allows(loc), isTrue, reason: loc);
      }
      for (final loc in [
        '/online-garage',
        '/workshop',
        '/settings/options',
        '/settings/commission',
        '/attendance/site',
      ]) {
        expect(manager.allows(loc), isFalse, reason: loc);
      }
    });

    test('the counter sells; the books are not theirs', () {
      expect(counter.allows('/inventory/counter-sale/new'), isTrue);
      expect(counter.allows('/job/new'), isTrue);
      expect(counter.allows('/expenses'), isFalse);
      expect(counter.allows('/reports'), isFalse);
    });

    test('the accountant reads cards and keeps the books', () {
      expect(accountant.allows('/job/abc'), isTrue);
      expect(accountant.allows('/job/new'), isFalse);
      expect(accountant.allows('/job/abc/items'), isFalse);
      expect(accountant.allows('/expenses'), isTrue);
      expect(accountant.allows('/reports'), isTrue);
    });

    test('the money questions', () {
      expect(mechanic.handlesMoney, isFalse);
      expect(mechanic.editJobs, isTrue);
      expect(accountant.handlesMoney, isFalse);
      expect(counter.handlesMoney, isTrue);
      expect(mechanic.manageAttendance, isFalse);
      expect(manager.manageAttendance, isTrue);
    });
  });

  group('reading the answer', () {
    test('an empty answer is the owner; an unknown role gets the least', () {
      expect(Access.fromJson(const {}).isOwner, isTrue);
      expect(StaffRole.parse('supervisor'), StaffRole.mechanic);
    });

    test('survives the round trip through the phone', () {
      final m = _as('mechanic');
      expect(Access.fromJson(m.toJson()), m);
    });

    test('the team splits members from invitations by staff record', () {
      final t = Team.fromJson({
        'members': [
          {'profile_id': 'p1', 'email': 'o@x.in', 'role': 'owner', 'me': true},
          {
            'profile_id': 'p2',
            'email': 'm@x.in',
            'role': 'mechanic',
            'staff_id': 's1',
          },
        ],
        'invites': [
          {'email': 'c@x.in', 'role': 'counter', 'staff_id': 's2'},
        ],
      });
      expect(t.memberFor('s1')?.role, StaffRole.mechanic);
      expect(t.memberFor(''), isNull);
      expect(t.inviteFor('s2')?.email, 'c@x.in');
      expect(t.inviteFor('s1'), isNull);
    });
  });

  test('a card a mechanic was taken off does not linger on their phone', () {
    JobCard card(String id) => JobCard(
      id: id,
      number: id,
      customerId: 'c',
      vehicleId: 'v',
      createdAt: DateTime(2026),
    );
    final local = [card('mine'), card('taken-off')];
    final upstream = [card('mine')];
    expect(GarageGateway.debugMergeCards(local, upstream).map((c) => c.id), [
      'mine',
      'taken-off',
    ]);
    expect(
      GarageGateway.debugMergeCards(
        local,
        upstream,
        keepOrphans: false,
      ).map((c) => c.id),
      ['mine'],
    );
  });

  test('a workshop the server issued is never re-created from the phone', () {
    // A deleted account's workshop, or another account's on a shared phone.
    expect(
      GarageGateway.serverIssued('2b2d651f-09aa-4e50-a75d-29b18560bfbd'),
      isTrue,
    );
    // Registered with no connection: exists on this phone alone, goes up.
    expect(GarageGateway.serverIssued('garage-mf3k2-812'), isFalse);
  });

  group('on screen', () {
    Future<(ProviderContainer, String)> shop() async {
      SharedPreferences.setMockInitialValues({});
      localStore = await LocalStore.open();
      final container = ProviderContainer(
        overrides: [signedInProvider.overrideWithValue(true)],
      );
      final c = container.read(adminProvider.notifier);
      c.markSignedIn();
      c.completeOnboarding();
      c.saveGarage(
        const Garage(
          id: 'garage-test',
          name: 'Test Motors',
          phone: '9000000000',
          city: 'Jaipur',
          state: 'Rajasthan',
          pin: '302020',
        ),
      );
      final customer = c.upsertCustomer(name: 'Asha', phone: '9000000001');
      final vehicle = c.upsertVehicle(
        customerId: customer.id,
        regNo: 'RJ14AA1',
        brand: 'Suzuki',
        model: 'Swift',
      );
      final card = c.createJobCard(
        customerId: customer.id,
        vehicleId: vehicle.id,
        odometerKm: 1000,
        fuelPercent: 50,
      );
      c.addItem(card.id, kind: LineKind.job, name: 'Brake check', rate: 450);
      return (container, card.id);
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    testWidgets('a mechanic sent to the cash book lands on the dashboard, '
        'with no money tiles on it', (tester) async {
      final (container, _) = await shop();
      addTearDown(container.dispose);
      GarageGateway.instance.access.value = _as('mechanic');
      // Tall enough that the whole dashboard is built, so "not there" means
      // not there rather than not scrolled to.
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final router = container.read(routerProvider);
      router.go('/cashbook');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
      expect(find.text('Test Motors'), findsWidgets);
      expect(find.text('CashBook'), findsNothing);
      expect(find.text('Expenses'), findsNothing);
      expect(find.text('Owed to You'), findsNothing);
      expect(find.text('Inventory'), findsNothing);
      expect(find.text('Report'), findsNothing);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Appointment'), findsOneWidget);
    });

    testWidgets('a mechanic sees the mechanic copy and no way to take money', (
      tester,
    ) async {
      final (container, id) = await shop();
      addTearDown(container.dispose);
      GarageGateway.instance.access.value = _as('mechanic');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: JobCardDetailPage(id: id, initialDoc: DocKind.invoice),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Mechanic Copy'), findsWidgets);
      expect(find.text('Estimate'), findsNothing);
      expect(find.text('Update or Complete'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
      expect(find.textContaining('Pending balance'), findsNothing);
    });

    testWidgets('the owner still gets the bill', (tester) async {
      final (container, id) = await shop();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: JobCardDetailPage(id: id, initialDoc: DocKind.invoice),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Estimate'), findsOneWidget);
      expect(find.text('Update or Complete'), findsOneWidget);
    });

    testWidgets('settings shows a mechanic their role, not the owner rows', (
      tester,
    ) async {
      final (container, _) = await shop();
      addTearDown(container.dispose);
      GarageGateway.instance.access.value = _as('mechanic');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SettingsPage(),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Mechanic'), findsOneWidget);
      expect(find.text('Owner'), findsNothing);
      expect(find.text('Commission'), findsNothing);
      expect(find.text('Options'), findsNothing);
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });
}
