/// SHARED FILE. The identical engine lives at
/// `Admin/lib/core/tax/gst.dart`. The customer app must arrive at the
/// same rupee as the invoice the workshop printed, so this is a copy on
/// purpose and any change belongs in both.
/// Indian GST, the way a workshop actually bills it.
///
/// Everything here is pure arithmetic on plain values — no state, no
/// providers, no Flutter. That is deliberate: the tax on a bill is the one
/// number nobody may ever have to guess about, so it is computed in one
/// place, covered by tests, and shared unchanged by the job invoice, the
/// counter sale, the estimate, the purchase bill and the credit note.
///
/// Rupees are carried to paise and rounded once, at the end, on the bill
/// total. Rounding each line would let a 12-line invoice drift by a rupee
/// against the customer's own arithmetic.
library;

import 'package:flutter/foundation.dart';

/// Paise precision. Anything that leaves this file has been through it.
double paise(double v) => (v * 100).roundToDouble() / 100;

/// The slabs a garage ever touches. Labour is usually 18, parts 18 or 28,
/// and a handful of consumables sit at 5 or 12.
const List<double> kGstSlabs = <double>[0, 5, 12, 18, 28];

/// Whether the rate typed on a line already contains the tax.
///
/// A counter that prices "brake pads, 1200 all in" is working inclusive; a
/// workshop quoting "1200 plus GST" is working exclusive. Both are normal,
/// and getting the two confused is the classic way to lose the tax.
enum GstMode { exclusive, inclusive }

/// One billable row, reduced to the only things tax cares about.
@immutable
class TaxLine {
  const TaxLine({
    required this.name,
    this.hsn = '',
    this.qty = 1,
    this.rate = 0,
    this.discount = 0,
    this.gstRate = 0,
  });

  final String name;

  /// HSN for a part, SAC for a service. The same column on the invoice.
  final String hsn;

  final double qty;

  /// Per unit, before this line's discount.
  final double rate;

  /// Absolute rupees knocked off this line, not a percentage — that is how
  /// the counter types it and how the reference app's `Disc` field behaves.
  final double discount;

  /// Percent: one of [kGstSlabs].
  final double gstRate;

  /// What the line is worth before tax and before any bill-level discount.
  double get gross => paise(qty * rate);

  /// Never below zero: a discount larger than the line is a typo, not a
  /// credit, and it must not quietly subtract from the rest of the bill.
  double get net => paise((gross - discount).clamp(0, double.infinity));
}

/// What one line, or a whole bill, comes to once the tax is worked out.
@immutable
class GstBreakup {
  const GstBreakup({
    this.taxable = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
  });

  /// The value the tax is charged on.
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;

  double get tax => paise(cgst + sgst + igst);

  /// Taxable plus tax — before any round-off on the bill.
  double get total => paise(taxable + tax);

  GstBreakup operator +(GstBreakup o) => GstBreakup(
        taxable: paise(taxable + o.taxable),
        cgst: paise(cgst + o.cgst),
        sgst: paise(sgst + o.sgst),
        igst: paise(igst + o.igst),
      );

  static const GstBreakup zero = GstBreakup();
}

/// Where the supply happens, which is the only thing that decides whether
/// the tax splits into CGST+SGST or stands as one IGST amount.
///
/// Both codes are the two-digit state codes off a GSTIN. A customer with no
/// GSTIN is billed at the workshop's own state — an unregistered walk-in is
/// always a local supply.
@immutable
class PlaceOfSupply {
  const PlaceOfSupply({required this.fromState, required this.toState});

  /// The workshop's state code, e.g. `08` for Rajasthan.
  final String fromState;

  /// The customer's state code. Empty means "same as the workshop".
  final String toState;

  bool get isInterState =>
      toState.trim().isNotEmpty && toState.trim() != fromState.trim();

  /// The common case: an unregistered walk-in at the counter.
  factory PlaceOfSupply.local(String stateCode) =>
      PlaceOfSupply(fromState: stateCode, toState: stateCode);
}

