import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'attendance.dart';
import 'enums.dart';

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Every timestamp leaves here as UTC with its `Z`.
///
/// A bare `toIso8601String()` on a local time carries no offset, and Postgres
/// reads an offset-less string into a `timestamptz` as if it were already UTC
/// — so a card opened at 3:44 pm IST came back, through [_date]'s `toLocal`,
/// stamped 9:14 pm. Sending the instant spares the round trip that guess.
String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

double _num(Object? v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

List<String> _strings(Object? v) =>
    (v as List?)?.map((e) => '$e').toList() ?? const [];

/// Rupees rounded to paise — money never carries float noise into a bill.
double money(double v) => (v * 100).roundToDouble() / 100;

// ---------------------------------------------------------------------------
// The workshop itself
// ---------------------------------------------------------------------------

@immutable
class Garage {
  const Garage({
    required this.id,
    required this.name,
    required this.phone,
    this.altPhone = '',
    this.email = '',
    this.addressLine = '',
    this.city = '',
    this.state = '',
    this.pin = '',
    this.gstin = '',
    this.upiId = '',
    this.terms = '',
    this.logoPath,
    this.planExpiry,
    this.attendanceSite,
    this.blocked = false,
  });

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
  final String? logoPath;

  /// Subscription end date — the dashboard counts down to it.
  final DateTime? planExpiry;

  /// Where staff may punch in, and how close they have to be. Null until
  /// the owner pins one. It lives on the workshop rather than on the device
  /// because a location each phone could set for itself would not be a
  /// control at all.
  final AttendanceSite? attendanceSite;

  /// Blocked by the platform (29_block_and_district.sql). The console shows
  /// nothing but the way to support until a partner head unblocks it. Only
  /// the server sets it; the garage update strips it before sending.
  final bool blocked;

  String get postal => [
    addressLine,
    city,
    [state, pin].where((e) => e.trim().isNotEmpty).join(' '),
  ].where((e) => e.trim().isNotEmpty).join(', ');

  int get daysLeft {
    if (planExpiry == null) return 0;
    final now = DateTime.now();
    final end = DateTime(planExpiry!.year, planExpiry!.month, planExpiry!.day);
    return end.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  bool get planExpiringSoon => planExpiry != null && daysLeft <= 15;

  Garage copyWith({
    String? name,
    String? phone,
    String? altPhone,
    String? email,
    String? addressLine,
    String? city,
    String? state,
    String? pin,
    String? gstin,
    String? upiId,
    String? terms,
    String? logoPath,
    DateTime? planExpiry,
    AttendanceSite? attendanceSite,
    bool? blocked,
    // `??` cannot express "set this back to nothing", and un-pinning the
    // attendance location is exactly that.
    bool clearAttendanceSite = false,
  }) => Garage(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    altPhone: altPhone ?? this.altPhone,
    email: email ?? this.email,
    addressLine: addressLine ?? this.addressLine,
    city: city ?? this.city,
    state: state ?? this.state,
    pin: pin ?? this.pin,
    gstin: gstin ?? this.gstin,
    upiId: upiId ?? this.upiId,
    terms: terms ?? this.terms,
    logoPath: logoPath ?? this.logoPath,
    planExpiry: planExpiry ?? this.planExpiry,
    attendanceSite: clearAttendanceSite
        ? null
        : (attendanceSite ?? this.attendanceSite),
    blocked: blocked ?? this.blocked,
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
    'logo_path': logoPath,
    'plan_expiry': _iso(planExpiry),
    ...siteToJson(attendanceSite),
    'blocked': blocked,
  };

  factory Garage.fromJson(Map<String, dynamic> j) => Garage(
    id: j['id'] as String,
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
    logoPath: j['logo_path'] as String?,
    planExpiry: _date(j['plan_expiry']),
    attendanceSite: siteFromJson(j),
    blocked: (j['blocked'] ?? false) as bool,
  );
}

@immutable
class Staff {
  const Staff({
    required this.id,
    required this.name,
    this.phone = '',
    this.skill = '',
    this.active = true,
    this.designation = '',
    this.remarks = '',
  });

  final String id;
  final String name;
  final String phone;

  /// Speciality — "AC", "Denting", "Electrical".
  final String skill;
  final bool active;

  /// What they are employed as — Mechanic, Helper, Electrician… Separate
  /// from the app-login role in [StaffRole], which only some staff have.
  final String designation;
  final String remarks;

  Staff copyWith({
    String? name,
    String? phone,
    String? skill,
    bool? active,
    String? designation,
    String? remarks,
  }) => Staff(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    skill: skill ?? this.skill,
    active: active ?? this.active,
    designation: designation ?? this.designation,
    remarks: remarks ?? this.remarks,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'skill': skill,
    'active': active,
    // 35_jobcard_intake.sql. Shed by the sync until it has been run.
    'designation': designation,
    'remarks': remarks,
  };

  factory Staff.fromJson(Map<String, dynamic> j) => Staff(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    phone: (j['phone'] ?? '') as String,
    skill: (j['skill'] ?? '') as String,
    active: (j['active'] ?? true) as bool,
    designation: (j['designation'] ?? '') as String,
    remarks: (j['remarks'] ?? '') as String,
  );
}

// ---------------------------------------------------------------------------
// Customers and their vehicles
// ---------------------------------------------------------------------------

@immutable
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.altPhone = '',
    this.email = '',
    this.address = '',
    this.gstin = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String altPhone;
  final String email;
  final String address;

  /// A business customer's GST number, for a bill they can claim input tax
  /// on. Typed on the job card form, and thrown away there until now.
  final String gstin;
  final DateTime? createdAt;

  Customer copyWith({
    String? name,
    String? phone,
    String? altPhone,
    String? email,
    String? address,
    String? gstin,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    altPhone: altPhone ?? this.altPhone,
    email: email ?? this.email,
    address: address ?? this.address,
    gstin: gstin ?? this.gstin,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'alt_phone': altPhone,
    'email': email,
    'address': address,
    'gstin': gstin,
    'created_at': _iso(createdAt),
  };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    phone: (j['phone'] ?? '') as String,
    altPhone: (j['alt_phone'] ?? '') as String,
    email: (j['email'] ?? '') as String,
    address: (j['address'] ?? '') as String,
    gstin: (j['gstin'] ?? '') as String,
    createdAt: _date(j['created_at']),
  );
}

@immutable
class Vehicle {
  const Vehicle({
    required this.id,
    required this.customerId,
    required this.regNo,
    required this.brand,
    required this.model,
    this.variant = '',
    this.fuel = FuelType.petrol,
    this.transmission,
    this.shape = VehicleShape.fourWheeler,
    this.year,
    this.vin = '',
    this.engineNo = '',
    this.colour = '',
    this.insurer = '',
    this.policyNo = '',
    this.insuranceExpiry,
    this.insuranceFrom,
    this.insurerAddress = '',
    this.insurerGstin = '',
  });

  final String id;
  final String customerId;
  final String regNo;
  final String brand;
  final String model;
  final String variant;
  final FuelType fuel;

  /// Null when nobody has said. Usually filled in from the customer's own
  /// booking, which is the one place the console hears it from.
  final Transmission? transmission;

  /// What the vehicle physically is. Taken from the counter on the job card
  /// rather than guessed from the make, because the make cannot settle it —
  /// Honda and Suzuki both sell bikes and cars here — and because getting it
  /// wrong puts the wrong body on the damage sheet.
  final VehicleShape shape;

  final int? year;
  final String vin;
  final String engineNo;
  final String colour;

  /// The insurance the counter took down at check-in — typed on the job
  /// card form and, until now, dropped on the floor when the card opened.
  /// An insurance claim job cannot be filed without them.
  final String insurer;
  final String policyNo;
  final DateTime? insuranceExpiry;

  /// When the policy started, and the insurer's own address and GSTIN —
  /// what a claim invoice is billed to.
  final DateTime? insuranceFrom;
  final String insurerAddress;
  final String insurerGstin;

  /// Whether any insurance was taken down at all.
  bool get insured =>
      insurer.trim().isNotEmpty || policyNo.trim().isNotEmpty;

  /// `Maruti Suzuki 800 Old` — how the vehicle reads on every document.
  String get title =>
      [brand, model, variant].where((e) => e.trim().isNotEmpty).join(' ');

  Vehicle copyWith({
    String? regNo,
    String? brand,
    String? model,
    String? variant,
    FuelType? fuel,
    Transmission? transmission,
    VehicleShape? shape,
    int? year,
    String? vin,
    String? engineNo,
    String? colour,
    String? insurer,
    String? policyNo,
    DateTime? insuranceExpiry,
    DateTime? insuranceFrom,
    String? insurerAddress,
    String? insurerGstin,
  }) => Vehicle(
    id: id,
    customerId: customerId,
    regNo: regNo ?? this.regNo,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    variant: variant ?? this.variant,
    fuel: fuel ?? this.fuel,
    transmission: transmission ?? this.transmission,
    shape: shape ?? this.shape,
    year: year ?? this.year,
    vin: vin ?? this.vin,
    engineNo: engineNo ?? this.engineNo,
    colour: colour ?? this.colour,
    insurer: insurer ?? this.insurer,
    policyNo: policyNo ?? this.policyNo,
    insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
    insuranceFrom: insuranceFrom ?? this.insuranceFrom,
    insurerAddress: insurerAddress ?? this.insurerAddress,
    insurerGstin: insurerGstin ?? this.insurerGstin,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'reg_no': regNo,
    'brand': brand,
    'model': model,
    'variant': variant,
    'fuel': fuel.name,
    // '' rather than null: the column is NOT NULL DEFAULT '' (18_*.sql).
    'transmission': transmission?.name ?? '',
    'shape': shape.name,
    'year': year,
    'vin': vin,
    'engine_no': engineNo,
    'colour': colour,
    'insurer': insurer,
    'policy_no': policyNo,
    'insurance_expiry': _iso(insuranceExpiry),
    // 35_jobcard_intake.sql. Shed by the sync until it has been run.
    'insurance_from': _iso(insuranceFrom),
    'insurer_address': insurerAddress,
    'insurer_gstin': insurerGstin,
  };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
    id: j['id'] as String,
    customerId: (j['customer_id'] ?? '') as String,
    regNo: (j['reg_no'] ?? '') as String,
    brand: (j['brand'] ?? '') as String,
    model: (j['model'] ?? '') as String,
    variant: (j['variant'] ?? '') as String,
    fuel: FuelTypeX.parse(j['fuel'] as String?),
    transmission: TransmissionX.tryParse(j['transmission'] as String?),
    // Absent on anything saved before the counter was asked, and on a
    // row pulled from a database that has not had the column added yet.
    // Both fall back to a car, which is what the overwhelming majority
    // of those records are.
    shape: VehicleShapeX.parse(j['shape'] as String?),
    year: (j['year'] as num?)?.toInt(),
    vin: (j['vin'] ?? '') as String,
    engineNo: (j['engine_no'] ?? '') as String,
    colour: (j['colour'] ?? '') as String,
    insurer: (j['insurer'] ?? '') as String,
    policyNo: (j['policy_no'] ?? '') as String,
    insuranceExpiry: _date(j['insurance_expiry']),
    insuranceFrom: _date(j['insurance_from']),
    insurerAddress: (j['insurer_address'] ?? '') as String,
    insurerGstin: (j['insurer_gstin'] ?? '') as String,
  );
}

