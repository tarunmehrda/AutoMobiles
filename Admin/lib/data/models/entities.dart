import 'package:flutter/foundation.dart';

import 'enums.dart';

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

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
  }) =>
      Garage(
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
        'plan_expiry': planExpiry?.toIso8601String(),
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
  });

  final String id;
  final String name;
  final String phone;
  final String skill;
  final bool active;

  Staff copyWith({String? name, String? phone, String? skill, bool? active}) =>
      Staff(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        skill: skill ?? this.skill,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'skill': skill,
        'active': active,
      };

  factory Staff.fromJson(Map<String, dynamic> j) => Staff(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        skill: (j['skill'] ?? '') as String,
        active: (j['active'] ?? true) as bool,
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
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String altPhone;
  final String email;
  final String address;
  final DateTime? createdAt;

  Customer copyWith({
    String? name,
    String? phone,
    String? altPhone,
    String? email,
    String? address,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        altPhone: altPhone ?? this.altPhone,
        email: email ?? this.email,
        address: address ?? this.address,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'alt_phone': altPhone,
        'email': email,
        'address': address,
        'created_at': createdAt?.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        altPhone: (j['alt_phone'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        address: (j['address'] ?? '') as String,
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
    this.year,
    this.vin = '',
    this.engineNo = '',
    this.colour = '',
  });

  final String id;
  final String customerId;
  final String regNo;
  final String brand;
  final String model;
  final String variant;
  final FuelType fuel;
  final int? year;
  final String vin;
  final String engineNo;
  final String colour;

  /// `Maruti Suzuki 800 Old` — how the vehicle reads on every document.
  String get title =>
      [brand, model, variant].where((e) => e.trim().isNotEmpty).join(' ');

  Vehicle copyWith({
    String? regNo,
    String? brand,
    String? model,
    String? variant,
    FuelType? fuel,
    int? year,
    String? vin,
    String? engineNo,
    String? colour,
  }) =>
      Vehicle(
        id: id,
        customerId: customerId,
        regNo: regNo ?? this.regNo,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        variant: variant ?? this.variant,
        fuel: fuel ?? this.fuel,
        year: year ?? this.year,
        vin: vin ?? this.vin,
        engineNo: engineNo ?? this.engineNo,
        colour: colour ?? this.colour,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'reg_no': regNo,
        'brand': brand,
        'model': model,
        'variant': variant,
        'fuel': fuel.name,
        'year': year,
        'vin': vin,
        'engine_no': engineNo,
        'colour': colour,
      };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        customerId: (j['customer_id'] ?? '') as String,
        regNo: (j['reg_no'] ?? '') as String,
        brand: (j['brand'] ?? '') as String,
        model: (j['model'] ?? '') as String,
        variant: (j['variant'] ?? '') as String,
        fuel: FuelTypeX.parse(j['fuel'] as String?),
        year: (j['year'] as num?)?.toInt(),
        vin: (j['vin'] ?? '') as String,
        engineNo: (j['engine_no'] ?? '') as String,
        colour: (j['colour'] ?? '') as String,
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
  }) =>
      LineItem(
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
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
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
      );
}

/// A mark plotted on the body diagram, stored as a 0..1 fraction of the
/// diagram box so it lands in the same place at any size.
@immutable
class DentMark {
  const DentMark({
    required this.id,
    required this.dx,
    required this.dy,
    this.severity = DentSeverity.scratch,
    this.note = '',
  });

  final String id;
  final double dx;
  final double dy;
  final DentSeverity severity;
  final String note;

  DentMark copyWith({DentSeverity? severity, String? note}) => DentMark(
        id: id,
        dx: dx,
        dy: dy,
        severity: severity ?? this.severity,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dx': dx,
        'dy': dy,
        'severity': severity.name,
        'note': note,
      };

  factory DentMark.fromJson(Map<String, dynamic> j) => DentMark(
        id: j['id'] as String,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'mode': mode.name,
        'at': at.toIso8601String(),
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
        'at': at.toIso8601String(),
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

  double get taxAmount => money(taxable * taxRate);

  double get total => money(taxable + taxAmount);

  double get paid => money(payments.fold<double>(0, (s, e) => s + e.amount));

  double get balance => money((total - paid).clamp(0, double.infinity));

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
  }) =>
      JobCard(
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
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
        'promised_at': promisedAt?.toIso8601String(),
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
        'next_service_at': nextServiceAt?.toIso8601String(),
        'next_service_km': nextServiceKm,
        'estimate_sent_at': estimateSentAt?.toIso8601String(),
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
@immutable
class MasterItem {
  const MasterItem({
    required this.id,
    required this.kind,
    required this.name,
    this.partNo = '',
    this.rate = 0,
    this.stock = 0,
    this.unit = 'nos',
    this.lowAt = 2,
  });

  final String id;
  final LineKind kind;
  final String name;
  final String partNo;
  final double rate;
  final double stock;
  final String unit;
  final double lowAt;

  bool get tracksStock => kind.isStocked;
  bool get low => tracksStock && stock <= lowAt && stock > 0;
  bool get out => tracksStock && stock <= 0;

  MasterItem copyWith({
    String? name,
    String? partNo,
    double? rate,
    double? stock,
    String? unit,
    double? lowAt,
  }) =>
      MasterItem(
        id: id,
        kind: kind,
        name: name ?? this.name,
        partNo: partNo ?? this.partNo,
        rate: rate ?? this.rate,
        stock: stock ?? this.stock,
        unit: unit ?? this.unit,
        lowAt: lowAt ?? this.lowAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'part_no': partNo,
        'rate': rate,
        'stock': stock,
        'unit': unit,
        'low_at': lowAt,
      };

  factory MasterItem.fromJson(Map<String, dynamic> j) => MasterItem(
        id: j['id'] as String,
        kind: LineKindX.parse(j['kind'] as String?),
        name: (j['name'] ?? '') as String,
        partNo: (j['part_no'] ?? '') as String,
        rate: _num(j['rate']),
        stock: _num(j['stock']),
        unit: (j['unit'] ?? 'nos') as String,
        lowAt: _num(j['low_at']),
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
  });

  final String id;
  final String name;
  final String phone;
  final DateTime at;
  final String regNo;
  final String vehicle;
  final String note;
  final bool accepted;
  final String? jobCardId;

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
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'at': at.toIso8601String(),
        'reg_no': regNo,
        'vehicle': vehicle,
        'note': note,
        'accepted': accepted,
        'job_card_id': jobCardId,
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
        'at': at.toIso8601String(),
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
