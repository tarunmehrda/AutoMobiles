import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../data/models/entities.dart';
import '../data/models/enums.dart';
import '../data/models/workshop.dart';
import '../data/repo/app_data.dart';
import '../data/repo/local_store.dart';
import '../data/seed/catalog_seed.dart';
import '../data/repo/auth_service.dart';
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
class AppController extends StateNotifier<AppData> {
  AppController(this._store, this._remote) : super(_store.read()) {
    _remote.hydrate(state).then((remote) {
      if (remote != null && mounted) _set(remote);
      unawaited(connectWorkshop());
    });
  }

  final LocalStore _store;
  final SupabaseGateway _remote;

  void _set(AppData next) {
    state = next;
    _store.write(next);
    _remote.push(next);
  }

  // ---------------------------------------------------------------------
  // Onboarding & auth
  // ---------------------------------------------------------------------

  void completeOnboarding() => _set(state.copyWith(onboarded: true));

  /// Mock OTP, used only when no backend is configured. With Supabase on,
  /// [AuthService] sends and verifies the real code.
  Future<String?> requestOtp(String phone) async {
    if (AppConfig.hasSupabase) return null;
    return (100000 + _rand.nextInt(899999)).toString();
  }

  /// The offline path: any six digits shown on screen, or `123456`.
  Future<bool> verifyOtp({
    required String phone,
    required String entered,
    required String? expected,
  }) async {
    if (entered != expected && entered != '123456') return false;

    // Returning user: keep everything, just restore the session.
    if (state.user != null && state.user!.phone == phone) return true;

    _set(state.copyWith(
      user: AppUser(
        id: newId('user'),
        name: '',
        phone: phone,
        referralCode: _referralCode(),
        createdAt: DateTime.now(),
      ),
    ));
    return true;
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

  void saveProfile({
    required String name,
    String? email,
    DateTime? dob,
    String? gender,
  }) {
    final u = state.user;
    if (u == null) return;
    _set(state.copyWith(
      user: u.copyWith(name: name, email: email, dob: dob, gender: gender),
    ));
  }

  Future<void> signOut() async {
    await _remote.reset();
    await AuthService.instance.signOut();
    await _store.clear();
    state = AppData(onboarded: state.onboarded, themeMode: state.themeMode);
  }


  // ---------------------------------------------------------------------
  // The workshop's side
  // ---------------------------------------------------------------------

  /// Pulls the garage's job cards for this customer and stays subscribed, so
  /// a line ticked off at the counter shows up here without a refresh.
  ///
  /// Safe to call again: it is how the app recovers after a sign-in, a
  /// redeemed code, or the network coming back.
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
  Future<void> refreshWorkshop() async {
    if (!_remote.enabled) return;

    final cards = await _remote.workshopCards();
    final requests = await _remote.myBookingRequests();
    final shop = await _remote.linkedWorkshop();
    if (!mounted) return;

    // An empty answer when we already have cards means the network hiccuped
    // or the link was withdrawn — either way, do not blank the screen over
    // it. A real removal arrives as a card that is simply no longer live.
    final keepCards = cards.isEmpty && state.workshopCards.isNotEmpty;

    var next = state.copyWith(
      workshopCards: keepCards ? null : cards,
      workshop: shop,
    );
    if (!keepCards) next = _mirrorWorkshop(next, cards, requests);
    _set(next);
  }

  // ---------------------------------------------------------------------
  // Mirroring the workshop onto the customer's bookings
  // ---------------------------------------------------------------------

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

  /// Redeems the six-digit code the workshop hands over. Returns null when
  /// it worked, or a sentence to put in front of the person.
  Future<String?> redeemWorkshopCode(String code) async {
    final problem = await _remote.redeemWorkshopCode(code);
    if (problem != null) return problem;
    await connectWorkshop();
    return null;
  }

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
          note: state.workshop.isLinked
              ? 'Slot reserved at ${state.workshop.name}'
              : 'Slot reserved',
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
    unawaited(_tellTheWorkshop(booking));
    return booking;
  }

  /// Puts the booking on the linked workshop's front desk, so the counter
  /// sees it arrive rather than hearing about it on the phone.
  ///
  /// Fire-and-forget on purpose: the booking is already confirmed here, and
  /// a customer who is not linked to any workshop simply has nowhere to send
  /// it. Where several workshops are linked, the request goes to the one
  /// that last had the car.
  Future<void> _tellTheWorkshop(Booking booking) async {
    final links = await _remote.linkedWorkshops();
    if (links.isEmpty) return;

    final recent = state.workshopCards.isEmpty
        ? null
        : state.workshopCards.first.garageId;
    final link = links.firstWhere(
      (l) => l['garage_id'] == recent,
      orElse: () => links.first,
    );
    final gid = link['garage_id'];
    if (gid == null || gid.isEmpty) return;

    final v = state.vehicleById(booking.vehicleId);
    await _remote.requestWorkshopBooking(
      garageId: gid,
      id: 'req-${booking.id}',
      name: state.user?.name ?? '',
      phone: state.user?.phone ?? '',
      at: booking.slot,
      regNo: v?.regNumber ?? '',
      vehicle: v == null ? '' : '${v.brand} ${v.model}',
      note: booking.lines.map((e) => e.name).join(', '),
    );
  }

  void rescheduleBooking(String id, DateTime slot) {
    final b = state.bookingById(id);
    if (b == null) return;
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
  }

  void cancelBooking(String id, String reason) {
    final b = state.bookingById(id);
    if (b == null) return;
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
  }

  void addBookingNote(String id, String note) {
    final b = state.bookingById(id);
    if (b == null) return;
    _replaceBooking(b.copyWith(notes: note));
  }

  List<JobStage> _stageFlow(ServiceMode mode) => [
        JobStage.confirmed,
        if (mode == ServiceMode.pickup) JobStage.pickupAssigned,
        JobStage.received,
        JobStage.inspectionStarted,
        JobStage.inspectionComplete,
        JobStage.estimateSent,
        JobStage.awaitingApproval,
        JobStage.repairInProgress,
        JobStage.qualityCheck,
        JobStage.readyForDelivery,
        JobStage.delivered,
      ];

  List<JobStage> stageFlowFor(Booking b) => _stageFlow(b.mode);

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
    final nextStage =
        approvedIds.isEmpty ? JobStage.qualityCheck : JobStage.repairInProgress;

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