// ---------------------------------------------------------------------------
// Job card contents
// ---------------------------------------------------------------------------

/// One billable row. The same shape covers labour, spares and lubes so the
/// item editor, the invoice and the stock ledger all read one list.
@immutable
class LineItem {
  const LineItem({
    required this.id,
    required this.kind,
    required this.name,
    this.partNo = '',
    this.qty = 1,
    this.rate = 0,
    this.mechanicId,
    this.state = WorkState.pending,
    this.remark = '',
    this.masterId,
    this.gstRate,
    this.unit = '',
  });

  final String id;
  final LineKind kind;
  final String name;
  final String partNo;
  final double qty;
  final double rate;
  final String? mechanicId;
  final WorkState state;
  final String remark;

  /// Set when the row came from the master list, so issuing and returning the
  /// part moves the right stock row. Free-typed rows leave it null.
  final String? masterId;

  /// This line's own GST, as a fraction (0.18). Null bills it at the card's
  /// rate, which is how every line was billed before lines carried one.
  final double? gstRate;

  /// `ltr`, `kg`, `nos` — printed after the quantity. Empty prints nothing.
  final String unit;

  /// The GST this line is billed at, given the card's own rate.
  double gstOn(double cardRate) => gstRate ?? cardRate;

  double get amount => money(qty * rate);

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// `1 * 500` as it reads under the row in the editor.
  String get breakdown => '${_trim(qty)} * ${_trim(rate)}';

