import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/i18n/app_language.dart';
import '../data/models/access.dart';
import '../data/models/attendance.dart';
import '../data/models/entities.dart';
import '../data/models/enums.dart';
import '../data/repo/admin_data.dart';
import '../data/repo/garage_gateway.dart';
import '../data/repo/push_service.dart';
import 'admin_state.dart';

/// What the signed-in person may do at this workshop. See [Access].
final accessProvider = Provider<Access>((ref) {
  final notifier = ref.watch(garageGatewayProvider).access;
  void changed() => ref.invalidateSelf();
  notifier.addListener(changed);
  ref.onDispose(() => notifier.removeListener(changed));
  return notifier.value;
});

/// The whole snapshot, for screens that need to cross-reference several
/// collections at once rather than watch one slice.
final adminDataProvider = Provider<AdminData>(
  (ref) => ref.watch(adminProvider),
);

// --- session -----------------------------------------------------------------

final garageProvider = Provider<Garage?>(
  (ref) => ref.watch(adminProvider.select((s) => s.garage)),
);

// Whether anybody is signed in is decided by the session, not by the
// snapshot — see `signedInProvider` in state/auth_state.dart.

final onboardedProvider = Provider<bool>(
  (ref) => ref.watch(adminProvider.select((s) => s.onboarded)),
);

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(adminProvider.select((s) => s.themeMode)),
);

/// The language the console is read in. Selecting the stored tag rather
/// than the enum keeps this a String comparison, so it only fires when the
/// language genuinely changes.
final languageProvider = Provider<AppLanguage>(
  (ref) => AppLanguage.fromCode(
    ref.watch(adminProvider.select((s) => s.languageCode)),
  ),
);

final staffProvider = Provider<List<Staff>>(
  (ref) => ref.watch(adminProvider.select((s) => s.staff)),
);

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
  (ref) => ref.watch(adminProvider.select((s) => s.jobCards)),
);

final customersProvider = Provider<List<Customer>>(
  (ref) => ref.watch(adminProvider.select((s) => s.customers)),
);

final vehiclesProvider = Provider<List<Vehicle>>(
  (ref) => ref.watch(adminProvider.select((s) => s.vehicles)),
);

final allMastersProvider = Provider<List<MasterItem>>(
  (ref) => ref.watch(adminProvider.select((s) => s.masters)),
);

final bookingsProvider = Provider<List<Booking>>(
  (ref) => ref.watch(adminProvider.select((s) => s.bookings)),
);

final reviewsProvider = Provider<List<Review>>(
  (ref) => ref.watch(adminProvider.select((s) => s.reviews)),
);

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
final bucketCountProvider = Provider.family<int, JobStatus>(
  (ref, status) =>
      ref.watch(jobCardsProvider).where((j) => j.status == status).length,
);

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
  final list =
      ref
          .watch(jobCardsProvider)
          .where((j) => j.vehicleId == card.vehicleId && j.id != cardId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
});

// --- money -------------------------------------------------------------------

final pendingBalanceProvider = Provider<List<JobCard>>((ref) {
  final list =
      ref
          .watch(jobCardsProvider)
          .where((j) => j.items.isNotEmpty && !j.settled)
          .toList()
        ..sort((a, b) => b.balance.compareTo(a.balance));
  return list;
});

final pendingTotalProvider = Provider<double>(
  (ref) => money(
    ref.watch(pendingBalanceProvider).fold<double>(0, (s, j) => s + j.balance),
  ),
);

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
  (ref, kind) =>
      ref.watch(allMastersProvider).where((m) => m.kind == kind).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
);

final lowStockProvider = Provider<List<MasterItem>>(
  (ref) =>
      ref.watch(allMastersProvider).where((m) => m.low || m.out).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock)),
);

// --- front desk --------------------------------------------------------------

final openBookingsProvider = Provider<List<Booking>>((ref) {
  final list = ref.watch(bookingsProvider).where((b) => !b.accepted).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  return list;
});

// --- the bell ----------------------------------------------------------------

final notificationsProvider = Provider<List<GarageNotification>>(
  (ref) => ref.watch(adminProvider.select((s) => s.notifications)),
);

/// The feed as the screen reads it: newest first.
final notificationFeedProvider = Provider<List<GarageNotification>>((ref) {
  final list = [...ref.watch(notificationsProvider)]
    ..sort((a, b) => b.at.compareTo(a.at));
  return list;
});

/// What the badge counts. A separate provider from the feed so the dot does
/// not rebuild every screen that shows it each time an old alert is pruned.
final unreadCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length,
);

/// Alerts as they land, for whatever is on screen to announce once.
///
/// See [AdminController.alerts] for why this is an event stream rather than
/// a slice of state.
final garageAlertProvider = StreamProvider<GarageNotification>(
  (ref) => ref.watch(adminProvider.notifier).alerts,
);

/// Routes from push notifications the user tapped while the console was in
/// the background or closed. Empty on a build without push.
final pushOpenedProvider = StreamProvider<String>(
  (ref) => ref.watch(pushServiceProvider).openedRoutes,
);

final serviceDueProvider = Provider<List<JobCard>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final list = ref.watch(jobCardsProvider).where((j) {
    final due = j.nextServiceAt;
    if (due == null) return false;
    return !DateTime(due.year, due.month, due.day).isAfter(today);
  }).toList()..sort((a, b) => a.nextServiceAt!.compareTo(b.nextServiceAt!));
  return list;
});

final averageRatingProvider = Provider<double>((ref) {
  final reviews = ref.watch(reviewsProvider);
  if (reviews.isEmpty) return 0;
  return reviews.fold<double>(0, (s, r) => s + r.stars) / reviews.length;
});

// --- expenses, day book and the counter -------------------------------------

