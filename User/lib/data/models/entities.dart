import 'package:flutter/material.dart';

import 'enums.dart';

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.dob,
    this.gender,
    this.avatarUrl,
    this.referralCode,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final DateTime? dob;
  final String? gender;
  final String? avatarUrl;
  final String? referralCode;
  final DateTime? createdAt;

  /// [phone] is editable like the rest. It used to be fixed at sign-in,
  /// which left every Google account with an empty number forever — and the
  /// workshop matches a booking to its customer by that number. Nothing on
  /// the server grants access on the strength of a typed phone, so letting
  /// the customer set it is safe.
  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    DateTime? dob,
    String? gender,
    String? avatarUrl,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        dob: dob ?? this.dob,
        gender: gender ?? this.gender,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        referralCode: referralCode,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'dob': dob?.toIso8601String(),
        'gender': gender,
        'avatar_url': avatarUrl,
        'referral_code': referralCode,
        'created_at': createdAt?.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        email: j['email'] as String?,
        dob: _date(j['dob']),
        gender: j['gender'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        referralCode: j['referral_code'] as String?,
        createdAt: _date(j['created_at']),
      );
}

@immutable
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.house,
    required this.street,
    required this.area,
    required this.city,
    required this.state,
    required this.pin,
    this.landmark,
    this.contactName,
    this.contactPhone,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String house;
  final String street;
  final String area;
  final String city;
  final String state;
  final String pin;
  final String? landmark;
  final String? contactName;
  final String? contactPhone;
  final bool isDefault;

  String get oneLine =>
      [house, street, area, city, '$state $pin'].where((e) => e.trim().isNotEmpty).join(', ');

  String get shortLine =>
      [area, city].where((e) => e.trim().isNotEmpty).join(', ');

  IconData get icon => switch (label.toLowerCase()) {
        'home' => Icons.home_rounded,
        'office' || 'work' => Icons.business_center_rounded,
        _ => Icons.place_rounded,
      };

  Address copyWith({
    String? label,
    String? house,
    String? street,
    String? area,
    String? city,
    String? state,
    String? pin,
    String? landmark,
    String? contactName,
    String? contactPhone,
    bool? isDefault,
  }) =>
      Address(
        id: id,
        label: label ?? this.label,
        house: house ?? this.house,
        street: street ?? this.street,
        area: area ?? this.area,
        city: city ?? this.city,
        state: state ?? this.state,
        pin: pin ?? this.pin,
        landmark: landmark ?? this.landmark,
        contactName: contactName ?? this.contactName,
        contactPhone: contactPhone ?? this.contactPhone,
        isDefault: isDefault ?? this.isDefault,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'house': house,
        'street': street,
        'area': area,
        'city': city,
        'state': state,
        'pin': pin,
        'landmark': landmark,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'is_default': isDefault,
      };

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: j['id'] as String,
        label: (j['label'] ?? 'Home') as String,
        house: (j['house'] ?? '') as String,
        street: (j['street'] ?? '') as String,
        area: (j['area'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        state: (j['state'] ?? '') as String,
        pin: (j['pin'] ?? '') as String,
        landmark: j['landmark'] as String?,
        contactName: j['contact_name'] as String?,
        contactPhone: j['contact_phone'] as String?,
        isDefault: (j['is_default'] ?? false) as bool,
      );
}

// ---------------------------------------------------------------------------
// Vehicles
// ---------------------------------------------------------------------------

@immutable
class VehicleBrand {
  const VehicleBrand({
    required this.id,
    required this.name,
    required this.logoUrl,
    this.popular = false,
    this.accent = 0xFF6B7684,
  });

  final String id;
  final String name;
  final String logoUrl;
  final bool popular;
  final int accent;

  Color get color => Color(accent);
}

@immutable
class VehicleModel {
  const VehicleModel({
    required this.id,
    required this.brandId,
    required this.name,
    required this.body,
    this.imageUrl,
    this.variants = const [],
  });

  final String id;
  final String brandId;
  final String name;
  final BodyType body;
  final String? imageUrl;
  final List<String> variants;
}