  String get qtyLabel => _trim(qty);

  LineItem copyWith({
    LineKind? kind,
    String? name,
    String? partNo,
    double? qty,
    double? rate,
    String? mechanicId,
    WorkState? state,
    String? remark,
    bool clearMechanic = false,
    double? gstRate,
    bool clearGst = false,
    String? unit,
  }) => LineItem(
    id: id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    partNo: partNo ?? this.partNo,
    qty: qty ?? this.qty,
    rate: rate ?? this.rate,
    mechanicId: clearMechanic ? null : (mechanicId ?? this.mechanicId),
    state: state ?? this.state,
    remark: remark ?? this.remark,
    masterId: masterId,
    gstRate: clearGst ? null : (gstRate ?? this.gstRate),
    unit: unit ?? this.unit,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    // 35_jobcard_intake.sql; save_job_card() ignores both until then.
    'gst_rate': gstRate,
    'unit': unit,
    'name': name,
    'part_no': partNo,
    'qty': qty,
    'rate': rate,
    'mechanic_id': mechanicId,
    'state': state.name,
    'remark': remark,
    'master_id': masterId,
  };

  factory LineItem.fromJson(Map<String, dynamic> j) => LineItem(
    id: j['id'] as String,
    kind: LineKindX.parse(j['kind'] as String?),
    name: (j['name'] ?? '') as String,
    partNo: (j['part_no'] ?? '') as String,
    qty: _num(j['qty']),
    rate: _num(j['rate']),
    mechanicId: j['mechanic_id'] as String?,
    state: WorkStateX.parse(j['state'] as String?),
    remark: (j['remark'] ?? '') as String,
    masterId: j['master_id'] as String?,
    gstRate: (j['gst_rate'] as num?)?.toDouble(),
    unit: (j['unit'] ?? '') as String,
  );
}

/// A mark plotted on the body diagram, stored as a 0..1 fraction of the
/// diagram box so it lands in the same place at any size.
@immutable
class DentMark {
  const DentMark({
    required this.id,
    this.view = '',
    this.part = '',
    this.label = '',
    this.points = const <double>[],
    this.dx = 0.5,
    this.dy = 0.5,
    this.severity = DentSeverity.scratch,
    this.note = '',
  });

  /// Builds a mark pinned to a named component, given where that component
  /// sits on the view it is drawn on.
  ///
  /// [at] is in the view's own, unmirrored space, so a mark taken on the
  /// passenger's flank lands in the same place on the sheet as the drawing it
  /// was taken on. The caller flips it, not this.
  factory DentMark.spot({
    required String id,
    required String view,
    required String part,
    required String label,
    required Offset at,
    DentSeverity severity = DentSeverity.scratch,
    String note = '',
  }) => DentMark(
    id: id,
    view: view,
    part: part,
    label: label,
    points: [at.dx, at.dy],
    dx: at.dx,
    dy: at.dy,
    severity: severity,
    note: note,
  );

  /// Builds a mark from a brush stroke, given as points in the view's box.
  factory DentMark.stroke({
    required String id,
    required String view,
    required List<Offset> path,
    DentSeverity severity = DentSeverity.scratch,
    String note = '',
  }) => DentMark(
    id: id,
    view: view,
    points: [
      for (final o in path) ...[o.dx, o.dy],
    ],
    dx: path.isEmpty ? 0.5 : path.first.dx,
    dy: path.isEmpty ? 0.5 : path.first.dy,
    severity: severity,
    note: note,
  );

  final String id;

  /// Which drawing this was painted on, as `<vehicleKind>.<view>` — for
  /// instance `fourWheeler.side`. Marks are only shown on the view they were
  /// put on, so a body panel never picks up someone else's damage.
  final String view;

  /// The component this was pinned to, as `<vehicleKind>.<area>.<part>` — for
  /// instance `fourWheeler.driver.door_front_right`. Empty on a brush stroke,
  /// which is damage drawn across the body rather than onto one panel.
  final String part;

  /// What that component is called, kept alongside the id so a printed copy
  /// reads properly even if the catalog is renamed under it.
  final String label;

  /// The stroke, flattened to x, y pairs, each 0..1 within the view's box.
  /// One pair is a dab rather than a drag.
  final List<double> points;

  /// Where the stroke starts, kept separately so anything that only wants a
  /// single position — the summary list, a printed copy — has one.
  final double dx;
  final double dy;

  final DentSeverity severity;
  final String note;

  /// The stroke as points again.
  List<Offset> get path => [
    for (var i = 0; i + 1 < points.length; i += 2)
      Offset(points[i], points[i + 1]),
  ];

  /// Whether this was pinned to a panel rather than painted freehand.
  bool get isSpot => part.isNotEmpty;

  /// Where the damage is, in words, for the summary list and the printed
  /// copy. A pinned mark names the panel; a brush stroke can only name the
  /// drawing it was painted on — `fourWheeler.side` reads as `side view`.
  String get where {
    if (label.isNotEmpty) return label;
    if (view.isEmpty) return 'the body';
    final dot = view.indexOf('.');
    return '${dot < 0 ? view : view.substring(dot + 1)} view';
  }

