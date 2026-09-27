import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/enums.dart';
import '../models/workshop.dart';

/// The whole customer-side dataset in one immutable snapshot. Persisted as a
/// single JSON document so a restart restores the app exactly as it was.
@immutable
class AppData {
  const AppData({
    this.user,
    this.vehicles = const [],
    this.activeVehicleId,
    this.addresses = const [],
    this.bookings = const [],
    this.inspections = const {},
    this.estimates = const {},
    this.invoices = const {},
    this.notifications = const [],
    this.chat = const [],
    this.tickets = const [],
    this.workshopCards = const [],
    this.workshop = Workshop.none,
    this.onboarded = false,
    this.themeMode = ThemeMode.system,
    this.savedPackageIds = const {},
    this.recentSearches = const [],
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.whatsappEnabled = true,
    this.serviceRemindersEnabled = true,
    this.offersEnabled = true,
  });

  final AppUser? user;
  final List<Vehicle> vehicles;
  final String? activeVehicleId;
  final List<Address> addresses;
  final List<Booking> bookings;

  /// bookingId -> inspection
  final Map<String, Inspection> inspections;

  /// bookingId -> every estimate version, oldest first
  final Map<String, List<Estimate>> estimates;

  /// bookingId -> invoice
  final Map<String, Invoice> invoices;

  final List<AppNotification> notifications;
  final List<ChatMessage> chat;
  final List<SupportTicket> tickets;

  /// The garage's own job cards for this customer, read from `my_job_cards`
  /// and kept live over realtime. Read-only here — the workshop owns them.
  final List<WorkshopCard> workshopCards;

  /// The garage this customer deals with, as that garage filled it in.
  /// [Workshop.none] until they have booked with one.
  final Workshop workshop;

  /// Whatever the workshop has on the floor right now, newest first.
  List<WorkshopCard> get liveWorkshopCards {
    final list = workshopCards.where((c) => c.isLive).toList()
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return list;
  }

  final bool onboarded;
  final ThemeMode themeMode;
  final Set<String> savedPackageIds;
  final List<String> recentSearches;

  final bool pushEnabled;
  final bool emailEnabled;
  final bool whatsappEnabled;
  final bool serviceRemindersEnabled;
  final bool offersEnabled;

  bool get isSignedIn => user != null;

  Vehicle? get activeVehicle {
    if (vehicles.isEmpty) return null;
    for (final v in vehicles) {
      if (v.id == activeVehicleId) return v;
    }
    return vehicles.first;
  }