@immutable
class Vehicle {
  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.regNumber,
    required this.fuel,
    required this.transmission,
    required this.year,
    this.body = BodyType.hatchback,
    this.variant,
    this.odometerKm = 0,
    this.imageUrl,
    this.insuranceExpiry,
    this.pucExpiry,
    this.vin,
    this.isPrimary = false,
    this.lastServiceDate,
    this.lastServiceKm,
    this.colorHex,
  });

  final String id;
  final String brand;
  final String model;
  final String regNumber;
  final FuelType fuel;
  final Transmission transmission;
  final int year;
  final BodyType body;
  final String? variant;
  final int odometerKm;
  final String? imageUrl;
  final DateTime? insuranceExpiry;
  final DateTime? pucExpiry;
  final String? vin;
  final bool isPrimary;
  final DateTime? lastServiceDate;
  final int? lastServiceKm;
  final String? colorHex;

  String get title => '$brand $model';
  String get specLine =>
      '${fuel.label} • ${transmission.label} • $year';

  /// Next service is due 6 months or 10,000 km after the last one.
  DateTime get nextServiceDue =>
      (lastServiceDate ?? DateTime.now()).add(const Duration(days: 182));

  int get daysToService =>
      nextServiceDue.difference(DateTime.now()).inDays;

  Vehicle copyWith({
    String? brand,
    String? model,
    String? regNumber,
    FuelType? fuel,
    Transmission? transmission,
    int? year,
    BodyType? body,
    String? variant,
    int? odometerKm,
    String? imageUrl,
    DateTime? insuranceExpiry,
    DateTime? pucExpiry,
    String? vin,
    bool? isPrimary,
    DateTime? lastServiceDate,
    int? lastServiceKm,
  }) =>
      Vehicle(
        id: id,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        regNumber: regNumber ?? this.regNumber,
        fuel: fuel ?? this.fuel,
        transmission: transmission ?? this.transmission,
        year: year ?? this.year,
        body: body ?? this.body,
        variant: variant ?? this.variant,
        odometerKm: odometerKm ?? this.odometerKm,
        imageUrl: imageUrl ?? this.imageUrl,
        insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
        pucExpiry: pucExpiry ?? this.pucExpiry,
        vin: vin ?? this.vin,
        isPrimary: isPrimary ?? this.isPrimary,
        lastServiceDate: lastServiceDate ?? this.lastServiceDate,
        lastServiceKm: lastServiceKm ?? this.lastServiceKm,
        colorHex: colorHex,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'model': model,
        'reg_number': regNumber,
        'fuel': fuel.name,
        'transmission': transmission.name,
        'year': year,
        'body': body.name,
        'variant': variant,
        'odometer_km': odometerKm,
        'image_url': imageUrl,
        'insurance_expiry': insuranceExpiry?.toIso8601String(),
        'puc_expiry': pucExpiry?.toIso8601String(),
        'vin': vin,
        'is_primary': isPrimary,
        'last_service_date': lastServiceDate?.toIso8601String(),
        'last_service_km': lastServiceKm,
        'color_hex': colorHex,
      };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        brand: (j['brand'] ?? '') as String,
        model: (j['model'] ?? '') as String,
        regNumber: (j['reg_number'] ?? '') as String,
        fuel: FuelTypeX.parse(j['fuel'] as String?),
        transmission: TransmissionX.parse(j['transmission'] as String?),
        year: (j['year'] ?? DateTime.now().year) as int,
        body: BodyTypeX.parse(j['body'] as String?),
        variant: j['variant'] as String?,
        odometerKm: (j['odometer_km'] ?? 0) as int,
        imageUrl: j['image_url'] as String?,
        insuranceExpiry: _date(j['insurance_expiry']),
        pucExpiry: _date(j['puc_expiry']),
        vin: j['vin'] as String?,
        isPrimary: (j['is_primary'] ?? false) as bool,
        lastServiceDate: _date(j['last_service_date']),
        lastServiceKm: j['last_service_km'] as int?,
        colorHex: j['color_hex'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Catalogue
// ---------------------------------------------------------------------------

@immutable
class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.accent,
    this.featured = false,
  });

  final String id;
  final String name;
  final String tagline;
  final IconData icon;
  final int accent;
  final bool featured;

  Color get color => Color(accent);
}

@immutable
class ServicePackage {
  const ServicePackage({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.subtitle,
    required this.mrp,
    required this.price,
    required this.durationHours,
    required this.warrantyMonths,
    this.recommendedEveryKm,
    this.includes = const [],
    this.excludes = const [],
    this.description = '',
    this.tags = const [],
    this.rating = 4.7,
    this.reviewCount = 0,
    this.popular = false,
    this.imageUrl,
    this.groups = const [],
  });