/// A whole document, priced.
@immutable
class GstInvoice {
  const GstInvoice({
    required this.lines,
    required this.breakup,
    required this.lineBreakups,
    required this.billDiscount,
    required this.roundOff,
    required this.registered,
  });

  final List<TaxLine> lines;

  /// Per line, in the same order as [lines], after the bill-level discount
  /// has been apportioned. The invoice prints these.
  final List<GstBreakup> lineBreakups;

  final GstBreakup breakup;

  /// The bill-level discount actually applied. Never more than the bill.
  final double billDiscount;

  /// Grand total minus the untidy total, in the range -0.50 .. +0.49.
  final double roundOff;

  /// False when the workshop has GST switched off. Everything still adds
  /// up; there is simply no tax anywhere and no HSN column to print.
  final bool registered;

  /// Sum of the lines before any discount.
  double get gross => paise(lines.fold<double>(0, (s, l) => s + l.gross));

  /// Sum of the per-line discounts.
  double get lineDiscount =>
      paise(lines.fold<double>(0, (s, l) => s + (l.gross - l.net)));

  double get taxable => breakup.taxable;
  double get cgst => breakup.cgst;
  double get sgst => breakup.sgst;
  double get igst => breakup.igst;
  double get tax => breakup.tax;

  /// What the customer pays, rounded to the rupee.
  double get grandTotal => paise(breakup.total + roundOff);

  /// HSN-wise rollup, which is what GSTR-1 actually asks for.
  Map<String, GstBreakup> get hsnSummary {
    final out = <String, GstBreakup>{};
    for (var i = 0; i < lines.length; i++) {
      final key = lines[i].hsn.trim().isEmpty ? '-' : lines[i].hsn.trim();
      out[key] = (out[key] ?? GstBreakup.zero) + lineBreakups[i];
    }
    return out;
  }
}

/// The one entry point. Everything that bills goes through here.
class Gst {
  const Gst._();

  /// Price a document.
  ///
  /// [billDiscount] is apportioned across the lines in proportion to their
  /// net value, because a lump discount off the bottom of an invoice still
  /// has to reduce the taxable value of each slab it touched. Putting it
  /// all against one line would under- or over-state the tax.
  ///
  /// When [registered] is false the workshop is not GST-registered: the
  /// result carries the same money with every tax figure at zero, so one
  /// set of screens prints both a Tax Invoice and a plain Bill.
  static GstInvoice bill({
    required List<TaxLine> lines,
    required PlaceOfSupply place,
    GstMode mode = GstMode.exclusive,
    double billDiscount = 0,
    bool registered = true,
    bool roundOffTotal = true,
  }) {
    final net = paise(lines.fold<double>(0, (s, l) => s + l.net));
    final discount = paise(billDiscount.clamp(0, net));

    final perLine = <GstBreakup>[];
    for (final line in lines) {
      // Apportion by share of the net bill. A zero bill has nothing to
      // share out, which also keeps the division safe.
      final share = net == 0 ? 0.0 : line.net / net;
      final after = paise(line.net - (discount * share));
      perLine.add(_line(
        value: after,
        gstRate: registered ? line.gstRate : 0,
        mode: mode,
        interState: place.isInterState,
      ));
    }

    final total = perLine.fold<GstBreakup>(GstBreakup.zero, (s, e) => s + e);
    final round = roundOffTotal
        ? paise(total.total.roundToDouble() - total.total)
        : 0.0;

    return GstInvoice(
      lines: lines,
      lineBreakups: perLine,
      breakup: total,
      billDiscount: discount,
      roundOff: round,
      registered: registered,
    );
  }

  /// One line's tax, given what it is worth after every discount.
  static GstBreakup _line({
    required double value,
    required double gstRate,
    required GstMode mode,
    required bool interState,
  }) {
    if (value <= 0 || gstRate <= 0) {
      return GstBreakup(taxable: paise(value < 0 ? 0 : value));
    }

    final double taxable;
    final double tax;
    if (mode == GstMode.inclusive) {
      // The rate already contains the tax, so strip it back out.
      taxable = paise(value / (1 + gstRate / 100));
      tax = paise(value - taxable);
    } else {
      taxable = paise(value);
      tax = paise(value * gstRate / 100);
    }

    if (interState) return GstBreakup(taxable: taxable, igst: tax);
    // Half each, with the odd paisa landing on CGST so the two halves still
    // add back to the tax exactly.
    final half = paise(tax / 2);
    return GstBreakup(
      taxable: taxable,
      cgst: paise(tax - half),
      sgst: half,
    );
  }
}

