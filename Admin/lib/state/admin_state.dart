import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/entities.dart';
import '../data/models/enums.dart';
import '../data/repo/admin_data.dart';
import '../data/repo/garage_gateway.dart';
import '../data/repo/local_store.dart';
import '../data/seed/seed.dart';

final _rand = Random();

String newId([String prefix = 'id']) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_rand.nextInt(9999)}';

/// Set in main() before the app builds. Not `final` so tests can rebuild it
/// with a fresh mock between cases.
late LocalStore localStore;

final adminProvider = StateNotifierProvider<AdminController, AdminData>(
    (ref) => AdminController(localStore, ref.read(garageGatewayProvider)));

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
class AdminController extends StateNotifier<AdminData> {
  AdminController(this._store, this._remote) : super(_store.read());

  final LocalStore _store;
  final GarageGateway _remote;

  /// True while a change that came down the wire is being applied, so it is
  /// not pushed straight back up.
  bool _applyingRemote = false;

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
    _set(state.copyWith(
      jobCards: [
        for (final j in state.jobCards) if (j.id == card.id) card else j,
      ],
    ));
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

  void signOut() {
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
  Future<void> connectBackend() async {
    if (!_remote.enabled) return;

    final garage = await _remote.ensureGarage(state.garage);
    if (garage == null) return;
    if (!mounted) return;

    if (state.garage?.id != garage.id || state.garage != garage) {
      _setRemote(state.copyWith(garage: garage, signedIn: true));
    }

    final remote = await _remote.hydrate(state);
    if (!mounted) return;

    if (remote != null && _hasRows(remote)) {
      // Somebody has used this workshop before: upstream is the truth.
      _setRemote(remote);
    } else {
      // A workshop nobody has synced yet. Seed it from this device rather
      // than letting an empty snapshot wipe what is on the counter.
      _remote.push(state);
    }

    _remote.connect(
      garageId: garage.id,
      onCard: _remoteCard,
      onRow: _remoteRow,
      onGone: _remoteGone,
    );
  }

  Future<void> disconnectBackend() => _remote.reset();

  static bool _hasRows(AdminData d) =>
      d.jobCards.isNotEmpty ||
      d.customers.isNotEmpty ||
      d.masters.isNotEmpty ||
      d.staff.isNotEmpty;

  /// A job card another device opened, edited or billed.
  void _remoteCard(JobCard card) {
    final known = state.jobById(card.id) != null;
    _setRemote(state.copyWith(
      jobCards: known
          ? [for (final j in state.jobCards) if (j.id == card.id) card else j]
          : [card, ...state.jobCards],
    ));
  }

  /// A row from one of the garage-scoped tables, already stripped of the
  /// columns the local model does not carry.
  void _remoteRow(String table, Map<String, dynamic> row) {
    List<T> merged<T>(List<T> list, T value, String Function(T) id) {
      final key = id(value);
      return list.any((e) => id(e) == key)
          ? [for (final e in list) if (id(e) == key) value else e]
          : [...list, value];
    }

    switch (table) {
      case 'garages':
        _setRemote(state.copyWith(garage: Garage.fromJson(row)));
      case 'staff':
        _setRemote(state.copyWith(
            staff: merged(state.staff, Staff.fromJson(row), (e) => e.id)));
      case 'garage_customers':
        _setRemote(state.copyWith(
            customers: merged(
                state.customers, Customer.fromJson(row), (e) => e.id)));
      case 'garage_vehicles':
        _setRemote(state.copyWith(
            vehicles:
                merged(state.vehicles, Vehicle.fromJson(row), (e) => e.id)));
      case 'masters':
        _setRemote(state.copyWith(
            masters:
                merged(state.masters, MasterItem.fromJson(row), (e) => e.id)));
      case 'garage_bookings':
        _setRemote(state.copyWith(
            bookings:
                merged(state.bookings, Booking.fromJson(row), (e) => e.id)));
      case 'reviews':
        _setRemote(state.copyWith(
            reviews: merged(state.reviews, Review.fromJson(row), (e) => e.id)));
    }
  }

  void _remoteGone(String table, String id) {
    switch (table) {
      case 'job_cards':
        _setRemote(state.copyWith(
            jobCards: state.jobCards.where((e) => e.id != id).toList()));
      case 'staff':
        _setRemote(state.copyWith(
            staff: state.staff.where((e) => e.id != id).toList()));
      case 'garage_customers':
        _setRemote(state.copyWith(
            customers: state.customers.where((e) => e.id != id).toList()));
      case 'garage_vehicles':
        _setRemote(state.copyWith(
            vehicles: state.vehicles.where((e) => e.id != id).toList()));
      case 'masters':
        _setRemote(state.copyWith(
            masters: state.masters.where((e) => e.id != id).toList()));
      case 'garage_bookings':
        _setRemote(state.copyWith(
            bookings: state.bookings.where((e) => e.id != id).toList()));
      case 'reviews':
        _setRemote(state.copyWith(
            reviews: state.reviews.where((e) => e.id != id).toList()));
    }
  }

  /// Wipe the job cards and customers but keep the workshop and masters.
  void clearJobCards() => _set(state.copyWith(
        jobCards: const [],
        bookings: const [],
        reviews: const [],
        seq: 0,
      ));

  void setThemeMode(ThemeMode mode) => _set(state.copyWith(themeMode: mode));

  // ---------------------------------------------------------------------
  // Workshop profile
  // ---------------------------------------------------------------------

  void saveGarage(Garage garage) {
    _set(state.copyWith(garage: garage));
    // The workshop that was just filled in at setup is the one the backend
    // has been waiting for — join now rather than at the next sign-in.
    if (_remote.enabled && _remote.garageId == null) {
      unawaited(connectBackend());
    }
  }

  void setSmsEnabled(bool v) => _set(state.copyWith(smsEnabled: v));
  void setWhatsappEnabled(bool v) => _set(state.copyWith(whatsappEnabled: v));
  void setReminderDays(int days) =>
      _set(state.copyWith(reminderDaysBefore: days.clamp(1, 30)));
  void setDefaultTaxRate(double rate) =>
      _set(state.copyWith(defaultTaxRate: rate.clamp(0, 0.5)));

  Staff addStaff({required String name, String phone = '', String skill = ''}) {
    final s = Staff(id: newId('st'), name: name, phone: phone, skill: skill);
    _set(state.copyWith(staff: [...state.staff, s]));
    return s;
  }

  void updateStaff(Staff staff) => _set(state.copyWith(
        staff: [
          for (final s in state.staff) if (s.id == staff.id) staff else s,
        ],
      ));

  void removeStaff(String id) => _set(state.copyWith(
        staff: state.staff.where((s) => s.id != id).toList(),
      ));

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
  }) {
    final existing = state.customerByPhone(phone);
    if (existing != null) {
      final merged = existing.copyWith(
        name: name.trim().isEmpty ? existing.name : name.trim(),
        altPhone: altPhone.isEmpty ? existing.altPhone : altPhone,
        email: email.isEmpty ? existing.email : email,
        address: address.isEmpty ? existing.address : address,
      );
      _set(state.copyWith(
        customers: [
          for (final c in state.customers) if (c.id == merged.id) merged else c,
        ],
      ));
      return merged;
    }
    final created = Customer(
      id: newId('c'),
      name: name.trim(),
      phone: phone.trim(),
      altPhone: altPhone,
      email: email,
      address: address,
      createdAt: DateTime.now(),
    );
    _set(state.copyWith(customers: [...state.customers, created]));
    return created;
  }

  void updateCustomer(Customer c) => _set(state.copyWith(
        customers: [
          for (final e in state.customers) if (e.id == c.id) c else e,
        ],
      ));

  /// Find by registration or create against the given customer.
  Vehicle upsertVehicle({
    required String customerId,
    required String regNo,
    required String brand,
    required String model,
    String variant = '',
    FuelType fuel = FuelType.petrol,
    int? year,
    String colour = '',
  }) {
    final existing = state.vehicleByReg(regNo);
    if (existing != null) {
      final merged = existing.copyWith(
        brand: brand.trim().isEmpty ? existing.brand : brand.trim(),
        model: model.trim().isEmpty ? existing.model : model.trim(),
        variant: variant.isEmpty ? existing.variant : variant,
        fuel: fuel,
        year: year ?? existing.year,
        colour: colour.isEmpty ? existing.colour : colour,
      );
      _set(state.copyWith(
        vehicles: [
          for (final v in state.vehicles) if (v.id == merged.id) merged else v,
        ],
      ));
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
      year: year,
      colour: colour,
    );
    _set(state.copyWith(vehicles: [...state.vehicles, created]));
    return created;
  }

  void updateVehicle(Vehicle v) => _set(state.copyWith(
        vehicles: [
          for (final e in state.vehicles) if (e.id == v.id) v else e,
        ],
      ));

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
  }) {
    final now = DateTime.now();
    final seq = state.seq + 1;
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
          label: 'Job card created',
          at: now,
          state: state.smsEnabled ? SmsState.delivered : SmsState.skipped,
        ),
      ],
    );
    _set(state.copyWith(jobCards: [card, ...state.jobCards], seq: seq));
    return card;
  }

  /// Move a card from Open to Complete. Refused while the bill is empty —
  /// there is nothing to hand the customer.
  bool markComplete(String id) {
    final card = _find(id);
    if (card == null || !card.canComplete) return false;
    final now = DateTime.now();
    _put(card.copyWith(
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
          label: 'Work complete',
          at: now,
          state: state.smsEnabled ? SmsState.delivered : SmsState.skipped,
        ),
      ],
    ));
    return true;
  }

  /// Close a card and schedule the reminder trail. A balance may be carried —
  /// it stays visible under Pending Balance until it is collected.
  bool closeJobCard(
    String id, {
    DateTime? nextServiceAt,
    int? nextServiceKm,
  }) {
    final card = _find(id);
    if (card == null || !card.canClose) return false;
    final now = DateTime.now();
    final due = nextServiceAt ?? now.add(const Duration(days: 180));
    final gap = state.reminderDaysBefore;

    SmsEvent reminder(int n, Duration before) => SmsEvent(
          id: newId('s'),
          label: 'Service reminder $n',
          at: DateTime(due.year, due.month, due.day, 8).subtract(before),
          state: state.smsEnabled ? SmsState.scheduled : SmsState.skipped,
        );

    _put(card.copyWith(
      status: JobStatus.closed,
      closedAt: now,
      nextServiceAt: due,
      nextServiceKm: nextServiceKm ?? (card.odometerKm + 5000),
      sms: [
        ...card.sms,
        SmsEvent(
          id: newId('s'),
          label: 'Invoice closed',
          at: now,
          state: state.smsEnabled ? SmsState.delivered : SmsState.skipped,
        ),
        reminder(1, Duration(days: gap)),
        reminder(2, Duration.zero),
        reminder(3, Duration(days: -gap)),
      ],
    ));
    return true;
  }

  /// Send a card back to the floor. Reminders that have not gone out yet are
  /// dropped so a reopened card cannot nag the customer.
  void reopenJobCard(String id) {
    final card = _find(id);
    if (card == null || card.isOpen) return;
    _put(card.copyWith(
      status: JobStatus.open,
      sms: card.sms
          .where((e) => e.state != SmsState.scheduled)
          .toList(),
    ));
  }

  void deleteJobCard(String id) {
    final card = _find(id);
    if (card == null) return;
    // Returning the card returns its parts to the shelf.
    for (final li in card.items) {
      _moveStock(li.masterId, li.qty);
    }
    _set(state.copyWith(
      jobCards: state.jobCards.where((j) => j.id != id).toList(),
    ));
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
    _put(card.copyWith(
      odometerKm: km ?? card.odometerKm,
      fuelPercent: fuelPercent == null
          ? card.fuelPercent
          : fuelPercent.clamp(0, 100),
    ));
  }

  void setPromisedAt(String id, DateTime? at) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(promisedAt: at));
  }

  void addDent(String id, DentMark mark) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(dents: [...card.dents, mark]));
  }

  void updateDent(String id, DentMark mark) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(dents: [
      for (final d in card.dents) if (d.id == mark.id) mark else d,
    ]));
  }

  void removeDent(String id, String dentId) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(
        dents: card.dents.where((d) => d.id != dentId).toList()));
  }

  void addPhotos(String id, List<String> paths) {
    final card = _find(id);
    if (card == null || paths.isEmpty) return;
    _put(card.copyWith(photos: [...card.photos, ...paths]));
  }

  void removePhoto(String id, String path) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(
        photos: card.photos.where((p) => p != path).toList()));
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
      mechanicId: mechanicId ??
          (card.mechanicIds.isEmpty ? null : card.mechanicIds.first),
      masterId: master?.id,
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
    _put(card.copyWith(items: [
      for (final e in card.items) if (e.id == line.id) line else e,
    ]));
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
    _put(card.copyWith(
        items: card.items.where((e) => e.id != lineId).toList()));
    _moveStock(removed.masterId, removed.qty);
  }

  void setLineState(String id, String lineId, WorkState work) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(items: [
      for (final e in card.items)
        if (e.id == lineId) e.copyWith(state: work) else e,
    ]));
  }

  void setLineMechanic(String id, String lineId, String? mechanicId) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(items: [
      for (final e in card.items)
        if (e.id == lineId)
          e.copyWith(mechanicId: mechanicId, clearMechanic: mechanicId == null)
        else
          e,
    ]));
  }

  void setLineRemark(String id, String lineId, String remark) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(items: [
      for (final e in card.items)
        if (e.id == lineId) e.copyWith(remark: remark) else e,
    ]));
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
    _put(card.copyWith(
      estimateSentAt: now,
      sms: [
        ...card.sms,
        SmsEvent(
          id: newId('s'),
          label: 'Estimate shared',
          at: now,
          state: state.smsEnabled ? SmsState.delivered : SmsState.skipped,
        ),
      ],
    ));
  }

  // ---------------------------------------------------------------------
  // Money in
  // ---------------------------------------------------------------------

  /// Collect against a card. Never takes more than the outstanding balance.
  void addPayment(
    String id, {
    required double amount,
    required PayMode mode,
    String note = '',
  }) {
    final card = _find(id);
    if (card == null || amount <= 0) return;
    final take = amount > card.balance ? card.balance : amount;
    if (take <= 0) return;
    _put(card.copyWith(payments: [
      ...card.payments,
      Payment(
        id: newId('p'),
        amount: money(take),
        mode: mode,
        at: DateTime.now(),
        note: note,
      ),
    ]));
  }

  void removePayment(String id, String paymentId) {
    final card = _find(id);
    if (card == null) return;
    _put(card.copyWith(
      payments: card.payments.where((p) => p.id != paymentId).toList(),
    ));
  }

  // ---------------------------------------------------------------------
  // Masters and stock
  // ---------------------------------------------------------------------

  MasterItem addMaster({
    required LineKind kind,
    required String name,
    String partNo = '',
    double rate = 0,
    double stock = 0,
    String unit = 'nos',
  }) {
    final m = MasterItem(
      id: newId('m'),
      kind: kind,
      name: name.trim(),
      partNo: partNo.trim(),
      rate: rate,
      stock: stock,
      unit: unit,
    );
    _set(state.copyWith(masters: [...state.masters, m]));
    return m;
  }

  void updateMaster(MasterItem m) => _set(state.copyWith(
        masters: [
          for (final e in state.masters) if (e.id == m.id) m else e,
        ],
      ));

  void removeMaster(String id) => _set(state.copyWith(
        masters: state.masters.where((m) => m.id != id).toList(),
      ));

  /// Receive stock into the store.
  void restock(String masterId, double qty) => _moveStock(masterId, qty);

  void _moveStock(String? masterId, double delta) {
    if (masterId == null || delta == 0) return;
    final m = state.masterById(masterId);
    if (m == null || !m.tracksStock) return;
    _set(state.copyWith(masters: [
      for (final e in state.masters)
        if (e.id == masterId)
          e.copyWith(stock: (e.stock + delta).clamp(0, double.infinity))
        else
          e,
    ]));
  }

  // ---------------------------------------------------------------------
  // Bookings and feedback
  // ---------------------------------------------------------------------

  void acceptBooking(String bookingId, {String? jobCardId}) => _set(
        state.copyWith(bookings: [
          for (final b in state.bookings)
            if (b.id == bookingId)
              b.copyWith(accepted: true, jobCardId: jobCardId)
            else
              b,
        ]),
      );

  void removeBooking(String bookingId) => _set(state.copyWith(
        bookings: state.bookings.where((b) => b.id != bookingId).toList(),
      ));

  void addBooking(Booking booking) =>
      _set(state.copyWith(bookings: [...state.bookings, booking]));
}
