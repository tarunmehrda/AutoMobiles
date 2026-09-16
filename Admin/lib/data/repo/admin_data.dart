import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/enums.dart';

/// The whole workshop in one immutable snapshot, persisted as a single JSON
/// document — same approach as the customer app, so a restart restores the
/// console exactly as it was left.
@immutable
class AdminData {
  const AdminData({
    this.garage,
    this.staff = const [],
    this.customers = const [],
    this.vehicles = const [],
    this.jobCards = const [],
    this.masters = const [],
    this.bookings = const [],
    this.reviews = const [],
    this.signedIn = false,
    this.onboarded = false,
    this.themeMode = ThemeMode.system,
    this.seq = 0,
    this.smsEnabled = true,
    this.whatsappEnabled = true,
    this.reminderDaysBefore = 5,
    this.defaultTaxRate = 0,
  });

  final Garage? garage;
  final List<Staff> staff;
  final List<Customer> customers;
  final List<Vehicle> vehicles;
  final List<JobCard> jobCards;
  final List<MasterItem> masters;
  final List<Booking> bookings;
  final List<Review> reviews;

  final bool signedIn;
  final bool onboarded;
  final ThemeMode themeMode;

  /// Running job card counter, reset by the number prefix each day.
  final int seq;

  final bool smsEnabled;
  final bool whatsappEnabled;
  final int reminderDaysBefore;
  final double defaultTaxRate;

  bool get isReady => signedIn && garage != null;

  // --- lookups -------------------------------------------------------------