/// GSTIN: the 15-character registration number, and the state code inside it.
class Gstin {
  const Gstin._();

  static const String _charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// `08HMMPK3586G1ZG` -> `08`. Empty for anything that is not a GSTIN.
  static String stateCode(String gstin) {
    final v = gstin.trim().toUpperCase();
    if (v.length < 2) return '';
    final head = v.substring(0, 2);
    return int.tryParse(head) == null ? '' : head;
  }

  /// Shape plus the official check digit. Catches a transposed pair, which
  /// a length check alone will not.
  static bool isValid(String gstin) {
    final v = gstin.trim().toUpperCase();
    if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
        .hasMatch(v)) {
      return false;
    }
    return v[14] == checkDigit(v.substring(0, 14));
  }

  /// The 15th character, computed from the first 14.
  static String checkDigit(String first14) {
    var sum = 0;
    for (var i = 0; i < first14.length; i++) {
      final value = _charset.indexOf(first14[i]);
      if (value < 0) return '';
      final product = value * (i.isEven ? 1 : 2);
      sum += (product ~/ 36) + (product % 36);
    }
    return _charset[(36 - (sum % 36)) % 36];
  }

  /// State code -> state, for the place-of-supply picker and for printing
  /// "Place of Supply: 08 - Rajasthan" on a tax invoice.
  static const Map<String, String> states = {
    '01': 'Jammu and Kashmir', '02': 'Himachal Pradesh', '03': 'Punjab',
    '04': 'Chandigarh', '05': 'Uttarakhand', '06': 'Haryana',
    '07': 'Delhi', '08': 'Rajasthan', '09': 'Uttar Pradesh',
    '10': 'Bihar', '11': 'Sikkim', '12': 'Arunachal Pradesh',
    '13': 'Nagaland', '14': 'Manipur', '15': 'Mizoram',
    '16': 'Tripura', '17': 'Meghalaya', '18': 'Assam',
    '19': 'West Bengal', '20': 'Jharkhand', '21': 'Odisha',
    '22': 'Chhattisgarh', '23': 'Madhya Pradesh', '24': 'Gujarat',
    '26': 'Dadra and Nagar Haveli and Daman and Diu', '27': 'Maharashtra',
    '29': 'Karnataka', '30': 'Goa', '31': 'Lakshadweep',
    '32': 'Kerala', '33': 'Tamil Nadu', '34': 'Puducherry',
    '35': 'Andaman and Nicobar Islands', '36': 'Telangana',
    '37': 'Andhra Pradesh', '38': 'Ladakh', '97': 'Other Territory',
  };

  static String stateName(String code) => states[code.trim()] ?? '';
}

/// The SAC codes for the services this workshop sells, and the HSN codes for
/// the parts it stocks. Seeded so nobody has to look them up, editable in
/// the masters because a garage's accountant may prefer their own.
class TaxCodes {
  const TaxCodes._();

  /// Maintenance and repair of motor vehicles. The whole services master
  /// sits under this one SAC unless the workshop overrides a row.
  static const String serviceSac = '998714';

  /// Car washing and similar.
  static const String washSac = '999713';

  /// Common part groups a garage bills, by HSN.
  static const Map<String, String> partHsn = {
    'Parts and accessories': '8708',
    'Tyres': '4011',
    'Batteries': '8507',
    'Lubricants and oils': '2710',
    'Filters': '8421',
    'Bulbs and lamps': '8539',
    'Brake linings and pads': '6813',
    'Spark plugs': '8511',
    'Paints': '3208',
  };

  /// The slab that applies unless a row says otherwise.
  static const double defaultServiceRate = 18;
  static const double defaultPartRate = 28;
}
