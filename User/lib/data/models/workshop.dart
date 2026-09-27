import 'package:flutter/foundation.dart';
import '../../core/tax/gst.dart';

/// A workshop's name with its PIN code: "Balaji-333503". Two shops called
/// Balaji are common; two in the same PIN code are not. The name alone when
/// an older workshop never saved a PIN.
String workshopLabel(String name, String pin) {
  final n = name.trim();
  final p = pin.trim();
  return n.isEmpty || p.isEmpty ? n : '$n-$p';
}

/// The workshop this customer actually deals with, as the garage filled it
/// in on its own console.
///
/// It replaces the shop that used to be hard-coded into the app: the name on
/// the invoice, the number the call button dials and the address on the
/// booking screen are now whatever the linked garage says they are. Until an
/// account is linked to a workshop this is [Workshop.none] and the screens
/// that would quote a garage say so instead of inventing one.
@immutable
class Workshop {
  const Workshop({
    this.id = '',
    this.name = '',
    this.phone = '',
    this.altPhone = '',
    this.email = '',
    this.addressLine = '',
    this.city = '',
    this.state = '',
    this.pin = '',
    this.gstin = '',
    this.upiId = '',
    this.terms = '',
    this.services = const [],
    this.rating = 0,
    this.reviewCount = 0,
  });

  /// No workshop linked yet.
  static const Workshop none = Workshop();

  final String id;
  final String name;
  final String phone;
  final String altPhone;
  final String email;
  final String addressLine;
  final String city;
  final String state;
  final String pin;
  final String gstin;
  final String upiId;
  final String terms;

  /// What the workshop has chosen to publish on its online garage page. Empty
  /// until the counter adds something, which the booking flow says plainly
  /// rather than inventing a menu.
  final List<WorkshopService> services;

  final double rating;
  final int reviewCount;

  bool get isLinked => id.isNotEmpty;

  /// "Balaji-333503" — how the app names a workshop on screen.
  String get label => workshopLabel(name, pin);

  /// Two letters for the avatar when the workshop has no logo.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2))
          .toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// The whole address on one line, skipping whatever the garage left blank.
  String get address => [addressLine, city, state, pin]
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .join(', ');

