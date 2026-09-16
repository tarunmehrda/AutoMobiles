import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/entities.dart';
import '../data/models/enums.dart';
import '../data/models/workshop.dart';
import '../data/seed/catalog_seed.dart';
import 'app_state.dart';

// --- account -----------------------------------------------------------------

final userProvider = Provider<AppUser?>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.user)));

final isSignedInProvider = Provider<bool>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.user != null)));

final needsProfileProvider = Provider<bool>((ref) => ref.watch(
    appControllerProvider.select((s) => s.user != null && s.user!.name.isEmpty)));

final onboardedProvider = Provider<bool>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.onboarded)));

final themeModeProvider = Provider<ThemeMode>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.themeMode)));

// --- vehicles ----------------------------------------------------------------

final vehiclesProvider = Provider<List<Vehicle>>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.vehicles)));

final activeVehicleProvider = Provider<Vehicle?>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.activeVehicle)));

final addressesProvider = Provider<List<Address>>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.addresses)));

// --- bookings ----------------------------------------------------------------

final bookingsProvider = Provider<List<Booking>>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.bookings)));

final spotlightBookingProvider = Provider<Booking?>((ref) =>
    ref.watch(appControllerProvider.select((s) => s.spotlightBooking)));

final bookingProvider = Provider.family<Booking?, String>((ref, id) =>
    ref.watch(appControllerProvider.select((s) => s.bookingById(id))));

final inspectionProvider = Provider.family<Inspection?, String>((ref, id) =>
    ref.watch(appControllerProvider.select((s) => s.inspections[id])));

final estimatesProvider = Provider.family<List<Estimate>, String>(
    (ref, id) => ref.watch(appControllerProvider.select((s) => s.estimatesFor(id))));

final latestEstimateProvider = Provider.family<Estimate?, String>((ref, id) =>
    ref.watch(appControllerProvider.select((s) => s.latestEstimate(id))));

final invoiceProvider = Provider.family<Invoice?, String>(
    (ref, id) => ref.watch(appControllerProvider.select((s) => s.invoices[id])));

// --- the workshop's side -----------------------------------------------------

/// Every job card the garage has opened for this customer, newest first.
final workshopCardsProvider = Provider<List<WorkshopCard>>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.workshopCards)));

/// The one on the floor right now, if there is one. This is what Home
/// leads with — it is the most live thing in the app.
final liveWorkshopCardProvider = Provider<WorkshopCard?>((ref) => ref.watch(
    appControllerProvider.select((s) {
      final live = s.liveWorkshopCards;
      return live.isEmpty ? null : live.first;
    })));

final workshopCardProvider = Provider.family<WorkshopCard?, String>(
    (ref, id) => ref.watch(appControllerProvider.select((s) {
          for (final c in s.workshopCards) {
            if (c.id == id) return c;
          }
          return null;
        })));

// --- notifications -----------------------------------------------------------

final notificationsProvider = Provider<List<AppNotification>>((ref) =>
    ref.watch(appControllerProvider.select((s) => s.notifications)));

final unreadCountProvider = Provider<int>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.unreadCount)));

final chatProvider = Provider<List<ChatMessage>>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.chat)));

final ticketsProvider = Provider<List<SupportTicket>>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.tickets)));

// --- catalogue ---------------------------------------------------------------

final categoriesProvider =
    Provider<List<ServiceCategory>>((ref) => Seed.categories);

final packagesProvider = Provider<List<ServicePackage>>((ref) => Seed.packages);

final addOnsProvider = Provider<List<AddOn>>((ref) => Seed.addOns);

final couponsProvider = Provider<List<Coupon>>((ref) => Seed.coupons());

final savedPackagesProvider = Provider<Set<String>>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.savedPackageIds)));

final recentSearchesProvider = Provider<List<String>>(
    (ref) => ref.watch(appControllerProvider.select((s) => s.recentSearches)));