  Vehicle? vehicleById(String? id) {
    if (id == null) return null;
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  Booking? bookingById(String? id) {
    if (id == null) return null;
    for (final b in bookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  Address? addressById(String? id) {
    if (id == null) return null;
    for (final a in addresses) {
      if (a.id == id) return a;
    }
    return null;
  }

  Address? get defaultAddress {
    if (addresses.isEmpty) return null;
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return addresses.first;
  }

  List<Estimate> estimatesFor(String bookingId) =>
      estimates[bookingId] ?? const [];

  Estimate? latestEstimate(String bookingId) {
    final list = estimatesFor(bookingId);
    return list.isEmpty ? null : list.last;
  }

  List<Booking> get liveBookings => bookings
      .where((b) =>
          b.status == BookingStatus.active || b.status == BookingStatus.upcoming)
      .toList()
    ..sort((a, b) => a.slot.compareTo(b.slot));

  Booking? get spotlightBooking {
    final live = liveBookings;
    if (live.isEmpty) return null;
    // Anything waiting on the customer jumps the queue.
    for (final b in live) {
      if (b.needsApproval) return b;
    }
    for (final b in live) {
      if (b.status == BookingStatus.active) return b;
    }
    return live.first;
  }

  List<Booking> bookingsWith(BookingStatus status) =>
      bookings.where((b) => b.status == status).toList()
        ..sort((a, b) => b.slot.compareTo(a.slot));

  List<Booking> historyFor(String vehicleId) => bookings
      .where((b) =>
          b.vehicleId == vehicleId && b.status == BookingStatus.completed)
      .toList()
    ..sort((a, b) => b.slot.compareTo(a.slot));

  int get unreadCount => notifications.where((n) => !n.read).length;

  /// Approvals, unpaid invoices and expiring documents that need the user.
  int get actionCount {
    var n = 0;
    for (final b in liveBookings) {
      if (b.needsApproval) n++;
      final inv = invoices[b.id];
      if (inv != null && !inv.paid) n++;
    }
    return n;
  }

  AppData copyWith({
    AppUser? user,
    bool clearUser = false,
    List<Vehicle>? vehicles,
    String? activeVehicleId,
    bool clearActiveVehicle = false,
    List<Address>? addresses,
    List<Booking>? bookings,
    Map<String, Inspection>? inspections,
    Map<String, List<Estimate>>? estimates,
    Map<String, Invoice>? invoices,
    List<AppNotification>? notifications,
    List<ChatMessage>? chat,
    List<SupportTicket>? tickets,
    List<WorkshopCard>? workshopCards,
    Workshop? workshop,
    bool? onboarded,
    ThemeMode? themeMode,
    Set<String>? savedPackageIds,
    List<String>? recentSearches,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? whatsappEnabled,
    bool? serviceRemindersEnabled,
    bool? offersEnabled,
  }) =>
      AppData(
        user: clearUser ? null : (user ?? this.user),
        vehicles: vehicles ?? this.vehicles,
        activeVehicleId: clearActiveVehicle
            ? null
            : (activeVehicleId ?? this.activeVehicleId),
        addresses: addresses ?? this.addresses,
        bookings: bookings ?? this.bookings,
        inspections: inspections ?? this.inspections,
        estimates: estimates ?? this.estimates,
        invoices: invoices ?? this.invoices,
        notifications: notifications ?? this.notifications,
        chat: chat ?? this.chat,
        tickets: tickets ?? this.tickets,
        workshopCards: workshopCards ?? this.workshopCards,
        workshop: workshop ?? this.workshop,
        onboarded: onboarded ?? this.onboarded,
        themeMode: themeMode ?? this.themeMode,
        savedPackageIds: savedPackageIds ?? this.savedPackageIds,
        recentSearches: recentSearches ?? this.recentSearches,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        emailEnabled: emailEnabled ?? this.emailEnabled,
        whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
        serviceRemindersEnabled:
            serviceRemindersEnabled ?? this.serviceRemindersEnabled,
        offersEnabled: offersEnabled ?? this.offersEnabled,
      );

  Map<String, dynamic> toJson() => {
        'user': user?.toJson(),
        'vehicles': vehicles.map((e) => e.toJson()).toList(),
        'active_vehicle_id': activeVehicleId,
        'addresses': addresses.map((e) => e.toJson()).toList(),
        'bookings': bookings.map((e) => e.toJson()).toList(),
        'inspections':
            inspections.map((k, v) => MapEntry(k, v.toJson())),
        'estimates': estimates.map(
            (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
        'invoices': invoices.map((k, v) => MapEntry(k, v.toJson())),
        'notifications': notifications.map((e) => e.toJson()).toList(),
        'chat': chat.map((e) => e.toJson()).toList(),
        'tickets': tickets.map((e) => e.toJson()).toList(),
        'workshop_cards': workshopCards.map((e) => e.toJson()).toList(),
        'workshop': workshop.toJson(),
        'onboarded': onboarded,
        'theme_mode': themeMode.name,
        'saved_package_ids': savedPackageIds.toList(),
        'recent_searches': recentSearches,
        'push_enabled': pushEnabled,
        'email_enabled': emailEnabled,
        'whatsapp_enabled': whatsappEnabled,
        'service_reminders_enabled': serviceRemindersEnabled,
        'offers_enabled': offersEnabled,
      };

  factory AppData.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> listOf(String key) =>
        ((j[key] ?? const []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    final inspectionsRaw =
        Map<String, dynamic>.from((j['inspections'] ?? const {}) as Map);
    final estimatesRaw =
        Map<String, dynamic>.from((j['estimates'] ?? const {}) as Map);
    final invoicesRaw =
        Map<String, dynamic>.from((j['invoices'] ?? const {}) as Map);

    return AppData(
      user: j['user'] == null
          ? null
          : AppUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
      vehicles: listOf('vehicles').map(Vehicle.fromJson).toList(),
      activeVehicleId: j['active_vehicle_id'] as String?,
      addresses: listOf('addresses').map(Address.fromJson).toList(),
      bookings: listOf('bookings').map(Booking.fromJson).toList(),
      inspections: inspectionsRaw.map((k, v) => MapEntry(
          k, Inspection.fromJson(Map<String, dynamic>.from(v as Map)))),
      estimates: estimatesRaw.map((k, v) => MapEntry(
          k,
          (v as List)
              .map((e) =>
                  Estimate.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList())),
      invoices: invoicesRaw.map((k, v) =>
          MapEntry(k, Invoice.fromJson(Map<String, dynamic>.from(v as Map)))),
      notifications:
          listOf('notifications').map(AppNotification.fromJson).toList(),
      chat: listOf('chat').map(ChatMessage.fromJson).toList(),
      tickets: listOf('tickets').map(SupportTicket.fromJson).toList(),
      workshopCards:
          listOf('workshop_cards').map(WorkshopCard.fromJson).toList(),
      workshop: j['workshop'] == null
          ? Workshop.none
          : Workshop.fromJson(Map<String, dynamic>.from(j['workshop'] as Map)),
      onboarded: (j['onboarded'] ?? false) as bool,
      themeMode: ThemeMode.values.firstWhere(
          (e) => e.name == j['theme_mode'],
          orElse: () => ThemeMode.system),
      savedPackageIds:
          ((j['saved_package_ids'] ?? const []) as List).cast<String>().toSet(),
      recentSearches:
          ((j['recent_searches'] ?? const []) as List).cast<String>(),
      pushEnabled: (j['push_enabled'] ?? true) as bool,
      emailEnabled: (j['email_enabled'] ?? true) as bool,
      whatsappEnabled: (j['whatsapp_enabled'] ?? true) as bool,
      serviceRemindersEnabled:
          (j['service_reminders_enabled'] ?? true) as bool,
      offersEnabled: (j['offers_enabled'] ?? true) as bool,
    );
  }
}
