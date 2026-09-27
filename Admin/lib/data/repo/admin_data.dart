import 'package:flutter/material.dart';

import '../models/attendance.dart';
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
    this.expenses = const [],
    this.cashBook = const [],
    this.suppliers = const [],
    this.counterSales = const [],
    this.purchaseOrders = const [],
    this.onlineServices = const [],
    this.attendance = const [],
    this.notifications = const [],
    this.signedIn = false,
    this.onboarded = false,
    this.themeMode = ThemeMode.system,
    this.languageCode = 'en',
    this.seq = 0,
    this.smsEnabled = true,
    this.whatsappEnabled = true,
    this.reminderDaysBefore = 5,
    this.defaultTaxRate = 0,
    this.onlineGarageOn = false,
    this.onlineSlug = '',
  });

  final Garage? garage;
  final List<Staff> staff;
  final List<Customer> customers;
  final List<Vehicle> vehicles;
  final List<JobCard> jobCards;
  final List<MasterItem> masters;
  final List<Booking> bookings;
  final List<Review> reviews;
  final List<Expense> expenses;
  final List<CashEntry> cashBook;
  final List<Supplier> suppliers;
  final List<CounterSale> counterSales;
  final List<PurchaseOrder> purchaseOrders;

  /// Services the workshop publishes on its online garage page.
  final List<OnlineService> onlineServices;

  /// The attendance register, newest first.
  ///
  /// Unlike every other collection here this one is not pushed upstream.
  /// Rows are created by `punch_attendance()` and only ever read back, so
  /// what is held on the device is a cache of the server's register rather
  /// than a second copy with equal standing. See [AttendanceGateway].
  final List<AttendancePunch> attendance;

  /// The workshop's alert feed, newest first.
  ///
  /// Read-only here for the same reason as [attendance]: rows are raised by
  /// database triggers at the moment the thing they describe happened, so
  /// the console has nothing to push back. Marking one read goes through
  /// `read_garage_notifications()`, not through the snapshot.
  final List<GarageNotification> notifications;

  final bool signedIn;
  final bool onboarded;
  final ThemeMode themeMode;

  /// The language tag the console is read in — see [AppLanguage]. Held
  /// as a plain string so an unknown tag in an older snapshot falls back
  /// to English instead of failing to parse.
  final String languageCode;

  /// Running job card counter, reset by the number prefix each day.
  final int seq;

  final bool smsEnabled;
  final bool whatsappEnabled;
  final int reminderDaysBefore;
  final double defaultTaxRate;

  /// Whether the public online garage page is live.
  final bool onlineGarageOn;

  /// The handle in `my.ttngarage.com/<slug>`.
  final String onlineSlug;

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

  /// Matched the way the database matches: the last ten digits, so
  /// '+91 98123 45678' and '9812345678' are one customer.
  ///
  /// It used to compare the strings as typed. A customer the booking had
  /// already created as '919812345678' then got a second record when the
  /// counter typed '9812345678', the database refused that duplicate
  /// (`garage_customers_unique_phone` is on `norm_phone`), the vehicle
  /// pointing at it was refused in turn, and so was the job card — on every
  /// push, for good. The card lived on one phone only.
  Customer? customerByPhone(String phone) {
    final want = normPhone(phone);
    if (want.isEmpty) return null;
    for (final c in customers) {
      if (normPhone(c.phone) == want) return c;
    }
    return null;
  }

  /// `public.norm_phone()` in Dart.
  static String normPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length <= 10 ? digits : digits.substring(digits.length - 10);
  }

  static String _plate(String reg) => reg.replaceAll(' ', '').toUpperCase();

  Vehicle? vehicleByReg(String reg) {
    final want = _plate(reg);
    if (want.isEmpty) return null;
    for (final v in vehicles) {
      if (_plate(v.regNo) == want) return v;
    }
    return null;
  }

  /// The request from the customer app still waiting on this plate — the one
  /// whose slot is nearest now, when a customer has booked more than once.
  ///
  /// A car booked from the app is not a workshop vehicle until its first
  /// card is opened, so [vehicleByReg] cannot see it. Typing its plate on a
  /// new card used to answer "Vehicle not registered yet" and leave the
  /// counter to type again everything the customer already had.
  Booking? openBookingByReg(String reg) {
    final want = _plate(reg);
    if (want.isEmpty) return null;
    final now = DateTime.now();
    Booking? best;
    for (final b in bookings) {
      if (b.accepted || _plate(b.regNo) != want) continue;
      if (best == null ||
          b.at.difference(now).abs() < best.at.difference(now).abs()) {
        best = b;
      }
    }
    return best;
  }

  List<Vehicle> vehiclesOf(String customerId) =>
      vehicles.where((v) => v.customerId == customerId).toList();

  /// Every job card for a vehicle, newest first — powers "Last History".
  List<JobCard> historyOf(String vehicleId, {String? excludeId}) {
    final list =
        jobCards
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
    final list =
        jobCards.where((j) => j.items.isNotEmpty && !j.settled).toList()
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

  // --- the bell ------------------------------------------------------------

  /// The alert feed, newest first. Sorted here rather than trusted to
  /// arrive in order: a row that came down the realtime channel is merged
  /// onto the end of whatever the last fetch returned.
  List<GarageNotification> get feed {
    final list = [...notifications]..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  int get unreadCount => notifications.where((n) => !n.read).length;

  /// Closed cards whose next service falls on or before today.
  List<JobCard> get serviceDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return jobCards.where((j) {
      final due = j.nextServiceAt;
      if (due == null) return false;
      return !DateTime(due.year, due.month, due.day).isAfter(today);
    }).toList()..sort((a, b) => a.nextServiceAt!.compareTo(b.nextServiceAt!));
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

  double get lifetimeRevenue => money(
    jobCards
        .where((j) => j.status != JobStatus.open)
        .fold<double>(0, (s, j) => s + j.total),
  );

  double get averageTicket {
    final billed = jobCards.where((j) => j.status != JobStatus.open).toList();
    if (billed.isEmpty) return 0;
    return money(lifetimeRevenue / billed.length);
  }

  double get averageRating {
    if (reviews.isEmpty) return 0;
    return reviews.fold<double>(0, (s, r) => s + r.stars) / reviews.length;
  }

  // --- expenses and the day book ------------------------------------------

  double get expenseTotal =>
      money(expenses.fold<double>(0, (s, e) => s + e.amount));

  double get expensePending =>
      money(expenses.fold<double>(0, (s, e) => s + e.pending));

  List<Expense> get expensesByDate {
    final list = [...expenses]..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<CashEntry> cashOn(DateTime day) {
    final list = cashBook.where((e) => sameDay(e.at, day)).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  /// Cash in and cash out for one day, as the CashBook summary reads them.
  ({double inward, double outward}) cashSummary(DateTime day) {
    var i = 0.0;
    var o = 0.0;
    for (final e in cashOn(day)) {
      if (e.inward) {
        i += e.amount;
      } else {
        o += e.amount;
      }
    }
    return (inward: money(i), outward: money(o));
  }

  // --- counter sales -------------------------------------------------------

  double get counterSaleTotal =>
      money(counterSales.fold<double>(0, (s, e) => s + e.total));

  List<CounterSale> get counterSalesByDate {
    final list = [...counterSales]..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  List<PurchaseOrder> get ordersByDate {
    final list = [...purchaseOrders]..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  Supplier? supplierById(String? id) {
    if (id == null) return null;
    for (final s in suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Value of everything on the shelf, split by kind — what the inventory
  /// donut reads.
  double stockValueOf(LineKind kind) => money(
    masters
        .where((m) => m.kind == kind && m.tracksStock)
        .fold<double>(0, (s, m) => s + m.stock * m.rate),
  );

  // --- reminders -----------------------------------------------------------

  /// Cards whose next service falls inside [from]..[to].
  List<JobCard> serviceDueBetween(DateTime from, DateTime to) {
    final list = jobCards.where((j) {
      final due = j.nextServiceAt;
      if (due == null) return false;
      return !due.isBefore(from) && !due.isAfter(to);
    }).toList()..sort((a, b) => a.nextServiceAt!.compareTo(b.nextServiceAt!));
    return list;
  }

  // --- attendance ----------------------------------------------------------

  /// Where staff may punch in. Null until the owner pins one.
  AttendanceSite? get attendanceSite => garage?.attendanceSite;

  /// Accepted punches only, newest first — the register as payroll reads it.
  List<AttendancePunch> get attendanceAccepted =>
      attendance.where((p) => p.accepted).toList();

  /// Everything that happened on one calendar day, newest first.
  List<AttendancePunch> attendanceOn(DateTime day) =>
      attendance.where((p) => sameDay(p.at, day)).toList();

  /// Who is on the floor right now, by each person's last accepted punch.
  List<Staff> get onDuty =>
      staff.where((s) => Shift.onDuty(attendance, s.id)).toList();

  AdminData copyWith({
    Garage? garage,
    List<Staff>? staff,
    List<Customer>? customers,
    List<Vehicle>? vehicles,
    List<JobCard>? jobCards,
    List<MasterItem>? masters,
    List<Booking>? bookings,
    List<Review>? reviews,
    List<Expense>? expenses,
    List<CashEntry>? cashBook,
    List<Supplier>? suppliers,
    List<CounterSale>? counterSales,
    List<PurchaseOrder>? purchaseOrders,
    List<OnlineService>? onlineServices,
    List<AttendancePunch>? attendance,
    List<GarageNotification>? notifications,
    bool? signedIn,
    bool? onboarded,
    ThemeMode? themeMode,
    String? languageCode,
    int? seq,
    bool? smsEnabled,
    bool? whatsappEnabled,
    int? reminderDaysBefore,
    double? defaultTaxRate,
    bool? onlineGarageOn,
    String? onlineSlug,
  }) => AdminData(
    garage: garage ?? this.garage,
    staff: staff ?? this.staff,
    customers: customers ?? this.customers,
    vehicles: vehicles ?? this.vehicles,
    jobCards: jobCards ?? this.jobCards,
    masters: masters ?? this.masters,
    bookings: bookings ?? this.bookings,
    reviews: reviews ?? this.reviews,
    expenses: expenses ?? this.expenses,
    cashBook: cashBook ?? this.cashBook,
    suppliers: suppliers ?? this.suppliers,
    counterSales: counterSales ?? this.counterSales,
    purchaseOrders: purchaseOrders ?? this.purchaseOrders,
    onlineServices: onlineServices ?? this.onlineServices,
    attendance: attendance ?? this.attendance,
    notifications: notifications ?? this.notifications,
    signedIn: signedIn ?? this.signedIn,
    onboarded: onboarded ?? this.onboarded,
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode ?? this.languageCode,
    seq: seq ?? this.seq,
    smsEnabled: smsEnabled ?? this.smsEnabled,
    whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
    reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
    defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
    onlineGarageOn: onlineGarageOn ?? this.onlineGarageOn,
    onlineSlug: onlineSlug ?? this.onlineSlug,
  );

  /// Sign-out wipes the session but keeps nothing else around either — the
  /// console is single-tenant, so the whole snapshot goes.
  AdminData signedOut() => AdminData(
    onboarded: true,
    themeMode: themeMode,
    languageCode: languageCode,
  );

  Map<String, dynamic> toJson() => {
    'garage': garage?.toJson(),
    'staff': staff.map((e) => e.toJson()).toList(),
    'customers': customers.map((e) => e.toJson()).toList(),
    'vehicles': vehicles.map((e) => e.toJson()).toList(),
    'job_cards': jobCards.map((e) => e.toJson()).toList(),
    'masters': masters.map((e) => e.toJson()).toList(),
    'bookings': bookings.map((e) => e.toJson()).toList(),
    'reviews': reviews.map((e) => e.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'cash_book': cashBook.map((e) => e.toJson()).toList(),
    'suppliers': suppliers.map((e) => e.toJson()).toList(),
    'counter_sales': counterSales.map((e) => e.toJson()).toList(),
    'purchase_orders': purchaseOrders.map((e) => e.toJson()).toList(),
    'online_services': onlineServices.map((e) => e.toJson()).toList(),
    'attendance': attendance.map((e) => e.toJson()).toList(),
    'notifications': notifications.map((e) => e.toJson()).toList(),
    'signed_in': signedIn,
    'onboarded': onboarded,
    'theme_mode': themeMode.name,
    'language_code': languageCode,
    'seq': seq,
    'sms_enabled': smsEnabled,
    'whatsapp_enabled': whatsappEnabled,
    'reminder_days_before': reminderDaysBefore,
    'default_tax_rate': defaultTaxRate,
    'online_garage_on': onlineGarageOn,
    'online_slug': onlineSlug,
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
      expenses: list('expenses', Expense.fromJson),
      cashBook: list('cash_book', CashEntry.fromJson),
      suppliers: list('suppliers', Supplier.fromJson),
      counterSales: list('counter_sales', CounterSale.fromJson),
      purchaseOrders: list('purchase_orders', PurchaseOrder.fromJson),
      onlineServices: list('online_services', OnlineService.fromJson),
      attendance: list('attendance', AttendancePunch.fromJson),
      notifications: list('notifications', GarageNotification.fromJson),
      signedIn: (j['signed_in'] ?? false) as bool,
      onboarded: (j['onboarded'] ?? false) as bool,
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.name == j['theme_mode'],
        orElse: () => ThemeMode.system,
      ),
      languageCode: (j['language_code'] ?? 'en') as String,
      seq: (j['seq'] as num?)?.toInt() ?? 0,
      smsEnabled: (j['sms_enabled'] ?? true) as bool,
      whatsappEnabled: (j['whatsapp_enabled'] ?? true) as bool,
      reminderDaysBefore: (j['reminder_days_before'] as num?)?.toInt() ?? 5,
      defaultTaxRate: (j['default_tax_rate'] as num?)?.toDouble() ?? 0,
      onlineGarageOn: (j['online_garage_on'] ?? false) as bool,
      onlineSlug: (j['online_slug'] ?? '') as String,
    );
  }
}
