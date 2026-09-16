import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/entities.dart';
import '../data/models/enums.dart';
import '../data/repo/admin_data.dart';
import 'admin_state.dart';

/// The whole snapshot, for screens that need to cross-reference several
/// collections at once rather than watch one slice.
final adminDataProvider =
    Provider<AdminData>((ref) => ref.watch(adminProvider));

// --- session -----------------------------------------------------------------

final garageProvider = Provider<Garage?>(
    (ref) => ref.watch(adminProvider.select((s) => s.garage)));

// Whether anybody is signed in is decided by the session, not by the
// snapshot — see `signedInProvider` in state/auth_state.dart.

final onboardedProvider = Provider<bool>(
    (ref) => ref.watch(adminProvider.select((s) => s.onboarded)));

final themeModeProvider = Provider<ThemeMode>(
    (ref) => ref.watch(adminProvider.select((s) => s.themeMode)));

final staffProvider = Provider<List<Staff>>(
    (ref) => ref.watch(adminProvider.select((s) => s.staff)));

// --- the collections ---------------------------------------------------------
//
// Everything below derives from one of these four, never from the whole
// snapshot.
//
// The distinction matters more than it looks. `select` holds on to the last
// value and compares it with `==`, and two Lists with the same contents are
// never equal in Dart — so a provider that selects a freshly built list
// (`s.of(status)`, `s.lowStock`, ...) reports a change on *every* edit
// anywhere in the console. Typing a work note would rebuild the stock list.
//
// Selecting the stored list instead compares by identity: it only changes
// when that list is actually replaced. Derived views then hang off it, so a
// payment rebuilds the money strip and leaves the inventory alone.

final jobCardsProvider = Provider<List<JobCard>>(
    (ref) => ref.watch(adminProvider.select((s) => s.jobCards)));

final customersProvider = Provider<List<Customer>>(
    (ref) => ref.watch(adminProvider.select((s) => s.customers)));

final vehiclesProvider = Provider<List<Vehicle>>(
    (ref) => ref.watch(adminProvider.select((s) => s.vehicles)));

final allMastersProvider = Provider<List<MasterItem>>(
    (ref) => ref.watch(adminProvider.select((s) => s.masters)));

final bookingsProvider = Provider<List<Booking>>(
    (ref) => ref.watch(adminProvider.select((s) => s.bookings)));

final reviewsProvider = Provider<List<Review>>(
    (ref) => ref.watch(adminProvider.select((s) => s.reviews)));

// --- job cards ---------------------------------------------------------------

final jobCardProvider = Provider.family<JobCard?, String>((ref, id) {
  for (final j in ref.watch(jobCardsProvider)) {
    if (j.id == id) return j;
  }
  return null;
});

final bucketProvider = Provider.family<List<JobCard>, JobStatus>((ref, status) {
  final list =
      ref.watch(jobCardsProvider).where((j) => j.status == status).toList()
        ..sort((a, b) => b.stampFor(status).compareTo(a.stampFor(status)));
  return list;
});

/// Counts are ints, so a rebuild only reaches the dashboard when the number
/// on the tile actually changes.
final bucketCountProvider = Provider.family<int, JobStatus>((ref, status) =>
    ref.watch(jobCardsProvider).where((j) => j.status == status).length);

final customerProvider = Provider.family<Customer?, String>((ref, id) {
  for (final c in ref.watch(customersProvider)) {
    if (c.id == id) return c;
  }
  return null;
});

final vehicleProvider = Provider.family<Vehicle?, String>((ref, id) {
  for (final v in ref.watch(vehiclesProvider)) {
    if (v.id == id) return v;
  }
  return null;
});

/// Previous visits for the vehicle on a given card, newest first.
final historyProvider = Provider.family<List<JobCard>, String>((ref, cardId) {
  final card = ref.watch(jobCardProvider(cardId));
  if (card == null) return const [];
  final list = ref
      .watch(jobCardsProvider)
      .where((j) => j.vehicleId == card.vehicleId && j.id != cardId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
});

// --- money -------------------------------------------------------------------

final pendingBalanceProvider = Provider<List<JobCard>>((ref) {
  final list = ref
      .watch(jobCardsProvider)
      .where((j) => j.items.isNotEmpty && !j.settled)
      .toList()
    ..sort((a, b) => b.balance.compareTo(a.balance));
  return list;
});

final pendingTotalProvider = Provider<double>((ref) => money(ref
    .watch(pendingBalanceProvider)
    .fold<double>(0, (s, j) => s + j.balance)));

/// Billed and collected for the calendar day, for the dashboard strip.
final todayMoneyProvider = Provider<({double billed, double collected})>((ref) {
  final cards = ref.watch(jobCardsProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  final to = from.add(const Duration(days: 1));

  var billed = 0.0;
  var collected = 0.0;
  for (final j in cards) {
    if (j.status != JobStatus.open) {
      final at = j.completedAt ?? j.createdAt;
      if (!at.isBefore(from) && !at.isAfter(to)) billed += j.total;
    }
    for (final p in j.payments) {
      if (!p.at.isBefore(from) && !p.at.isAfter(to)) collected += p.amount;
    }
  }
  return (billed: money(billed), collected: money(collected));
});

// --- masters and stock -------------------------------------------------------

final mastersProvider = Provider.family<List<MasterItem>, LineKind>(
    (ref, kind) => ref.watch(allMastersProvider).where((m) => m.kind == kind).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

final lowStockProvider = Provider<List<MasterItem>>((ref) =>
    ref.watch(allMastersProvider).where((m) => m.low || m.out).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock)));

// --- front desk --------------------------------------------------------------

final openBookingsProvider = Provider<List<Booking>>((ref) {
  final list = ref.watch(bookingsProvider).where((b) => !b.accepted).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  return list;
});

final serviceDueProvider = Provider<List<JobCard>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final list = ref.watch(jobCardsProvider).where((j) {
    final due = j.nextServiceAt;
    if (due == null) return false;
    return !DateTime(due.year, due.month, due.day).isAfter(today);
  }).toList()
    ..sort((a, b) => a.nextServiceAt!.compareTo(b.nextServiceAt!));
  return list;
});

final averageRatingProvider = Provider<double>((ref) {
  final reviews = ref.watch(reviewsProvider);
  if (reviews.isEmpty) return 0;
  return reviews.fold<double>(0, (s, r) => s + r.stars) / reviews.length;
});
