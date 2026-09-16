import 'package:flutter/foundation.dart';

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

  bool get isLinked => id.isNotEmpty;

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
    this.paid = 0,
    this.nextServiceAt,
    this.nextServiceKm,
  });

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
      _round(items.fold<double>(0, (s, e) => s + e.qty * e.rate));

  double get taxable => _round(subTotal - discount);

  double get tax => _round(taxable * taxRate);

  double get total => _round(taxable + tax);

  double get balance {
    final left = _round(total - paid);
    return left < 0 ? 0 : left;
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
        discount: _num(j['discount']),
        taxRate: _num(j['tax_rate']),
        paid: _num(j['paid']),
        nextServiceAt: _date(j['next_service_at']),
        nextServiceKm: (j['next_service_km'] as num?)?.toInt(),
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

  /// `pending`, `running`, `done` or `skipped`.
  final String state;
  final String remark;

  bool get isFinished => state == 'done' || state == 'skipped';

  double get amount => _round(qty * rate);

  factory WorkshopLine.fromJson(Map<String, dynamic> j) => WorkshopLine(
        id: (j['id'] ?? '') as String,
        kind: (j['kind'] ?? 'job') as String,
        name: (j['name'] ?? '') as String,
        partNo: (j['part_no'] ?? '') as String,
        qty: _num(j['qty']),
        rate: _num(j['rate']),
        state: (j['state'] ?? 'pending') as String,
        remark: (j['remark'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'name': name,
        'part_no': partNo,
        'qty': qty,
        'rate': rate,
        'state': state,
        'remark': remark,
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