  DentMark copyWith({DentSeverity? severity, String? note}) => DentMark(
    id: id,
    view: view,
    part: part,
    label: label,
    points: points,
    dx: dx,
    dy: dy,
    severity: severity ?? this.severity,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (view.isNotEmpty) 'view': view,
    if (part.isNotEmpty) 'part': part,
    if (label.isNotEmpty) 'label': label,
    if (points.isNotEmpty) 'points': points,
    'dx': dx,
    'dy': dy,
    'severity': severity.name,
    'note': note,
  };

  factory DentMark.fromJson(Map<String, dynamic> j) => DentMark(
    id: j['id'] as String,
    view: (j['view'] ?? '') as String,
    part: (j['part'] ?? '') as String,
    label: (j['label'] ?? '') as String,
    points: [for (final v in (j['points'] as List?) ?? const []) _num(v)],
    dx: _num(j['dx']),
    dy: _num(j['dy']),
    severity: DentSeverityX.parse(j['severity'] as String?),
    note: (j['note'] ?? '') as String,
  );
}

@immutable
class Payment {
  const Payment({
    required this.id,
    required this.amount,
    required this.mode,
    required this.at,
    this.note = '',
  });

  final String id;
  final double amount;
  final PayMode mode;
  final DateTime at;
  final String note;

  /// Taken at the counter when the card was opened. Minted with an `adv-`
  /// id (see `addPayment`); older advances are known by their note.
  bool get isAdvance =>
      id.startsWith('adv-') || note.toLowerCase().contains('advance');

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'mode': mode.name,
    'at': _iso(at)!,
    'note': note,
  };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id: j['id'] as String,
    amount: _num(j['amount']),
    mode: PayModeX.parse(j['mode'] as String?),
    at: _date(j['at']) ?? DateTime.now(),
    note: (j['note'] ?? '') as String,
  );
}

/// One line of the job card message trail — what was sent, or is due to go.
@immutable
class SmsEvent {
  const SmsEvent({
    required this.id,
    required this.label,
    required this.at,
    this.state = SmsState.scheduled,
  });

  final String id;
  final String label;
  final DateTime at;
  final SmsState state;

  SmsEvent copyWith({SmsState? state, DateTime? at}) => SmsEvent(
    id: id,
    label: label,
    at: at ?? this.at,
    state: state ?? this.state,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'at': _iso(at)!,
    'state': state.name,
  };

  factory SmsEvent.fromJson(Map<String, dynamic> j) => SmsEvent(
    id: j['id'] as String,
    label: (j['label'] ?? '') as String,
    at: _date(j['at']) ?? DateTime.now(),
    state: SmsStateX.parse(j['state'] as String?),
  );
}

// ---------------------------------------------------------------------------
// The job card
// ---------------------------------------------------------------------------

@immutable
class JobCard {
  const JobCard({
    required this.id,
    required this.number,
    required this.customerId,
    required this.vehicleId,
    required this.createdAt,
    this.status = JobStatus.open,
    this.completedAt,
    this.closedAt,
    this.promisedAt,
    this.odometerKm = 0,
    this.fuelPercent = 0,
    this.mechanicIds = const [],
    this.voices = const [],
    this.accessories = const [],
    this.workNote = '',
    this.dents = const [],
    this.photos = const [],
    this.items = const [],
    this.discount = 0,
    this.taxRate = 0,
    this.payments = const [],
    this.sms = const [],
    this.nextServiceAt,
    this.nextServiceKm,
    this.estimateSentAt,
  });

  final String id;

  /// `A0914-001` — printed on every document.
  final String number;
  final String customerId;
  final String vehicleId;
  final JobStatus status;

  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? closedAt;

  /// "Vehicle needs to be ready by" — shown as a banner while open.
  final DateTime? promisedAt;

  final int odometerKm;
  final int fuelPercent;

  final List<String> mechanicIds;

  /// What the customer asked for, in their words.
  final List<String> voices;

  /// What came in with the car.
  final List<String> accessories;
  final String workNote;
  final List<DentMark> dents;

  /// File paths from the camera or gallery picker.
  final List<String> photos;

  final List<LineItem> items;
  final double discount;
  final double taxRate;
  final List<Payment> payments;
  final List<SmsEvent> sms;

  final DateTime? nextServiceAt;
  final int? nextServiceKm;
  final DateTime? estimateSentAt;

  // --- money ---------------------------------------------------------------

  List<LineItem> itemsOf(LineKind kind) =>
      items.where((e) => e.kind == kind).toList();

  double totalOf(LineKind kind) =>
      money(itemsOf(kind).fold<double>(0, (sum, e) => sum + e.amount));

  double get subTotal =>
      money(items.fold<double>(0, (sum, e) => sum + e.amount));

  double get taxable => money((subTotal - discount).clamp(0, double.infinity));

  /// Lines may carry their own GST (28% on a battery, 18% on labour); one
  /// without bills at [taxRate]. A discount comes off every line in
  /// proportion, so the tax falls with it.
  double get taxAmount {
    final sub = subTotal;
    if (sub <= 0) return 0;
    final share = taxable / sub;
    return money(
      items.fold<double>(0, (t, e) => t + e.amount * share * e.gstOn(taxRate)),
    );
  }

  /// Whether any line is billed at a rate other than the card's.
  bool get mixedGst => items.any((e) => e.gstRate != null && e.gstRate != taxRate);

  /// Money taken before the work was done — the advance, as the invoice
  /// prints it apart from what was paid at delivery.
  double get advancePaid => money(
    payments.where((p) => p.isAdvance).fold<double>(0, (s, e) => s + e.amount),
  );

  double get total => money(taxable + taxAmount);

  double get paid => money(payments.fold<double>(0, (s, e) => s + e.amount));

  double get balance => money((total - paid).clamp(0, double.infinity));

  /// Money taken beyond the bill — an advance bigger than the work turned
  /// out to be. Owed back to the customer, and shown as such, rather than
  /// the advance being cut down to the bill when it was taken.
  double get excess => money((paid - total).clamp(0, double.infinity));

  bool get settled => balance <= 0.009;