final expensesProvider = Provider<List<Expense>>(
  (ref) => ref.watch(adminDataProvider).expensesByDate,
);

final expenseTotalsProvider = Provider<({double total, double pending})>((ref) {
  final d = ref.watch(adminDataProvider);
  return (total: d.expenseTotal, pending: d.expensePending);
});

final cashBookProvider = Provider<List<CashEntry>>(
  (ref) => ref.watch(adminProvider.select((s) => s.cashBook)),
);

/// Entries for one calendar day, newest first.
final cashDayProvider = Provider.family<List<CashEntry>, DateTime>(
  (ref, day) => ref.watch(adminDataProvider).cashOn(day),
);

final cashSummaryProvider =
    Provider.family<({double inward, double outward}), DateTime>(
      (ref, day) => ref.watch(adminDataProvider).cashSummary(day),
    );

final suppliersProvider = Provider<List<Supplier>>(
  (ref) => ref.watch(adminProvider.select((s) => s.suppliers)),
);

final counterSalesProvider = Provider<List<CounterSale>>(
  (ref) => ref.watch(adminDataProvider).counterSalesByDate,
);

// --- online garage ----------------------------------------------------------

final onlineGarageOnProvider = Provider<bool>(
  (ref) => ref.watch(adminProvider.select((s) => s.onlineGarageOn)),
);

final onlineSlugProvider = Provider<String>(
  (ref) => ref.watch(adminProvider.select((s) => s.onlineSlug)),
);

final onlineServicesProvider = Provider<List<OnlineService>>(
  (ref) => ref.watch(adminProvider.select((s) => s.onlineServices)),
);

/// The link the workshop shares on WhatsApp: where its customers get the
/// app they book it from. Empty while the shopfront is off, because then
/// there is nothing on it to book.
final onlineLinkProvider = Provider<String>((ref) {
  final on = ref.watch(onlineGarageOnProvider);
  return on ? AppConfig.customerAppLink : '';
});

/// The message that goes with [onlineLinkProvider].
final onlineShareTextProvider = Provider<String>((ref) {
  final link = ref.watch(onlineLinkProvider);
  final name = ref.watch(adminProvider.select((s) => s.garage?.name)) ?? '';
  if (link.isEmpty) return '';
  return 'Book your next service at ${name.isEmpty ? 'our workshop' : name} '
      'on the Balaji Car app: $link — search for us by name, pick a slot, '
      'and track your car while we work on it.';
});

// --- attendance --------------------------------------------------------------

/// Where staff may punch in. Null until the owner pins one, which is what
/// the attendance screen checks before it offers a button at all.
final attendanceSiteProvider = Provider<AttendanceSite?>(
  (ref) => ref.watch(adminProvider.select((s) => s.garage?.attendanceSite)),
);

/// The whole register this device knows about, newest first.
final attendanceProvider = Provider<List<AttendancePunch>>(
  (ref) => ref.watch(adminProvider.select((s) => s.attendance)),
);

/// One calendar day of it.
final attendanceDayProvider = Provider.family<List<AttendancePunch>, DateTime>(
  (ref, day) => ref
      .watch(attendanceProvider)
      .where((p) => AdminData.sameDay(p.at, day))
      .toList(),
);

/// Whether somebody is on the floor, by their last accepted punch.
final onDutyProvider = Provider.family<bool, String>(
  (ref, staffId) => Shift.onDuty(ref.watch(attendanceProvider), staffId),
);

/// What the big button should offer this person next.
final nextPunchProvider = Provider.family<PunchKind, String>(
  (ref, staffId) => Shift.next(ref.watch(attendanceProvider), staffId),
);

/// Everyone currently punched in — the headcount on the dashboard tile.
final onFloorProvider = Provider<List<Staff>>((ref) {
  final log = ref.watch(attendanceProvider);
  return ref
      .watch(staffProvider)
      .where((s) => Shift.onDuty(log, s.id))
      .toList();
});

/// Refused attempts, newest first. The ones worth an owner's attention are
/// the [PunchBlockX.isAbuse] rows; the rest are phones having a bad day.
final blockedPunchesProvider = Provider<List<AttendancePunch>>(
  (ref) => ref.watch(attendanceProvider).where((p) => !p.accepted).toList(),
);

// --- reminders --------------------------------------------------------------

/// Cards whose next service falls inside a window — the Service Due screen
/// pages through Today / This week / This month with the same provider.
final serviceDueRangeProvider =
    Provider.family<List<JobCard>, ({DateTime from, DateTime to})>(
      (ref, r) => ref.watch(adminDataProvider).serviceDueBetween(r.from, r.to),
    );

/// Vehicles whose insurance runs out inside a window.
final insuranceDueRangeProvider =
    Provider.family<List<JobCard>, ({DateTime from, DateTime to})>((ref, r) {
      final list = ref.watch(jobCardsProvider).where((j) {
        final due = j.nextServiceAt;
        if (due == null) return false;
        // Insurance is tracked a year out from the visit until the workshop
        // records a policy of its own.
        final renewal = j.createdAt.add(const Duration(days: 365));
        return !renewal.isBefore(r.from) && !renewal.isAfter(r.to);
      }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });

final purchaseOrdersProvider = Provider<List<PurchaseOrder>>(
  (ref) => ref.watch(adminDataProvider).ordersByDate,
);

/// Value on the shelf split by kind — what the inventory donut reads.
final stockSplitProvider =
    Provider<({double spare, double lube, double total})>((ref) {
      final d = ref.watch(adminDataProvider);
      final spare = d.stockValueOf(LineKind.spare);
      final lube = d.stockValueOf(LineKind.lube);
      return (spare: spare, lube: lube, total: money(spare + lube));
    });
