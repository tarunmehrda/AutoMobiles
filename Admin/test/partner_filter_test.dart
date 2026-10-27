import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/data/repo/platform_gateway.dart';
import 'package:garagepro_admin/features/platform/widgets/partner_filters.dart';
import 'package:garagepro_admin/features/platform/widgets/register_card.dart';

/// The Partners tab: Active / Non-active is "blocked or not", and the
/// State → District → PIN filters only ever offer choices that lead to
/// someone.
void main() {
  const garages = [
    RegisteredGarage(
        id: 'a', name: 'Alaria', city: 'Chandigarh', state: 'Chandigarh',
        pin: '160001'),
    RegisteredGarage(
        id: 'b', name: 'Ganesha', city: 'Chandigarh', state: 'chandigarh',
        pin: '160022'),
    RegisteredGarage(
        id: 'c', name: 'Hanuman', city: 'Jaipur', district: 'Jaipur',
        state: 'Rajasthan', pin: '302001'),
    RegisteredGarage(
        id: 'd', name: 'Balaji', city: 'Sanganer', district: 'Jaipur',
        state: 'Rajasthan', pin: '302029', blocked: true),
  ];

  List<String> ids(List<RegisteredGarage> gs) => [for (final g in gs) g.id];

  test('active and non-active split on blocked', () {
    expect(ids(const PartnerFilter().apply(garages)), ['a', 'b', 'c']);
    expect(ids(const PartnerFilter(active: false).apply(garages)), ['d']);
  });

  test('state is matched without regard to case', () {
    const f = PartnerFilter(state: 'Chandigarh');
    expect(ids(f.apply(garages)), ['a', 'b']);
    expect(f.states(garages), {'Chandigarh': 2, 'Rajasthan': 1});
  });

  test('a garage with no district is filed under its city', () {
    const f = PartnerFilter(active: false, district: 'Jaipur');
    expect(ids(f.apply(garages)), ['d']);
    expect(const PartnerFilter().districts(garages),
        {'Chandigarh': 2, 'Jaipur': 1});
  });

  test('PIN choices stay inside the chosen state and district', () {
    const f = PartnerFilter(state: 'Chandigarh', district: 'Chandigarh');
    expect(f.pins(garages).keys, ['160001', '160022']);
    expect(ids(f.copyWith(pin: () => '160022').apply(garages)), ['b']);
  });

  Future<void> pumpCard(WidgetTester tester, RegisteredGarage g) =>
      tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RegisterCard(garage: g, onChanged: () async {}),
              ),
            ),
          ),
        ),
      );

  testWidgets('the card offers Block, and Unblock once blocked',
      (tester) async {
    await pumpCard(tester, garages[0]);
    expect(find.text('Block'), findsOneWidget);
    expect(find.text('Unblock'), findsNothing);

    await pumpCard(tester, garages[3]);
    await tester.pumpAndSettle();
    expect(find.text('Unblock'), findsOneWidget);
    expect(find.text('Blocked'), findsWidgets);
  });

  testWidgets('the filter bar shows both sides with their counts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartnerFilterBar(
            garages: garages,
            filter: const PartnerFilter(),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Non-active'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('State'), findsOneWidget);
    expect(find.text('District'), findsOneWidget);
    expect(find.text('PIN code'), findsOneWidget);
  });
}