  final String id;
  final String categoryId;
  final String name;
  final String subtitle;
  final int mrp;
  final int price;
  final double durationHours;
  final int warrantyMonths;
  final int? recommendedEveryKm;
  final List<String> includes;
  final List<String> excludes;
  final String description;
  final List<String> tags;
  final double rating;
  final int reviewCount;
  final bool popular;
  final String? imageUrl;

  /// Tab groupings inside a category screen, e.g. "Scheduled packages".
  final List<String> groups;

  int get savings => mrp - price;
  int get discountPercent =>
      mrp <= 0 ? 0 : (((mrp - price) / mrp) * 100).round();
}

@immutable
class AddOn {
  const AddOn({
    required this.id,
    required this.name,
    required this.price,
    required this.blurb,
    required this.icon,
    this.mrp,
    this.durationMins = 30,
  });

  final String id;
  final String name;
  final int price;
  final String blurb;
  final IconData icon;
  final int? mrp;
  final int durationMins;
}

@immutable
class Coupon {
  const Coupon({
    required this.code,
    required this.title,
    required this.blurb,
    required this.isPercent,
    required this.value,
    this.minOrder = 0,
    this.maxDiscount,
    required this.validTill,
    this.accent = 0xFFFF5F2E,
  });

  final String code;
  final String title;
  final String blurb;
  final bool isPercent;
  final int value;
  final int minOrder;
  final int? maxDiscount;
  final DateTime validTill;
  final int accent;

  Color get color => Color(accent);

  int discountFor(int subtotal) {
    if (subtotal < minOrder) return 0;
    final raw = isPercent ? (subtotal * value / 100).round() : value;
    if (maxDiscount != null && raw > maxDiscount!) return maxDiscount!;
    return raw > subtotal ? subtotal : raw;
  }

  bool get isLive => DateTime.now().isBefore(validTill);
}

// ---------------------------------------------------------------------------
// Cart & bookings
// ---------------------------------------------------------------------------

@immutable
class CartLine {
  const CartLine({
    required this.id,
    required this.name,
    required this.price,
    required this.mrp,
    required this.isAddOn,
    this.durationHours = 0,
    this.categoryId,
  });

  final String id;
  final String name;
  final int price;
  final int mrp;
  final bool isAddOn;
  final double durationHours;
  final String? categoryId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'mrp': mrp,
        'is_add_on': isAddOn,
        'duration_hours': durationHours,
        'category_id': categoryId,
      };

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        price: (j['price'] ?? 0) as int,
        mrp: (j['mrp'] ?? 0) as int,
        isAddOn: (j['is_add_on'] ?? false) as bool,
        durationHours: ((j['duration_hours'] ?? 0) as num).toDouble(),
        categoryId: j['category_id'] as String?,
      );
}

@immutable
class TimelineEvent {
  const TimelineEvent({
    required this.stage,
    required this.at,
    this.note,
    this.photos = const [],
    this.actor,
  });

  final JobStage stage;
  final DateTime at;
  final String? note;
  final List<String> photos;
  final String? actor;

  Map<String, dynamic> toJson() => {
        'stage': stage.name,
        'at': at.toIso8601String(),
        'note': note,
        'photos': photos,
        'actor': actor,
      };

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
        stage: JobStageX.parse(j['stage'] as String?),
        at: _date(j['at']) ?? DateTime.now(),
        note: j['note'] as String?,
        photos: ((j['photos'] ?? const []) as List).cast<String>(),
        actor: j['actor'] as String?,
      );
}

// ---------------------------------------------------------------------------
// The job card the garage opened
// ---------------------------------------------------------------------------

/// One piece of damage the workshop logged at handover, stored as a fraction
/// of the body diagram so it lands in the same place at any size.
@immutable
class HandoverMark {
  const HandoverMark({
    required this.id,
    required this.dx,
    required this.dy,
    this.kind = MarkKind.scratch,
    this.note = '',
  });

  final String id;
  final double dx;
  final double dy;
  final MarkKind kind;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dx': dx,
        'dy': dy,
        'kind': kind.name,
        'note': note,
      };

  factory HandoverMark.fromJson(Map<String, dynamic> j) => HandoverMark(
        id: (j['id'] ?? '') as String,
        dx: (j['dx'] as num?)?.toDouble() ?? 0,
        dy: (j['dy'] as num?)?.toDouble() ?? 0,
        kind: MarkKindX.parse(j['kind'] as String?),
        note: (j['note'] ?? '') as String,
      );
}