  Customer? customerById(String? id) {
    if (id == null) return null;
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Vehicle? vehicleById(String? id) {
    if (id == null) return null;
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  JobCard? jobById(String? id) {
    if (id == null) return null;
    for (final j in jobCards) {
      if (j.id == id) return j;
    }
    return null;
  }

  Staff? staffById(String? id) {
    if (id == null) return null;
    for (final s in staff) {
      if (s.id == id) return s;
    }
    return null;
  }

  MasterItem? masterById(String? id) {
    if (id == null) return null;
    for (final m in masters) {
      if (m.id == id) return m;
    }
    return null;
  }

  Customer? customerByPhone(String phone) {
    final want = phone.trim();
    if (want.isEmpty) return null;
    for (final c in customers) {
      if (c.phone.trim() == want) return c;
    }
    return null;
  }

  Vehicle? vehicleByReg(String reg) {
    final want = reg.replaceAll(' ', '').toUpperCase();
    if (want.isEmpty) return null;
    for (final v in vehicles) {
      if (v.regNo.replaceAll(' ', '').toUpperCase() == want) return v;
    }
    return null;
  }

  List<Vehicle> vehiclesOf(String customerId) =>
      vehicles.where((v) => v.customerId == customerId).toList();

  /// Every job card for a vehicle, newest first — powers "Last History".
  List<JobCard> historyOf(String vehicleId, {String? excludeId}) {
    final list = jobCards
        .where((j) => j.vehicleId == vehicleId && j.id != excludeId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Review? reviewOf(String jobCardId) {
    for (final r in reviews) {
      if (r.jobCardId == jobCardId) return r;
    }
    return null;
  }

  // --- buckets -------------------------------------------------------------

  List<JobCard> of(JobStatus status) {
    final list = jobCards.where((j) => j.status == status).toList()
      ..sort((a, b) => b.stampFor(status).compareTo(a.stampFor(status)));
    return list;
  }

  int countOf(JobStatus status) =>
      jobCards.where((j) => j.status == status).length;

  /// Cards still owing money, whatever their stage.
  List<JobCard> get pendingBalance {
    final list = jobCards
        .where((j) => j.items.isNotEmpty && !j.settled)
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    return list;
  }

  double get pendingTotal =>
      money(pendingBalance.fold<double>(0, (s, j) => s + j.balance));

  List<Booking> get openBookings {
    final list = bookings.where((b) => !b.accepted).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return list;
  }

  /// Closed cards whose next service falls on or before today.
  List<JobCard> get serviceDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return jobCards.where((j) {
      final due = j.nextServiceAt;
      if (due == null) return false;
      return !DateTime(due.year, due.month, due.day).isAfter(today);
    }).toList()
      ..sort((a, b) => a.nextServiceAt!.compareTo(b.nextServiceAt!));
  }

  List<MasterItem> mastersOf(LineKind kind) =>
      masters.where((m) => m.kind == kind).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<MasterItem> get lowStock =>
      masters.where((m) => m.low || m.out).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));

  // --- revenue -------------------------------------------------------------

  /// Billed value of every card that has reached at least "complete".
  double revenueBetween(DateTime from, DateTime to) {
    var sum = 0.0;
    for (final j in jobCards) {
      if (j.status == JobStatus.open) continue;
      final at = j.completedAt ?? j.createdAt;
      if (at.isBefore(from) || at.isAfter(to)) continue;
      sum += j.total;
    }
    return money(sum);
  }

  double collectedBetween(DateTime from, DateTime to) {
    var sum = 0.0;
    for (final j in jobCards) {
      for (final p in j.payments) {
        if (p.at.isBefore(from) || p.at.isAfter(to)) continue;
        sum += p.amount;
      }
    }
    return money(sum);
  }

  double get lifetimeRevenue => money(jobCards
      .where((j) => j.status != JobStatus.open)
      .fold<double>(0, (s, j) => s + j.total));

  double get averageTicket {
    final billed = jobCards.where((j) => j.status != JobStatus.open).toList();
    if (billed.isEmpty) return 0;
    return money(lifetimeRevenue / billed.length);
  }

  double get averageRating {
    if (reviews.isEmpty) return 0;
    return reviews.fold<double>(0, (s, r) => s + r.stars) / reviews.length;
  }

  AdminData copyWith({
    Garage? garage,
    List<Staff>? staff,
    List<Customer>? customers,
    List<Vehicle>? vehicles,
    List<JobCard>? jobCards,
    List<MasterItem>? masters,
    List<Booking>? bookings,
    List<Review>? reviews,
    bool? signedIn,
    bool? onboarded,
    ThemeMode? themeMode,
    int? seq,
    bool? smsEnabled,
    bool? whatsappEnabled,
    int? reminderDaysBefore,
    double? defaultTaxRate,
  }) =>
      AdminData(
        garage: garage ?? this.garage,
        staff: staff ?? this.staff,
        customers: customers ?? this.customers,
        vehicles: vehicles ?? this.vehicles,
        jobCards: jobCards ?? this.jobCards,
        masters: masters ?? this.masters,
        bookings: bookings ?? this.bookings,
        reviews: reviews ?? this.reviews,
        signedIn: signedIn ?? this.signedIn,
        onboarded: onboarded ?? this.onboarded,
        themeMode: themeMode ?? this.themeMode,
        seq: seq ?? this.seq,
        smsEnabled: smsEnabled ?? this.smsEnabled,
        whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
        reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
        defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      );

  /// Sign-out wipes the session but keeps nothing else around either — the
  /// console is single-tenant, so the whole snapshot goes.
  AdminData signedOut() => const AdminData(onboarded: true);

  Map<String, dynamic> toJson() => {
        'garage': garage?.toJson(),
        'staff': staff.map((e) => e.toJson()).toList(),
        'customers': customers.map((e) => e.toJson()).toList(),
        'vehicles': vehicles.map((e) => e.toJson()).toList(),
        'job_cards': jobCards.map((e) => e.toJson()).toList(),
        'masters': masters.map((e) => e.toJson()).toList(),
        'bookings': bookings.map((e) => e.toJson()).toList(),
        'reviews': reviews.map((e) => e.toJson()).toList(),
        'signed_in': signedIn,
        'onboarded': onboarded,
        'theme_mode': themeMode.name,
        'seq': seq,
        'sms_enabled': smsEnabled,
        'whatsapp_enabled': whatsappEnabled,
        'reminder_days_before': reminderDaysBefore,
        'default_tax_rate': defaultTaxRate,
      };

  factory AdminData.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        ((j[key] as List?) ?? const [])
            .map((e) => parse(Map<String, dynamic>.from(e as Map)))
            .toList();

    return AdminData(
      garage: j['garage'] == null
          ? null
          : Garage.fromJson(Map<String, dynamic>.from(j['garage'] as Map)),
      staff: list('staff', Staff.fromJson),
      customers: list('customers', Customer.fromJson),
      vehicles: list('vehicles', Vehicle.fromJson),
      jobCards: list('job_cards', JobCard.fromJson),
      masters: list('masters', MasterItem.fromJson),
      bookings: list('bookings', Booking.fromJson),
      reviews: list('reviews', Review.fromJson),
      signedIn: (j['signed_in'] ?? false) as bool,
      onboarded: (j['onboarded'] ?? false) as bool,
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.name == j['theme_mode'],
        orElse: () => ThemeMode.system,
      ),
      seq: (j['seq'] as num?)?.toInt() ?? 0,
      smsEnabled: (j['sms_enabled'] ?? true) as bool,
      whatsappEnabled: (j['whatsapp_enabled'] ?? true) as bool,
      reminderDaysBefore: (j['reminder_days_before'] as num?)?.toInt() ?? 5,
      defaultTaxRate: (j['default_tax_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}
