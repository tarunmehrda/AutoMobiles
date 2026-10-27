import 'package:flutter/foundation.dart';

import '../../core/i18n/strings.dart';

/// What the signed-in person may do at this workshop, as the database says
/// (`my_access()`, 04_roles.sql / 31_staff_logins.sql).
///
/// The database is the real boundary: a policy, not this class, decides what
/// comes back. This decides what the app draws, so a mechanic is not shown
/// a Cash Book that would only ever be empty.
///
/// With no backend, or before anybody has said otherwise, the person holding
/// the phone is the owner. A console that locked its only user out because
/// it could not reach the server would be worse than one that shows a
/// screen the server will refuse to fill.
@immutable
class Access {
  const Access({
    this.role = StaffRole.owner,
    this.staffId = '',
    this.grid = const {},
    this.seesCost = true,
    this.ownJobsOnly = false,
  });

  static const owner = Access();

  final StaffRole role;

  /// The staff record that is this person: the mechanic a job card names.
  final String staffId;

  /// Module → the letters of what may be done: v(iew), c(reate), e(dit),
  /// d(elete). The same shape as `role_grid()` in the database.
  final Map<String, String> grid;
  final bool seesCost;
  final bool ownJobsOnly;

  bool get isOwner => role == StaffRole.owner;

  bool can(String module, [String action = 'v']) =>
      isOwner || (grid[module] ?? '').contains(action);

  // The questions screens actually ask.
  bool get openJobs => can('jobCards', 'c');
  bool get editJobs => can('jobCards', 'e');
  bool get deleteJobs => can('jobCards', 'd');

  /// Taking money, discounts, closing a card: editing the card and seeing
  /// what it costs. A mechanic may do the first and not the second.
  bool get handlesMoney => editJobs && seesCost;
  bool get books => can('finance');
  bool get stock => can('inventory') && seesCost;
  bool get people => can('customers');
  bool get reports => can('reports');
  bool get team => can('users');
  bool get manageAttendance => can('attendance', 'e');
  bool get purchases => can('purchases');
  bool get counterSale => can('counterSale');
  bool get workshopSettings => can('settings', 'e');

  /// Whether [location] may be opened at all. The router sends anything
  /// else home, so a screen reached by a stale link or a notification tap
  /// cannot be used to get round a hidden tile.
  bool allows(String location) {
    if (isOwner) return true;
    final loc = location.split('?').first;
    bool under(String p) => loc == p || loc.startsWith('$p/');

    if (loc == '/job/new') return openJobs;
    // The bill: rates, quantities and totals.
    if (RegExp(r'^/job/[^/]+/items').hasMatch(loc)) return handlesMoney;
    if (under('/job') || under('/jobs') || under('/bookings')) {
      return can('jobCards');
    }
    if (loc == '/inventory/counter-sale/new') return can('counterSale', 'c');
    if (under('/inventory/counter-sales')) return counterSale;
    if (loc == '/inventory/purchase-order/new') return can('purchases', 'c');
    if (under('/inventory/purchase-orders') || under('/inventory/suppliers')) {
      return purchases;
    }
    if (under('/inventory')) return stock;
    if (under('/platform')) return purchases;
    if (under('/analytics') || under('/reports')) return reports;
    if (under('/expenses') || under('/cashbook') || under('/pending')) {
      return books;
    }
    if (under('/customers') ||
        under('/customer') ||
        under('/service-due') ||
        under('/contacts') ||
        under('/feedback')) {
      return people;
    }
    if (under('/attendance/site')) return workshopSettings;
    if (under('/attendance')) return can('attendance');
    if (under('/staff')) return team;
    if (under('/online-garage') ||
        under('/workshop') ||
        under('/settings/options')) {
      return workshopSettings;
    }
    if (under('/settings/greetings')) return can('customers', 'e');
    // The ledger beyond the job card. Selling over the counter opens Sales
    // as much as keeping the books does; estimates are front-desk work.
    if (under('/sales')) return books || counterSale;
    if (under('/purchase')) return purchases;
    if (under('/estimates')) return can('jobCards');
    if (under('/trade')) return can('jobCards') || purchases || books;
    if (under('/bank-accounts')) return books;
    if (under('/settings/sync-share')) return team;
    // What the workshop owes the platform is the owner's business, and the
    // database answers nobody else.
    if (under('/settings/commission')) return false;
    return true;
  }

  factory Access.fromJson(Map<String, dynamic> j) {
    final role = StaffRole.parse(j['role'] as String?);
    final raw = j['permissions'];
    return Access(
      role: role,
      staffId: (j['staff_id'] ?? '') as String,
      grid: raw is Map
          ? {for (final e in raw.entries) '${e.key}': '${e.value}'}
          : const {},
      seesCost: (j['sees_cost'] ?? role == StaffRole.owner) as bool,
      ownJobsOnly: (j['own_jobs_only'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'staff_id': staffId,
    'permissions': grid,
    'sees_cost': seesCost,
    'own_jobs_only': ownJobsOnly,
  };

  @override
  bool operator ==(Object other) =>
      other is Access &&
      other.role == role &&
      other.staffId == staffId &&
      other.seesCost == seesCost &&
      other.ownJobsOnly == ownJobsOnly &&
      mapEquals(other.grid, grid);

  @override
  int get hashCode =>
      Object.hash(role, staffId, seesCost, ownJobsOnly, grid.length);
}

/// The owner, and the four roles an owner can give somebody they invite.
enum StaffRole {
  owner,
  manager,
  mechanic,
  counter,
  accountant;

  /// Anything the app does not know — an empty answer, a role added to the
  /// database later — is read as the owner only when it is empty. An
  /// unknown staff role gets the least: a mechanic.
  static StaffRole parse(String? v) {
    if (v == null || v.isEmpty) return StaffRole.owner;
    return StaffRole.values.firstWhere(
      (r) => r.name == v,
      orElse: () => StaffRole.mechanic,
    );
  }

  static const invitable = [manager, mechanic, counter, accountant];

  String get label => switch (this) {
    StaffRole.owner => 'Owner'.tr,
    StaffRole.manager => 'Manager'.tr,
    StaffRole.mechanic => 'Mechanic'.tr,
    StaffRole.counter => 'Counter'.tr,
    StaffRole.accountant => 'Accountant'.tr,
  };

  /// One line an owner can decide on.
  String get blurb => switch (this) {
    StaffRole.owner => 'Everything in this workshop'.tr,
    StaffRole.manager =>
      'Job cards, bookings, customers, stock and money. No workshop settings'
          .tr,
    StaffRole.mechanic =>
      'Only the job cards they are on. No prices, no money'.tr,
    StaffRole.counter =>
      'Job cards, bookings, customers, stock and counter sale'.tr,
    StaffRole.accountant => 'Reads job cards; keeps the books and reports'.tr,
  };
}
