import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro/core/config/app_config.dart';
import 'package:garagepro/data/models/entities.dart';
import 'package:garagepro/data/models/enums.dart';
import 'package:garagepro/data/seed/catalog_seed.dart';

/// The price on the last screen before Confirm must be the price on the
/// booking that comes back.
///
/// It was not. "Total Cost" on the appointment page added up the service
/// prices and stopped there, while [Booking] then charged a pick & drop fee
/// and 18% GST on top. An 800 rupee service booked for collection was
/// quoted at 800 and listed at 1,297 on the very next screen, with neither
/// the fee nor the tax shown anywhere the customer had been.
///
/// These tests hold the two sums to the same arithmetic. The page computes
/// its quote the same way, from the same constants.
void main() {
  Booking booking(ServiceMode mode, List<int> prices) => Booking(
    id: 'bk1',
    code: 'GAR1',
    vehicleId: 'v1',
    slot: DateTime(2026, 9, 22, 14),
    createdAt: DateTime(2026, 9, 21),
    status: BookingStatus.upcoming,
    mode: mode,
    pickupFee: mode == ServiceMode.pickup ? Seed.pickupFee : 0,
    lines: [
      for (var i = 0; i < prices.length; i++)
        CartLine(
          id: 'l$i',
          name: 'Service $i',
          price: prices[i],
          mrp: prices[i],
          isAddOn: false,
          durationHours: 1,
        ),
    ],
  );

  /// What the appointment page's summary now shows, in the same order it
  /// builds it.
  ({double services, double pickup, double gst, double total}) quote(
    ServiceMode mode,
    List<int> prices,
  ) {
    final services = prices.fold<double>(0, (s, e) => s + e);
    final pickup = mode == ServiceMode.pickup ? Seed.pickupFee.toDouble() : 0.0;
    final gst = ((services + pickup) * AppConfig.gstRate).roundToDouble();
    return (
      services: services,
      pickup: pickup,
      gst: gst,
      total: services + pickup + gst,
    );
  }

  test('a direct visit is quoted at what it is billed', () {
    final q = quote(ServiceMode.garage, [800]);
    final b = booking(ServiceMode.garage, [800]);

    expect(q.pickup, 0);
    expect(q.total, b.total.toDouble());
    expect(b.total, 944);
  });

  test('a pick & drop is quoted with its fee and its tax', () {
    final q = quote(ServiceMode.pickup, [800]);
    final b = booking(ServiceMode.pickup, [800]);

    // The two numbers the old summary left out, and the jump they caused.
    expect(q.pickup, Seed.pickupFee.toDouble());
    expect(q.gst, greaterThan(0));
    expect(q.services, 800);

    expect(q.total, b.total.toDouble());
    expect(b.total, 1297);
  });

  test('several services still agree', () {
    for (final mode in ServiceMode.values) {
      for (final prices in const [
        <int>[],
        [1],
        [800, 1200],
        [349, 349, 349],
      ]) {
        expect(
          quote(mode, prices).total,
          booking(mode, prices).total.toDouble(),
          reason: '$mode with $prices',
        );
      }
    }
  });
}