  // --- lifecycle -----------------------------------------------------------

  bool get isOpen => status == JobStatus.open;
  bool get isClosed => status == JobStatus.closed;

  /// Nothing can be completed until there is something to bill.
  bool get canComplete => status == JobStatus.open && items.isNotEmpty;
  bool get canClose => status == JobStatus.complete;

  /// Past the promised-ready time while still on the floor.
  bool get overdue =>
      isOpen && promisedAt != null && promisedAt!.isBefore(DateTime.now());

  /// The timestamp a list screen shows for the bucket it is rendering.
  DateTime stampFor(JobStatus s) => switch (s) {
    JobStatus.open => createdAt,
    JobStatus.complete => completedAt ?? createdAt,
    JobStatus.closed => closedAt ?? completedAt ?? createdAt,
  };

  JobCard copyWith({
    JobStatus? status,
    DateTime? completedAt,
    DateTime? closedAt,
    DateTime? promisedAt,
    int? odometerKm,
    int? fuelPercent,
    List<String>? mechanicIds,
    List<String>? voices,
    List<String>? accessories,
    String? workNote,
    List<DentMark>? dents,
    List<String>? photos,
    List<LineItem>? items,
    double? discount,
    double? taxRate,
    List<Payment>? payments,
    List<SmsEvent>? sms,
    DateTime? nextServiceAt,
    int? nextServiceKm,
    DateTime? estimateSentAt,
  }) => JobCard(
    id: id,
    number: number,
    customerId: customerId,
    vehicleId: vehicleId,
    createdAt: createdAt,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    closedAt: closedAt ?? this.closedAt,
    promisedAt: promisedAt ?? this.promisedAt,
    odometerKm: odometerKm ?? this.odometerKm,
    fuelPercent: fuelPercent ?? this.fuelPercent,
    mechanicIds: mechanicIds ?? this.mechanicIds,
    voices: voices ?? this.voices,
    accessories: accessories ?? this.accessories,
    workNote: workNote ?? this.workNote,
    dents: dents ?? this.dents,
    photos: photos ?? this.photos,
    items: items ?? this.items,
    discount: discount ?? this.discount,
    taxRate: taxRate ?? this.taxRate,
    payments: payments ?? this.payments,
    sms: sms ?? this.sms,
    nextServiceAt: nextServiceAt ?? this.nextServiceAt,
    nextServiceKm: nextServiceKm ?? this.nextServiceKm,
    estimateSentAt: estimateSentAt ?? this.estimateSentAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'customer_id': customerId,
    'vehicle_id': vehicleId,
    'status': status.name,
    'created_at': _iso(createdAt)!,
    'completed_at': _iso(completedAt),
    'closed_at': _iso(closedAt),
    'promised_at': _iso(promisedAt),
    'odometer_km': odometerKm,
    'fuel_percent': fuelPercent,
    'mechanic_ids': mechanicIds,
    'voices': voices,
    'accessories': accessories,
    'work_note': workNote,
    'dents': dents.map((e) => e.toJson()).toList(),
    'photos': photos,
    'items': items.map((e) => e.toJson()).toList(),
    'discount': discount,
    'tax_rate': taxRate,
    'payments': payments.map((e) => e.toJson()).toList(),
    'sms': sms.map((e) => e.toJson()).toList(),
    'next_service_at': _iso(nextServiceAt),
    'next_service_km': nextServiceKm,
    'estimate_sent_at': _iso(estimateSentAt),
  };