  /// Digits only, which is what a `wa.me` link wants. Indian numbers are
  /// stored ten digits long at the counter, so the country code is added
  /// back on unless the garage already typed one.
  String get whatsapp {
    final digits = phone.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) return '';
    return digits.length == 10 ? '91$digits' : digits;
  }

  factory Workshop.fromJson(Map<String, dynamic> j) => Workshop(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        altPhone: (j['alt_phone'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        addressLine: (j['address_line'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        state: (j['state'] ?? '') as String,
        pin: (j['pin'] ?? '') as String,
        gstin: (j['gstin'] ?? '') as String,
        upiId: (j['upi_id'] ?? '') as String,
        terms: (j['terms'] ?? '') as String,
        services: ((j['services'] as List?) ?? const [])
            .map((e) =>
                WorkshopService.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'alt_phone': altPhone,
        'email': email,
        'address_line': addressLine,
        'city': city,
        'state': state,
        'pin': pin,
        'gstin': gstin,
        'upi_id': upiId,
        'terms': terms,
        'services': services.map((e) => e.toJson()).toList(),
        'rating': rating,
        'review_count': reviewCount,
      };
}

/// One service the workshop offers on its online garage page.
@immutable
class WorkshopService {
  const WorkshopService({
    required this.id,
    required this.name,
    required this.price,
    this.blurb = '',
    this.durationMins = 60,
  });

  final String id;
  final String name;
  final double price;
  final String blurb;
  final int durationMins;

  factory WorkshopService.fromJson(Map<String, dynamic> j) => WorkshopService(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        blurb: (j['blurb'] ?? '') as String,
        durationMins: (j['duration_mins'] as num?)?.toInt() ?? 60,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'blurb': blurb,
        'duration_mins': durationMins,
      };
}

/// The workshop's own job card, as the garage wrote it at the counter.
///
/// This is the other half of the app: bookings are what you asked for, a
/// workshop card is what the garage is actually doing to your car right now.
/// It arrives through the `my_job_cards` view — read-only by construction,
/// and only ever the cards belonging to you.
@immutable
class WorkshopCard {
  const WorkshopCard({
    required this.id,
    required this.number,
    required this.status,
    required this.openedAt,
    this.completedAt,
    this.closedAt,
    this.promisedAt,
    this.garageId = '',
    this.garageName = '',
    this.garagePhone = '',
    this.regNo = '',
    this.vehicleTitle = '',
    this.mechanic = '',
    this.odometerKm = 0,
    this.fuelPercent = 0,
    this.voices = const [],
    this.accessories = const [],
    this.workNote = '',
    this.photos = const [],
    this.items = const [],
    this.discount = 0,
    this.taxRate = 0,
    this.gstOverride,
    this.gstInclusive = false,
    this.homeState = '',
    this.supplyState = '',
    this.paid = 0,
    this.nextServiceAt,
    this.nextServiceKm,
    this.dents = const [],
    this.myStars,
    this.myComment = '',
    this.garageGstin = '',
    this.garageAddress = '',
    this.garageCity = '',
    this.garageState = '',
    this.garagePin = '',
    this.garageEmail = '',
    this.garageTerms = '',
  });

  /// Damage the counter marked on the car when it came in, so the customer
  /// sees the same list they would argue about at handover.
  final List<WorkshopDent> dents;

  /// The rating this customer left on the card, if any (1 to 5).
  final int? myStars;
  final String myComment;

  // This card's own workshop, from the card itself. The invoice used to take
  // the letterhead from whichever linked workshop `linkedWorkshop()` happened
  // to return, so a customer of two garages could get one garage's address
  // and terms printed under the other's name.
  final String garageGstin;
  final String garageAddress;
  final String garageCity;
  final String garageState;
  final String garagePin;
  final String garageEmail;
  final String garageTerms;

  /// "Street, City, State PIN" — whatever parts the workshop filled in.
  String get garageWhere => [
        garageAddress,
        [garageCity, garageState, garagePin]
            .where((s) => s.trim().isNotEmpty)
            .join(' '),
      ].where((s) => s.trim().isNotEmpty).join(', ');

  final String id;

  /// `A0914-001` — the number printed on everything the garage hands over.
  final String number;

  /// `open`, `complete` or `closed`.
  final String status;

  final DateTime openedAt;
  final DateTime? completedAt;
  final DateTime? closedAt;
  final DateTime? promisedAt;

  final String garageId;
  final String garageName;
  final String garagePhone;

  final String regNo;
  final String vehicleTitle;

  /// Whoever is on the car, as one readable line.
  final String mechanic;

  final int odometerKm;
  final int fuelPercent;

  /// What you reported, in your words.
  final List<String> voices;

  /// What went in with the car.
  final List<String> accessories;

  final String workNote;
  final List<String> photos;

  final List<WorkshopLine> items;

  final double discount;
  final double taxRate;

  /// The workshop's per-invoice GST switch, exactly as it was when the card
  /// was raised. GST is optional: most of these arrive null with no rates
  /// anywhere, and the invoice is a plain Bill.
  final bool? gstOverride;

  /// True when the rates already contain the tax.
  final bool gstInclusive;

  /// The workshop's state code and this customer's, frozen by the console.
  final String homeState;
  final String supplyState;

  /// Collected so far, across every payment the garage has recorded.
  final double paid;

  final DateTime? nextServiceAt;
  final int? nextServiceKm;

  bool get isOpen => status == 'open';
  bool get isComplete => status == 'complete';
  bool get isClosed => status == 'closed';

  /// Still on the floor — the only state worth shouting about on Home.
  bool get isLive => isOpen || isComplete;

  double get subTotal =>
      _round(items.fold<double>(0, (s, e) => s + e.net));

  /// Whether the workshop charged tax on this card.
  bool get taxed =>
      gstOverride ?? (taxRate > 0 || items.any((e) => e.gstRate > 0));

  double _rateOf(WorkshopLine e) =>
      e.gstRate > 0 ? e.gstRate : _round(taxRate * 100);

  /// The same engine the console bills with, so the customer's copy of the
  /// invoice agrees with the printed one to the rupee.
  GstInvoice get bill => Gst.bill(
        lines: [
          for (final e in items)
            TaxLine(
              name: e.name,
              hsn: e.hsn,
              qty: e.qty,
              rate: e.rate,
              discount: e.discount,
              gstRate: _rateOf(e),
            ),
        ],
        place: PlaceOfSupply(fromState: homeState, toState: supplyState),
        mode: gstInclusive ? GstMode.inclusive : GstMode.exclusive,
        billDiscount: discount,
        registered: taxed,
      );

  double get taxable => bill.taxable;

  double get tax => bill.tax;

  double get cgst => bill.cgst;
  double get sgst => bill.sgst;
  double get igst => bill.igst;
  double get roundOff => bill.roundOff;
  bool get interState => bill.igst > 0;

  double get total => bill.grandTotal;

  /// What is still owed. Under half a rupee counts as nothing: [total] is
  /// rounded off to the rupee, the console takes payment against the exact
  /// figure, and the difference is the round-off, never money due. Without
  /// this a card paid in full at ₹1,456.78 read "Balance ₹0.22" here and
  /// its invoice never showed as paid.
  double get balance {
    final left = _round(total - paid);
    return left <= 0.5 ? 0 : left;
  }

  bool get settled => items.isNotEmpty && balance <= 0;

  /// How far along the work is, for the progress bar on the card.
  double get progress {
    if (isClosed) return 1;
    if (isComplete) return 0.9;
    if (items.isEmpty) return 0.15;
    final done = items.where((e) => e.isFinished).length;
    return 0.15 + 0.7 * (done / items.length);
  }

  String get statusLabel => switch (status) {
        'complete' => 'Ready for pickup',
        'closed' => 'Completed',
        _ => 'In the workshop',
      };

  factory WorkshopCard.fromJson(Map<String, dynamic> j) => WorkshopCard(
        id: (j['id'] ?? '') as String,
        number: (j['number'] ?? '') as String,
        status: (j['status'] ?? 'open') as String,
        openedAt: _date(j['opened_at']) ?? DateTime.now(),
        completedAt: _date(j['completed_at']),
        closedAt: _date(j['closed_at']),
        promisedAt: _date(j['promised_at']),
        garageId: (j['garage_id'] ?? '') as String,
        garageName: (j['garage_name'] ?? '') as String,
        garagePhone: (j['garage_phone'] ?? '') as String,
        regNo: (j['reg_no'] ?? '') as String,
        vehicleTitle: (j['vehicle_title'] ?? '') as String,
        mechanic: (j['mechanic'] ?? '') as String,
        odometerKm: (j['odometer_km'] as num?)?.toInt() ?? 0,
        fuelPercent: (j['fuel_percent'] as num?)?.toInt() ?? 0,
        voices: _strings(j['voices']),
        accessories: _strings(j['accessories']),
        workNote: (j['work_note'] ?? '') as String,
        photos: _strings(j['photos']),
        items: ((j['items'] as List?) ?? const [])
            .map((e) =>
                WorkshopLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        gstOverride: j['gst_override'] as bool?,
        gstInclusive: (j['gst_inclusive'] ?? false) as bool,
        homeState: (j['home_state'] ?? '') as String,
        supplyState: (j['supply_state'] ?? '') as String,
        discount: _num(j['discount']),
        taxRate: _num(j['tax_rate']),
        paid: _num(j['paid']),
        nextServiceAt: _date(j['next_service_at']),
        nextServiceKm: (j['next_service_km'] as num?)?.toInt(),
        dents: ((j['dents'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => WorkshopDent.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        myStars: (j['my_stars'] as num?)?.toInt(),
        myComment: (j['my_comment'] ?? '') as String,
        garageGstin: (j['garage_gstin'] ?? '') as String,
        garageAddress: (j['garage_address'] ?? '') as String,
        garageCity: (j['garage_city'] ?? '') as String,
        garageState: (j['garage_state'] ?? '') as String,
        garagePin: (j['garage_pin'] ?? '') as String,
        garageEmail: (j['garage_email'] ?? '') as String,
        garageTerms: (j['garage_terms'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'status': status,
        'opened_at': openedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
        'promised_at': promisedAt?.toIso8601String(),
        'garage_id': garageId,
        'garage_name': garageName,
        'garage_phone': garagePhone,
        'reg_no': regNo,
        'vehicle_title': vehicleTitle,
        'mechanic': mechanic,
        'odometer_km': odometerKm,
        'fuel_percent': fuelPercent,
        'voices': voices,
        'accessories': accessories,
        'work_note': workNote,
        'photos': photos,
        'items': items.map((e) => e.toJson()).toList(),
        'discount': discount,
        'tax_rate': taxRate,
        'paid': paid,
        'next_service_at': nextServiceAt?.toIso8601String(),
        'next_service_km': nextServiceKm,
        'dents': dents.map((e) => e.toJson()).toList(),
        'my_stars': myStars,
        'my_comment': myComment,
        'garage_gstin': garageGstin,
        'garage_address': garageAddress,
        'garage_city': garageCity,
        'garage_state': garageState,
        'garage_pin': garagePin,
        'garage_email': garageEmail,
        'garage_terms': garageTerms,
      };
}

/// One line on the workshop's bill.
@immutable
class WorkshopLine {
  const WorkshopLine({
    required this.id,
    required this.kind,
    required this.name,
    this.partNo = '',
    this.qty = 1,
    this.rate = 0,
    this.discount = 0,
    this.hsn = '',
    this.gstRate = 0,
    this.state = 'pending',
    this.remark = '',
  });

  final String id;

  /// `job`, `spare` or `lube`.
  final String kind;
  final String name;
  final String partNo;
  final double qty;
  final double rate;

  /// Rupees off this line, as the counter typed it.
  final double discount;

  /// HSN for a part, SAC for a service. Blank on an untaxed bill, which is
  /// the normal case — the workshop may not charge GST at all.
  final String hsn;

  /// Percent. Zero falls back to whatever the card is set to.
  final double gstRate;

  /// `pending`, `running`, `done` or `skipped`.
  final String state;
  final String remark;

  bool get isFinished => state == 'done' || state == 'skipped';

  double get amount => _round(qty * rate);

  /// After this line's discount, never below zero.
  double get net {
    final v = _round(amount - discount);
    return v < 0 ? 0 : v;
  }

  factory WorkshopLine.fromJson(Map<String, dynamic> j) => WorkshopLine(
        id: (j['id'] ?? '') as String,
        kind: (j['kind'] ?? 'job') as String,
        name: (j['name'] ?? '') as String,
        partNo: (j['part_no'] ?? '') as String,
        qty: _num(j['qty']),
        rate: _num(j['rate']),
        discount: _num(j['discount']),
        hsn: (j['hsn'] ?? '') as String,
        gstRate: _num(j['gst_rate']),
        state: (j['state'] ?? 'pending') as String,
        remark: (j['remark'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'name': name,
        'part_no': partNo,
        'qty': qty,
        'discount': discount,
        'hsn': hsn,
        'gst_rate': gstRate,
        'rate': rate,
        'state': state,
        'remark': remark,
      };
}

/// One mark on the damage sheet the counter filled in at check-in.
@immutable
class WorkshopDent {
  const WorkshopDent({
    this.id = '',
    this.label = '',
    this.severity = 'scratch',
    this.note = '',
    this.dx = 0.5,
    this.dy = 0.5,
  });

  final String id;

  /// Where on the car — "Front bumper", "Left rear door".
  final String label;

  /// Where on the console's body diagram, as fractions of its size.
  final double dx;
  final double dy;

  /// `scratch`, `dent`, `crack` or `rust`, as the console stores it.
  final String severity;
  final String note;

  String get severityLabel => switch (severity) {
        'dent' => 'Dent',
        'crack' => 'Break',
        'rust' => 'Rust',
        _ => 'Scratch',
      };

  factory WorkshopDent.fromJson(Map<String, dynamic> j) => WorkshopDent(
        id: (j['id'] ?? '') as String,
        label: (j['label'] ?? j['part'] ?? '') as String,
        severity: (j['severity'] ?? 'scratch') as String,
        note: (j['note'] ?? '') as String,
        dx: (j['dx'] as num?)?.toDouble() ?? 0.5,
        dy: (j['dy'] as num?)?.toDouble() ?? 0.5,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'severity': severity,
        'note': note,
        'dx': dx,
        'dy': dy,
      };
}

double _round(double v) => (v * 100).roundToDouble() / 100;

double _num(Object? v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

DateTime? _date(Object? v) => switch (v) {
      String s => DateTime.tryParse(s)?.toLocal(),
      DateTime d => d,
      _ => null,
    };

List<String> _strings(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];