/// Fuzzy-ish catalogue search across package names, tags, categories and
/// the contents of each package.
final searchProvider =
    Provider.autoDispose.family<List<ServicePackage>, String>((ref, query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final terms = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();

  int scoreOf(ServicePackage p) {
    final category = Seed.categoryById(p.categoryId);
    final haystack = [
      p.name,
      p.subtitle,
      p.description,
      ...p.tags,
      ...p.includes,
      ...p.groups,
      category?.name ?? '',
      category?.tagline ?? '',
    ].join(' ').toLowerCase();

    var score = 0;
    for (final t in terms) {
      if (p.name.toLowerCase().startsWith(t)) {
        score += 60;
      } else if (p.name.toLowerCase().contains(t)) {
        score += 40;
      } else if ((category?.name ?? '').toLowerCase().contains(t)) {
        score += 24;
      } else if (p.tags.any((e) => e.toLowerCase().contains(t))) {
        score += 18;
      } else if (haystack.contains(t)) {
        score += 8;
      } else {
        return 0;
      }
    }
    if (p.popular) score += 5;
    return score;
  }

  final hits = <(ServicePackage, int)>[];
  for (final p in Seed.packages) {
    final s = scoreOf(p);
    if (s > 0) hits.add((p, s));
  }
  hits.sort((a, b) => b.$2.compareTo(a.$2));
  return hits.map((e) => e.$1).toList();
});

/// Recommendations tuned to the selected vehicle's age, odometer and history.
final recommendedProvider = Provider<List<ServicePackage>>((ref) {
  final data = ref.watch(appControllerProvider);
  final v = data.activeVehicle;
  final ids = <String>{};

  if (v == null) {
    ids.addAll(['standard-service', 'car-spa', 'wheel-alignment', 'ac-gas-refill']);
  } else {
    final age = DateTime.now().year - v.year;
    final km = v.odometerKm;

    ids.add(km >= 90000
        ? 'comprehensive-service'
        : (km >= 30000 ? 'standard-service' : 'basic-service'));

    if (age >= 3) ids.add('ac-gas-refill');
    if (km >= 40000) ids.add('brake-pads-front');
    if (km >= 20000) ids.add('wheel-alignment');
    if (age >= 4) ids.add('battery-replace');
    ids.add('car-spa');

    final lastMonths = v.lastServiceDate == null
        ? 99
        : DateTime.now().difference(v.lastServiceDate!).inDays ~/ 30;
    if (lastMonths >= 6) ids.add('general-inspection');
  }

  return [
    for (final id in ids)
      if (Seed.packageById(id) != null) Seed.packageById(id)!
  ];
});

/// Documents and services about to come due — powers the reminder rail.
@immutable
class DueAlert {
  const DueAlert({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.days,
    required this.route,
    this.critical = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int days;
  final String route;
  final bool critical;
}

final dueAlertsProvider = Provider<List<DueAlert>>((ref) {
  final v = ref.watch(activeVehicleProvider);
  if (v == null) return const [];
  final now = DateTime.now();
  final out = <DueAlert>[];

  void add(String title, DateTime? when, IconData icon, String route) {
    if (when == null) return;
    final days = when.difference(now).inDays;
    if (days > 45) return;
    out.add(DueAlert(
      title: title,
      subtitle: days < 0
          ? 'Expired ${-days} days ago'
          : (days == 0 ? 'Expires today' : 'Expires in $days days'),
      icon: icon,
      days: days,
      route: route,
      critical: days <= 7,
    ));
  }

  add('Insurance renewal', v.insuranceExpiry, Icons.verified_user_rounded,
      '/vehicle/${v.id}');
  add('PUC certificate', v.pucExpiry, Icons.eco_rounded, '/vehicle/${v.id}');

  final serviceDays = v.daysToService;
  if (serviceDays <= 45) {
    out.add(DueAlert(
      title: 'Service due',
      subtitle: serviceDays < 0
          ? 'Overdue by ${-serviceDays} days'
          : 'Due in $serviceDays days',
      icon: Icons.build_circle_rounded,
      days: serviceDays,
      route: '/book',
      critical: serviceDays <= 7,
    ));
  }

  out.sort((a, b) => a.days.compareTo(b.days));
  return out;
});

/// Lifetime stats shown on My Garage.
@immutable
class GarageStats {
  const GarageStats({
    required this.services,
    required this.spend,
    required this.saved,
    required this.lastVisit,
  });

  final int services;
  final int spend;
  final int saved;
  final DateTime? lastVisit;
}

final garageStatsProvider = Provider<GarageStats>((ref) {
  final data = ref.watch(appControllerProvider);
  final done = data.bookings
      .where((b) => b.status == BookingStatus.completed)
      .toList()
    ..sort((a, b) => b.slot.compareTo(a.slot));

  var spend = 0;
  var saved = 0;
  for (final b in done) {
    final inv = data.invoices[b.id];
    spend += inv?.total ?? b.total;
    saved += (b.mrpTotal - b.subtotal) + b.discount;
  }

  return GarageStats(
    services: done.length,
    spend: spend,
    saved: saved,
    lastVisit: done.isEmpty ? null : done.first.slot,
  );
});