  factory JobCard.fromJson(Map<String, dynamic> j) => JobCard(
    id: j['id'] as String,
    number: (j['number'] ?? '') as String,
    customerId: (j['customer_id'] ?? '') as String,
    vehicleId: (j['vehicle_id'] ?? '') as String,
    status: JobStatusX.parse(j['status'] as String?),
    createdAt: _date(j['created_at']) ?? DateTime.now(),
    completedAt: _date(j['completed_at']),
    closedAt: _date(j['closed_at']),
    promisedAt: _date(j['promised_at']),
    odometerKm: (j['odometer_km'] as num?)?.toInt() ?? 0,
    fuelPercent: (j['fuel_percent'] as num?)?.toInt() ?? 0,
    mechanicIds: _strings(j['mechanic_ids']),
    voices: _strings(j['voices']),
    accessories: _strings(j['accessories']),
    workNote: (j['work_note'] ?? '') as String,
    dents: ((j['dents'] as List?) ?? const [])
        .map((e) => DentMark.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    photos: _strings(j['photos']),
    items: ((j['items'] as List?) ?? const [])
        .map((e) => LineItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    discount: _num(j['discount']),
    taxRate: _num(j['tax_rate']),
    payments: ((j['payments'] as List?) ?? const [])
        .map((e) => Payment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    sms: ((j['sms'] as List?) ?? const [])
        .map((e) => SmsEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    nextServiceAt: _date(j['next_service_at']),
    nextServiceKm: (j['next_service_km'] as num?)?.toInt(),
    estimateSentAt: _date(j['estimate_sent_at']),
  );
}

// ---------------------------------------------------------------------------
// Masters
// ---------------------------------------------------------------------------

/// A row in the labour / spare / lube master list, with stock for the two
/// kinds actually held in the store.
///
/// One shape covers all three kinds, and the fields that only make sense for
/// some of them simply sit at their defaults on the rest: a labour row has no
/// [make], no [rack] and no [cost], and a spare is never [outsourced]. That is
/// cheaper than three near-identical models, and it is what lets the billing
/// screens, the master list and the counter sale all read one list.
@immutable
class MasterItem {
  const MasterItem({
    required this.id,
    required this.kind,
    required this.name,
    this.partNo = '',
    this.rate = 0,
    this.cost = 0,
    this.stock = 0,
    this.unit = 'nos',
    this.lowAt = 2,
    this.make = '',
    this.rack = '',
    this.group = PartGroup.running,
    this.outsourced = false,
    this.fits = const <String>[],
  });

  final String id;
  final LineKind kind;
  final String name;
  final String partNo;

  /// What the customer is charged. The sale price on the editor.
  final double rate;

  /// What the workshop paid for it. Zero on labour, and zero on any spare
  /// received before the purchase price was being recorded — so [margin] is
  /// only shown where it was actually filled in.
  final double cost;

  final double stock;
  final String unit;
  final double lowAt;

  /// Brand of the part — Bosch, Yamalube, Minda. Not the vehicle's make.
  final String make;

  /// Where it physically sits in the store. Free text: workshops number
  /// their racks however they like.
  final String rack;

  /// Shelf grouping, spares only.
  final PartGroup group;

  /// Labour only: sent out to a specialist rather than done in house.
  final bool outsourced;

  /// Vehicles this fits, as the counter typed them. Advisory — nothing stops
  /// a part going onto a card for a vehicle that is not listed.
  final List<String> fits;

  bool get tracksStock => kind.isStocked;
  bool get low => tracksStock && stock <= lowAt && stock > 0;
  bool get out => tracksStock && stock <= 0;

  /// What the workshop makes on one of it, or null where no purchase price
  /// was ever recorded and the figure would be a lie.
  double? get margin => cost <= 0 ? null : money(rate - cost);

  /// Margin as a share of the sale price, 0..1.
  double? get marginPercent {
    final m = margin;
    if (m == null || rate <= 0) return null;
    return m / rate;
  }

  MasterItem copyWith({
    String? name,
    String? partNo,
    double? rate,
    double? cost,
    double? stock,
    String? unit,
    double? lowAt,
    String? make,
    String? rack,
    PartGroup? group,
    bool? outsourced,
    List<String>? fits,
  }) => MasterItem(
    id: id,
    kind: kind,
    name: name ?? this.name,
    partNo: partNo ?? this.partNo,
    rate: rate ?? this.rate,
    cost: cost ?? this.cost,
    stock: stock ?? this.stock,
    unit: unit ?? this.unit,
    lowAt: lowAt ?? this.lowAt,
    make: make ?? this.make,
    rack: rack ?? this.rack,
    group: group ?? this.group,
    outsourced: outsourced ?? this.outsourced,
    fits: fits ?? this.fits,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'part_no': partNo,
    'rate': rate,
    'cost': cost,
    'stock': stock,
    'unit': unit,
    'low_at': lowAt,
    'make': make,
    'rack': rack,
    'part_group': group.name,
    'outsourced': outsourced,
    'fits': fits,
  };

  factory MasterItem.fromJson(Map<String, dynamic> j) => MasterItem(
    id: j['id'] as String,
    kind: LineKindX.parse(j['kind'] as String?),
    name: (j['name'] ?? '') as String,
    partNo: (j['part_no'] ?? '') as String,
    rate: _num(j['rate']),
    cost: _num(j['cost']),
    stock: _num(j['stock']),
    unit: (j['unit'] ?? 'nos') as String,
    lowAt: _num(j['low_at']),
    make: (j['make'] ?? '') as String,
    rack: (j['rack'] ?? '') as String,
    group: PartGroupX.parse(j['part_group'] as String?),
    outsourced: (j['outsourced'] ?? false) as bool,
    fits: _strings(j['fits']),
  );
}

/// A customer asking for a slot before any job card exists.
@immutable
class Booking {
  const Booking({
    required this.id,
    required this.name,
    required this.phone,
    required this.at,
    this.regNo = '',
    this.vehicle = '',
    this.note = '',
    this.accepted = false,
    this.jobCardId,
    this.brand = '',
    this.model = '',
    this.variant = '',
    this.fuel,
    this.transmission,
    this.year,
    this.odometerKm,
    this.pickup = false,
    this.customerNote = '',
  });

  final String id;
  final String name;
  final String phone;
  final DateTime at;
  final String regNo;

  /// "Brand Model" as one string. What every booking carried before the
  /// columns below existed, and still the only thing an older customer app
  /// sends. Read through [brandModel], never split by hand.
  final String vehicle;

  /// The services the customer ticked, comma separated.
  final String note;
  final bool accepted;
  final String? jobCardId;

  // The car as the customer described it in their app (18_*.sql). Empty or
  // null on a booking from an older app, or one raised at this counter.
  final String brand;
  final String model;
  final String variant;
  final FuelType? fuel;
  final Transmission? transmission;
  final int? year;
  final int? odometerKm;

  /// Pick & drop rather than the customer driving in.
  final bool pickup;

  /// What the customer typed under "Additional notes".
  final String customerNote;

  /// Brand and model, from the columns when the booking has them, otherwise
  /// from [vehicle] matched against the makes the console knows.
  ///
  /// The console used to split [vehicle] on its first space, which turned
  /// "Maruti Suzuki Swift" into a brand of "Maruti" and a model of "Suzuki
  /// Swift" — and every two-word make (Land Rover, Mercedes-Benz AMG,
  /// Maruti Suzuki) went the same way. The longest known make the string
  /// starts with wins; only an unknown make falls back to the first space.
  ({String brand, String model}) brandModel(Iterable<String> knownMakes) {
    if (brand.trim().isNotEmpty) {
      return (brand: brand.trim(), model: model.trim());
    }
    final text = vehicle.trim();
    if (text.isEmpty) return (brand: '', model: '');
    String? best;
    for (final make in knownMakes) {
      final hit = text.toLowerCase() == make.toLowerCase() ||
          text.toLowerCase().startsWith('${make.toLowerCase()} ');
      if (hit && make.length > (best?.length ?? 0)) best = make;
    }
    if (best != null) {
      return (brand: best, model: text.substring(best.length).trim());
    }
    final space = text.indexOf(' ');
    return space < 0
        ? (brand: text, model: '')
        : (brand: text.substring(0, space), model: text.substring(space + 1));
  }

  Booking copyWith({bool? accepted, String? jobCardId}) => Booking(
    id: id,
    name: name,
    phone: phone,
    at: at,
    regNo: regNo,
    vehicle: vehicle,
    note: note,
    accepted: accepted ?? this.accepted,
    jobCardId: jobCardId ?? this.jobCardId,
    brand: brand,
    model: model,
    variant: variant,
    fuel: fuel,
    transmission: transmission,
    year: year,
    odometerKm: odometerKm,
    pickup: pickup,
    customerNote: customerNote,
  );

  /// What the console writes back to `garage_bookings`: the front-desk
  /// columns only.
  ///
  /// The car details are the customer's, written once by their app, and are
  /// deliberately not in here. An upsert only sets the columns it is sent,
  /// so leaving them out means accepting a booking can never blank them —
  /// and a console running against a database that has not had
  /// 18_booking_vehicle_details.sql yet does not trip over columns it
  /// lacks.
  Map<String, dynamic> toRow() => {
    'id': id,
    'name': name,
    'phone': phone,
    'at': _iso(at)!,
    'reg_no': regNo,
    'vehicle': vehicle,
    'note': note,
    'accepted': accepted,
    'job_card_id': jobCardId,
  };

  /// Everything, for the on-device store, so a booking read before a restart
  /// still has its car after one.
  Map<String, dynamic> toJson() => {
    ...toRow(),
    'brand': brand,
    'model': model,
    'variant': variant,
    'fuel': fuel?.name ?? '',
    'transmission': transmission?.name ?? '',
    'year': year,
    'odometer_km': odometerKm,
    'mode': pickup ? 'pickup' : 'garage',
    'customer_note': customerNote,
  };

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    phone: (j['phone'] ?? '') as String,
    at: _date(j['at']) ?? DateTime.now(),
    regNo: (j['reg_no'] ?? '') as String,
    vehicle: (j['vehicle'] ?? '') as String,
    note: (j['note'] ?? '') as String,
    accepted: (j['accepted'] ?? false) as bool,
    jobCardId: j['job_card_id'] as String?,
    brand: (j['brand'] ?? '') as String,
    model: (j['model'] ?? '') as String,
    variant: (j['variant'] ?? '') as String,
    fuel: FuelTypeX.tryParse(j['fuel'] as String?),
    transmission: TransmissionX.tryParse(j['transmission'] as String?),
    year: (j['year'] as num?)?.toInt(),
    odometerKm: (j['odometer_km'] as num?)?.toInt(),
    pickup: j['mode'] == 'pickup',
    customerNote: (j['customer_note'] ?? '') as String,
  );
}

/// A rating left against a closed job card.
@immutable
class Review {
  const Review({
    required this.id,
    required this.jobCardId,
    required this.stars,
    required this.at,
    this.comment = '',
  });

  final String id;
  final String jobCardId;
  final int stars;
  final DateTime at;
  final String comment;

  Map<String, dynamic> toJson() => {
    'id': id,
    'job_card_id': jobCardId,
    'stars': stars,
    'at': _iso(at)!,
    'comment': comment,
  };

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] as String,
    jobCardId: (j['job_card_id'] ?? '') as String,
    stars: (j['stars'] as num?)?.toInt() ?? 5,
    at: _date(j['at']) ?? DateTime.now(),
    comment: (j['comment'] ?? '') as String,
  );
}

// ---------------------------------------------------------------------------
// Money that does not sit on a job card
// ---------------------------------------------------------------------------

/// A shop expense — rent, electricity, a part bought from a supplier. Part of
/// it can stay unpaid, which is what the Expense screen totals as pending.
@immutable
class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.at,
    this.category = 'General',
    this.supplier = '',
    this.paid = 0,
    this.note = '',
    this.mode = PayMode.cash,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime at;
  final String category;
  final String supplier;
  final double paid;
  final String note;

