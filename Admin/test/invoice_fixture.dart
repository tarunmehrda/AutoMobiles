import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// A billed card, built through the controller the way the console builds one,
/// so the PDF is rendered from the same shape the app hands it.
Future<({JobCard card, Garage garage, Customer customer, Vehicle vehicle})>
billedCard() async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(adminProvider.notifier);

  c.markSignedIn();
  c.completeOnboarding();
  const garage = Garage(
    id: 'garage-test',
    name: 'Test Motors',
    phone: '9000000000',
    addressLine: '1 Workshop Road',
    city: 'Jaipur',
    state: 'Rajasthan',
    pin: '302020',
  );
  c.saveGarage(garage);
  c.addMaster(kind: LineKind.job, name: 'General Service Labour', rate: 900);

  final customer = c.upsertCustomer(name: 'Vikas Gurjar', phone: '9696969696');
  final vehicle = c.upsertVehicle(
    customerId: customer.id,
    regNo: 'RJ14 4C 2626',
    brand: 'Maruti Suzuki',
    model: '800',
    year: 2004,
  );
  var card = c.createJobCard(
    customerId: customer.id,
    vehicleId: vehicle.id,
    odometerKm: 50000,
    fuelPercent: 50,
  );
  c.addItem(
    card.id,
    kind: LineKind.job,
    name: 'General Service Labour',
    qty: 1,
    rate: 900,
  );
  card = container.read(adminProvider).jobById(card.id)!;

  return (card: card, garage: garage, customer: customer, vehicle: vehicle);
}

/// A card with something in every block a document can carry.
///
/// The optional blocks are the ones that only render when there is data
/// behind them, which means an empty card exercises none of their layout.
/// This one has a photograph on disk too, so the image path through the PDF
/// is the real one and not a skipped-because-missing branch.
Future<
  ({
    JobCard card,
    Garage garage,
    Customer customer,
    Vehicle vehicle,
    List<Staff> staff,
    Directory dir,
  })
>
fullCard() async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(adminProvider.notifier);

  c.markSignedIn();
  c.completeOnboarding();
  const garage = Garage(
    id: 'garage-test',
    name: 'Test Motors',
    phone: '9000000000',
    addressLine: '1 Workshop Road',
    city: 'Jaipur',
    state: 'Rajasthan',
    pin: '302020',
    gstin: '08AAACT1234C1ZB',
    upiId: 'testmotors@okbank',
  );
  c.saveGarage(garage);

  final fitter = c.addStaff(name: 'A Fitter', skill: 'Engine');
  final customer = c.upsertCustomer(name: 'A Customer', phone: '9000000001');
  final vehicle = c.upsertVehicle(
    customerId: customer.id,
    regNo: 'RJ14 4C 2626',
    brand: 'Maruti Suzuki',
    model: '800',
    year: 2004,
  );

  var card = c.createJobCard(
    customerId: customer.id,
    vehicleId: vehicle.id,
    odometerKm: 50000,
    fuelPercent: 50,
  );
  c.addItem(
    card.id,
    kind: LineKind.job,
    name: 'General Service Labour',
    qty: 1,
    rate: 900,
  );
  c.setTaxRate(card.id, 0.18);
  c.setMechanics(card.id, [fitter.id]);
  c.setVoices(card.id, ['Engine Noise', 'Brake Check']);
  c.setAccessories(card.id, ['Stepney', 'Tool Kit']);
  c.setWorkNote(
    card.id,
    'Check the clutch cable.\nRoad test before handing over.',
  );
  c.setDents(card.id, const [
    DentMark(
      id: 'd1',
      view: 'fourWheeler.side',
      severity: DentSeverity.scratch,
      note: 'Rear door',
    ),
  ]);

  // A real file, so the PDF embeds a real image rather than skipping a path
  // that is not there. One pixel is enough to prove the wiring.
  final dir = await Directory.systemTemp.createTemp('garagepro-doc-test');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final photo = File('${dir.path}${Platform.pathSeparator}shot.png');
  await photo.writeAsBytes(onePixelPng);
  c.addPhotos(card.id, [photo.path, '${dir.path}/gone-missing.png']);

  c.addPayment(card.id, amount: 200, mode: PayMode.upi, note: 'Advance');
  c.markComplete(card.id);

  card = container.read(adminProvider).jobById(card.id)!;
  return (
    card: card,
    garage: garage,
    customer: customer,
    vehicle: vehicle,
    staff: [fitter],
    dir: dir,
  );
}

/// The smallest thing the pdf package will accept as a picture.
final List<int> onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