/// The garage's own record of the visit, as the workshop console wrote it:
/// what you said, what you handed over, what was already damaged, and when
/// the car is due back.
///
/// The customer app only ever reads this — it is the garage's copy, mirrored
/// here so there is one version of the truth rather than two.
@immutable
class JobCardRecord {
  const JobCardRecord({
    required this.number,
    required this.openedAt,
    this.odometerKm = 0,
    this.fuelPercent = 0,
    this.promisedAt,
    this.voices = const [],
    this.accessories = const [],
    this.workNote = '',
    this.mechanic,
    this.marks = const [],
    this.photos = const [],
    this.nextServiceAt,
    this.nextServiceKm,
  });

  /// `A0914-001` — the number printed on every document the garage hands over.
  final String number;
  final DateTime openedAt;

  final int odometerKm;
  final int fuelPercent;

  /// When the garage promised the car back.
  final DateTime? promisedAt;

  /// What you reported, in your words.
  final List<String> voices;

  /// What went in with the car.
  final List<String> accessories;

  final String workNote;
  final String? mechanic;

  final List<HandoverMark> marks;
  final List<String> photos;

  final DateTime? nextServiceAt;
  final int? nextServiceKm;

  bool get hasIntake =>
      voices.isNotEmpty ||
      accessories.isNotEmpty ||
      marks.isNotEmpty ||
      photos.isNotEmpty ||
      workNote.trim().isNotEmpty;

  JobCardRecord copyWith({
    int? odometerKm,
    int? fuelPercent,
    DateTime? promisedAt,
    List<String>? voices,
    List<String>? accessories,
    String? workNote,
    String? mechanic,
    List<HandoverMark>? marks,
    List<String>? photos,
    DateTime? nextServiceAt,
    int? nextServiceKm,
  }) =>
      JobCardRecord(
        number: number,
        openedAt: openedAt,
        odometerKm: odometerKm ?? this.odometerKm,
        fuelPercent: fuelPercent ?? this.fuelPercent,
        promisedAt: promisedAt ?? this.promisedAt,
        voices: voices ?? this.voices,
        accessories: accessories ?? this.accessories,
        workNote: workNote ?? this.workNote,
        mechanic: mechanic ?? this.mechanic,
        marks: marks ?? this.marks,
        photos: photos ?? this.photos,
        nextServiceAt: nextServiceAt ?? this.nextServiceAt,
        nextServiceKm: nextServiceKm ?? this.nextServiceKm,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'opened_at': openedAt.toIso8601String(),
        'odometer_km': odometerKm,
        'fuel_percent': fuelPercent,
        'promised_at': promisedAt?.toIso8601String(),
        'voices': voices,
        'accessories': accessories,
        'work_note': workNote,
        'mechanic': mechanic,
        'marks': marks.map((e) => e.toJson()).toList(),
        'photos': photos,
        'next_service_at': nextServiceAt?.toIso8601String(),
        'next_service_km': nextServiceKm,
      };