  /// How the paid part went out — cash from the drawer, or online (UPI,
  /// bank transfer) from the bank account.
  final PayMode mode;

  double get pending => money((amount - paid).clamp(0, double.infinity));
  bool get settled => pending <= 0.009;

  Expense copyWith({
    String? title,
    double? amount,
    DateTime? at,
    String? category,
    String? supplier,
    double? paid,
    String? note,
    PayMode? mode,
  }) => Expense(
    id: id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    at: at ?? this.at,
    category: category ?? this.category,
    supplier: supplier ?? this.supplier,
    paid: paid ?? this.paid,
    note: note ?? this.note,
    mode: mode ?? this.mode,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'mode': mode.name,
    'amount': amount,
    'at': _iso(at)!,
    'category': category,
    'supplier': supplier,
    'paid': paid,
    'note': note,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'] as String,
    title: (j['title'] ?? '') as String,
    amount: _num(j['amount']),
    at: _date(j['at']) ?? DateTime.now(),
    category: (j['category'] ?? 'General') as String,
    supplier: (j['supplier'] ?? '') as String,
    paid: _num(j['paid']),
    note: (j['note'] ?? '') as String,
    mode: PayModeX.parse(j['mode'] as String?),
  );
}

/// One line in the day book. Cash in is money received, cash out is money
/// paid away; the CashBook screen pages a day at a time through these.
@immutable
class CashEntry {
  const CashEntry({
    required this.id,
    required this.party,
    required this.amount,
    required this.at,
    required this.inward,
    this.reason = '',
    this.mode = PayMode.cash,
    this.jobCardId,
    this.accountId,
  });

  final String id;
  final String party;
  final double amount;
  final DateTime at;

  /// True for money received, false for money paid out.
  final bool inward;
  final String reason;
  final PayMode mode;
  final String? jobCardId;

  /// The bank account this went through, when it was named. Null means
  /// "by the mode": cash is the drawer, anything else the primary bank.
  final String? accountId;

  /// Whether the money moved through the drawer rather than a bank.
  bool get isCash => mode == PayMode.cash && accountId == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'party': party,
    'amount': amount,
    'at': _iso(at)!,
    'inward': inward,
    'reason': reason,
    'mode': mode.name,
    'job_card_id': jobCardId,
    // 35_jobcard_intake.sql. Shed by the sync until it has been run.
    'account_id': accountId,
  };

  factory CashEntry.fromJson(Map<String, dynamic> j) => CashEntry(
    id: j['id'] as String,
    party: (j['party'] ?? '') as String,
    amount: _num(j['amount']),
    at: _date(j['at']) ?? DateTime.now(),
    inward: (j['inward'] ?? true) as bool,
    reason: (j['reason'] ?? '') as String,
    mode: PayModeX.parse(j['mode'] as String?),
    jobCardId: j['job_card_id'] as String?,
    accountId: j['account_id'] as String?,
  );
}

