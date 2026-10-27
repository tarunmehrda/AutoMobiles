import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';

import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/app_language.dart';
import '../core/i18n/strings.dart';
import '../data/models/access.dart';
import '../data/models/attendance.dart';
import '../data/models/books.dart';
import '../data/models/entities.dart';
import '../data/models/enums.dart';
import '../data/repo/admin_data.dart';
import '../data/repo/attendance_gate.dart';
import '../data/repo/attendance_gateway.dart';
import '../data/repo/garage_gateway.dart';
import '../data/repo/local_store.dart';
import '../data/repo/platform_gateway.dart';
import '../data/repo/push_service.dart';
import '../data/seed/seed.dart';

final _rand = Random();

String newId([String prefix = 'id']) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_rand.nextInt(9999)}';

/// Set in main() before the app builds. Not `final` so tests can rebuild it
/// with a fresh mock between cases.
late LocalStore localStore;

final adminProvider = StateNotifierProvider<AdminController, AdminData>(
  (ref) => AdminController(
    localStore,
    ref.read(garageGatewayProvider),
    ref.read(attendanceGatewayProvider),
  ),
);

/// A punch and everything the screen needs to explain it: the verdict, the
/// reading it was reached from, and whether anybody but this phone agreed.
typedef PunchOutcome = ({
  PunchBlock block,
  String message,
  GateReading reading,
  bool verified,
});

/// What one attempt at fetching the workshop behind a session could tell us.
///
/// [unreachable] is deliberately not the same as [noWorkshop]. Signing out
/// clears the workshop from the device, so after a sign-in the backend is
/// the only thing that knows this account already has one. If a flat
/// network answer counted as "no workshop", every sign-in on a bad
/// connection would hand the owner the registration form for a shop they
/// registered months ago.
enum RestoreOutcome { restored, noWorkshop, unreachable }