  factory JobCardRecord.fromJson(Map<String, dynamic> j) => JobCardRecord(
        number: (j['number'] ?? '') as String,
        openedAt: _date(j['opened_at']) ?? DateTime.now(),
        odometerKm: (j['odometer_km'] as num?)?.toInt() ?? 0,
        fuelPercent: (j['fuel_percent'] as num?)?.toInt() ?? 0,
        promisedAt: _date(j['promised_at']),
        voices: ((j['voices'] ?? const []) as List).cast<String>(),
        accessories: ((j['accessories'] ?? const []) as List).cast<String>(),
        workNote: (j['work_note'] ?? '') as String,
        mechanic: j['mechanic'] as String?,
        marks: ((j['marks'] ?? const []) as List)
            .map((e) =>
                HandoverMark.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        photos: ((j['photos'] ?? const []) as List).cast<String>(),
        nextServiceAt: _date(j['next_service_at']),
        nextServiceKm: (j['next_service_km'] as num?)?.toInt(),
      );
}

@immutable
class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.vehicleId,
    required this.lines,
    required this.mode,
    required this.slot,
    required this.status,
    required this.createdAt,
    this.garageId = '',
    this.addressId,
    this.stage = JobStage.confirmed,
    this.timeline = const [],
    this.couponCode,
    this.discount = 0,
    this.pickupFee = 0,
    this.advisor,
    this.technician,
    this.etaAt,
    this.inspectionId,
    this.estimateIds = const [],
    this.invoiceId,
    this.cancelReason,
    this.rating,
    this.reviewNote,
    this.notes,
    this.jobCard,
  });

  final String id;
  final String code;
  final String vehicleId;
  final List<CartLine> lines;
  final ServiceMode mode;
  final DateTime slot;
  final BookingStatus status;
  final DateTime createdAt;

  /// The workshop this was raised against, as the directory knows it.
  ///
  /// Empty on a booking made before a customer picked a workshop at all,
  /// which is every booking from the days when the counter had to hand out
  /// a code first. Those still read back; they simply have nowhere to be
  /// sent, which is what they had then too.
  final String garageId;
  final String? addressId;
  final JobStage stage;
  final List<TimelineEvent> timeline;
  final String? couponCode;
  final int discount;
  final int pickupFee;
  final String? advisor;
  final String? technician;
  final DateTime? etaAt;
  final String? inspectionId;
  final List<String> estimateIds;
  final String? invoiceId;
  final String? cancelReason;
  final double? rating;
  final String? reviewNote;
  final String? notes;

  /// The garage's own record of this visit, once a job card has been opened
  /// for it. Null while the booking is still only a slot.
  final JobCardRecord? jobCard;

  int get subtotal => lines.fold(0, (s, l) => s + l.price);
  int get mrpTotal => lines.fold(0, (s, l) => s + l.mrp);
  int get taxable => subtotal + pickupFee - discount;
  int get gst => (taxable * 0.18).round();
  int get total => taxable + gst;
  double get estimatedHours =>
      lines.fold<double>(0, (s, l) => s + l.durationHours);

  bool get isLive =>
      status == BookingStatus.active || status == BookingStatus.upcoming;

  /// Still "upcoming", a day past its slot, and no job card came of it: the
  /// visit did not happen, or the workshop never took it up. It used to sit
  /// at the top of Upcoming, and in the tab badge, for ever.
  bool get lapsed =>
      status == BookingStatus.upcoming &&
      jobCard == null &&
      slot.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  bool get needsApproval => stage == JobStage.awaitingApproval;

  Booking copyWith({
    List<CartLine>? lines,
    ServiceMode? mode,
    DateTime? slot,
    BookingStatus? status,
    String? addressId,
    JobStage? stage,
    List<TimelineEvent>? timeline,
    String? couponCode,
    int? discount,
    int? pickupFee,
    String? advisor,
    String? technician,
    DateTime? etaAt,
    String? inspectionId,
    List<String>? estimateIds,
    String? invoiceId,
    String? cancelReason,
    double? rating,
    String? reviewNote,
    String? notes,
    JobCardRecord? jobCard,
  }) =>
      Booking(
        id: id,
        code: code,
        vehicleId: vehicleId,
        lines: lines ?? this.lines,
        mode: mode ?? this.mode,
        slot: slot ?? this.slot,
        status: status ?? this.status,
        createdAt: createdAt,
        garageId: garageId,
        addressId: addressId ?? this.addressId,
        stage: stage ?? this.stage,
        timeline: timeline ?? this.timeline,
        couponCode: couponCode ?? this.couponCode,
        discount: discount ?? this.discount,
        pickupFee: pickupFee ?? this.pickupFee,
        advisor: advisor ?? this.advisor,
        technician: technician ?? this.technician,
        etaAt: etaAt ?? this.etaAt,
        inspectionId: inspectionId ?? this.inspectionId,
        estimateIds: estimateIds ?? this.estimateIds,
        invoiceId: invoiceId ?? this.invoiceId,
        cancelReason: cancelReason ?? this.cancelReason,
        rating: rating ?? this.rating,
        reviewNote: reviewNote ?? this.reviewNote,
        notes: notes ?? this.notes,
        jobCard: jobCard ?? this.jobCard,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'vehicle_id': vehicleId,
        'garage_id': garageId,
        'lines': lines.map((e) => e.toJson()).toList(),
        'mode': mode.name,
        'slot': slot.toIso8601String(),
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'address_id': addressId,
        'stage': stage.name,
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'coupon_code': couponCode,
        'discount': discount,
        'pickup_fee': pickupFee,
        'advisor': advisor,
        'technician': technician,
        'eta_at': etaAt?.toIso8601String(),
        'inspection_id': inspectionId,
        'estimate_ids': estimateIds,
        'invoice_id': invoiceId,
        'cancel_reason': cancelReason,
        'rating': rating,
        'review_note': reviewNote,
        'notes': notes,
        'job_card': jobCard?.toJson(),
      };

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        code: (j['code'] ?? '') as String,
        vehicleId: (j['vehicle_id'] ?? '') as String,
        lines: ((j['lines'] ?? const []) as List)
            .map((e) => CartLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        mode: ServiceModeX.parse(j['mode'] as String?),
        slot: _date(j['slot']) ?? DateTime.now(),
        status: BookingStatusX.parse(j['status'] as String?),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        garageId: (j['garage_id'] ?? '') as String,
        addressId: j['address_id'] as String?,
        stage: JobStageX.parse(j['stage'] as String?),
        timeline: ((j['timeline'] ?? const []) as List)
            .map((e) =>
                TimelineEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        couponCode: j['coupon_code'] as String?,
        discount: (j['discount'] ?? 0) as int,
        pickupFee: (j['pickup_fee'] ?? 0) as int,
        advisor: j['advisor'] as String?,
        technician: j['technician'] as String?,
        etaAt: _date(j['eta_at']),
        inspectionId: j['inspection_id'] as String?,
        estimateIds: ((j['estimate_ids'] ?? const []) as List).cast<String>(),
        invoiceId: j['invoice_id'] as String?,
        cancelReason: j['cancel_reason'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        reviewNote: j['review_note'] as String?,
        notes: j['notes'] as String?,
        jobCard: j['job_card'] == null
            ? null
            : JobCardRecord.fromJson(
                Map<String, dynamic>.from(j['job_card'] as Map)),
      );
}

// ---------------------------------------------------------------------------
// Inspection & estimates
// ---------------------------------------------------------------------------

@immutable
class InspectionItem {
  const InspectionItem({
    required this.area,
    required this.name,
    required this.condition,
    this.note,
    this.photos = const [],
    this.measurement,
  });

  final String area;
  final String name;
  final Condition condition;
  final String? note;
  final List<String> photos;

  /// e.g. "3.1 mm of 8 mm" for brake pads.
  final String? measurement;

  Map<String, dynamic> toJson() => {
        'area': area,
        'name': name,
        'condition': condition.name,
        'note': note,
        'photos': photos,
        'measurement': measurement,
      };

  factory InspectionItem.fromJson(Map<String, dynamic> j) => InspectionItem(
        area: (j['area'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        condition: ConditionX.parse(j['condition'] as String?),
        note: j['note'] as String?,
        photos: ((j['photos'] ?? const []) as List).cast<String>(),
        measurement: j['measurement'] as String?,
      );
}

@immutable
class Inspection {
  const Inspection({
    required this.id,
    required this.bookingId,
    required this.items,
    required this.createdAt,
    this.technician,
    this.summary,
  });

  final String id;
  final String bookingId;
  final List<InspectionItem> items;
  final DateTime createdAt;
  final String? technician;
  final String? summary;

  double get score => items.isEmpty
      ? 1
      : items.map((e) => e.condition.score).reduce((a, b) => a + b) /
          items.length;

  int count(Condition c) => items.where((e) => e.condition == c).length;

  List<String> get areas =>
      items.map((e) => e.area).toSet().toList(growable: false);

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'items': items.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'technician': technician,
        'summary': summary,
      };

  factory Inspection.fromJson(Map<String, dynamic> j) => Inspection(
        id: j['id'] as String,
        bookingId: (j['booking_id'] ?? '') as String,
        items: ((j['items'] ?? const []) as List)
            .map((e) =>
                InspectionItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        technician: j['technician'] as String?,
        summary: j['summary'] as String?,
      );
}

@immutable
class EstimateItem {
  const EstimateItem({
    required this.id,
    required this.name,
    required this.parts,
    required this.labour,
    required this.condition,
    this.note,
    this.approved = false,
    this.isNew = false,
    this.photos = const [],
  });

  final String id;
  final String name;
  final int parts;
  final int labour;
  final Condition condition;
  final String? note;
  final bool approved;

  /// Added in a later revision — highlighted in the UI.
  final bool isNew;
  final List<String> photos;

  int get total => parts + labour;

  EstimateItem copyWith({bool? approved}) => EstimateItem(
        id: id,
        name: name,
        parts: parts,
        labour: labour,
        condition: condition,
        note: note,
        approved: approved ?? this.approved,
        isNew: isNew,
        photos: photos,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parts': parts,
        'labour': labour,
        'condition': condition.name,
        'note': note,
        'approved': approved,
        'is_new': isNew,
        'photos': photos,
      };

  factory EstimateItem.fromJson(Map<String, dynamic> j) => EstimateItem(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        parts: (j['parts'] ?? 0) as int,
        labour: (j['labour'] ?? 0) as int,
        condition: ConditionX.parse(j['condition'] as String?),
        note: j['note'] as String?,
        approved: (j['approved'] ?? false) as bool,
        isNew: (j['is_new'] ?? false) as bool,
        photos: ((j['photos'] ?? const []) as List).cast<String>(),
      );
}

@immutable
class Estimate {
  const Estimate({
    required this.id,
    required this.bookingId,
    required this.version,
    required this.items,
    required this.createdAt,
    this.status = EstimateStatus.pending,
    this.reason,
    this.previousTotal,
    this.approvedAt,
    this.approvedBy,
  });

  final String id;
  final String bookingId;
  final int version;
  final List<EstimateItem> items;
  final DateTime createdAt;
  final EstimateStatus status;

  /// Why a revision was issued.
  final String? reason;
  final int? previousTotal;
  final DateTime? approvedAt;
  final String? approvedBy;

  int get total => items.fold(0, (s, e) => s + e.total);
  int get approvedTotal =>
      items.where((e) => e.approved).fold(0, (s, e) => s + e.total);
  int get approvedCount => items.where((e) => e.approved).length;
  bool get isRevision => version > 1;

  Estimate copyWith({
    List<EstimateItem>? items,
    EstimateStatus? status,
    DateTime? approvedAt,
    String? approvedBy,
  }) =>
      Estimate(
        id: id,
        bookingId: bookingId,
        version: version,
        items: items ?? this.items,
        createdAt: createdAt,
        status: status ?? this.status,
        reason: reason,
        previousTotal: previousTotal,
        approvedAt: approvedAt ?? this.approvedAt,
        approvedBy: approvedBy ?? this.approvedBy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'version': version,
        'items': items.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'status': status.name,
        'reason': reason,
        'previous_total': previousTotal,
        'approved_at': approvedAt?.toIso8601String(),
        'approved_by': approvedBy,
      };

  factory Estimate.fromJson(Map<String, dynamic> j) => Estimate(
        id: j['id'] as String,
        bookingId: (j['booking_id'] ?? '') as String,
        version: (j['version'] ?? 1) as int,
        items: ((j['items'] ?? const []) as List)
            .map((e) =>
                EstimateItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        status: EstimateStatusX.parse(j['status'] as String?),
        reason: j['reason'] as String?,
        previousTotal: j['previous_total'] as int?,
        approvedAt: _date(j['approved_at']),
        approvedBy: j['approved_by'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Invoice & payment
// ---------------------------------------------------------------------------

@immutable
class InvoiceLine {
  const InvoiceLine({
    required this.name,
    required this.amount,
    this.parts = 0,
    this.labour = 0,
    this.qty = 1,
  });

  final String name;
  final int amount;
  final int parts;
  final int labour;
  final int qty;

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'parts': parts,
        'labour': labour,
        'qty': qty,
      };

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
        name: (j['name'] ?? '') as String,
        amount: (j['amount'] ?? 0) as int,
        parts: (j['parts'] ?? 0) as int,
        labour: (j['labour'] ?? 0) as int,
        qty: (j['qty'] ?? 1) as int,
      );
}

@immutable
class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.bookingId,
    required this.lines,
    required this.createdAt,
    this.discount = 0,
    this.pickupFee = 0,
    this.paid = false,
    this.method,
    this.paidAt,
    this.transactionId,
    this.jobCardNumber,
    this.taxRate = 0.18,
  });

  final String id;
  final String number;
  final String bookingId;
  final List<InvoiceLine> lines;
  final DateTime createdAt;
  final int discount;
  final int pickupFee;
  final bool paid;
  final PaymentMethod? method;
  final DateTime? paidAt;
  final String? transactionId;

  /// Set when this bill is the garage's own, and carries its job card number.
  final String? jobCardNumber;

  /// The rate the bill was raised at. A workshop sets this on its console, so
  /// a bill that came from a job card is taxed the way that workshop taxes —
  /// including not at all, where it is not registered.
  final double taxRate;

  int get subtotal => lines.fold(0, (s, l) => s + l.amount);
  int get partsTotal => lines.fold(0, (s, l) => s + l.parts);
  int get labourTotal => lines.fold(0, (s, l) => s + l.labour);
  int get taxable => subtotal + pickupFee - discount;
  int get cgst => (taxable * taxRate / 2).round();
  int get sgst => gst - cgst;
  int get gst => (taxable * taxRate).round();
  int get total => taxable + gst;

  Invoice copyWith({
    bool? paid,
    PaymentMethod? method,
    DateTime? paidAt,
    String? transactionId,
  }) =>
      Invoice(
        id: id,
        number: number,
        bookingId: bookingId,
        lines: lines,
        createdAt: createdAt,
        discount: discount,
        pickupFee: pickupFee,
        paid: paid ?? this.paid,
        method: method ?? this.method,
        paidAt: paidAt ?? this.paidAt,
        transactionId: transactionId ?? this.transactionId,
        jobCardNumber: jobCardNumber,
        taxRate: taxRate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'booking_id': bookingId,
        'lines': lines.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'discount': discount,
        'pickup_fee': pickupFee,
        'paid': paid,
        'method': method?.name,
        'paid_at': paidAt?.toIso8601String(),
        'transaction_id': transactionId,
        'job_card_number': jobCardNumber,
        'tax_rate': taxRate,
      };

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        id: j['id'] as String,
        number: (j['number'] ?? '') as String,
        bookingId: (j['booking_id'] ?? '') as String,
        lines: ((j['lines'] ?? const []) as List)
            .map((e) =>
                InvoiceLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        discount: (j['discount'] ?? 0) as int,
        pickupFee: (j['pickup_fee'] ?? 0) as int,
        paid: (j['paid'] ?? false) as bool,
        method: j['method'] == null
            ? null
            : PaymentMethodX.parse(j['method'] as String?),
        paidAt: _date(j['paid_at']),
        transactionId: j['transaction_id'] as String?,
        jobCardNumber: j['job_card_number'] as String?,
        taxRate: (j['tax_rate'] as num?)?.toDouble() ?? 0.18,
      );
}

// ---------------------------------------------------------------------------
// Support, notifications, extras
// ---------------------------------------------------------------------------

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.read = false,
    this.bookingId,
    this.route,
  });

  final String id;
  final NotifyKind kind;
  final String title;
  final String body;
  final DateTime at;
  final bool read;
  final String? bookingId;
  final String? route;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        at: at,
        read: read ?? this.read,
        bookingId: bookingId,
        route: route,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'body': body,
        'at': at.toIso8601String(),
        'read': read,
        'booking_id': bookingId,
        'route': route,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        kind: NotifyKindX.parse(j['kind'] as String?),
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        at: _date(j['at']) ?? DateTime.now(),
        read: (j['read'] ?? false) as bool,
        bookingId: j['booking_id'] as String?,
        route: j['route'] as String?,
      );
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.at,
    required this.fromMe,
    this.author,
    this.imagePath,
    this.topic,
  });

  final String id;
  final String text;
  final DateTime at;
  final bool fromMe;
  final String? author;
  final String? imagePath;
  final String? topic;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'at': at.toIso8601String(),
        'from_me': fromMe,
        'author': author,
        'image_path': imagePath,
        'topic': topic,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        text: (j['text'] ?? '') as String,
        at: _date(j['at']) ?? DateTime.now(),
        fromMe: (j['from_me'] ?? false) as bool,
        author: j['author'] as String?,
        imagePath: j['image_path'] as String?,
        topic: j['topic'] as String?,
      );
}

@immutable
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.body,
    required this.createdAt,
    this.status = 'Open',
    this.bookingCode,
    this.replies = const [],
  });

  final String id;
  final String subject;
  final String category;
  final String body;
  final DateTime createdAt;
  final String status;
  final String? bookingCode;
  final List<String> replies;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'category': category,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'status': status,
        'booking_code': bookingCode,
        'replies': replies,
      };

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: j['id'] as String,
        subject: (j['subject'] ?? '') as String,
        category: (j['category'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        status: (j['status'] ?? 'Open') as String,
        bookingCode: j['booking_code'] as String?,
        replies: ((j['replies'] ?? const []) as List).cast<String>(),
      );
}

@immutable
@immutable
class FaqItem {
  const FaqItem(this.question, this.answer, this.group);
  final String question;
  final String answer;
  final String group;
}

// ---------------------------------------------------------------------------

DateTime? _date(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
