import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/entities.dart';
import '../data/models/enums.dart';
import '../data/models/workshop.dart';
import '../data/repo/app_data.dart';
import '../data/repo/local_store.dart';
import '../data/seed/catalog_seed.dart';
import '../data/repo/auth_service.dart';
import '../data/repo/push_service.dart';
import '../data/repo/supabase_gateway.dart';

final _rand = Random();

String newId([String prefix = 'id']) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_rand.nextInt(9999)}';

/// Set in main() before the app builds. Not `final` so tests can rebuild
/// it with a fresh mock between cases.
late LocalStore localStore;

final appControllerProvider =
    StateNotifierProvider<AppController, AppData>((ref) {
  return AppController(localStore, ref.read(supabaseGatewayProvider));
});

/// Single source of truth for everything the customer owns, plus the business
/// rules from the product spec (approval gating, estimate versioning,
/// invoice/payment linkage, immutable history).
class AppController extends StateNotifier<AppData>
    with WidgetsBindingObserver {
  AppController(this._store, this._remote) : super(_store.read()) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(restoreAccount());
  }

  /// When the app last went and asked the workshop for itself, so reopening
  /// it repeatedly does not hammer the server.
  DateTime? _lastResume;

  /// Catch up whenever the customer comes back to the app.
  ///
  /// [connectWorkshop] subscribes to the workshop's channel and that is
  /// supposed to be enough. On this project it is not: the channel joins
  /// and then delivers nothing (see
  /// `supabase/17_realtime_diagnose.sql`), so the counter could accept a
  /// booking, do the work and hand the car back while this app still said
  /// "Scheduled".
  ///
  /// Reopening the app is exactly when somebody wants to know where their
  /// car is, and it is a natural rate limit — nobody reopens an app twenty
  /// times a minute. [_resumeGap] covers the case where they do.
  static const _resumeGap = Duration(seconds: 20);

  // Named `lifecycle`, not `state`: this class already has a `state`.
  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) return;
    if (!_remote.enabled) return;
    final last = _lastResume;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _resumeGap) return;
    _lastResume = now;
    unawaited(refreshWorkshop());
  }

  /// Pulls this account back down from the backend and re-joins the
  /// workshop's channel.
  ///
  /// Called at startup and again whenever a session appears, because signing
  /// out wipes the device: without the second call, signing back in on an
  /// existing account looks like a brand new one until the next cold start,
  /// and the router asks for a profile and a vehicle that are already on the
  /// server.
  Future<void> restoreAccount() async {
    final remote = await _remote.hydrate(state);
    if (!mounted) return;
    if (remote != null) _set(remote);
    // Only now is there a customer to file this phone's push token under.
    if (_remote.enabled && _remote.userId != null) {
      unawaited(PushService.instance.start(_remote.registerDevice));
    }
    await connectWorkshop();
  }

  final LocalStore _store;
  final SupabaseGateway _remote;

  /// Updates from the workshop, as they land, for whatever is on screen to
  /// announce.
  ///
  /// Deliberately a stream and not a slice of state. "The workshop has
  /// started on your car" is an event: it happens once and is announced
  /// once, and a rebuild for an unrelated reason must not announce it
  /// again. The durable half is [AppData.notifications], which the bell
  /// lists; this is only the moment.
  final StreamController<AppNotification> _alerts =
      StreamController<AppNotification>.broadcast();

  Stream<AppNotification> get alerts => _alerts.stream;

  /// False until the first mirror has been absorbed. That one is the app
  /// catching up on everything that happened while it was shut, not a
  /// stack of things happening now.
  bool _alertsPrimed = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_alerts.close());
    super.dispose();
  }

  void _set(AppData next) {
    state = next;
    _store.write(next);
    _remote.push(next);
  }

  // ---------------------------------------------------------------------
  // Onboarding & auth
  // ---------------------------------------------------------------------

  void completeOnboarding() => _set(state.copyWith(onboarded: true));

  /// Start a session without a provider.
  ///
  /// There is no OTP anywhere in this app. Sign-in is Google or email and
  /// password, both of which arrive through [adoptSession]; this is the
  /// offline equivalent, for a build with no backend configured and for
  /// tests that need somebody signed in before they can do anything.
  ///
  /// A returning phone number keeps everything it had — signing in again is
  /// not the same as starting over.
  void signInOffline({required String phone, String name = ''}) {
    if (state.user != null && state.user!.phone == phone) return;
    _set(state.copyWith(
      user: AppUser(
        id: newId('user'),
        name: name,
        phone: phone,
        referralCode: _referralCode(),
        createdAt: DateTime.now(),
      ),
    ));
  }

  /// Adopts a real Supabase session into the local snapshot.
  ///
  /// Called whenever the session changes — including when Google hands the
  /// app back through a deep link, long after the sign-in screen is gone.
  /// Whatever the provider gave us fills the blanks; anything the customer
  /// has already edited here wins, because they typed it on purpose.
  void adoptSession({
    required String id,
    String? email,
    String? name,
    String? phone,
    String? avatarUrl,
  }) {
    final existing = state.user;
    if (existing != null && existing.id == id) {
      _set(state.copyWith(
        user: existing.copyWith(
          name: existing.name.trim().isEmpty ? (name ?? '') : existing.name,
          email: existing.email ?? email,
          avatarUrl: existing.avatarUrl ?? avatarUrl,
        ),
      ));
      return;
    }
    _set(state.copyWith(
      user: AppUser(
        id: id,
        name: (name ?? '').trim(),
        phone: phone ?? '',
        email: email,
        avatarUrl: avatarUrl,
        referralCode: existing?.referralCode ?? _referralCode(),
        createdAt: DateTime.now(),
      ),
    ));
  }

  /// [phone] is what the workshop sees on every booking request. A Google
  /// sign-in never provides one, so without this the counter got a blank
  /// number on every booking from those customers. Null leaves it alone.
  void saveProfile({
    required String name,
    String? phone,
    String? email,
    DateTime? dob,
    String? gender,
  }) {
    final u = state.user;
    if (u == null) return;
    _set(state.copyWith(
      user: u.copyWith(
          name: name, phone: phone, email: email, dob: dob, gender: gender),
    ));
  }

  /// Leaves the account and wipes the device with it.
  ///
  /// What survives is only what is not the customer's: whether the tour has
  /// been seen, and which theme they picked. Both are written back
  /// immediately, so signing out does not replay the tour on the next launch.
  Future<void> signOut() async {
    // Anything not yet uploaded goes first: the wipe below is final.
    await _remote.flush(state);
    await _remote.reset();
    await AuthService.instance.signOut();
    await _store.clear();
    final next =
        AppData(onboarded: state.onboarded, themeMode: state.themeMode);
    state = next;
    await _store.flush(next);
  }


  // ---------------------------------------------------------------------
  // The workshop's side
  // ---------------------------------------------------------------------

  /// Pulls the garage's job cards for this customer and stays subscribed, so
  /// a line ticked off at the counter shows up here without a refresh.
  ///
  /// Safe to call again: it is how the app recovers after a sign-in, a
  /// booking that has just put this customer on a workshop's books, or the
  /// network coming back.
  Future<void> connectWorkshop() async {
    if (!_remote.enabled) return;
    await refreshWorkshop();
    if (!mounted) return;
    _remote.watchWorkshop(() => unawaited(refreshWorkshop()));
  }

  /// Pulls everything the workshop owns — its letterhead, its job cards and
  /// what it did with this customer's booking requests — and mirrors it onto
  /// the customer's own record of the visit.
  ///
  /// This is the whole of the link between the two apps. Nothing on this side
  /// moves a booking along by itself any more: a stage, a quote, a bill and a
  /// completion all mean that somebody at the counter did something.
  ///
  /// True when the workshop answered. False means nothing could be asked —
  /// offline, or signed out — and the screen should say so rather than sit
  /// there looking refreshed.
  Future<bool> refreshWorkshop() async {
    if (!_remote.enabled) return false;

    final fetched = await _remote.workshopCards();
    final requests = await _remote.myBookingRequests();
    final shop =
        await _remote.linkedWorkshop(preferId: _latestWorkshopId(fetched));
    if (!mounted) return false;

    // No answer, or an empty one when we already have cards: the network
    // hiccuped or the link was withdrawn — either way, do not blank the
    // screen over it. A real removal arrives as a card that is simply no
    // longer live.
    final keepCards = fetched == null ||
        (fetched.isEmpty && state.workshopCards.isNotEmpty);

    var next = state.copyWith(
      workshopCards: keepCards ? null : fetched,
      workshop: shop,
    );
    if (!keepCards) {
      next = _mirrorWorkshop(next, fetched, requests ?? const {});
    }
    // Only on a real answer. A failed call says nothing about what the
    // workshop did, and must not read as "every request was declined".
    if (requests != null) {
      next = _noticeDeclined(next, requests);
      unawaited(_resendUndelivered(requests));
    }
    _set(next);

    // Primed by the first completed refresh, not by the first one that
    // found something. [_mirrorWorkshop] returns early when nothing has
    // moved, which on a launch with no news is the usual case -- so
    // priming in there meant the flag was still false when the workshop
    // finally did something, and the one update worth announcing was
    // swallowed as "the backlog".
    _alertsPrimed = true;
    return fetched != null;
  }

  /// The workshop this customer dealt with most recently: the newest job
  /// card or booking that names one. That is the workshop Home, the help
  /// page and the booking cards should be talking about.
  String? _latestWorkshopId(List<WorkshopCard>? cards) {
    DateTime? newest;
    String? id;
    for (final c in cards ?? state.workshopCards) {
      if (c.garageId.isEmpty) continue;
      if (newest == null || c.openedAt.isAfter(newest)) {
        newest = c.openedAt;
        id = c.garageId;
      }
    }
    for (final b in state.bookings) {
      if (b.garageId.isEmpty) continue;
      if (newest == null || b.createdAt.isAfter(newest)) {
        newest = b.createdAt;
        id = b.garageId;
      }
    }
    return id;
  }

  // ---------------------------------------------------------------------
  // Mirroring the workshop onto the customer's bookings
  // ---------------------------------------------------------------------

  /// Applies a set of job cards as though they had just arrived from the
  /// workshop. [refreshWorkshop] is the only caller in the app; this exists
  /// so the connection can be tested without a live Supabase behind it.
  @visibleForTesting
  void applyWorkshop(
    List<WorkshopCard> cards, {
    Map<String, Map<String, dynamic>> requests = const {},
    Workshop? shop,
  }) =>
      _set(_mirrorWorkshop(
          state.copyWith(workshopCards: cards, workshop: shop),
          cards,
          requests));

  /// Restates every booking the workshop has turned into a job card from that
  /// card: what stage it is at, what is being charged, and the bill once
  /// there is one.
  ///
  /// A booking the counter has not picked up yet is left exactly as the
  /// customer made it — an appointment, and nothing more.
  AppData _mirrorWorkshop(
    AppData data,
    List<WorkshopCard> cards,
    Map<String, Map<String, dynamic>> requests,
  ) {
    if (data.bookings.isEmpty) return data;

    final byId = {for (final c in cards) c.id: c};
    final bookings = <Booking>[];
    final estimates = {...data.estimates};
    final invoices = {...data.invoices};
    final fresh = <AppNotification>[];
    var changed = false;

    for (final b in data.bookings) {
      final card = b.status == BookingStatus.cancelled
          ? null
          : _cardFor(data, b, byId, requests);
      if (card == null) {
        bookings.add(b);
        continue;
      }

      final stage = _stageOf(card);
      final moved = stage != b.stage;

      final updated = b.copyWith(
        stage: stage,
        status: card.isClosed ? BookingStatus.completed : BookingStatus.active,
        technician: card.mechanic.isEmpty ? null : card.mechanic,
        etaAt: card.promisedAt,
        jobCard: _recordOf(card),
        timeline: moved
            ? [
                ...b.timeline,
                TimelineEvent(
                  stage: stage,
                  at: _atFor(card, stage),
                  note: stage.blurb,
                  actor: card.mechanic.isEmpty ? null : card.mechanic,
                ),
              ]
            : null,
      );

      // The quote is the workshop's line items, exactly as billed. It is a
      // statement of what is being done, not a proposal waiting on a tap —
      // what gets agreed is agreed at the counter.
      if (card.items.isNotEmpty) {
        final quote = _quoteOf(card, b.id);
        final current = data.estimatesFor(b.id);
        if (current.isEmpty || !_sameQuote(current.last, quote)) {
          estimates[b.id] = [quote];
          changed = true;
        }
      }

      // A bill exists once the work is off the floor.
      if (card.isComplete || card.isClosed) {
        final bill = _billOf(card, b, data.invoices[b.id]);
        if (!_sameBill(invoices[b.id], bill)) {
          invoices[b.id] = bill;
          changed = true;
        }
      }

      if (moved) {
        changed = true;
        fresh.add(AppNotification(
          id: 'n-${card.id}-${stage.name}',
          kind: NotifyKind.service,
          title: stage.label,
          body: '${b.code} • ${stage.blurb}',
          at: _atFor(card, stage),
          bookingId: b.id,
        ));
      } else if (!_sameBooking(updated, b)) {
        changed = true;
      }

      bookings.add(updated);
    }

    if (!changed) return data;

    // A stage can arrive twice — a reconnect re-reads the same card — so the
    // notification id is derived from the card and the stage, never minted.
    final known = {for (final n in data.notifications) n.id};
    final added = fresh.where((n) => !known.contains(n.id)).toList();

    // Say so, out loud, once. Everything here came off the workshop's own
    // job card -- the counter accepted the booking, started the work,
    // finished it -- so it is news to the customer by definition, and it
    // arrived while they were looking at something else. Without this the
    // app changed quietly underneath them and the only way to find out was
    // to go and check the bookings screen on the off chance.
    //
    // Oldest first, so a burst reads in the order it happened, and never
    // on the first pass: a cold start mirrors the whole history at once.
    if (_alertsPrimed && !_alerts.isClosed) {
      for (final n in added.reversed) {
        _alerts.add(n);
      }
    }

    return data.copyWith(
      bookings: bookings,
      estimates: estimates,
      invoices: invoices,
      notifications: added.isEmpty ? null : [...added, ...data.notifications],
    );
  }

  /// The job card this booking became, if the counter has opened one.
  ///
  /// The request the app filed carries the id `req-<bookingId>`, and the
  /// workshop writes the job card's id back onto that row when it accepts.
  /// Failing that, a card opened for the same car on the day of the slot is
  /// taken as the same visit — which is what happens when somebody turns up
  /// on an appointment and the counter opens a card without touching the
  /// diary.
  static WorkshopCard? _cardFor(
    AppData data,
    Booking b,
    Map<String, WorkshopCard> byId,
    Map<String, Map<String, dynamic>> requests,
  ) {
    final linked = (requests['req-${b.id}']?['job_card_id'] ?? '').toString();
    if (linked.isNotEmpty && byId.containsKey(linked)) return byId[linked];

    final reg = _plate(data.vehicleById(b.vehicleId)?.regNumber ?? '');
    if (reg.isEmpty) return null;

    for (final c in byId.values) {
      if (_plate(c.regNo) == reg && _sameDay(c.openedAt, b.slot)) return c;
    }
    return null;
  }

  /// Where the customer's timeline stands, read off the workshop's card.
  ///
  /// A job card has three states, so these are the three the customer sees,
  /// plus the difference between a card that has been priced and one that is
  /// actually being worked on.
  static JobStage _stageOf(WorkshopCard c) {
    if (c.isClosed) return JobStage.delivered;
    if (c.isComplete) return JobStage.readyForDelivery;
    if (c.items.isEmpty) return JobStage.received;
    if (c.items.any((e) => e.state == 'running' || e.isFinished)) {
      return JobStage.repairInProgress;
    }
    return JobStage.estimateSent;
  }

  static DateTime _atFor(WorkshopCard c, JobStage stage) => switch (stage) {
        JobStage.delivered => c.closedAt ?? DateTime.now(),
        JobStage.readyForDelivery => c.completedAt ?? DateTime.now(),
        JobStage.received => c.openedAt,
        _ => DateTime.now(),
      };

  /// The intake the counter wrote down, in the shape the booking screens
  /// already know how to draw.
  static JobCardRecord _recordOf(WorkshopCard c) => JobCardRecord(
        number: c.number,
        openedAt: c.openedAt,
        odometerKm: c.odometerKm,
        fuelPercent: c.fuelPercent,
        promisedAt: c.promisedAt,
        voices: c.voices,
        accessories: c.accessories,
        workNote: c.workNote,
        mechanic: c.mechanic.isEmpty ? null : c.mechanic,
        // The damage the counter logged at check-in. Never carried across
        // before, so the customer's record said nothing was marked.
        marks: [
          for (final d in c.dents)
            HandoverMark(
              id: d.id,
              dx: d.dx,
              dy: d.dy,
              kind: MarkKindX.parse(d.severity),
              note: [d.label, d.note]
                  .where((s) => s.trim().isNotEmpty)
                  .join(' — '),
            ),
        ],
        photos: c.photos,
        nextServiceAt: c.nextServiceAt,
        nextServiceKm: c.nextServiceKm,
      );

  /// The workshop's line items as a quote. Labour lands under labour and
  /// parts under parts, which is the split the estimate screen prints.
  static Estimate _quoteOf(WorkshopCard c, String bookingId) => Estimate(
        id: 'est-${c.id}',
        bookingId: bookingId,
        version: 1,
        createdAt: c.openedAt,
        status: EstimateStatus.approved,
        items: [
          for (final e in c.items)
            EstimateItem(
              id: e.id,
              name: e.name,
              parts: e.kind == 'job' ? 0 : e.amount.round(),
              labour: e.kind == 'job' ? e.amount.round() : 0,
              condition:
                  e.state == 'skipped' ? Condition.monitor : Condition.replace,
              note: e.remark.isEmpty ? null : e.remark,
              approved: e.state != 'skipped',
            ),
        ],
      );

  static bool _sameQuote(Estimate a, Estimate b) =>
      a.items.length == b.items.length &&
      a.total == b.total &&
      a.approvedTotal == b.approvedTotal;

  /// The workshop's bill, at the workshop's own tax rate and discount.
  ///
  /// [existing] is the copy already on this device: whatever the customer has
  /// paid through the app stays recorded, and the garage's own payments can
  /// settle it too. Neither side gets to un-pay the other.
  static Invoice _billOf(WorkshopCard c, Booking b, Invoice? existing) =>
      Invoice(
        id: existing?.id ?? 'inv-${c.id}',
        number: c.number,
        bookingId: b.id,
        jobCardNumber: c.number,
        createdAt: c.completedAt ?? c.closedAt ?? c.openedAt,
        discount: c.discount.round(),
        taxRate: c.taxRate,
        lines: [
          for (final e in c.items)
            InvoiceLine(
              name: e.name,
              amount: e.amount.round(),
              parts: e.kind == 'job' ? 0 : e.amount.round(),
              labour: e.kind == 'job' ? e.amount.round() : 0,
              qty: e.qty.round() < 1 ? 1 : e.qty.round(),
            ),
        ],
        paid: (existing?.paid ?? false) || c.settled,
        method: existing?.method,
        paidAt: existing?.paidAt ?? (c.settled ? c.closedAt : null),
        transactionId: existing?.transactionId,
      );

  static bool _sameBill(Invoice? a, Invoice? b) {
    if (a == null || b == null) return a == b;
    return a.number == b.number &&
        a.total == b.total &&
        a.paid == b.paid &&
        a.lines.length == b.lines.length;
  }

  static bool _sameBooking(Booking a, Booking b) =>
      a.stage == b.stage &&
      a.status == b.status &&
      a.technician == b.technician &&
      a.etaAt == b.etaAt &&
      a.jobCard?.number == b.jobCard?.number &&
      a.jobCard?.workNote == b.jobCard?.workNote &&
      a.jobCard?.odometerKm == b.jobCard?.odometerKm;

  static String _plate(String v) =>
      v.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _referralCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'GP${List.generate(5, (_) => chars[_rand.nextInt(chars.length)]).join()}';
  }

  // ---------------------------------------------------------------------
  // Vehicles
  // ---------------------------------------------------------------------

  Vehicle addVehicle(Vehicle vehicle) {
    final isFirst = state.vehicles.isEmpty;
    final v = isFirst ? vehicle.copyWith(isPrimary: true) : vehicle;
    _set(state.copyWith(
      vehicles: [...state.vehicles, v],
      activeVehicleId: state.activeVehicleId ?? v.id,
    ));
    return v;
  }

  void updateVehicle(Vehicle vehicle) {
    _set(state.copyWith(
      vehicles: [
        for (final v in state.vehicles) v.id == vehicle.id ? vehicle : v
      ],
    ));
  }

  void removeVehicle(String id) {
    final remaining = state.vehicles.where((v) => v.id != id).toList();
    _set(state.copyWith(
      vehicles: remaining,
      activeVehicleId: state.activeVehicleId == id
          ? (remaining.isEmpty ? null : remaining.first.id)
          : state.activeVehicleId,
      clearActiveVehicle: remaining.isEmpty,
      // History is never deleted — the spec requires it to survive.
    ));
  }

  void setActiveVehicle(String id) =>
      _set(state.copyWith(activeVehicleId: id));

  void setPrimaryVehicle(String id) {
    _set(state.copyWith(
      vehicles: [
        for (final v in state.vehicles) v.copyWith(isPrimary: v.id == id)
      ],
      activeVehicleId: id,
    ));
  }

  void updateOdometer(String vehicleId, int km) {
    final v = state.vehicleById(vehicleId);
    if (v == null) return;
    updateVehicle(v.copyWith(odometerKm: km));
  }

  // ---------------------------------------------------------------------
  // Addresses
  // ---------------------------------------------------------------------

  Address saveAddress(Address address) {
    final exists = state.addresses.any((a) => a.id == address.id);
    final makeDefault = address.isDefault || state.addresses.isEmpty;
    final list = [
      for (final a in state.addresses)
        if (a.id == address.id)
          address.copyWith(isDefault: makeDefault)
        else
          a.copyWith(isDefault: makeDefault ? false : a.isDefault),
      if (!exists) address.copyWith(isDefault: makeDefault),
    ];
    _set(state.copyWith(addresses: list));
    return address;
  }

  void removeAddress(String id) {
    final list = state.addresses.where((a) => a.id != id).toList();
    if (list.isNotEmpty && !list.any((a) => a.isDefault)) {
      list[0] = list[0].copyWith(isDefault: true);
    }
    _set(state.copyWith(addresses: list));
  }

  void setDefaultAddress(String id) {
    _set(state.copyWith(
      addresses: [
        for (final a in state.addresses) a.copyWith(isDefault: a.id == id)
      ],
    ));
  }

  // ---------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------

  Booking createBooking({
    required String vehicleId,
    required List<CartLine> lines,
    required ServiceMode mode,
    required DateTime slot,
    String garageId = '',
    String workshopName = '',
    String? addressId,
    String? couponCode,
    int discount = 0,
    String? notes,
  }) {
    final now = DateTime.now();
    final id = newId('bk');
    final booking = Booking(
      id: id,
      code: _bookingCode(now),
      vehicleId: vehicleId,
      garageId: garageId,
      lines: lines,
      mode: mode,
      slot: slot,
      status: BookingStatus.upcoming,
      createdAt: now,
      addressId: addressId,
      couponCode: couponCode,
      discount: discount,
      pickupFee: mode == ServiceMode.pickup ? Seed.pickupFee : 0,
      notes: notes,
      stage: JobStage.confirmed,
      timeline: [
        TimelineEvent(
          stage: JobStage.confirmed,
          at: now,
          note: switch (workshopName.isNotEmpty
              ? workshopName
              : (state.workshop.isLinked ? state.workshop.name : '')) {
            '' => 'Slot reserved',
            final where => 'Slot reserved at $where',
          },
        ),
      ],
    );

    _set(state.copyWith(
      bookings: [booking, ...state.bookings],
      notifications: [
        AppNotification(
          id: newId('n'),
          kind: NotifyKind.booking,
          title: 'Booking confirmed',
          body:
              '${booking.code} • ${_dayLabel(slot)} at ${_timeLabel(slot)}. We will see you then.',
          at: now,
          bookingId: id,
        ),
        ...state.notifications,
      ],
    ));
    return booking;
  }

  /// Puts the booking on the workshop's front desk, so the counter sees it
  /// arrive rather than hearing about it on the phone.
  ///
  /// The workshop is the one the customer picked out of the directory, and
  /// that is the whole of the qualification now. It used to ask
  /// `linkedWorkshops()` first and give up when the list came back empty —
  /// which it did for every customer who had not been handed a code at the
  /// counter. So the front desk stayed empty for exactly the people the
  /// front desk is for, and the booking they had just confirmed on screen
  /// went nowhere. Inserting the row is itself what links the two: from
  /// then on `deals_with_garage()` is true and the workshop's page, menu
  /// and job cards open up.
  ///
  /// Returns whether the workshop has it, and the booking screen says which.
  /// It used to be fire-and-forget behind a "sent to the workshop" toast
  /// shown before anything was sent, so a booking made offline read as
  /// delivered and never arrived. The booking is still kept on the phone
  /// either way; one that could not be filed is filed again on the next
  /// refresh (see [_resendUndelivered]).
  Future<bool> tellTheWorkshop(Booking booking) async {
    // A booking with no workshop on it predates the directory. There is
    // nowhere to send it, and inventing a destination would be worse.
    if (booking.garageId.isEmpty) return false;

    // Bounded, so a dead network cannot hold the confirm button forever.
    // The send carries on behind the timeout and records how it ended.
    final sent = await _sendToWorkshop(booking)
        .timeout(const Duration(seconds: 12), onTimeout: () => false);

    // That row is the link. `deals_with_garage()` reads `garage_bookings`,
    // so from this moment the workshop's letterhead, its menu and any job
    // card it opens for this customer are all readable — but only to a
    // session that goes and looks. This is where redeeming a code used to
    // reconnect, and the booking has taken that job along with the rest.
    if (sent && mounted) unawaited(connectWorkshop());
    return sent;
  }

  /// Booking ids with a send in flight, so a resend on refresh cannot race
  /// the send from the booking screen.
  final Set<String> _sending = {};

  /// Files one request, with the car as the customer described it, and
  /// records on this phone whether it landed. Never reconnects: that is
  /// [tellTheWorkshop]'s job, and doing it here would loop — a refresh
  /// resends, the resend reconnects, the reconnect refreshes.
  Future<bool> _sendToWorkshop(Booking booking) async {
    if (!_sending.add(booking.id)) return false;
    try {
      final v = state.vehicleById(booking.vehicleId);
      final sent = await _remote.requestWorkshopBooking(
        garageId: booking.garageId,
        id: 'req-${booking.id}',
        name: state.user?.name ?? '',
        phone: state.user?.phone ?? '',
        at: booking.slot,
        regNo: v?.regNumber ?? '',
        vehicle: v == null ? '' : '${v.brand} ${v.model}',
        note: booking.lines.map((e) => e.name).join(', '),
        brand: v?.brand ?? '',
        model: v?.model ?? '',
        variant: v?.variant ?? '',
        fuel: v?.fuel.name ?? '',
        transmission: v?.transmission.name ?? '',
        year: v == null || v.year <= 0 ? null : v.year,
        odometerKm: v == null || v.odometerKm <= 0 ? null : v.odometerKm,
        mode: booking.mode.name,
        customerNote: booking.notes ?? '',
      );
      _setRequestState(booking.id, sent ? 'sent' : 'pending');
      return sent;
    } finally {
      _sending.remove(booking.id);
    }
  }

  void _setRequestState(String bookingId, String? value) {
    final states = _store.readRequestStates();
    if (value == null) {
      if (states.remove(bookingId) == null) return;
    } else {
      if (states[bookingId] == value) return;
      states[bookingId] = value;
    }
    _store.writeRequestStates(states);
  }

  /// Files again every request this phone could not deliver, while its slot
  /// is still worth keeping. [requests] is what the workshop actually holds:
  /// one that turns out to be there after all is simply marked delivered.
  Future<void> _resendUndelivered(
    Map<String, Map<String, dynamic>> requests,
  ) async {
    final states = _store.readRequestStates();
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    for (final b in state.bookings) {
      if (states[b.id] != 'pending') continue;
      if (requests.containsKey('req-${b.id}')) {
        _setRequestState(b.id, 'sent');
        continue;
      }
      if (b.status != BookingStatus.upcoming || b.slot.isBefore(cutoff)) {
        // Cancelled on the phone, or a slot long gone: nothing to deliver.
        _setRequestState(b.id, null);
        continue;
      }
      if (!mounted) return;
      await _sendToWorkshop(b);
    }
  }

  /// A request this phone delivered that is no longer on the workshop's desk,
  /// with no job card made from it, was declined at the counter — declining
  /// deletes the row. The customer used to go on seeing "Confirmed" for a
  /// visit nobody was expecting. Now they are told, and the booking stops
  /// counting as upcoming.
  ///
  /// Only for requests known to have arrived: one this phone never managed
  /// to file is missing for a different reason, and is [_resendUndelivered]'s.
  AppData _noticeDeclined(
    AppData data,
    Map<String, Map<String, dynamic>> requests,
  ) {
    final states = _store.readRequestStates();
    var next = data;
    for (final b in data.bookings) {
      if (states[b.id] != 'sent') continue;
      if (requests.containsKey('req-${b.id}')) continue;
      _setRequestState(b.id, null);
      if (b.status != BookingStatus.upcoming || b.jobCard != null) continue;

      const reason = 'Declined by the workshop';
      next = _writeBooking(
        next,
        b.copyWith(
          status: BookingStatus.cancelled,
          cancelReason: reason,
          timeline: [
            ...b.timeline,
            TimelineEvent(stage: b.stage, at: DateTime.now(), note: reason),
          ],
        ),
      ).copyWith(notifications: [
        AppNotification(
          id: newId('n'),
          kind: NotifyKind.booking,
          title: 'Booking declined',
          body: '${b.code} was declined by the workshop. '
              'Book another slot or call them.',
          at: DateTime.now(),
          bookingId: b.id,
        ),
        ...next.notifications,
      ]);
    }
    return next;
  }

  /// Moves a booking to a new slot — on the phone and on the workshop's
  /// front desk.
  ///
  /// It used to move only the phone's copy, so the counter still expected
  /// the car at the old time. A request this phone has not managed to
  /// deliver yet needs nothing upstream: the resend reads the new slot.
  /// Returns an error sentence, or null when it has moved.
  Future<String?> rescheduleBooking(String id, DateTime slot) async {
    final before = state.bookingById(id);
    if (before == null) return null;
    if (before.jobCard != null) {
      return 'The workshop has already started on this booking. '
          'Call them to change the time.';
    }
    final undelivered = _store.readRequestStates()[id] == 'pending';
    if (before.garageId.isNotEmpty && _remote.enabled && !undelivered) {
      final moved =
          await _remote.rescheduleWorkshopBooking('req-${before.id}', slot);
      if (!moved) {
        return 'Could not move it with the workshop. Check your connection, '
            'or call them if they have already accepted it.';
      }
    }
    if (!mounted) return null;
    final b = state.bookingById(id);
    if (b == null) return null;
    _replaceBooking(b.copyWith(
      slot: slot,
      timeline: [
        ...b.timeline,
        TimelineEvent(
          stage: b.stage,
          at: DateTime.now(),
          note: 'Rescheduled to ${_dayLabel(slot)}, ${_timeLabel(slot)}',
        ),
      ],
    ), notify: (
      title: 'Booking rescheduled',
      body: '${b.code} moved to ${_dayLabel(slot)} at ${_timeLabel(slot)}.',
      kind: NotifyKind.booking,
    ));
    return null;
  }

  /// Rates a finished job card, 1 to 5 stars, with an optional comment. It
  /// lands in the workshop's Feedback screen and rings their bell
  /// (`notify_new_review`). Rating again changes the first rating rather
  /// than adding a second. Returns an error sentence, or null.
  Future<String?> reviewCard(
    WorkshopCard card, {
    required int stars,
    String comment = '',
  }) async {
    if (!card.isClosed) {
      return 'You can rate the service once the workshop has closed the '
          'job card.';
    }
    final error = await _remote.saveReview(
      garageId: card.garageId,
      jobCardId: card.id,
      stars: stars,
      comment: comment,
    );
    if (error != null || !mounted) return error;

    // The booking this card came from carries the rating too, so the
    // booking history shows it without another round trip.
    for (final b in state.bookings) {
      if (b.jobCard?.number == card.number &&
          b.garageId == card.garageId) {
        rateBooking(b.id, stars.toDouble(), comment.trim().isEmpty ? null : comment.trim());
      }
    }
    await refreshWorkshop();
    return null;
  }

  /// Deletes the account for good — the sign-in and everything the
  /// customer owns on the server — and then wipes this phone.
  ///
  /// It used to be a sign-out with a scarier label: the account and every
  /// car, booking and invoice on it came straight back at the next sign-in.
  /// Returns an error sentence, or null once it is gone.
  Future<String?> deleteAccount() async {
    if (_remote.enabled && AuthService.instance.userId != null) {
      final error = await _remote.deleteAccount();
      if (error != null) return error;
    }
    await _remote.reset();
    await AuthService.instance.signOut();
    await _store.clear();
    final next =
        AppData(onboarded: state.onboarded, themeMode: state.themeMode);
    state = next;
    await _store.flush(next);
    return null;
  }

  /// Calls a booking off — on the phone and on the workshop's front desk.
  ///
  /// It used to change only the phone's copy (and nothing called it), so the
  /// counter kept the slot and could open a job card for a visit the
  /// customer had already cancelled. The request is withdrawn first. Once
  /// the counter has accepted it the database refuses, because calling off
  /// work already under way is a phone call, not a button.
  ///
  /// Returns an error sentence, or null when it is cancelled.
  Future<String?> cancelBooking(String id, String reason) async {
    final before = state.bookingById(id);
    if (before == null) return null;
    if (before.jobCard != null) {
      return 'The workshop has already started on this booking. '
          'Call them to cancel.';
    }
    if (before.garageId.isNotEmpty && _remote.enabled) {
      final gone = await _remote.withdrawWorkshopBooking('req-${before.id}');
      if (!gone) {
        return 'Could not cancel with the workshop. Check your connection, '
            'or call them if they have already accepted it.';
      }
    }
    _setRequestState(id, null);
    if (!mounted) return null;

    // Re-read: the await above is long enough for a refresh to have landed.
    final b = state.bookingById(id);
    if (b == null) return null;
    // Cancelled appointments keep their historical record.
    _replaceBooking(
      b.copyWith(
        status: BookingStatus.cancelled,
        cancelReason: reason,
        timeline: [
          ...b.timeline,
          TimelineEvent(
              stage: b.stage, at: DateTime.now(), note: 'Cancelled — $reason'),
        ],
      ),
      notify: (
        title: 'Booking cancelled',
        body: '${b.code} has been cancelled. No charges applied.',
        kind: NotifyKind.booking,
      ),
    );
    return null;
  }

  void addBookingNote(String id, String note) {
    final b = state.bookingById(id);
    if (b == null) return;
    _replaceBooking(b.copyWith(notes: note));
  }

  /// The steps the tracker draws, which are exactly the steps a workshop
  /// can put a car through: the customer books it, the counter opens a card,
  /// prices it, works it, finishes it and hands it back.
  ///
  /// It used to run to eleven, most of them stages nothing could ever reach.
  /// A tracker that stops four rungs from the top on every single job reads
  /// as broken, so the ones the console cannot report are not drawn.
  static const List<JobStage> _stageFlow = [
    JobStage.confirmed,
    JobStage.received,
    JobStage.estimateSent,
    JobStage.repairInProgress,
    JobStage.readyForDelivery,
    JobStage.delivered,
  ];

  List<JobStage> stageFlowFor(Booking b) => _stageFlow;

  // ---------------------------------------------------------------------
  // Estimates
  // ---------------------------------------------------------------------

  /// Approve a specific set of estimate items. Anything not in [approvedIds]
  /// is explicitly declined and never worked on.
  void approveEstimate(String bookingId, Set<String> approvedIds) {
    final b = state.bookingById(bookingId);
    final est = state.latestEstimate(bookingId);
    if (b == null || est == null) return;

    final items = [
      for (final i in est.items) i.copyWith(approved: approvedIds.contains(i.id))
    ];
    final status = approvedIds.isEmpty
        ? EstimateStatus.rejected
        : (approvedIds.length == est.items.length
            ? EstimateStatus.approved
            : EstimateStatus.partiallyApproved);

    final approved = est.copyWith(
      items: items,
      status: status,
      approvedAt: DateTime.now(),
      approvedBy: state.user?.name.isNotEmpty == true
          ? state.user!.name
          : state.user?.phone,
    );

    final versions = [...state.estimatesFor(bookingId)];
    versions[versions.length - 1] = approved;

    final now = DateTime.now();
    const nextStage = JobStage.repairInProgress;

    final updatedBooking = b.copyWith(
      stage: nextStage,
      status: BookingStatus.active,
      timeline: [
        ...b.timeline,
        TimelineEvent(
          stage: nextStage,
          at: now,
          note: approvedIds.isEmpty
              ? 'Additional work declined — only the booked package will be done'
              : '${approvedIds.length} of ${est.items.length} items approved '
                  '(₹${approved.approvedTotal})',
          actor: approved.approvedBy,
        ),
      ],
    );

    var data = state.copyWith(
      estimates: {...state.estimates, bookingId: versions},
      notifications: [
        AppNotification(
          id: newId('n'),
          kind: NotifyKind.service,
          title: approvedIds.isEmpty ? 'Work continues as booked' : 'Repair started',
          body: approvedIds.isEmpty
              ? 'We will only complete the package you booked.'
              : 'Approval received. Technicians are on the job.',
          at: now,
          bookingId: bookingId,
        ),
        ...state.notifications,
      ],
    );
    data = _writeBooking(data, updatedBooking);
    _set(data);
  }

  // ---------------------------------------------------------------------
  // Invoice & payment
  // ---------------------------------------------------------------------

  /// A bill for a booking the workshop has not billed itself — the services
  /// the customer ordered, at the price they were quoted. Once a job card
  /// exists, [_billOf] replaces this with the garage's own figures.
  AppData _withInvoice(AppData data, Booking b) {
    final lines = <InvoiceLine>[
      for (final l in b.lines) InvoiceLine(name: l.name, amount: l.price),
    ];

    final invoice = Invoice(
      id: newId('inv'),
      number: 'INV/${DateTime.now().year}/${_tail(b.code, 6)}',
      bookingId: b.id,
      lines: lines,
      createdAt: DateTime.now(),
      discount: b.discount,
      pickupFee: b.pickupFee,
    );

    return data.copyWith(
      invoices: {...data.invoices, b.id: invoice},
      notifications: [
        AppNotification(
          id: newId('n'),
          kind: NotifyKind.payment,
          title: 'Invoice ready',
          body:
              '${invoice.number} • ₹${invoice.total}. Pay in the app or at the counter.',
          at: DateTime.now(),
          bookingId: b.id,
        ),
        ...data.notifications,
      ],
    );
  }

  Invoice? ensureInvoice(String bookingId) {
    final existing = state.invoices[bookingId];
    if (existing != null) return existing;
    final b = state.bookingById(bookingId);
    if (b == null) return null;
    final data = _withInvoice(state, b);
    _set(_writeBooking(data, b.copyWith(invoiceId: data.invoices[bookingId]!.id)));
    return state.invoices[bookingId];
  }

  /// Payments always attach to a specific invoice.
  Future<Invoice?> payInvoice(String bookingId, PaymentMethod method) async {
    final invoice = state.invoices[bookingId];
    final b = state.bookingById(bookingId);
    if (invoice == null || b == null) return null;

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return null;

    final paid = invoice.copyWith(
      paid: true,
      method: method,
      paidAt: DateTime.now(),
      transactionId:
          'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
    );

    var data = state.copyWith(
      invoices: {...state.invoices, bookingId: paid},
      notifications: [
        AppNotification(
          id: newId('n'),
          kind: NotifyKind.payment,
          title: 'Payment successful',
          body: '₹${paid.total} paid via ${method.label}. ${paid.number}',
          at: DateTime.now(),
          bookingId: bookingId,
        ),
        ...state.notifications,
      ],
    );

    data = _writeBooking(
      data,
      b.copyWith(
        invoiceId: paid.id,
        timeline: [
          ...b.timeline,
          TimelineEvent(
              stage: b.stage,
              at: DateTime.now(),
              note: 'Payment of ₹${paid.total} received via ${method.label}'),
        ],
      ),
    );
    _set(data);
    return paid;
  }

  /// Marks the job delivered and closes the loop.
  void completeBooking(String bookingId) {
    final b = state.bookingById(bookingId);
    if (b == null) return;
    final v = state.vehicleById(b.vehicleId);
    var data = _writeBooking(
      state,
      b.copyWith(
        stage: JobStage.delivered,
        status: BookingStatus.completed,
        timeline: [
          ...b.timeline,
          TimelineEvent(
              stage: JobStage.delivered,
              at: DateTime.now(),
              note: 'Handed back to you. Thanks for choosing us.'),
        ],
      ),
    );
    if (v != null) {
      data = data.copyWith(vehicles: [
        for (final x in data.vehicles)
          x.id == v.id
              ? x.copyWith(
                  lastServiceDate: DateTime.now(), lastServiceKm: x.odometerKm)
              : x
      ]);
    }
    _set(data);
  }

  void rateBooking(String bookingId, double rating, String? note) {
    final b = state.bookingById(bookingId);
    if (b == null) return;
    _replaceBooking(b.copyWith(rating: rating, reviewNote: note));
  }

  // ---------------------------------------------------------------------
  // Notifications, chat, support
  // ---------------------------------------------------------------------

  void markNotificationRead(String id) {
    _set(state.copyWith(
      notifications: [
        for (final n in state.notifications)
          n.id == id ? n.copyWith(read: true) : n
      ],
    ));
  }

  void markAllNotificationsRead() {
    _set(state.copyWith(
      notifications: [
        for (final n in state.notifications) n.copyWith(read: true)
      ],
    ));
  }

  void clearNotifications() => _set(state.copyWith(notifications: const []));

  void sendChat(String text, {String? topic, String? imagePath}) {
    final msg = ChatMessage(
      id: newId('c'),
      text: text,
      at: DateTime.now(),
      fromMe: true,
      topic: topic,
      imagePath: imagePath,
    );
    _set(state.copyWith(chat: [...state.chat, msg]));
  }

  SupportTicket raiseTicket({
    required String subject,
    required String category,
    required String body,
    String? bookingCode,
  }) {
    final t = SupportTicket(
      id: 'TKT${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      subject: subject,
      category: category,
      body: body,
      createdAt: DateTime.now(),
      bookingCode: bookingCode,
    );
    _set(state.copyWith(tickets: [t, ...state.tickets]));
    return t;
  }

  // ---------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------

  void setThemeMode(ThemeMode mode) => _set(state.copyWith(themeMode: mode));

  void toggleSavedPackage(String id) {
    final s = {...state.savedPackageIds};
    if (!s.remove(id)) s.add(id);
    _set(state.copyWith(savedPackageIds: s));
  }

  void pushSearch(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    final list = [t, ...state.recentSearches.where((e) => e != t)].take(8).toList();
    _set(state.copyWith(recentSearches: list));
  }

  void clearSearches() => _set(state.copyWith(recentSearches: const []));

  void setPrefs({
    bool? push,
    bool? email,
    bool? whatsapp,
    bool? reminders,
    bool? offers,
  }) {
    _set(state.copyWith(
      pushEnabled: push,
      emailEnabled: email,
      whatsappEnabled: whatsapp,
      serviceRemindersEnabled: reminders,
      offersEnabled: offers,
    ));
  }

  /// Clears this device's copy of the service history, leaving the account
  /// and the cars intact. The workshop's own record is untouched, and any
  /// job card it still holds for this customer comes straight back on the
  /// next refresh.
  void clearHistory() => _set(state.copyWith(
        bookings: const [],
        inspections: const {},
        estimates: const {},
        invoices: const {},
        notifications: const [],
        chat: const [],
      ));

  // ---------------------------------------------------------------------

  void _replaceBooking(
    Booking b, {
    ({String title, String body, NotifyKind kind})? notify,
  }) {
    var data = _writeBooking(state, b);
    if (notify != null) {
      data = data.copyWith(notifications: [
        AppNotification(
          id: newId('n'),
          kind: notify.kind,
          title: notify.title,
          body: notify.body,
          at: DateTime.now(),
          bookingId: b.id,
        ),
        ...data.notifications,
      ]);
    }
    _set(data);
  }

  AppData _writeBooking(AppData data, Booking b) => data.copyWith(
        bookings: [for (final x in data.bookings) x.id == b.id ? b : x],
      );

  /// Last [n] characters, used to keep invoice and job-card numbers short.
  static String _tail(String value, int n) =>
      value.length <= n ? value : value.substring(value.length - n);

  String _bookingCode(DateTime d) =>
      'GAR${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}'
      '${(d.millisecondsSinceEpoch % 900 + 100)}';

  String _dayLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  String _timeLabel(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}

/// Convenience: initialise persistence before the widget tree is built.
Future<void> initLocalStore() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  localStore = LocalStore(prefs);
}