/// Somebody the workshop buys spares from.
@immutable
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.gstin = '',
    this.outstanding = 0,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String gstin;
  final double outstanding;

  Supplier copyWith({
    String? name,
    String? phone,
    String? address,
    String? gstin,
    double? outstanding,
  }) => Supplier(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    gstin: gstin ?? this.gstin,
    outstanding: outstanding ?? this.outstanding,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'gstin': gstin,
    'outstanding': outstanding,
  };

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    phone: (j['phone'] ?? '') as String,
    address: (j['address'] ?? '') as String,
    gstin: (j['gstin'] ?? '') as String,
    outstanding: _num(j['outstanding']),
  );
}

/// A spare or lube sold over the counter, with no job card behind it.
@immutable
class CounterSale {
  const CounterSale({
    required this.id,
    required this.number,
    required this.customer,
    required this.at,
    this.phone = '',
    this.items = const [],
    this.paid = 0,
  });

  final String id;
  final String number;
  final String customer;
  final DateTime at;
  final String phone;
  final List<LineItem> items;
  final double paid;

  double get total => money(items.fold<double>(0, (s, e) => s + e.amount));
  double get balance => money((total - paid).clamp(0, double.infinity));

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'customer': customer,
    'at': _iso(at)!,
    'phone': phone,
    'items': items.map((e) => e.toJson()).toList(),
    'paid': paid,
  };

  factory CounterSale.fromJson(Map<String, dynamic> j) => CounterSale(
    id: j['id'] as String,
    number: (j['number'] ?? '') as String,
    customer: (j['customer'] ?? '') as String,
    at: _date(j['at']) ?? DateTime.now(),
    phone: (j['phone'] ?? '') as String,
    items: ((j['items'] as List?) ?? const [])
        .map((e) => LineItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    paid: _num(j['paid']),
  );
}

/// A service the workshop has chosen to show on its public online garage page.
@immutable
class OnlineService {
  const OnlineService({
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'blurb': blurb,
    'duration_mins': durationMins,
  };

  factory OnlineService.fromJson(Map<String, dynamic> j) => OnlineService(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    price: _num(j['price']),
    blurb: (j['blurb'] ?? '') as String,
    durationMins: (j['duration_mins'] as num?)?.toInt() ?? 60,
  );
}

/// An order placed on a supplier. Receiving it is what puts the parts on the
/// shelf, so stock never moves on a promise.
@immutable
class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.number,
    required this.supplierId,
    required this.at,
    this.items = const [],
    this.received = false,
    this.receivedAt,
    this.note = '',
  });

  final String id;
  final String number;
  final String supplierId;
  final DateTime at;
  final List<LineItem> items;
  final bool received;
  final DateTime? receivedAt;
  final String note;

  double get total => money(items.fold<double>(0, (s, e) => s + e.amount));

  double get qty => items.fold<double>(0, (s, e) => s + e.qty);

  PurchaseOrder copyWith({bool? received, DateTime? receivedAt}) =>
      PurchaseOrder(
        id: id,
        number: number,
        supplierId: supplierId,
        at: at,
        items: items,
        received: received ?? this.received,
        receivedAt: receivedAt ?? this.receivedAt,
        note: note,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'supplier_id': supplierId,
    'at': _iso(at)!,
    'items': items.map((e) => e.toJson()).toList(),
    'received': received,
    'received_at': _iso(receivedAt),
    'note': note,
  };

  factory PurchaseOrder.fromJson(Map<String, dynamic> j) => PurchaseOrder(
    id: j['id'] as String,
    number: (j['number'] ?? '') as String,
    supplierId: (j['supplier_id'] ?? '') as String,
    at: _date(j['at']) ?? DateTime.now(),
    items: ((j['items'] as List?) ?? const [])
        .map((e) => LineItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    received: (j['received'] ?? false) as bool,
    receivedAt: _date(j['received_at']),
    note: (j['note'] ?? '') as String,
  );
}

// ---------------------------------------------------------------------------
// The bell
// ---------------------------------------------------------------------------

/// One alert in the workshop's feed.
///
/// Unlike everything else in this file, these are not the console's to
/// write. Rows are raised by triggers in `06_notifications.sql` at the
/// moment the thing they describe happened, and the app only ever reads
/// them and marks them read — so the local list is a cache of the
/// workshop's feed, not a second copy with equal standing.
@immutable
class GarageNotification {
  const GarageNotification({
    required this.id,
    required this.title,
    required this.at,
    this.kind = 'booking',
    this.body = '',
    this.route,
    this.bookingId,
    this.jobCardId,
    this.read = false,
  });

  final String id;

  /// What raised it: `booking`, `review`. Held as a plain string so a kind
  /// added on the server does not have to be taught to an app already on a
  /// phone — an unknown kind still shows, with the default icon.
  final String kind;

  final String title;
  final String body;
  final DateTime at;

  /// The console path this opens, decided when the row was written.
  final String? route;

  final String? bookingId;
  final String? jobCardId;
  final bool read;

  GarageNotification copyWith({bool? read}) => GarageNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    at: at,
    route: route,
    bookingId: bookingId,
    jobCardId: jobCardId,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'body': body,
    'at': _iso(at)!,
    'route': route,
    'booking_id': bookingId,
    'job_card_id': jobCardId,
    'read': read,
  };

  factory GarageNotification.fromJson(Map<String, dynamic> j) =>
      GarageNotification(
        id: j['id'] as String,
        kind: (j['kind'] ?? 'booking') as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        at: _date(j['at']) ?? DateTime.now(),
        route: j['route'] as String?,
        bookingId: j['booking_id'] as String?,
        jobCardId: j['job_card_id'] as String?,
        read: (j['read'] ?? false) as bool,
      );
}
