// SHARED TEST. Mirrors `Admin/test/gst_test.dart`, because the engine is
// a deliberate copy and the customer app must reach the same rupee.
import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro/core/tax/gst.dart';

/// The tax on a bill is the one number a garage cannot afford to have
/// approximately right, so every rule the engine implements is pinned here.
void main() {
  const jaipur = PlaceOfSupply(fromState: '08', toState: '08');
  const toGujarat = PlaceOfSupply(fromState: '08', toState: '24');

  group('a single line, exclusive of tax', () {
    test('splits into CGST and SGST inside the state', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'General Service', rate: 1000, gstRate: 18)],
        place: jaipur,
      );

      expect(bill.taxable, 1000);
      expect(bill.cgst, 90);
      expect(bill.sgst, 90);
      expect(bill.igst, 0);
      expect(bill.tax, 180);
      expect(bill.grandTotal, 1180);
    });

    test('becomes one IGST amount across a state line', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'General Service', rate: 1000, gstRate: 18)],
        place: toGujarat,
      );

      expect(bill.cgst, 0);
      expect(bill.sgst, 0);
      expect(bill.igst, 180);
      expect(bill.grandTotal, 1180);
    });

    test('a customer with no GSTIN is billed local', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'Car Wash', rate: 500, gstRate: 18)],
        place: const PlaceOfSupply(fromState: '08', toState: ''),
      );

      expect(bill.igst, 0);
      expect(bill.cgst, 45);
      expect(bill.sgst, 45);
    });
  });

  group('a rate that already contains the tax', () {
    test('strips the tax back out', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'Brake Pads', rate: 1180, gstRate: 18)],
        place: jaipur,
        mode: GstMode.inclusive,
      );

      expect(bill.taxable, 1000);
      expect(bill.tax, 180);
      // The whole point: the customer still pays the number on the label.
      expect(bill.grandTotal, 1180);
    });

    test('at 28 percent too', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'Tyre', rate: 6400, gstRate: 28)],
        place: jaipur,
        mode: GstMode.inclusive,
      );

      expect(bill.taxable, 5000);
      expect(bill.tax, 1400);
      expect(bill.grandTotal, 6400);
    });
  });

  group('quantity and discounts', () {
    test('multiplies before it taxes', () {
      final bill = Gst.bill(
        lines: const [
          TaxLine(name: 'Engine Oil', qty: 3.5, rate: 620, gstRate: 18),
        ],
        place: jaipur,
      );

      expect(bill.gross, 2170);
      expect(bill.taxable, 2170);
      expect(bill.tax, 390.6);
    });

    test('a line discount comes off before the tax', () {
      final bill = Gst.bill(
        lines: const [
          TaxLine(name: 'Denting', rate: 2000, discount: 500, gstRate: 18),
        ],
        place: jaipur,
      );

      expect(bill.taxable, 1500);
      expect(bill.tax, 270);
      expect(bill.grandTotal, 1770);
    });

    test('a discount bigger than the line does not go negative', () {
      final bill = Gst.bill(
        lines: const [
          TaxLine(name: 'Goodwill', rate: 300, discount: 900, gstRate: 18),
          TaxLine(name: 'Labour', rate: 1000, gstRate: 18),
        ],
        place: jaipur,
      );

      // The typo costs the workshop 300, not 900 off the rest of the bill.
      expect(bill.taxable, 1000);
      expect(bill.grandTotal, 1180);
    });

    test('a bill discount is shared across the slabs it touched', () {
      final bill = Gst.bill(
        lines: const [
          TaxLine(name: 'Labour', rate: 1000, gstRate: 18),
          TaxLine(name: 'Tyre', rate: 1000, gstRate: 28),
        ],
        place: jaipur,
        billDiscount: 200,
      );

      // 100 off each, not 200 off whichever line came first.
      expect(bill.taxable, 1800);
      expect(bill.tax, 162 + 252);
      expect(bill.lineBreakups.first.taxable, 900);
      expect(bill.lineBreakups.last.taxable, 900);
    });

    test('a bill discount cannot exceed the bill', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'Labour', rate: 500, gstRate: 18)],
        place: jaipur,
        billDiscount: 5000,
      );

      expect(bill.billDiscount, 500);
      expect(bill.taxable, 0);
      expect(bill.grandTotal, 0);
    });
  });

  group('rounding', () {
    test('the bill lands on a whole rupee', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'Service', rate: 999, gstRate: 18)],
        place: jaipur,
      );

      // 999 + 179.82 = 1178.82
      expect(bill.roundOff, 0.18);
      expect(bill.grandTotal, 1179);
    });

    test('rounds down when that is nearer', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'Service', rate: 1001, gstRate: 18)],
        place: jaipur,
      );

      // 1001 + 180.18 = 1181.18
      expect(bill.roundOff, -0.18);
      expect(bill.grandTotal, 1181);
    });

    test('can be switched off for a document that must not round', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'Service', rate: 999, gstRate: 18)],
        place: jaipur,
        roundOffTotal: false,
      );

      expect(bill.roundOff, 0);
      expect(bill.grandTotal, 1178.82);
    });

    test('the two halves always add back to the tax exactly', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'Consumable', rate: 55.4, gstRate: 5)],
        place: jaipur,
      );

      // 2.77 will not halve evenly; the odd paisa has to land somewhere.
      expect(bill.tax, 2.77);
      expect(bill.cgst, 1.38);
      expect(bill.sgst, 1.39);
      // Added as money, which is how they are printed. Added as raw doubles
      // they come to 2.7699999999999996, so anything summing the two halves
      // has to go back through paise() first.
      expect(paise(bill.cgst + bill.sgst), bill.tax);
    });
  });

  group('a workshop that is not GST registered', () {
    test('sees the same money with no tax anywhere', () {
      final bill = Gst.bill(
        lines: const [
          TaxLine(name: 'Labour', rate: 1000, gstRate: 18),
          TaxLine(name: 'Filter', rate: 350, gstRate: 28),
        ],
        place: jaipur,
        registered: false,
      );

      expect(bill.tax, 0);
      expect(bill.cgst, 0);
      expect(bill.igst, 0);
      expect(bill.taxable, 1350);
      expect(bill.grandTotal, 1350);
      expect(bill.registered, isFalse);
    });
  });

  group('GSTR-1 rollup', () {
    test('groups by HSN and keeps the totals', () {
      final bill = Gst.bill(
        lines: const [
          TaxLine(name: 'Brake pad', hsn: '6813', rate: 1000, gstRate: 28),
          TaxLine(name: 'Brake shoe', hsn: '6813', rate: 500, gstRate: 28),
          TaxLine(name: 'Labour', hsn: '998714', rate: 900, gstRate: 18),
        ],
        place: jaipur,
      );

      final hsn = bill.hsnSummary;
      expect(hsn.keys.toSet(), {'6813', '998714'});
      expect(hsn['6813']!.taxable, 1500);
      expect(hsn['6813']!.tax, 420);
      expect(hsn['998714']!.taxable, 900);
      expect(hsn['998714']!.tax, 162);
    });

    test('a line with no code still appears', () {
      final bill = Gst.bill(
        lines: const [TaxLine(name: 'Misc', rate: 100, gstRate: 18)],
        place: jaipur,
      );
      expect(bill.hsnSummary.keys, ['-']);
    });
  });

  group('GSTIN', () {
    test('accepts the workshop own number', () {
      // Balaji Automobiles, from the brief.
      expect(Gstin.isValid('08HMMPK3586G1ZG'), isTrue);
      expect(Gstin.stateCode('08HMMPK3586G1ZG'), '08');
      expect(Gstin.stateName('08'), 'Rajasthan');
    });

    test('catches a wrong check digit', () {
      expect(Gstin.isValid('08HMMPK3586G1ZA'), isFalse);
    });

    test('catches a transposed pair, which a length check would not', () {
      expect(Gstin.isValid('80HMMPK3586G1ZG'), isFalse);
    });

    test('rejects the obviously malformed', () {
      expect(Gstin.isValid(''), isFalse);
      expect(Gstin.isValid('not a gstin'), isFalse);
      expect(Gstin.isValid('08HMMPK3586G1Z'), isFalse);
      expect(Gstin.stateCode('XX'), '');
    });
  });

  group('place of supply', () {
    test('same state is not inter-state', () {
      expect(PlaceOfSupply.local('08').isInterState, isFalse);
      expect(
        const PlaceOfSupply(fromState: '08', toState: '08').isInterState,
        isFalse,
      );
    });

    test('a different state is', () {
      expect(toGujarat.isInterState, isTrue);
    });
  });
}