/// Single source of truth for the workshop, plus the rules that keep a job
/// card honest:
///
/// - A job card number is minted once and never changes.
/// - Nothing completes with an empty bill; nothing closes before it completes.
/// - Stock moves the moment a part is put on a card, and comes back if the
///   line is removed or the quantity drops.
/// - Payments always attach to a job card, and a card is settled only when
///   the collected total reaches the billed total.
/// - Closing a card schedules the service reminder trail.
class AdminController extends StateNotifier<AdminData>
    with WidgetsBindingObserver {
  AdminController(this._store, this._remote, [AttendanceGateway? attendance])
    : _attendance = attendance ?? AttendanceGateway.instance,
      super(_store.read()) {
    WidgetsBinding.instance.addObserver(this);
    final saved = _store.access;
    if (saved != null) _remote.access.value = Access.fromJson(saved);
  }

  final LocalStore _store;
  final GarageGateway _remote;
  final AttendanceGateway _attendance;

  /// True while a change that came down the wire is being applied, so it is
  /// not pushed straight back up.
  bool _applyingRemote = false;

  /// Alerts that arrived while this console was running, for whatever is on
  /// screen to announce.
  ///
  /// Deliberately a stream and not a slice of state. "A booking just came
  /// in" is an event, not a condition: it happens once, it is announced
  /// once, and a console that rebuilds for an unrelated reason must not
  /// announce it again. The durable half — what the bell counts and the
  /// feed lists — is [AdminData.notifications]; this is only the moment.
  ///
  /// Only the realtime path feeds it. A fetch that returns fifty rows on
  /// launch is the console catching up, not fifty things happening, and
  /// banner-ing all of them would be the one behaviour guaranteed to make
  /// the counter turn the feature off.
  final StreamController<GarageNotification> _alerts =
      StreamController<GarageNotification>.broadcast();

  Stream<GarageNotification> get alerts => _alerts.stream;

  /// When the console last went and asked the server for itself, so coming
  /// back to the app repeatedly does not hammer it.
  DateTime? _lastResume;

  /// Catch up whenever the counter comes back to the console.
  ///
  /// The realtime channel is supposed to make this unnecessary, and when it
  /// is working it does. It is not always working: on 22 Sep 2026 this
  /// project's channel reported `subscribed` and then delivered no events
  /// at all, for any table, so a booking confirmed on a customer's phone
  /// reached the database and never reached the front desk. The counter had
  /// no way to know, because a silent channel looks exactly like a quiet
  /// afternoon.
  ///
  /// Refetching on resume is the cheap insurance. A phone at a service
  /// counter is picked up, used and put down all day, so "when they come
  /// back to it" is both the moment the data matters and a natural rate
  /// limit. [_resumeGap] stops a quick app-switch from refetching twice.
  static const _resumeGap = Duration(seconds: 20);

  // Named `lifecycle`, not `state`: this class already has a `state`, and
  // shadowing it here would quietly read the parameter instead of the
  // snapshot two lines down.
  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) return;
    if (!_remote.enabled || state.garage == null) return;
    final last = _lastResume;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _resumeGap) return;
    _lastResume = now;
    unawaited(resync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_alerts.close());
    super.dispose();
  }

  void _set(AdminData next) {
    state = next;
    _store.write(next);
    if (!_applyingRemote) _remote.push(next);
  }

  /// Applies a change made on another device without echoing it back.
  void _setRemote(AdminData next) {
    _applyingRemote = true;
    try {
      _set(next);
    } finally {
      _applyingRemote = false;
    }
  }

  /// Replace one job card in place, keeping list order stable.
  void _put(JobCard card) {
    _set(
      state.copyWith(
        jobCards: [
          for (final j in state.jobCards)
            if (j.id == card.id) card else j,
        ],
      ),
    );
  }

  JobCard? _find(String id) => state.jobById(id);

  // ---------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------

  void completeOnboarding() => _set(state.copyWith(onboarded: true));

  /// Marks the on-device session live. Real authentication lives in
  /// [AuthService]; this only covers the no-backend case and the moment just
  /// after a successful sign-in.
  void markSignedIn() => _set(state.copyWith(signedIn: true));

  /// Clearing the counter for the next person to sign in.
  ///
  /// Only what can be fetched again is thrown away. A workshop the backend
  /// has never confirmed exists on this device and nowhere else, so wiping
  /// it is not hygiene, it is losing the shop — and with it any chance of
  /// signing back in without typing the whole registration out again. In
  /// that case the session goes and the workshop stays.
  void signOut() {
    // The live connection alone is not enough: signing out of the account
    // closes it first, so by the time this runs it usually reads as never
    // synced — and the whole workshop stayed on the phone for whoever
    // signed in next, who then tried to upload it as their own.
    final synced = _remote.garageId != null || _confirmed(state.garage);
    unawaited(_remote.reset());
    unawaited(_store.setAccess(null));
    final next = synced
        ? state.signedOut()
        : state.copyWith(signedIn: false, onboarded: true);
    state = next;
    _store.flush(next);
  }

  /// After the account is deleted upstream: everything goes, synced or not.
  /// There is no workshop left to send an unsent card to.
  void wipe() {
    unawaited(_remote.reset());
    final next = state.signedOut();
    state = next;
    _store.flush(next);
  }

  // ---------------------------------------------------------------------
  // Backend session
  // ---------------------------------------------------------------------

  /// Joins the console to its workshop upstream: finds or creates the
  /// garage, decides which side is authoritative, then opens the realtime
  /// channel. Safe to call again — it is how the app recovers after the
  /// network comes back.
  ///
  /// Called whenever a Supabase session appears. With no backend configured
  /// it does nothing at all and the console runs exactly as before.
  Future<RestoreOutcome> connectBackend() async {
    // Nothing upstream to ask, so whatever is on this device is the answer.
    if (!_remote.enabled) {
      return state.garage == null
          ? RestoreOutcome.noWorkshop
          : RestoreOutcome.restored;
    }

    final lookup = await _remote.ensureGarage(state.garage);
    if (!lookup.reachable) return RestoreOutcome.unreachable;
    final garage = lookup.garage;
    if (garage == null) {
      // What is on this phone is a workshop the server no longer gives this
      // account: a staff login the owner removed, a deleted account signing
      // in fresh, or another account's shop on a shared phone. Clear it, and
      // they land on "Who are you?" to register or join.
      if (!_remote.access.value.isOwner || _confirmed(state.garage)) {
        _remote.access.value = Access.owner;
        unawaited(_store.setAccess(null));
        if (mounted) _setRemote(state.signedOut().copyWith(signedIn: true));
      }
      return RestoreOutcome.noWorkshop;
    }
    // This account demonstrably has a workshop, so a lookup that fails on
    // some later sign-in is a fault to retry, not a new shop to register.
    unawaited(_store.markRegistered());
    if (!mounted) return RestoreOutcome.restored;

    final adopted = adoptWorkshop(state, garage);
    if (adopted != null) _setRemote(adopted);

    // Before the download, which keeps or drops cards by it. A failed ask
    // keeps whatever this phone last knew.
    final access = await _remote.fetchAccess();
    if (!mounted) return RestoreOutcome.restored;
    if (access != null) {
      _remote.access.value = access;
      unawaited(_store.setAccess(access.toJson()));
    }

    final remote = await _remote.hydrate(state);
    if (!mounted) return RestoreOutcome.restored;

    if (remote != null && _hasRows(remote)) {
      // Somebody has used this workshop before: upstream is the truth.
      _setRemote(remote);
      // ...but not the whole truth. `_setRemote` deliberately does not echo
      // back, and a hydrate can hand us rows this device is still holding
      // alone -- a job card whose `save_job_card()` failed, or a collection
      // the snapshot did not answer on. Without this they stay dirty and
      // nothing ever retries them: the card survives on the phone (which is
      // the point of the merge in `_mergeCards`) but never reaches the
      // server, even after the reason it failed has been fixed.
      //
      // Cheap to do unconditionally. `push()` skips every row the gateway
      // already holds as known-good, so on a device with nothing outstanding
      // this sends nothing at all.
      _remote.push(state);
    } else {
      // A workshop nobody has synced yet. Seed it from this device rather
      // than letting an empty snapshot wipe what is on the counter.
      _remote.push(state);
    }

    unawaited(_remote.connect(
      garageId: garage.id,
      onCard: _remoteCard,
      onRow: _remoteRow,
      onGone: _remoteGone,
    ));
    // Neither the register nor the alert feed is part of `garage_snapshot`
    // — both have their own RPC because both have their own write path.
    // Not awaited: a console that could not reach them still opens, showing
    // whatever this device last saw.
    unawaited(refreshAttendance());
    unawaited(refreshNotifications());

    // Only now is there a workshop to file this handset under, which is why
    // this is here and not in `main()` beside `PushService.init`.
    unawaited(PushService.instance.start(_remote.registerDevice));
    return RestoreOutcome.restored;
  }

  Future<void> disconnectBackend() => _remote.reset();

  /// What this phone holds once it joins [garage], the workshop the signed-in
  /// account has upstream. Null when it already holds exactly that.
  @visibleForTesting
  static AdminData? adoptWorkshop(AdminData local, Garage garage) {
    final mine = local.garage;
    if (_confirmed(mine) && mine!.id != garage.id) {
      // What is on this phone belongs to another workshop the server knows
      // — another account used this phone before. It is safe upstream in
      // that workshop; merged in here, its job cards were refused forever
      // with "belongs to another garage". Start this one clean.
      return local.signedOut().copyWith(garage: garage, signedIn: true);
    }
    if (mine?.id != garage.id || mine != garage) {
      return local.copyWith(garage: garage, signedIn: true);
    }
    return null;
  }

  /// Whether [g] is a workshop the server has confirmed. Its id is then the
  /// server's UUID; one registered on this phone and never synced still
  /// carries the id it was given here (`newId('garage')`).
  static bool _confirmed(Garage? g) => g != null && _serverId.hasMatch(g.id);

  static final _serverId = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool _hasRows(AdminData d) =>
      d.jobCards.isNotEmpty ||
      d.customers.isNotEmpty ||
      d.masters.isNotEmpty ||
      d.staff.isNotEmpty;

  /// A job card another device opened, edited or billed.
  void _remoteCard(JobCard card) {
    final known = state.jobById(card.id) != null;
    _setRemote(
      state.copyWith(
        jobCards: known
            ? [
                for (final j in state.jobCards)
                  if (j.id == card.id) card else j,
              ]
            : [card, ...state.jobCards],
      ),
    );
  }

  /// A row from one of the garage-scoped tables, already stripped of the
  /// columns the local model does not carry.
  void _remoteRow(String table, Map<String, dynamic> row) {
    List<T> merged<T>(List<T> list, T value, String Function(T) id) {
      final key = id(value);
      return list.any((e) => id(e) == key)
          ? [
              for (final e in list)
                if (id(e) == key) value else e,
            ]
          : [...list, value];
    }

    switch (table) {
      case 'garages':
        _setRemote(state.copyWith(garage: Garage.fromJson(row)));
      case 'staff':
        _setRemote(
          state.copyWith(
            staff: merged(state.staff, Staff.fromJson(row), (e) => e.id),
          ),
        );
      case 'garage_customers':
        _setRemote(
          state.copyWith(
            customers: merged(
              state.customers,
              Customer.fromJson(row),
              (e) => e.id,
            ),
          ),
        );
      case 'garage_vehicles':
        _setRemote(
          state.copyWith(
            vehicles: merged(
              state.vehicles,
              Vehicle.fromJson(row),
              (e) => e.id,
            ),
          ),
        );
      case 'masters':
        _setRemote(
          state.copyWith(
            masters: merged(
              state.masters,
              MasterItem.fromJson(row),
              (e) => e.id,
            ),
          ),
        );
      case 'garage_bookings':
        _setRemote(
          state.copyWith(
            bookings: merged(
              state.bookings,
              Booking.fromJson(row),
              (e) => e.id,
            ),
          ),
        );
      case 'reviews':
        _setRemote(
          state.copyWith(
            reviews: merged(state.reviews, Review.fromJson(row), (e) => e.id),
          ),
        );
      case 'expenses':
        _setRemote(
          state.copyWith(
            expenses: merged(
              state.expenses,
              Expense.fromJson(row),
              (e) => e.id,
            ),
          ),
        );
      case 'cash_book':
        _setRemote(
          state.copyWith(
            cashBook: merged(
              state.cashBook,
              CashEntry.fromJson(row),
              (e) => e.id,
            ),
          ),
        );
      case 'suppliers':
        _setRemote(
          state.copyWith(
            suppliers: merged(
              state.suppliers,
              Supplier.fromJson(row),
              (e) => e.id,
            ),
          ),
        );
      case 'counter_sales':
        _setRemote(
          state.copyWith(
            counterSales: merged(
              state.counterSales,
              CounterSale.fromJson(row),
              (e) => e.id,
            ),
          ),
        );
      case 'purchase_orders':
        _setRemote(
          state.copyWith(
            purchaseOrders: merged(
              state.purchaseOrders,
              PurchaseOrder.fromJson(row),
              (e) => e.id,
            ),
          ),
        );
      case 'online_services':
        _setRemote(
          state.copyWith(
            onlineServices: merged(
              state.onlineServices,
              OnlineService.fromJson(row),
              (e) => e.id,
            ),
          ),
        );
      case 'garage_notifications':
        final n = GarageNotification.fromJson(row);
        // Announce it only the first time it is seen and only while it is
        // still unread. The same row arrives again when another device at
        // the counter marks it read, and that is the opposite of news.
        final known = state.notifications.any((e) => e.id == n.id);
        _setRemote(
          state.copyWith(
            notifications: merged(state.notifications, n, (e) => e.id),
          ),
        );
        // `_announced` is shared with [refreshNotifications] so a row that
        // arrives both ways is still only announced once.
        if (!known && !n.read && !_alerts.isClosed && _announced.add(n.id)) {
          _alerts.add(n);
        }
      case 'attendance':
        // A row that arrived from the database has been through
        // `punch_attendance`, so it is checked by construction —
        // `fromServer`, not `fromJson`, or every punch synced from another
        // phone would land in the register marked unverified.
        final p = AttendancePunch.fromServer(row);
        final next = merged(state.attendance, p, (e) => e.id)
          ..sort((a, b) => b.at.compareTo(a.at));
        _setRemote(state.copyWith(attendance: next));
    }
  }

  void _remoteGone(String table, String id) {
    switch (table) {
      case 'job_cards':
        _setRemote(
          state.copyWith(
            jobCards: state.jobCards.where((e) => e.id != id).toList(),
          ),
        );
      case 'staff':
        _setRemote(
          state.copyWith(staff: state.staff.where((e) => e.id != id).toList()),
        );
      case 'garage_customers':
        _setRemote(
          state.copyWith(
            customers: state.customers.where((e) => e.id != id).toList(),
          ),
        );
      case 'garage_vehicles':
        _setRemote(
          state.copyWith(
            vehicles: state.vehicles.where((e) => e.id != id).toList(),
          ),
        );
      case 'masters':
        _setRemote(
          state.copyWith(
            masters: state.masters.where((e) => e.id != id).toList(),
          ),
        );
      case 'garage_bookings':
        _setRemote(
          state.copyWith(
            bookings: state.bookings.where((e) => e.id != id).toList(),
          ),
        );
      case 'garage_notifications':
        _setRemote(
          state.copyWith(
            notifications:
                state.notifications.where((e) => e.id != id).toList(),
          ),
        );
      case 'reviews':
        _setRemote(
          state.copyWith(
            reviews: state.reviews.where((e) => e.id != id).toList(),
          ),
        );
      case 'expenses':
        _setRemote(
          state.copyWith(
            expenses: state.expenses.where((e) => e.id != id).toList(),
          ),
        );
      case 'cash_book':
        _setRemote(
          state.copyWith(
            cashBook: state.cashBook.where((e) => e.id != id).toList(),
          ),
        );
      case 'suppliers':
        _setRemote(
          state.copyWith(
            suppliers: state.suppliers.where((e) => e.id != id).toList(),
          ),
        );
      case 'counter_sales':
        _setRemote(
          state.copyWith(
            counterSales: state.counterSales.where((e) => e.id != id).toList(),
          ),
        );
      case 'purchase_orders':
        _setRemote(
          state.copyWith(
            purchaseOrders: state.purchaseOrders
                .where((e) => e.id != id)
                .toList(),
          ),
        );
      case 'online_services':
        _setRemote(
          state.copyWith(
            onlineServices: state.onlineServices
                .where((e) => e.id != id)
                .toList(),
          ),
        );
    }
  }

  /// Wipe the job cards and customers but keep the workshop and masters.
  void clearJobCards() => _set(
    state.copyWith(
      jobCards: const [],
      bookings: const [],
      reviews: const [],
      seq: 0,
    ),
  );

  void setThemeMode(ThemeMode mode) => _set(state.copyWith(themeMode: mode));

  /// Swaps the language the console is read in.
  ///
  /// The dictionary is pointed at the new language here, before the
  /// snapshot lands, so the rebuild the state change triggers already
  /// reads the new copy.
  void setLanguage(AppLanguage language) {
    Tr.use(language);
    _set(state.copyWith(languageCode: language.code));
  }

  // ---------------------------------------------------------------------
  // Workshop profile
  // ---------------------------------------------------------------------

  /// [lat] and [lng] are a real fix off the phone, where the owner tapped
  /// "Use current location". They are what the customer app searches on —
  /// a workshop with an address but no pin is excluded by every radius
  /// filter in `nearby_garages()`, so it can be perfectly well registered
  /// and still turn up in nothing.
  ///
  /// The details are saved on the phone at once. What comes back is whether
  /// the map pin reached the server: null when it did (or there was no pin
  /// to send), otherwise a sentence to show. The pin used to fail in
  /// silence under a "Workshop details saved" toast, leaving the workshop
  /// off every "near me" search with nobody the wiser.
  ///
  /// [district] comes from the same location lookup as the pin; the
  /// platform files workshops by it.
  Future<String?> saveGarage(
    Garage garage, {
    double? lat,
    double? lng,
    String? district,
  }) async {
    _set(state.copyWith(garage: garage));
    unawaited(_store.markRegistered());
    // The workshop that was just filled in at setup is the one the backend
    // has been waiting for — join now rather than at the next sign-in.
    if (_remote.enabled && _remote.garageId == null) {
      await connectBackend();
    }
    return _pushLocation(lat, lng, district);
  }

  /// Sends the pin up once the garage row exists to hang it on.
  ///
  /// Deliberately after [connectBackend]: `set_garage_location` is keyed on
  /// a garage id, and at first setup there is not one until the console has
  /// joined. The address goes with it so the two can never disagree about
  /// where the workshop is.
  Future<String?> _pushLocation(
    double? lat,
    double? lng,
    String? district,
  ) async {
    if (lat == null || lng == null) return null;
    if (!_remote.enabled) return null;
    final gid = _remote.garageId;
    if (gid == null) {
      return 'The location will be sent once the console is online.';
    }
    final g = state.garage;
    return PlatformGateway.instance.setLocation(
      gid,
      lat: lat,
      lng: lng,
      addressLine: g?.addressLine,
      city: g?.city,
      district: district,
      state: g?.state,
      pin: g?.pin,
    );
  }

  void setSmsEnabled(bool v) => _set(state.copyWith(smsEnabled: v));
  void setWhatsappEnabled(bool v) => _set(state.copyWith(whatsappEnabled: v));
  void setReminderDays(int days) =>
      _set(state.copyWith(reminderDaysBefore: days.clamp(1, 30)));
  void setDefaultTaxRate(double rate) =>
      _set(state.copyWith(defaultTaxRate: rate.clamp(0, 0.5)));

  Staff addStaff({
    required String name,
    String phone = '',
    String skill = '',
    String designation = '',
    String remarks = '',
  }) {
    final s = Staff(
      id: newId('st'),
      name: name,
      phone: phone,
      skill: skill,
      designation: designation,
      remarks: remarks,
    );
    _set(state.copyWith(staff: [...state.staff, s]));
    return s;
  }

  void updateStaff(Staff staff) => _set(
    state.copyWith(
      staff: [
        for (final s in state.staff)
          if (s.id == staff.id) staff else s,
      ],
    ),
  );

  void removeStaff(String id) => _set(
    state.copyWith(staff: state.staff.where((s) => s.id != id).toList()),
  );

  // ---------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------

  /// How many rows the device keeps. The server holds the real register;
  /// this is only what the screens page through without a round trip.
  static const int _registerCap = 600;

  /// Pins the workshop's attendance location, or un-pins it with null.
  ///
  /// It rides on the garage row, so it syncs by the same path as the rest
  /// of the letterhead and lands on every phone in the shop.
  void setAttendanceSite(AttendanceSite? site) {
    final g = state.garage;
    if (g == null) return;
    _set(
      state.copyWith(
        garage: site == null
            ? g.copyWith(clearAttendanceSite: true)
            : g.copyWith(attendanceSite: site),
      ),
    );
  }

  /// Pulls the register down from the server, which is the only place it is
  /// authoritative. A failed fetch leaves what is on the device alone.
  Future<void> refreshAttendance() async {
    final rows = await _attendance.log();
    if (rows == null || !mounted) return;
    // Remote data: applied without echoing back, like any other row that
    // came down the wire.
    _setRemote(state.copyWith(attendance: rows));
  }

  /// Re-reads the whole workshop from the server, for a screen that offers
  /// pull-to-refresh.
  ///
  /// The console is realtime-first and this is the fallback for when that
  /// is not working. It was not working, and there was no fallback: on a
  /// project whose `garage_bookings` never made it onto the realtime
  /// publication (see `supabase/16_fix_realtime_publication.sql`) a booking
  /// reached the database instantly and the front desk only saw it after
  /// the app was force-stopped and relaunched. Four bookings were confirmed
  /// on a customer's phone and the counter showed one.
  ///
  /// Whatever the reason a channel goes quiet -- a dropped socket, a
  /// publication nobody ran the migration for, a phone that slept through
  /// the event -- the counter needs a way to ask again that does not
  /// involve restarting the app.
  ///
  /// Safe on a bad connection: [GarageGateway.hydrate] returns null when it
  /// cannot reach the server, and null leaves the console exactly as it is.
  Future<void> resync() async {
    final remote = await _remote.hydrate(state);
    if (remote != null && mounted) {
      _setRemote(remote);
      // Same reason as the restore path: anything this device is still
      // holding alone gets another go up the wire.
      _remote.push(state);
    }
    if (!mounted) return;
    await Future.wait([
      refreshNotifications(),
      refreshAttendance(),
      uploadPendingPhotos(),
    ]);
  }

  /// Everything the server refused on the last push, by step. The app
  /// shell shows a banner while this is not empty.
  ValueListenable<Map<String, String>> get syncIssues => _remote.syncIssues;

  /// The banner's Retry: push everything now.
  Future<void> retrySync() => _remote.pushNow(state);

  // ---------------------------------------------------------------------
  // The bell
  // ---------------------------------------------------------------------

  /// Ids the counter has already been shown a banner for, so a refetch
  /// does not announce the same booking twice.
  final Set<String> _announced = <String>{};

  /// False until the first fetch has been absorbed. That fetch is the
  /// console catching up, not fifty things happening.
  bool _feedPrimed = false;

  /// Re-reads the alert feed, and announces anything genuinely new.
  ///
  /// A null answer means the feed could not be reached, which leaves the
  /// cached one alone — the counter keeps seeing what it last saw instead
  /// of an empty bell that looks like "nothing happened".
  ///
  /// This used to fetch silently and leave announcing entirely to the
  /// realtime channel. That was fine while the channel worked. When it
  /// stopped — see `supabase/17_realtime_diagnose.sql` — the counter got
  /// no banner for anything, ever: a booking would appear in the list the
  /// next time somebody happened to look, with nothing to draw them to
  /// it. A workshop cannot run on a screen you have to remember to check.
  ///
  /// So the rule is now about the row, not about how it arrived: an
  /// unread alert this console has not announced before gets announced
  /// once, whichever path carried it. [_announced] is what stops a
  /// refetch from repeating itself, and [_feedPrimed] is what stops the
  /// backlog going off like an alarm on launch.
  Future<void> refreshNotifications() async {
    final rows = await _remote.notifications();
    if (rows == null || !mounted) return;
    _setRemote(state.copyWith(notifications: rows));

    if (!_feedPrimed) {
      // First look: learn what is already there, say nothing.
      _announced.addAll(rows.map((e) => e.id));
      _feedPrimed = true;
      return;
    }

    // Oldest first, so a burst arrives in the order it happened.
    final fresh = [
      for (final n in rows.reversed)
        if (!n.read && _announced.add(n.id)) n,
    ];
    if (_alerts.isClosed) return;
    for (final n in fresh) {
      _alerts.add(n);
    }
  }

  /// Marks [ids] read, or the whole feed when null.
  ///
  /// The badge clears locally first so opening the bell feels instant, and
  /// is put back if the round trip failed — an unread count that lies in
  /// the reassuring direction is the one way this feature does real harm.
  Future<void> markNotificationsRead([List<String>? ids]) async {
    final before = state.notifications;
    final target = ids?.toSet();
    final after = <GarageNotification>[];
    var changed = false;
    for (final n in before) {
      final touch = !n.read && (target == null || target.contains(n.id));
      if (touch) changed = true;
      after.add(touch ? n.copyWith(read: true) : n);
    }
    // Opening an already-read feed is the common case — the counter checks
    // the bell far more often than anything lands in it.
    if (!changed) return;
    _setRemote(state.copyWith(notifications: after));

    // With no backend there is nobody to tell, and the local change is the
    // whole of the truth.
    if (!_remote.enabled) return;
    final ok = await _remote.markNotificationsRead(ids);
    // Re-read rather than restoring `before`: an alert may have landed on
    // the channel while that round trip was in flight, and putting the old
    // list back would drop it from the cache to undo something else.
    if (!ok && mounted) unawaited(refreshNotifications());
  }

  /// Marks [who] in or out, if the phone can prove where it is.
  ///
  /// Two gates, deliberately not one. The device runs [AttendanceGate]
  /// first, because it is the only side that can see the mock-provider flag
  /// and ask a second provider for a cross-check — and because refusing on
  /// the phone costs no round trip. Then the backend runs its own checks on
  /// the submitted coordinates, and its answer is the one that is recorded:
  /// the client's verdict is advisory, the server's is the register.
  ///
  /// An attempt the phone caught as *abuse* — a mock provider, two
  /// providers disagreeing, a jump nothing could have travelled — is still
  /// sent upstream rather than dropped, so it lands in the register as a
  /// blocked attempt. Silently swallowing it on the device would mean the
  /// one thing the owner most needs to see never leaves the phone that did
  /// it.
  Future<PunchOutcome> punch({
    required Staff who,
    required PunchKind kind,
  }) async {
    final site = state.attendanceSite;
    final previous = Shift.lastAccepted(state.attendance, who.id);
    final reading = await AttendanceGate.read(site: site, previous: previous);

    if (!reading.ok && !reading.block.isAbuse) {
      return (
        block: reading.block,
        message: AttendanceGate.explain(
          reading.block,
          site: site,
          reading: reading,
        ),
        reading: reading,
        verified: false,
      );
    }

    final result = await _attendance.punch(
      staffId: who.id,
      staffName: who.name,
      kind: kind,
      lat: reading.lat,
      lng: reading.lng,
      accuracyM: reading.accuracyM,
      distanceM: reading.distanceM,
      mocked: reading.mocked,
      fixAt: reading.fixAt,
      note: reading.note,
    );

    // The backend answered, whichever way. Its row is the record.
    if (result.punch != null) {
      _mergePunch(result.punch!);
      return (
        block: result.block,
        message: result.message.isNotEmpty
            ? result.message
            : AttendanceGate.explain(
                result.block,
                site: site,
                reading: reading,
              ),
        reading: reading,
        verified: true,
      );
    }

    // Nothing upstream to ask. The punch is recorded on the device and
    // marked unverified, which the register shows rather than hides — an
    // unchecked punch that looks identical to a checked one is worse than
    // no punch at all.
    final local = AttendancePunch(
      id: newId('at'),
      staffId: who.id,
      staffName: who.name,
      kind: kind,
      at: DateTime.now(),
      lat: reading.lat,
      lng: reading.lng,
      accuracyM: reading.accuracyM,
      distanceM: reading.distanceM,
      mocked: reading.mocked,
      accepted: reading.ok,
      block: reading.block,
      verified: false,
      note: reading.note,
    );
    _mergePunch(local);
    return (
      block: reading.ok ? PunchBlock.offline : reading.block,
      message: result.message.isNotEmpty
          ? result.message
          : AttendanceGate.explain(reading.block, site: site, reading: reading),
      reading: reading,
      verified: false,
    );
  }

  /// Adds a row, replacing any earlier copy of the same id, newest first.
  void _mergePunch(AttendancePunch p) {
    final rest = state.attendance.where((e) => e.id != p.id);
    final next = [p, ...rest]..sort((a, b) => b.at.compareTo(a.at));
    _set(
      state.copyWith(
        attendance: next.length > _registerCap
            ? next.sublist(0, _registerCap)
            : next,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Customers and vehicles
  // ---------------------------------------------------------------------

  /// Find by phone or create. Keeps one customer record per number so a
  /// returning car lands on the same history.
  Customer upsertCustomer({
    required String name,
    required String phone,
    String altPhone = '',
    String email = '',
    String address = '',
    String gstin = '',
  }) {
    final existing = state.customerByPhone(phone);
    if (existing != null) {
      final merged = existing.copyWith(
        name: name.trim().isEmpty ? existing.name : name.trim(),
        altPhone: altPhone.isEmpty ? existing.altPhone : altPhone,
        email: email.isEmpty ? existing.email : email,
        address: address.isEmpty ? existing.address : address,
        gstin: gstin.trim().isEmpty
            ? existing.gstin
            : gstin.trim().toUpperCase(),
      );
      _set(
        state.copyWith(
          customers: [
            for (final c in state.customers)
              if (c.id == merged.id) merged else c,
          ],
        ),
      );
      return merged;
    }
    final created = Customer(
      id: newId('c'),
      name: name.trim(),
      phone: phone.trim(),
      altPhone: altPhone,
      email: email,
      address: address,
      gstin: gstin.trim().toUpperCase(),
      createdAt: DateTime.now(),
    );
    _set(state.copyWith(customers: [...state.customers, created]));
    return created;
  }

  void updateCustomer(Customer c) => _set(
    state.copyWith(
      customers: [
        for (final e in state.customers)
          if (e.id == c.id) c else e,
      ],
    ),
  );

  /// Find by registration or create against the given customer.
  Vehicle upsertVehicle({
    required String customerId,
    required String regNo,
    required String brand,
    required String model,
    String variant = '',
    FuelType fuel = FuelType.petrol,
    Transmission? transmission,
    VehicleShape? shape,
    int? year,
    String colour = '',
    String insurer = '',
    String policyNo = '',
    DateTime? insuranceExpiry,
    DateTime? insuranceFrom,
    String insurerAddress = '',
    String insurerGstin = '',
  }) {
    final existing = state.vehicleByReg(regNo);
    if (existing != null) {
      final merged = existing.copyWith(
        brand: brand.trim().isEmpty ? existing.brand : brand.trim(),
        model: model.trim().isEmpty ? existing.model : model.trim(),
        variant: variant.isEmpty ? existing.variant : variant,
        fuel: fuel,
        transmission: transmission,
        // Null means the caller had nothing to say about the body, which is
        // not the same as saying it is a car — keep what is on record.
        shape: shape ?? existing.shape,
        year: year ?? existing.year,
        colour: colour.isEmpty ? existing.colour : colour,
        insurer: insurer.trim().isEmpty ? existing.insurer : insurer.trim(),
        policyNo:
            policyNo.trim().isEmpty ? existing.policyNo : policyNo.trim(),
        insuranceExpiry: insuranceExpiry ?? existing.insuranceExpiry,
        insuranceFrom: insuranceFrom ?? existing.insuranceFrom,
        insurerAddress: insurerAddress.trim().isEmpty
            ? existing.insurerAddress
            : insurerAddress.trim(),
        insurerGstin: insurerGstin.trim().isEmpty
            ? existing.insurerGstin
            : insurerGstin.trim().toUpperCase(),
      );
      _set(
        state.copyWith(
          vehicles: [
            for (final v in state.vehicles)
              if (v.id == merged.id) merged else v,
          ],
        ),
      );
      return merged;
    }
    final created = Vehicle(
      id: newId('v'),
      customerId: customerId,
      regNo: regNo.trim().toUpperCase(),
      brand: brand.trim(),
      model: model.trim(),
      variant: variant.trim(),
      fuel: fuel,
      transmission: transmission,
      shape: shape ?? VehicleShape.fourWheeler,
      year: year,
      colour: colour,
      insurer: insurer.trim(),
      policyNo: policyNo.trim(),
      insuranceExpiry: insuranceExpiry,
      insuranceFrom: insuranceFrom,
      insurerAddress: insurerAddress.trim(),
      insurerGstin: insurerGstin.trim().toUpperCase(),
    );
    _set(state.copyWith(vehicles: [...state.vehicles, created]));
    return created;
  }

  void updateVehicle(Vehicle v) => _set(
    state.copyWith(
      vehicles: [
        for (final e in state.vehicles)
          if (e.id == v.id) v else e,
      ],
    ),
  );

  // ---------------------------------------------------------------------
  // Job card lifecycle
  // ---------------------------------------------------------------------

  /// Open a job card. The number is minted here, once.
  JobCard createJobCard({
    required String customerId,
    required String vehicleId,
    int odometerKm = 0,
    int fuelPercent = 0,
    DateTime? promisedAt,
    List<String> voices = const [],
    List<String> accessories = const [],
    List<String> mechanicIds = const [],
    String workNote = '',
    bool? sms,
  }) {
    final now = DateTime.now();
    final seq = state.seq + 1;
    final texting = sms ?? state.smsEnabled;
    final card = JobCard(
      id: newId('j'),
      number: Seed.numberFor(now, seq),
      customerId: customerId,
      vehicleId: vehicleId,
      createdAt: now,
      promisedAt: promisedAt,
      odometerKm: odometerKm,
      fuelPercent: fuelPercent,
      voices: voices,
      accessories: accessories,
      mechanicIds: mechanicIds,
      workNote: workNote,
      taxRate: state.defaultTaxRate,
      sms: [
        SmsEvent(
          id: newId('s'),
          label: 'Job card created'.tr,
          at: now,
          state: texting ? SmsState.scheduled : SmsState.skipped,
        ),
      ],
    );
    _set(state.copyWith(jobCards: [card, ...state.jobCards], seq: seq));
    return card;
  }

  /// Move a card from Open to Complete. Refused while the bill is empty —
  /// there is nothing to hand the customer.
  ///
  /// [at] is the date the counter picked on the Complete sheet; it used to
  /// be asked for and then ignored in favour of the current moment. [sms]
  /// is this card's choice and leaves the workshop-wide setting alone.
  bool markComplete(String id, {DateTime? at, bool? sms}) {
    final card = _find(id);
    if (card == null || !card.canComplete) return false;
    final now = at ?? DateTime.now();
    final texting = sms ?? state.smsEnabled;
    _put(
      card.copyWith(
        status: JobStatus.complete,
        completedAt: now,
        items: [
          // Anything still untouched is treated as done at completion.
          for (final li in card.items)
            li.state == WorkState.skipped
                ? li
                : li.copyWith(state: WorkState.done),
        ],
        sms: [
          ...card.sms,
          SmsEvent(
            id: newId('s'),
            label: 'Work complete'.tr,
            at: now,
            state: texting ? SmsState.scheduled : SmsState.skipped,
          ),
        ],
      ),
    );
    return true;
  }

  /// Close a card and schedule the reminder trail. A balance may be carried —
  /// it stays visible under Pending Balance until it is collected.
  bool closeJobCard(
    String id, {
    DateTime? nextServiceAt,
    int? nextServiceKm,
    bool? sms,
  }) {
    final card = _find(id);
    if (card == null || !card.canClose) return false;
    final now = DateTime.now();
    final due = nextServiceAt ?? now.add(const Duration(days: 180));
    final gap = state.reminderDaysBefore;
    final texting = sms ?? state.smsEnabled;

    SmsEvent reminder(int n, Duration before) => SmsEvent(
      id: newId('s'),
      label: 'Service reminder {0}'.trf([n]),
      at: DateTime(due.year, due.month, due.day, 8).subtract(before),
      state: texting ? SmsState.scheduled : SmsState.skipped,
    );

    _put(
      card.copyWith(
        status: JobStatus.closed,
        closedAt: now,
        nextServiceAt: due,
        nextServiceKm: nextServiceKm ?? (card.odometerKm + 5000),
        sms: [
          ...card.sms,
          SmsEvent(
            id: newId('s'),
            label: 'Invoice closed'.tr,
            at: now,
            state: texting ? SmsState.scheduled : SmsState.skipped,
          ),
          reminder(1, Duration(days: gap)),
          reminder(2, Duration.zero),
          reminder(3, Duration(days: -gap)),
        ],
      ),
    );
    return true;
  }

  /// Send a card back to the floor. Reminders that have not gone out yet are
  /// dropped so a reopened card cannot nag the customer.
  void reopenJobCard(String id) {
    final card = _find(id);
    if (card == null || card.isOpen) return;
    // Everything not yet sent goes — the reminders, and the "ready" and
    // "invoice closed" notices that are no longer true — except the check-in
    // notice, which is always first and is still true.
    _put(
      card.copyWith(
        status: JobStatus.open,
        sms: [
          for (var i = 0; i < card.sms.length; i++)
            if (i == 0 || card.sms[i].state != SmsState.scheduled) card.sms[i],
        ],
      ),
    );
  }

  /// Records that a message in the card's trail was handed to the phone's
  /// SMS app to send. The counter taps Send; the phone sends it. That is the
  /// only way a message leaves this app: there is no SMS gateway behind it.
  void markSmsSent(String cardId, String smsId) {
    final card = _find(cardId);
    if (card == null) return;
    _put(
      card.copyWith(
        sms: [
          for (final e in card.sms)
            if (e.id == smsId)
              SmsEvent(
                id: e.id,
                label: e.label,
                at: e.at,
                state: SmsState.delivered,
              )
            else
              e,
        ],
      ),
    );
  }

  void deleteJobCard(String id) {
    final card = _find(id);
    if (card == null) return;
    // Returning the card returns its parts to the shelf.
    for (final li in card.items) {
      _moveStock(li.masterId, li.qty);
    }
    _set(
      state.copyWith(
        jobCards: state.jobCards.where((j) => j.id != id).toList(),
        // And its money comes out of the day book. It used to stay, so the
        // drawer (and Bank & Cash) went on counting payments for a card
        // that no longer existed.
        cashBook: state.cashBook.where((e) => e.jobCardId != id).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Job card contents
  // ---------------------------------------------------------------------

  void setVoices(String id, List<String> voices) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(voices: voices));
  }

  void setAccessories(String id, List<String> accessories) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(accessories: accessories));
  }

  void setWorkNote(String id, String note) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(workNote: note));
  }

  void setMechanics(String id, List<String> mechanicIds) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(mechanicIds: mechanicIds));
  }

  void setOdometer(String id, {int? km, int? fuelPercent}) {
    final card = _find(id);
    if (card == null) return;
    _put(
      card.copyWith(
        odometerKm: km ?? card.odometerKm,
        fuelPercent: fuelPercent == null
            ? card.fuelPercent
            : fuelPercent.clamp(0, 100),
      ),
    );
  }

  void setPromisedAt(String id, DateTime? at) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(promisedAt: at));
  }

  /// Replace the whole set at once. The dent sheet works on a copy and only
  /// writes back when it is kept, so the discard button really does discard.
  void setDents(String id, List<DentMark> marks) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(dents: [...marks]));
  }

  void addDent(String id, DentMark mark) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(dents: [...card.dents, mark]));
  }

  void updateDent(String id, DentMark mark) {
    final card = _find(id);
    if (card == null) return;
    _put(
      card.copyWith(
        dents: [
          for (final d in card.dents)
            if (d.id == mark.id) mark else d,
        ],
      ),
    );
  }

  void removeDent(String id, String dentId) {
    final card = _find(id);
    if (card == null) return;
    _put(
      card.copyWith(dents: card.dents.where((d) => d.id != dentId).toList()),
    );
  }

  /// Pins photos to a card, then sends them to storage.
  ///
  /// The card shows them at once from the phone's own files; each is swapped
  /// for its storage URL as its upload finishes, so every other phone, the
  /// PDF and the customer can see it. One that cannot go up now (offline)
  /// stays local and is tried again on the next resync.
  void addPhotos(String id, List<String> paths) {
    final card = _find(id);
    if (card == null || paths.isEmpty) return;
    _put(card.copyWith(photos: [...card.photos, ...paths]));
    unawaited(_uploadPhotos(id, paths));
  }

  static bool _isUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  Future<void> _uploadPhotos(String cardId, List<String> paths) async {
    if (!_remote.enabled) return;
    for (final local in paths) {
      if (_isUrl(local)) continue;
      final url = await _remote.uploadPhoto(cardId, local);
      if (url == null || !mounted) continue;
      final card = _find(cardId);
      if (card == null) return;
      _put(
        card.copyWith(
          photos: [for (final p in card.photos) p == local ? url : p],
        ),
      );
    }
  }

  /// Uploads any photo still held only as a file on this phone. A file that
  /// is not on this phone (taken on another one) is simply skipped.
  Future<void> uploadPendingPhotos() async {
    for (final card in [...state.jobCards]) {
      final local = [
        for (final p in card.photos)
          if (!_isUrl(p)) p,
      ];
      if (local.isNotEmpty) await _uploadPhotos(card.id, local);
    }
  }

  void removePhoto(String id, String path) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(photos: card.photos.where((p) => p != path).toList()));
  }

  // ---------------------------------------------------------------------
  // Billing lines
  // ---------------------------------------------------------------------

  /// Put a row on the card. Passing [master] issues the part from stock.
  LineItem? addItem(
    String id, {
    required LineKind kind,
    required String name,
    String partNo = '',
    double qty = 1,
    double rate = 0,
    String? mechanicId,
    MasterItem? master,
    double? gstRate,
    String unit = '',
  }) {
    final card = _find(id);
    if (card == null || card.isClosed) return null;
    final line = LineItem(
      id: newId('li'),
      kind: kind,
      name: name.trim(),
      partNo: partNo.trim().isEmpty ? (master?.partNo ?? '') : partNo.trim(),
      qty: qty <= 0 ? 1 : qty,
      rate: rate,
      mechanicId:
          mechanicId ??
          (card.mechanicIds.isEmpty ? null : card.mechanicIds.first),
      masterId: master?.id,
      gstRate: gstRate,
      // A stocked part bills in the unit it is counted out in.
      unit: unit.isNotEmpty ? unit : (master?.unit ?? ''),
    );
    _put(card.copyWith(items: [...card.items, line]));
    _moveStock(line.masterId, -line.qty);
    return line;
  }

  /// Edit a row. A quantity change moves the difference in or out of stock.
  void updateItem(String id, LineItem line) {
    final card = _find(id);
    if (card == null || card.isClosed) return;
    final before = card.items.firstWhere(
      (e) => e.id == line.id,
      orElse: () => line,
    );
    _put(
      card.copyWith(
        items: [
          for (final e in card.items)
            if (e.id == line.id) line else e,
        ],
      ),
    );
    if (before.masterId == line.masterId) {
      _moveStock(line.masterId, before.qty - line.qty);
    } else {
      _moveStock(before.masterId, before.qty);
      _moveStock(line.masterId, -line.qty);
    }
  }

  void removeItem(String id, String lineId) {
    final card = _find(id);
    if (card == null || card.isClosed) return;
    LineItem? removed;
    for (final e in card.items) {
      if (e.id == lineId) removed = e;
    }
    if (removed == null) return;
    _put(
      card.copyWith(items: card.items.where((e) => e.id != lineId).toList()),
    );
    _moveStock(removed.masterId, removed.qty);
  }

  void setLineState(String id, String lineId, WorkState work) {
    final card = _find(id);
    if (card == null) return;
    _put(
      card.copyWith(
        items: [
          for (final e in card.items)
            if (e.id == lineId) e.copyWith(state: work) else e,
        ],
      ),
    );
  }

  void setLineMechanic(String id, String lineId, String? mechanicId) {
    final card = _find(id);
    if (card == null) return;
    _put(
      card.copyWith(
        items: [
          for (final e in card.items)
            if (e.id == lineId)
              e.copyWith(
                mechanicId: mechanicId,
                clearMechanic: mechanicId == null,
              )
            else
              e,
        ],
      ),
    );
  }

  void setLineRemark(String id, String lineId, String remark) {
    final card = _find(id);
    if (card == null) return;
    _put(
      card.copyWith(
        items: [
          for (final e in card.items)
            if (e.id == lineId) e.copyWith(remark: remark) else e,
        ],
      ),
    );
  }

  void setDiscount(String id, double value) {
    final card = _find(id);
    if (card == null || card.isClosed) return;
    _put(card.copyWith(discount: value.clamp(0, card.subTotal)));
  }

  void setTaxRate(String id, double rate) {
    final card = _find(id);
    if (card == null || card.isClosed) return;
    _put(card.copyWith(taxRate: rate.clamp(0, 0.5)));
  }

  void markEstimateSent(String id) {
    final card = _find(id);
    if (card == null) return;
    final now = DateTime.now();
    _put(
      card.copyWith(
        estimateSentAt: now,
        sms: [
          ...card.sms,
          SmsEvent(
            id: newId('s'),
            label: 'Estimate shared'.tr,
            at: now,
            state: state.smsEnabled ? SmsState.delivered : SmsState.skipped,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Money in
  // ---------------------------------------------------------------------

  /// Collect against a card. Never takes more than the outstanding balance,
  /// and every rupee collected also lands in the day book, because the
  /// CashBook screen is meant to be the whole day's cash, not a second ledger
  /// somebody has to keep by hand.
  /// Takes money against a card.
  ///
  /// An ordinary payment stops at the balance. An [advance] is taken in full
  /// whatever the bill says so far: it used to be cut to the balance too, so
  /// an advance on a card with no lines yet was dropped entirely — the cash
  /// was in the drawer and nowhere in the books. Whatever it comes to beyond
  /// the final bill shows as [JobCard.excess], owed back to the customer.
  void addPayment(
    String id, {
    required double amount,
    required PayMode mode,
    String note = '',
    bool advance = false,
    String? accountId,
  }) {
    final card = _find(id);
    if (card == null || amount <= 0) return;
    final take = advance || amount <= card.balance ? amount : card.balance;
    if (take <= 0) return;
    final now = DateTime.now();
    final paymentId = newId(advance ? 'adv' : 'p');
    _put(
      card.copyWith(
        payments: [
          ...card.payments,
          Payment(
            id: paymentId,
            amount: money(take),
            mode: mode,
            at: now,
            note: note,
          ),
        ],
      ),
    );
    final customer = state.customerById(card.customerId);
    _set(
      state.copyWith(
        cashBook: [
          ...state.cashBook,
          CashEntry(
            // Named after the payment, so taking the payment back can find
            // the drawer entry it made (see [removePayment]).
            id: 'cb-$paymentId',
            party: customer?.name ?? card.number,
            amount: money(take),
            at: now,
            inward: true,
            reason: note.isEmpty ? 'Jobcard Payment' : note,
            mode: mode,
            jobCardId: card.id,
            accountId: accountId,
          ),
        ],
      ),
    );
  }

  /// Takes a payment off a card, and the cash-book entry it made with it.
  ///
  /// The entry used to be looked for by the payment's own id, which it never
  /// had — it was minted its own — so nothing matched: the bill reopened and
  /// the day book went on counting money the workshop no longer had. Entries
  /// made since carry `cb-<payment id>`; older ones are matched on the card,
  /// the amount and the moment, which is how they were written.
  void removePayment(String id, String paymentId) {
    final card = _find(id);
    if (card == null) return;
    Payment? payment;
    for (final p in card.payments) {
      if (p.id == paymentId) payment = p;
    }
    _put(
      card.copyWith(
        payments: card.payments.where((p) => p.id != paymentId).toList(),
      ),
    );

    String? drawer;
    for (final e in state.cashBook) {
      final legacy = payment != null &&
          e.inward &&
          e.jobCardId == card.id &&
          e.amount == payment.amount &&
          e.at.isAtSameMomentAs(payment.at);
      if (e.id == 'cb-$paymentId' || legacy) {
        drawer = e.id;
        break;
      }
    }
    if (drawer == null) return;
    _set(
      state.copyWith(
        cashBook: state.cashBook.where((e) => e.id != drawer).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Masters and stock
  // ---------------------------------------------------------------------

  MasterItem addMaster({
    required LineKind kind,
    required String name,
    String partNo = '',
    double rate = 0,
    double cost = 0,
    double stock = 0,
    String unit = 'nos',
    double lowAt = 2,
    String make = '',
    String rack = '',
    PartGroup group = PartGroup.running,
    bool outsourced = false,
    List<String> fits = const <String>[],
  }) {
    final m = MasterItem(
      id: newId('m'),
      kind: kind,
      name: name.trim(),
      partNo: partNo.trim(),
      rate: rate,
      cost: cost,
      stock: stock,
      unit: unit,
      lowAt: lowAt,
      make: make.trim(),
      rack: rack.trim(),
      group: group,
      outsourced: outsourced,
      fits: fits,
    );
    _set(state.copyWith(masters: [...state.masters, m]));
    return m;
  }

  void updateMaster(MasterItem m) => _set(
    state.copyWith(
      masters: [
        for (final e in state.masters)
          if (e.id == m.id) m else e,
      ],
    ),
  );

  void removeMaster(String id) => _set(
    state.copyWith(masters: state.masters.where((m) => m.id != id).toList()),
  );

  /// Receive stock into the store.
  void restock(String masterId, double qty) => _moveStock(masterId, qty);

  void _moveStock(String? masterId, double delta) {
    if (masterId == null || delta == 0) return;
    final m = state.masterById(masterId);
    if (m == null || !m.tracksStock) return;
    _set(
      state.copyWith(
        masters: [
          for (final e in state.masters)
            if (e.id == masterId)
              e.copyWith(stock: (e.stock + delta).clamp(0, double.infinity))
            else
              e,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Bookings and feedback
  // ---------------------------------------------------------------------

  void acceptBooking(String bookingId, {String? jobCardId}) => _set(
    state.copyWith(
      bookings: [
        for (final b in state.bookings)
          if (b.id == bookingId)
            b.copyWith(accepted: true, jobCardId: jobCardId)
          else
            b,
      ],
    ),
  );

  void removeBooking(String bookingId) => _set(
    state.copyWith(
      bookings: state.bookings.where((b) => b.id != bookingId).toList(),
    ),
  );

  void addBooking(Booking booking) =>
      _set(state.copyWith(bookings: [...state.bookings, booking]));

  // ---------------------------------------------------------------------
  // Expenses
  // ---------------------------------------------------------------------

  Expense addExpense({
    required String title,
    required double amount,
    String category = 'General',
    String supplier = '',
    double paid = 0,
    String note = '',
    DateTime? at,
    PayMode mode = PayMode.cash,
  }) {
    final when = at ?? DateTime.now();
    final e = Expense(
      id: newId('ex'),
      title: title.trim(),
      amount: money(amount),
      at: when,
      category: category,
      supplier: supplier.trim(),
      paid: money(paid.clamp(0, amount)),
      note: note.trim(),
      mode: mode,
    );
    _set(state.copyWith(expenses: [...state.expenses, e]));
    // Money actually handed over is money out of the drawer — or out of the
    // bank, when it went online.
    if (e.paid > 0) {
      addCash(
        party: e.supplier.isEmpty ? e.title : e.supplier,
        amount: e.paid,
        inward: false,
        reason: e.category,
        mode: mode,
        at: when,
      );
    }
    return e;
  }

  void updateExpense(Expense e) => _set(
    state.copyWith(
      expenses: [
        for (final x in state.expenses)
          if (x.id == e.id) e else x,
      ],
    ),
  );

  void removeExpense(String id) => _set(
    state.copyWith(expenses: state.expenses.where((e) => e.id != id).toList()),
  );

  // ---------------------------------------------------------------------
  // Cash book
  // ---------------------------------------------------------------------

  CashEntry addCash({
    required String party,
    required double amount,
    required bool inward,
    String reason = '',
    PayMode mode = PayMode.cash,
    DateTime? at,
    String? accountId,
    String? id,
  }) {
    final e = CashEntry(
      id: id ?? newId('cb'),
      party: party.trim(),
      amount: money(amount),
      at: at ?? DateTime.now(),
      inward: inward,
      reason: reason.trim(),
      mode: mode,
      accountId: accountId,
    );
    _set(state.copyWith(cashBook: [...state.cashBook, e]));
    return e;
  }

  void removeCash(String id) => _set(
    state.copyWith(cashBook: state.cashBook.where((e) => e.id != id).toList()),
  );

  // ---------------------------------------------------------------------
  // Suppliers
  // ---------------------------------------------------------------------

  Supplier addSupplier({
    required String name,
    String phone = '',
    String address = '',
    String gstin = '',
  }) {
    final s = Supplier(
      id: newId('sup'),
      name: name.trim(),
      phone: phone.trim(),
      address: address.trim(),
      gstin: gstin.trim(),
    );
    _set(state.copyWith(suppliers: [...state.suppliers, s]));
    return s;
  }

  void updateSupplier(Supplier s) => _set(
    state.copyWith(
      suppliers: [
        for (final e in state.suppliers)
          if (e.id == s.id) s else e,
      ],
    ),
  );

  void removeSupplier(String id) => _set(
    state.copyWith(
      suppliers: state.suppliers.where((e) => e.id != id).toList(),
    ),
  );

  // ---------------------------------------------------------------------
  // Counter sales — spares sold with no job card behind them
  // ---------------------------------------------------------------------

  CounterSale addCounterSale({
    required String customer,
    required List<LineItem> items,
    String phone = '',
    double paid = 0,
  }) {
    final seq = state.seq + 1;
    final sale = CounterSale(
      id: newId('cs'),
      number: 'CS-${seq.toString().padLeft(4, '0')}',
      customer: customer.trim(),
      at: DateTime.now(),
      phone: phone.trim(),
      items: items,
      paid: money(paid),
    );
    for (final li in items) {
      _moveStock(li.masterId, -li.qty);
    }
    _set(state.copyWith(counterSales: [...state.counterSales, sale], seq: seq));
    if (sale.paid > 0) {
      addCash(
        party: sale.customer,
        amount: sale.paid,
        inward: true,
        reason: 'Counter Sale ${sale.number}',
      );
    }
    return sale;
  }

  /// Deletes a counter sale and undoes what it did: the parts go back on
  /// the shelf and the money it put in the day book comes out. It used to
  /// drop the sale alone, so the stock stayed short and the drawer stayed
  /// long by exactly that sale.
  void removeCounterSale(String id) {
    CounterSale? sale;
    for (final e in state.counterSales) {
      if (e.id == id) sale = e;
    }
    if (sale == null) return;
    for (final li in sale.items) {
      _moveStock(li.masterId, li.qty);
    }
    final reason = 'Counter Sale ${sale.number}';
    String? drawer;
    for (final e in state.cashBook) {
      if (e.inward && e.reason == reason && e.amount == sale.paid) {
        drawer = e.id;
        break;
      }
    }
    _set(
      state.copyWith(
        counterSales: state.counterSales.where((e) => e.id != id).toList(),
        cashBook: drawer == null
            ? null
            : state.cashBook.where((e) => e.id != drawer).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Purchase orders
  // ---------------------------------------------------------------------

  PurchaseOrder addPurchaseOrder({
    required String supplierId,
    required List<LineItem> items,
    String note = '',
  }) {
    final seq = state.seq + 1;
    final order = PurchaseOrder(
      id: newId('po'),
      number: 'PO-${seq.toString().padLeft(4, '0')}',
      supplierId: supplierId,
      at: DateTime.now(),
      items: items,
      note: note.trim(),
    );
    _set(
      state.copyWith(
        purchaseOrders: [...state.purchaseOrders, order],
        seq: seq,
      ),
    );
    return order;
  }

  /// Receiving is what puts the parts on the shelf — an order on its own
  /// changes nothing, so a promise can never be counted as stock.
  void receivePurchaseOrder(String id) {
    final order = state.purchaseOrders.firstWhereOrNull((e) => e.id == id);
    if (order == null || order.received) return;
    for (final li in order.items) {
      _moveStock(li.masterId, li.qty);
    }
    _set(
      state.copyWith(
        purchaseOrders: [
          for (final e in state.purchaseOrders)
            if (e.id == id)
              e.copyWith(received: true, receivedAt: DateTime.now())
            else
              e,
        ],
      ),
    );
  }

  void removePurchaseOrder(String id) => _set(
    state.copyWith(
      purchaseOrders: state.purchaseOrders.where((e) => e.id != id).toList(),
    ),
  );

  // ---------------------------------------------------------------------
  // Bank accounts and cash in hand
  // ---------------------------------------------------------------------

  /// Adds or replaces an account. Marking one primary unmarks the rest, so
  /// "where does UPI money go" always has exactly one answer.
  void saveAccount(BankAccount a) {
    final list = [
      for (final e in state.bankAccounts)
        if (e.id != a.id) a.primary ? e.copyWith(primary: false) : e,
      a,
    ];
    // The first bank is the primary one until somebody says otherwise.
    final banks = list.where((e) => !e.cash).toList();
    if (banks.isNotEmpty && !banks.any((e) => e.primary)) {
      final i = list.indexWhere((e) => e.id == banks.first.id);
      list[i] = list[i].copyWith(primary: true);
    }
    _set(state.copyWith(bankAccounts: list));
  }

  BankAccount addBank({
    required String name,
    String holder = '',
    String accountNo = '',
    String ifsc = '',
    String branch = '',
    String upiId = '',
    double opening = 0,
    DateTime? openingAt,
    bool printOnInvoice = false,
    bool printUpiQr = false,
    bool primary = false,
  }) {
    final a = BankAccount(
      id: newId('ba'),
      name: name.trim(),
      holder: holder.trim(),
      accountNo: accountNo.trim(),
      ifsc: ifsc.trim().toUpperCase(),
      branch: branch.trim(),
      upiId: upiId.trim(),
      opening: money(opening),
      openingAt: openingAt ?? DateTime.now(),
      printOnInvoice: printOnInvoice,
      printUpiQr: printUpiQr,
      primary: primary,
    );
    saveAccount(a);
    return a;
  }

  /// The drawer's opening balance, and the day it was counted.
  void setCashOpening(double amount, DateTime at) => saveAccount(
    state.cashAccount.copyWith(opening: money(amount), openingAt: at),
  );

  void removeAccount(String id) {
    if (id == kCashAccountId) return;
    _set(
      state.copyWith(
        bankAccounts: state.bankAccounts.where((e) => e.id != id).toList(),
        // Lines that named it fall back to their mode rather than vanish.
        cashBook: [
          for (final e in state.cashBook)
            if (e.accountId == id)
              CashEntry(
                id: e.id,
                party: e.party,
                amount: e.amount,
                at: e.at,
                inward: e.inward,
                reason: e.reason,
                mode: e.mode,
                jobCardId: e.jobCardId,
              )
            else
              e,
        ],
      ),
    );
  }

  /// Moves money between two accounts — cash banked, cash withdrawn. Two
  /// lines in the day book, one out of [fromId] and one into [toId].
  void transferFunds({
    required String fromId,
    required String toId,
    required double amount,
    DateTime? at,
    String note = '',
  }) {
    if (fromId == toId || amount <= 0) return;
    final from = state.accountById(fromId);
    final to = state.accountById(toId);
    if (from == null || to == null) return;
    final when = at ?? DateTime.now();
    final tag = newId('tr');
    final reason = note.trim().isEmpty ? 'Transfer' : note.trim();
    addCash(
      id: '$tag-out',
      party: to.title,
      amount: amount,
      inward: false,
      reason: reason,
      mode: from.cash ? PayMode.cash : PayMode.netbanking,
      accountId: fromId,
      at: when,
    );
    addCash(
      id: '$tag-in',
      party: from.title,
      amount: amount,
      inward: true,
      reason: reason,
      mode: to.cash ? PayMode.cash : PayMode.netbanking,
      accountId: toId,
      at: when,
    );
  }

  // ---------------------------------------------------------------------
  // Sales and purchase documents
  // ---------------------------------------------------------------------

  /// The next number for a kind of document — `PB-0007`.
  String nextTradeNumber(TradeKind kind) {
    var n = state.tradeDocs.where((d) => d.kind == kind).length + 1;
    String fmt(int v) => '${kind.prefix}-${v.toString().padLeft(4, '0')}';
    // A deleted document leaves a gap in the count, not a free number.
    while (state.tradeDocs.any((d) => d.number == fmt(n))) {
      n++;
    }
    return fmt(n);
  }

  /// Records a sale return, sale order, purchase bill or purchase return,
  /// and everything it does to the rest of the books:
  ///
  /// * stock moves for every stocked line (none for an order);
  /// * money settled on it enters the day book, in or out;
  /// * what is left unpaid on a purchase bill is owed to the supplier, and
  ///   a purchase return takes its unrefunded value off that debt.
  TradeDoc addTradeDoc({
    required TradeKind kind,
    required List<TradeLine> lines,
    String party = '',
    String phone = '',
    String gstin = '',
    String address = '',
    String? supplierId,
    String? customerId,
    TaxSplit split = TaxSplit.intra,
    double discount = 0,
    double paid = 0,
    PayMode mode = PayMode.cash,
    String? accountId,
    String note = '',
    String refNo = '',
    DateTime? at,
    DateTime? dueAt,
  }) {
    final supplier = state.supplierById(supplierId);
    String pick(String typed, String? fallback) =>
        typed.trim().isEmpty ? (fallback ?? '') : typed.trim();
    final draft = TradeDoc(
      id: newId('td'),
      kind: kind,
      number: nextTradeNumber(kind),
      at: at ?? DateTime.now(),
      party: pick(party, supplier?.name),
      phone: pick(phone, supplier?.phone),
      gstin: pick(gstin, supplier?.gstin),
      address: pick(address, supplier?.address),
      supplierId: supplierId,
      customerId: customerId,
      lines: lines,
      split: split,
      discount: money(discount),
      mode: mode,
      accountId: accountId,
      note: note.trim(),
      refNo: refNo.trim(),
      dueAt: dueAt,
    );
    final settled = money(paid.clamp(0, draft.total));
    final doc = draft.copyWith(paid: settled);

    for (final l in lines) {
      _moveStock(l.masterId, l.qty * kind.stockSign);
    }
    _set(state.copyWith(tradeDocs: [...state.tradeDocs, doc]));
    if (settled > 0) {
      addCash(
        id: 'cb-${doc.id}',
        party: doc.party.isEmpty ? doc.number : doc.party,
        amount: settled,
        inward: kind.moneyIn,
        reason: doc.number,
        mode: mode,
        accountId: accountId,
        at: doc.at,
      );
    }
    _owe(supplierId, _debtOf(doc));
    return doc;
  }

  /// What a document adds to the supplier's account: a bill's unpaid part
  /// is owed, a return's unrefunded part is knocked off.
  double _debtOf(TradeDoc d) => switch (d.kind) {
    TradeKind.purchaseBill => d.balance,
    TradeKind.purchaseReturn => -d.balance,
    _ => 0,
  };

  void _owe(String? supplierId, double delta) {
    final s = state.supplierById(supplierId);
    if (s == null || delta == 0) return;
    updateSupplier(
      s.copyWith(
        outstanding: money((s.outstanding + delta).clamp(0, double.infinity)),
      ),
    );
  }

  /// Settles more of a document after the fact.
  void settleTradeDoc(
    String id, {
    required double amount,
    required PayMode mode,
    String? accountId,
  }) {
    final d = state.tradeDocs.firstWhereOrNull((e) => e.id == id);
    if (d == null) return;
    final take = money(amount.clamp(0, d.balance));
    if (take <= 0) return;
    _set(
      state.copyWith(
        tradeDocs: [
          for (final e in state.tradeDocs)
            if (e.id == id) e.copyWith(paid: money(e.paid + take)) else e,
        ],
      ),
    );
    addCash(
      party: d.party.isEmpty ? d.number : d.party,
      amount: take,
      inward: d.kind.moneyIn,
      reason: d.number,
      mode: mode,
      accountId: accountId,
    );
    _owe(d.supplierId, switch (d.kind) {
      TradeKind.purchaseBill => -take,
      TradeKind.purchaseReturn => take,
      _ => 0,
    });
  }

  /// A sale order handed over: the stock goes out now, and whatever is
  /// collected at delivery is taken.
  void fulfilSaleOrder(
    String id, {
    double collect = 0,
    PayMode mode = PayMode.cash,
    String? accountId,
  }) {
    final d = state.tradeDocs.firstWhereOrNull((e) => e.id == id);
    if (d == null || d.kind != TradeKind.saleOrder || d.fulfilled) return;
    for (final l in d.lines) {
      _moveStock(l.masterId, -l.qty);
    }
    _set(
      state.copyWith(
        tradeDocs: [
          for (final e in state.tradeDocs)
            if (e.id == id) e.copyWith(fulfilled: true) else e,
        ],
      ),
    );
    if (collect > 0) {
      settleTradeDoc(id, amount: collect, mode: mode, accountId: accountId);
    }
  }

  /// An estimate turned into a job card. It stays on the list, marked.
  void markEstimateConverted(String id) => _set(
    state.copyWith(
      tradeDocs: [
        for (final e in state.tradeDocs)
          if (e.id == id) e.copyWith(fulfilled: true) else e,
      ],
    ),
  );

  /// Deletes a document and undoes it: stock back where it was, its money
  /// out of the day book, the supplier's account as it stood.
  void removeTradeDoc(String id) {
    final d = state.tradeDocs.firstWhereOrNull((e) => e.id == id);
    if (d == null) return;
    final sign = d.kind == TradeKind.saleOrder
        ? (d.fulfilled ? -1 : 0)
        : d.kind.stockSign;
    for (final l in d.lines) {
      _moveStock(l.masterId, -l.qty * sign);
    }
    // Everything paid against it comes off, so the supplier is put back to
    // owing what they did before the document existed.
    _owe(d.supplierId, switch (d.kind) {
      TradeKind.purchaseBill => -d.total,
      TradeKind.purchaseReturn => d.total,
      _ => 0,
    } + _paidBack(d));
    _set(
      state.copyWith(
        tradeDocs: state.tradeDocs.where((e) => e.id != id).toList(),
        cashBook: state.cashBook
            .where((e) => e.id != 'cb-${d.id}' && e.reason != d.number)
            .toList(),
      ),
    );
  }

  /// The money a document's own day-book lines moved, signed as the
  /// supplier sees it — undone along with the document.
  double _paidBack(TradeDoc d) => switch (d.kind) {
    TradeKind.purchaseBill => d.paid,
    TradeKind.purchaseReturn => -d.paid,
    _ => 0,
  };

  /// Money received outside a job card — "Payment In".
  CashEntry recordPaymentIn({
    required String party,
    required double amount,
    PayMode mode = PayMode.cash,
    String? accountId,
    DateTime? at,
  }) => addCash(
    party: party,
    amount: amount,
    inward: true,
    reason: kPaymentIn,
    mode: mode,
    accountId: accountId,
    at: at,
  );

  /// Money paid to a supplier — "Pay Out". Comes off what they are owed.
  CashEntry recordPayOut({
    required String party,
    required double amount,
    String? supplierId,
    PayMode mode = PayMode.cash,
    String? accountId,
    DateTime? at,
  }) {
    final e = addCash(
      party: party,
      amount: amount,
      inward: false,
      reason: kPayOut,
      mode: mode,
      accountId: accountId,
      at: at,
    );
    _owe(supplierId, -money(amount));
    return e;
  }

  // ---------------------------------------------------------------------
  // Growing the business, and the companies on this phone
  // ---------------------------------------------------------------------

  void setSocial(SocialLinks links) => _set(state.copyWith(social: links));

  /// Remembers the account now signed in, for "Switch company".
  void rememberCompany(String email, String name) {
    final key = email.trim().toLowerCase();
    if (key.isEmpty) return;
    _set(
      state.copyWith(
        knownCompanies: [
          KnownCompany(email: key, name: name.trim(), lastUsed: DateTime.now()),
          for (final c in state.knownCompanies)
            if (c.email != key) c,
        ],
      ),
    );
  }

  void forgetCompany(String email) => _set(
    state.copyWith(
      knownCompanies: [
        for (final c in state.knownCompanies)
          if (c.email != email.trim().toLowerCase()) c,
      ],
    ),
  );

  // ---------------------------------------------------------------------
  // Online garage
  // ---------------------------------------------------------------------

  /// Turning the page on mints a handle the first time, so the share link is
  /// never empty when the toggle goes green.
  /// Switches the online shopfront — the service menu customers book from —
  /// on or off, here and on the server, so the customer app honours it.
  void setOnlineGarage(bool on) {
    var slug = state.onlineSlug;
    if (on && slug.isEmpty) slug = _mintSlug();
    _set(state.copyWith(onlineGarageOn: on, onlineSlug: slug));
    unawaited(_remote.setOnline(on));
  }

  String _mintSlug() {
    final base = (state.garage?.name ?? 'garage').toLowerCase().replaceAll(
      RegExp('[^a-z0-9]'),
      '',
    );
    final head = base.isEmpty
        ? 'garage'
        : base.substring(0, min(4, base.length));
    const alphabet = 'abcdefghijklmnopqrstuvwxyz';
    final tail = List.generate(
      4,
      (_) => alphabet[_rand.nextInt(alphabet.length)],
    ).join();
    return '$head$tail';
  }

  void addOnlineService({
    required String name,
    required double price,
    String blurb = '',
    int durationMins = 60,
  }) => _set(
    state.copyWith(
      onlineServices: [
        ...state.onlineServices,
        OnlineService(
          id: newId('os'),
          name: name.trim(),
          price: money(price),
          blurb: blurb.trim(),
          durationMins: durationMins,
        ),
      ],
    ),
  );

  void removeOnlineService(String id) => _set(
    state.copyWith(
      onlineServices: state.onlineServices.where((e) => e.id != id).toList(),
    ),
  );
}
