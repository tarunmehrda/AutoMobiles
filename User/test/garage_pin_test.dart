import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro/core/utils/formatters.dart';
import 'package:garagepro/data/models/directory.dart';
import 'package:garagepro/data/models/workshop.dart';

/// The line under a workshop's name in search, on its page and on the
/// booking screen. It used to show the PIN only when the address and city
/// were both blank, so almost no workshop ever showed one.
void main() {
  NearbyGarage garage({
    String address = '',
    String city = '',
    String pin = '',
  }) =>
      NearbyGarage(
        id: 'g',
        name: 'Sharma Auto',
        addressLine: address,
        city: city,
        pin: pin,
      );

  test('the PIN is shown beside the place', () {
    expect(
      garage(address: 'Sector 15', city: 'Jaipur', pin: '302001').where,
      'Sector 15, Jaipur - 302001',
    );
    expect(garage(city: 'Jaipur', pin: '302001').where, 'Jaipur - 302001');
  });

  test('a PIN on its own still reads as one', () {
    expect(garage(pin: '302001').where, 'PIN 302001');
  });

  test('a workshop with no PIN yet shows just the place', () {
    expect(garage(address: 'Sector 15', city: 'Jaipur').where,
        'Sector 15, Jaipur');
    expect(garage().where, '');
  });

  test('partner registration needs a real PIN', () {
    expect(Fmt.isPin('302001'), isTrue);
    expect(Fmt.isPin(''), isFalse);
    expect(Fmt.isPin('012345'), isFalse);
    expect(Fmt.isPin('3020'), isFalse);
  });

  test('a workshop is named "Name-PIN" on screen', () {
    expect(garage(pin: '333503').label, 'Sharma Auto-333503');
    expect(garage(pin: ' 333503 ').label, 'Sharma Auto-333503');
    // Registered before the PIN was required: the name alone, no dangling -.
    expect(garage().label, 'Sharma Auto');
    expect(
      const Workshop(name: 'Balaji', pin: '333503').label,
      'Balaji-333503',
    );
  });
}
