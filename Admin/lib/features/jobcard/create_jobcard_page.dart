import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/local_image.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/vehicle_art.dart';
import '../../core/widgets/vehicle_card.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/repo/device_contacts.dart';
import '../../data/seed/seed.dart';
import '../../data/seed/vehicle_catalog.dart';
import '../../data/seed/vehicle_media.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../bookings/booking_details.dart';
import '../shared/sms_text.dart';
import '../shared/support_sheet.dart';
import 'panels/checklist_page.dart';
import 'widgets/draft_dents_page.dart';
import 'billing/billing.dart';
import 'intake/damage_panel.dart';
import 'intake/intake_finder.dart';
import 'intake/quick_list.dart';
import 'intake/year_sheet.dart';
import 'widgets/vehicle_parts.dart' show VehicleArea;
import 'widgets/photo_pick.dart';
import 'widgets/vehicle_picker.dart';

/// Opening a card walks six steps, in the order the workshop's own paper
/// intake sheet asks them:
///
/// 1. who the customer is,
/// 2. what the vehicle is, and its insurance,
/// 3. the damage it came in with,
/// 4. what the customer said, and what came in with the vehicle,
/// 5. the services — spares, jobs and lubes — and who does them,
/// 6. when it is promised back, money down, and open the card.
///
/// Steps 1, 2 and 5 are what the invoice is printed from. Steps 3 and 4 are
/// the workshop's own protection at handover, and can be skipped.
///
/// Each step keeps its own draft, so backing up never loses a field.
class CreateJobCardPage extends ConsumerStatefulWidget {
  const CreateJobCardPage({
    super.key,
    this.bookingId,
    this.vehicleId,
    this.estimateId,
  });

  final String? bookingId;
  final String? vehicleId;

  /// An estimate being turned into a card: its customer and lines come with.
  final String? estimateId;

  @override
  ConsumerState<CreateJobCardPage> createState() => _CreateJobCardPageState();
}

/// The modes an advance can be taken in at the counter. Card is left off:
/// a swipe machine settles to the bank days later, and the counter books
/// those as payments on the card, not as money down at intake.
const _advanceModes = [
  PayMode.cash,
  PayMode.upi,
  PayMode.cheque,
  PayMode.netbanking,
];

class _CreateJobCardPageState extends ConsumerState<CreateJobCardPage> {
  final _pager = PageController();
  int _step = 0;

  // --- 1 · customer -------------------------------------------------------
  /// The one search box for a name, a number or a plate.
  final _find = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _gstin = TextEditingController();
  bool _matchedCustomer = false;

  /// The customer on record this card is for, once one has been picked or
  /// the number typed matches one. Their vehicles are offered on step 2.
  String? _ownerId;

  // --- 2 · vehicle --------------------------------------------------------
  final _reg = TextEditingController();
  bool _noPlate = false;
  bool _searched = false;
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _variant = TextEditingController();
  final _km = TextEditingController();
  int _fuelLevel = 0;
  VehicleShape _shape = VehicleShape.fourWheeler;
  FuelType _fuel = FuelType.petrol;

  /// Null until somebody says — the counter, the record, or the customer's
  /// own booking.
  Transmission? _transmission;

  /// The make year off the RC. Printed on the invoice, so it is asked for;
  /// the record or the booking fills it when either knows it.
  int? _year;
  bool _matchedVehicle = false;

  final _insurer = TextEditingController();
  final _policy = TextEditingController();
  final _insurerAddress = TextEditingController();
  final _insurerGstin = TextEditingController();
  DateTime? _policyFrom;
  DateTime? _policyExpiry;
  bool _insuranceOpen = false;

  /// The customer's request this card answers: the one the counter opened
  /// it from, or one the plate turned up. Accepted when the card is created,
  /// so it leaves the Bookings list.
  Booking? _booking;

  /// Pictures taken at the counter before the card exists. They are held as
  /// paths until [_create] has an id to hang them on.
  final _photos = <String>[];
  bool _pickingPhotos = false;

  // --- 3 · damage ---------------------------------------------------------
  final _dents = <DentMark>[];

  // --- 4 · voice and accessories ------------------------------------------
  final _voices = <String>[];
  final _accessories = <String>[];

  // --- 5 · services -------------------------------------------------------
  final _items = <LineItem>[];
  final _estimate = TextEditingController();
  final _mechanics = <String>[];

  // --- 6 · delivery -------------------------------------------------------
  DateTime _promised = DateTime.now()
      .add(const Duration(days: 1))
      .copyWith(hour: 10, minute: 0, second: 0, millisecond: 0, microsecond: 0);

  /// Whether money changed hands at intake. A box to tick rather than an
  /// amount defaulting to zero, because "0" in a field reads as a decision
  /// somebody made, and the mode chips only make sense once one was.
  bool _advanceOn = false;
  final _advance = TextEditingController();
  PayMode _advanceMode = PayMode.cash;
  final _notes = TextEditingController();
  bool _sms = true;

  @override
  void initState() {
    super.initState();
    _sms = ref.read(adminProvider).smsEnabled;
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    _pager.dispose();
    for (final c in [
      _find,
      _name,
      _phone,
      _email,
      _address,
      _gstin,
      _reg,
      _brand,
      _model,
      _variant,
      _km,
      _insurer,
      _policy,
      _insurerAddress,
      _insurerGstin,
      _estimate,
      _advance,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Prefill — an estimate, a booking or a vehicle passed in fills the form.
  // -----------------------------------------------------------------------

  void _prefill() {
    final data = ref.read(adminProvider);
    _applyEstimate();

    if (widget.vehicleId != null) {
      final v = data.vehicleById(widget.vehicleId);
      if (v != null) {
        _applyLookup(reg: v.regNo, jump: true);
        return;
      }
    }

    final booking = widget.bookingId == null
        ? null
        : data.bookings.where((b) => b.id == widget.bookingId).firstOrNull;
    if (booking == null) return;

    _booking = booking;
    _name.text = booking.name;
    _phone.text = booking.phone;
    if (booking.regNo.isNotEmpty) _applyLookup(reg: booking.regNo);
    _applyBooking(booking);
    setState(() {});
    // The customer is who booked, so the card opens on what they booked —
    // the vehicle — with the customer step a tap back on the stepper.
    _goTo(1);
  }

  /// An estimate turned into a card brings who it was for and every line on
  /// it, so the work quoted is the work billed without being typed twice.
  void _applyEstimate() {
    final id = widget.estimateId;
    if (id == null) return;
    final data = ref.read(adminProvider);
    final est = data.tradeDocs.firstWhereOrNull((d) => d.id == id);
    if (est == null) return;

    final who = data.customerById(est.customerId);
    _name.text = est.party.trim().isNotEmpty ? est.party : (who?.name ?? '');
    _phone.text = est.phone.trim().isNotEmpty ? est.phone : (who?.phone ?? '');
    if (who != null) {
      _email.text = who.email;
      _address.text = who.address;
      _gstin.text = who.gstin;
      _ownerId = who.id;
      _matchedCustomer = true;
    } else {
      _address.text = est.address;
      _gstin.text = est.gstin;
    }

    for (final l in est.lines) {
      _items.add(
        LineItem(
          id: newId('li'),
          kind: l.kind,
          name: l.name,
          qty: l.qty,
          rate: l.rate,
          masterId: l.masterId,
          // Zero on an estimate means "no slab given", and a null here bills
          // the line at the card's rate rather than tax-free.
          gstRate: l.gstRate == 0 ? null : l.gstRate,
          unit: l.unit,
        ),
      );
    }
    _estimate.text = est.total.toStringAsFixed(2);
    if (est.note.trim().isNotEmpty && _notes.text.trim().isEmpty) {
      _notes.text = est.note.trim();
    }
    setState(() {});
  }

  /// The car as the customer described it when they booked.
  ///
  /// This used to be one string split on its first space, so a booked
  /// "Maruti Suzuki Swift" opened as brand "Maruti", model "Suzuki Swift",
  /// petrol by default, no gearbox, and a blank KM reading — for a car
  /// whose owner had typed 60,000 km into the app.
  ///
  /// Runs after the plate lookup. The booking is the newer word, so a field
  /// it carries replaces the record's; a field it leaves out leaves the
  /// record alone. An old-style booking with only the one string still
  /// defers to the record, as it always did, because a guess from a string
  /// should not overwrite what the counter typed.
  void _applyBooking(Booking b) {
    final structured = b.brand.trim().isNotEmpty;
    final named = b.brandModel(VehicleCatalog.models.keys);
    if (named.brand.isNotEmpty && (structured || _brand.text.isEmpty)) {
      _brand.text = named.brand;
      _model.text = named.model;
      if (structured) _variant.text = b.variant;
      // The customer app books cars and nothing else.
      _shape = VehicleShape.fourWheeler;
    }
    if (b.fuel != null) _fuel = b.fuel!;
    if (b.transmission != null) _transmission = b.transmission;
    if (b.year != null && b.year! > 0) _year = b.year;
    // Newer than the last card's reading, which the lookup put there.
    if (b.odometerKm != null && b.odometerKm! > 0) {
      _km.text = '${b.odometerKm}';
    }

    for (final said in [b.note.trim(), b.customerNote.trim()]) {
      if (said.isNotEmpty && !_voices.contains(said)) _voices.add(said);
    }
    if (b.pickup && _notes.text.trim().isEmpty) {
      _notes.text = 'Customer asked for pick & drop'.tr;
    }
  }

  /// Look the plate up. A hit fills the whole form — vehicle and owner; a
  /// miss simply means the vehicle is new, which is a normal outcome, not an
  /// error.
  ///
  /// [reg] is the plate to look up; left out, it is whatever is in the
  /// plate field. [jump] moves on to the vehicle step, for a lookup started
  /// from the customer step's search.
  void _applyLookup({String? reg, bool jump = false}) {
    final data = ref.read(adminProvider);
    if (reg != null) _reg.text = reg.trim();
    final typed = _reg.text.trim();

    final v = data.vehicleByReg(typed);
    if (v == null) {
      setState(() {
        _searched = typed.isNotEmpty;
        _matchedVehicle = false;
      });
      _followBooking(data.openBookingByReg(typed), ownerOnRecord: false);
      if (jump) _goTo(1);
      return;
    }

    _brand.text = v.brand;
    _model.text = v.model;
    _variant.text = v.variant;
    _fuel = v.fuel;
    _transmission = v.transmission;
    _year = v.year;
    _shape = v.shape;

    // Insurance comes back with the car, so a claim job is not typed twice.
    if (v.insurer.isNotEmpty) _insurer.text = v.insurer;
    if (v.policyNo.isNotEmpty) _policy.text = v.policyNo;
    if (v.insuranceFrom != null) _policyFrom = v.insuranceFrom;
    if (v.insuranceExpiry != null) _policyExpiry = v.insuranceExpiry;
    if (v.insurerAddress.isNotEmpty) _insurerAddress.text = v.insurerAddress;
    if (v.insurerGstin.isNotEmpty) _insurerGstin.text = v.insurerGstin;

    final owner = data.customerById(v.customerId);
    if (owner != null) {
      _name.text = owner.name;
      _phone.text = owner.phone;
      _email.text = owner.email;
      if (owner.address.isNotEmpty) _address.text = owner.address;
      if (owner.gstin.isNotEmpty) _gstin.text = owner.gstin;
      _matchedCustomer = true;
      _ownerId = owner.id;
    }

    // Carry the last reading forward so the counter types the difference.
    final last = data.historyOf(v.id).firstOrNull;
    if (last != null && _km.text.isEmpty) _km.text = '${last.odometerKm}';

    setState(() {
      _searched = true;
      _matchedVehicle = true;
      _noPlate = false;
    });
    _followBooking(data.openBookingByReg(typed), ownerOnRecord: owner != null);
    if (jump) _goTo(1);
  }

  /// A plate typed on a new card may be one the customer has just booked
  /// from their app. Their booking then fills the form exactly as opening
  /// the card from the Bookings list would, and is the one accepted.
  ///
  /// Searching on to another plate lets go of it again, and takes back what
  /// the customer said, so one car's complaints do not ride onto another's
  /// card. A card opened from a booking keeps that booking: it was chosen.
  void _followBooking(Booking? found, {required bool ownerOnRecord}) {
    if (widget.bookingId != null || found?.id == _booking?.id) return;
    final was = _booking;
    if (was != null) {
      _voices.removeWhere(
        (v) => v == was.note.trim() || v == was.customerNote.trim(),
      );
      if (_notes.text == 'Customer asked for pick & drop'.tr) _notes.clear();
    }
    _booking = found;
    if (found != null) {
      // The owner on record wins, as it does when the card is opened from
      // the booking; a car new to the workshop takes whoever booked it.
      if (!ownerOnRecord) {
        _name.text = found.name;
        _phone.text = found.phone;
      }
      _applyBooking(found);
    }
    setState(() {});
  }

  /// A number typed that is already on record brings the rest of that
  /// customer with it — and their vehicles, offered on the next step.
  void _applyCustomerByPhone() {
    final existing = ref.read(adminProvider).customerByPhone(_phone.text);
    if (existing == null) {
      if (_matchedCustomer || _ownerId != null) {
        setState(() {
          _matchedCustomer = false;
          _ownerId = null;
        });
      }
      return;
    }
    _name.text = existing.name;
    if (_email.text.isEmpty) _email.text = existing.email;
    if (_address.text.isEmpty) _address.text = existing.address;
    if (_gstin.text.isEmpty) _gstin.text = existing.gstin;
    setState(() {
      _matchedCustomer = true;
      _ownerId = existing.id;
    });
  }

  /// A customer picked from the search. Everything on record replaces what
  /// was typed: the counter picked them precisely so as not to type it.
  void _pickCustomer(Customer c) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _name.text = c.name;
      _phone.text = c.phone;
      _email.text = c.email;
      _address.text = c.address;
      _gstin.text = c.gstin;
      _matchedCustomer = true;
      _ownerId = c.id;
      _find.clear();
    });
  }

  /// A vehicle picked from the search: the plate lookup, run as if typed on
  /// the vehicle step, which is where the counter lands — the customer is
  /// already filled in by then.
  void _pickVehicle(String reg) {
    _find.clear();
    _applyLookup(reg: reg, jump: true);
  }

  // -----------------------------------------------------------------------
  // Navigation
  // -----------------------------------------------------------------------

  static const _lastStep = 5;

  void _goTo(int step) {
    final clamped = step.clamp(0, _lastStep);
    // Tapping Next twice, or Back on the first step, used to re-run the
    // animation from where it already was and read as a twitch.
    if (clamped == _step) return;
    // The keyboard is almost always up when Next is pressed, and it only
    // drops when the field that owned it is disposed — which is at the *end*
    // of the slide. The page would travel, land, and then the whole scaffold
    // would jump as the inset collapsed. Dismissing it first puts both
    // movements on the same frame, so they read as one.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = clamped);
    _pager.animateToPage(
      clamped,
      duration: Motion.base,
      curve: Motion.emphasized,
    );
  }

  /// A plate long enough to be one, or a vehicle that genuinely has none.
  ///
  /// This asks the *field*, not [_noPlate]. The two disagree whenever the
  /// counter switches the toggle on and then finds a plate on the chassis
  /// after all — which is the normal way a walk-in goes, and used to leave
  /// them stuck behind a greyed-out box.
  bool get _plateOk {
    final typed = _reg.text.trim();
    return typed.isEmpty ? _noPlate : typed.length >= 4;
  }

  /// What step 1 still needs, or null when it is done. Said in words: a
  /// Next that only greys out leaves the counter hunting for the reason.
  String? get _customerMissing {
    if (_name.text.trim().isEmpty) return 'Enter the customer’s name'.tr;
    if (_phone.text.trim().length < 10) {
      return 'Enter a 10-digit contact number'.tr;
    }
    return null;
  }

  String? get _vehicleMissing {
    if (!_plateOk) {
      return 'Enter the vehicle number, or switch on No Vehicle Number'.tr;
    }
    if (_brand.text.trim().isEmpty) return 'Pick the brand'.tr;
    if (_model.text.trim().isEmpty) return 'Pick the model'.tr;
    if (_year == null || _year! <= 0) return 'Pick the make year'.tr;
    return null;
  }

  /// Next on a step that is not finished says what is missing instead of
  /// moving on.
  void _next(int from, String? missing) {
    if (missing != null) {
      GFeedback.error(context, missing);
      return;
    }
    _goTo(from + 1);
  }

  double get _itemsTotal => _items.fold<double>(0, (s, e) => s + e.amount);

  // -----------------------------------------------------------------------
  // Create
  // -----------------------------------------------------------------------

  void _create() {
    if (_customerMissing case final why?) {
      _goTo(0);
      GFeedback.error(context, why);
      return;
    }
    if (_vehicleMissing case final why?) {
      _goTo(1);
      GFeedback.error(context, why);
      return;
    }
    final ctrl = ref.read(adminProvider.notifier);

    final customer = ctrl.upsertCustomer(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      gstin: _gstin.text.trim(),
    );
    final vehicle = ctrl.upsertVehicle(
      customerId: customer.id,
      regNo: _noPlate && _reg.text.trim().isEmpty
          ? 'NO-PLATE-${DateTime.now().millisecondsSinceEpoch % 100000}'
          : _reg.text.trim(),
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      variant: _variant.text.trim(),
      fuel: _fuel,
      transmission: _transmission,
      shape: _shape,
      year: _year,
      insurer: _insurer.text.trim(),
      policyNo: _policy.text.trim(),
      insuranceFrom: _policyFrom,
      insuranceExpiry: _policyExpiry,
      insurerAddress: _insurerAddress.text.trim(),
      insurerGstin: _insurerGstin.text.trim(),
    );

    // This card's choice. It used to be written into the workshop-wide
    // setting, so switching SMS off for one customer switched it off for
    // every card after.
    final card = ctrl.createJobCard(
      customerId: customer.id,
      vehicleId: vehicle.id,
      // Optional on the form: a car towed in with a dead cluster has no
      // reading to give, and holding the card hostage to one only got "0"
      // typed in to get past it.
      odometerKm: int.tryParse(_km.text.trim()) ?? 0,
      fuelPercent: _fuelLevel,
      promisedAt: _promised,
      voices: _voices,
      accessories: _accessories,
      mechanicIds: _mechanics,
      sms: _sms,
    );

    // A card opened on a verbal quote alone still needs something to bill
    // against, so the estimate becomes its single labour line.
    final quoted = _quoted;
    if (_items.isEmpty && quoted > 0) {
      ctrl.addItem(
        card.id,
        kind: LineKind.job,
        name: 'Labour charge'.tr,
        rate: quoted,
      );
    }

    for (final li in _items) {
      ctrl.addItem(
        card.id,
        kind: li.kind,
        name: li.name,
        partNo: li.partNo,
        qty: li.qty,
        rate: li.rate,
        mechanicId: li.mechanicId,
        master: ref.read(adminProvider).masterById(li.masterId),
        gstRate: li.gstRate,
        unit: li.unit,
      );
    }
    for (final d in _dents) {
      ctrl.addDent(card.id, d);
    }
    if (_photos.isNotEmpty) {
      ctrl.addPhotos(card.id, _photos);
    }
    if (_notes.text.trim().isNotEmpty) {
      ctrl.setWorkNote(card.id, _notes.text.trim());
    }
    final advance = _advanceTaken;
    if (advance > 0) {
      ctrl.addPayment(
        card.id,
        amount: advance,
        mode: _advanceMode,
        note: 'Jobcard Payment Advance'.tr,
        // Taken in full even when the card has no lines yet — it used to be
        // cut to the (zero) balance and vanish.
        advance: true,
      );
    }

    final booking = _booking;
    if (booking != null) {
      ctrl.acceptBooking(booking.id, jobCardId: card.id);
    }
    // Only once the card exists, so an abandoned intake leaves the estimate
    // open to be converted again.
    if (widget.estimateId != null) {
      ctrl.markEstimateConverted(widget.estimateId!);
    }

    // There is no SMS gateway: with this card's switch on, the welcome
    // message opens in the phone's SMS app and the counter taps Send there.
    // Started before the page is replaced — everything it reads through
    // `ref` is read before its first await, while this page is still here.
    if (_sms) sendNewCardSms(context, ref, card.id, 'Job card created');
    GFeedback.success(context, 'Jobcard Created Successfully!!'.tr);
    // Step 7 of the owner's flow: the card opens on the mechanic copy, ready
    // to hand to the floor; the invoice (step 8) is a tab away.
    context.pushReplacement('/job/${card.id}?doc=mechanicCopy');
  }

  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_step - 1);
      },
      child: Scaffold(
        backgroundColor: p.canvas,
        appBar: _CockpitIntakeHeader(
          step: _step,
          onStep: _goTo,
          onBack: () => _step == 0 ? context.pop() : _goTo(_step - 1),
          onHelp: () => GFeedback.info(
            context,
            'Customer, vehicle, damage, what they said, the work, then the promise. Damage and voice can be skipped.'
                .tr,
          ),
        ),
        body: PageView(
          controller: _pager,
          physics: const NeverScrollableScrollPhysics(),
          // Builds the neighbouring step before the slide starts rather than
          // on its first frame. A step is a few hundred widgets deep, and
          // inflating one inside frame one of the animation is exactly the
          // stutter you see at the moment of the tap.
          allowImplicitScrolling: true,
          // [_goTo] has already moved the stepper, so by the time the page
          // settles this is a no-op — and a setState here rebuilds every
          // step mid-slide for nothing. Only a scroll that started elsewhere
          // gets through.
          onPageChanged: (i) {
            if (i != _step) setState(() => _step = i);
          },
          children: [
            _customerStep(),
            _vehicleStep(),
            _damageStep(),
            _voiceStep(),
            _servicesStep(),
            _deliveryStep(),
          ],
        ),
      ),
    );
  }

  /// A step's frame: the form scrolling between an optional pinned head and
  /// the bar that moves the card on.
  Widget _stepFrame({
    Widget? pinned,
    required List<Widget> children,
    required Widget bar,
  }) {
    return Column(
      children: [
        ?pinned,
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              Gap.page,
              pinned == null ? Gap.md : Gap.lg,
              Gap.page,
              Gap.xxl,
            ),
            children: children,
          ),
        ),
        GBottomBar(child: bar),
      ],
    );
  }

  // --- 1 · customer -------------------------------------------------------

  Widget _customerStep() {
    final p = context.c;
    final query = _find.text.trim();
    return _stepFrame(
      children: [
        _Band(
          label: 'Customer Details'.tr,
          blurb: 'Who is bringing it in'.tr,
          icon: Icons.person_rounded,
          tone: GTone.success,
          action: 'Contacts'.tr,
          actionIcon: Icons.person_add_alt_rounded,
          onAction: _pickFromCustomers,
        ),
        const SizedBox(height: Gap.sm),
        const _PrintHint(printed: true),
        const SizedBox(height: Gap.md),
        GField(
          hint: 'Search customer, phone or vehicle no.'.tr,
          controller: _find,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.search,
          prefix: Icon(Icons.search_rounded, size: 19, color: p.inkMuted),
          suffix: query.isEmpty
              ? null
              : Pressable(
                  onTap: () => setState(_find.clear),
                  scale: 0.85,
                  child: Icon(Icons.close_rounded, size: 18, color: p.inkFaint),
                ),
          onChanged: (_) => setState(() {}),
        ),
        if (query.length >= 2) ...[
          const SizedBox(height: Gap.sm),
          Entrance(
            child: IntakeResults(
              data: ref.read(adminProvider),
              query: query,
              onVehicle: (v) => _pickVehicle(v.regNo),
              onCustomer: _pickCustomer,
              onPlate: _pickVehicle,
            ),
          ),
        ],
        const SizedBox(height: Gap.lg),
        // Everything the customer typed, whole and first.
        if (_booking != null) ...[
          _BookedCard(booking: _booking!, onContinue: () => _goTo(1)),
          const SizedBox(height: Gap.lg),
        ],
        GField(
          label: 'Customer Name *'.tr,
          hint: 'Rahul Sharma'.tr,
          controller: _name,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Contact No *'.tr,
          hint: '9876543210',
          controller: _phone,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: (_) {
            _applyCustomerByPhone();
            setState(() {});
          },
          suffix: _matchedCustomer
              ? Icon(Icons.check_circle_rounded, size: 18, color: p.success)
              : null,
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Email (optional)'.tr,
          hint: 'xyz@gmail.com',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Address (optional)'.tr,
          hint: '12, MG Road, Bengaluru'.tr,
          controller: _address,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Customer GSTIN (optional)'.tr,
          hint: '29ABCDE1234F1Z5',
          controller: _gstin,
          textCapitalization: TextCapitalization.characters,
        ),
      ],
      bar: _StepNav(
        ready: _customerMissing == null,
        onNext: () => _next(0, _customerMissing),
      ),
    );
  }

  /// Everyone the counter could mean: the shop's own customers first, then
  /// the phone's address book behind it, one row per number.
  ///
  /// It used to offer the saved customers alone, so on a phone whose shop had
  /// not opened a card yet the button answered "No saved customers yet" and
  /// did nothing else — while the first-run screen had already asked for
  /// contacts, and the manifests already carried the permission.
  Future<void> _pickFromCustomers() async {
    final data = ref.read(adminProvider);

    // Keyed by number, so a customer already on record wins over the same
    // number sitting in the phone book under a nickname.
    final saved = <String, ContactPick>{};
    for (final c in data.customers) {
      final phone = c.phone.trim();
      if (phone.isEmpty) continue;
      saved[phone] = (name: c.name, phone: phone, email: c.email);
    }

    final book = await DeviceContacts.read();
    if (!mounted) return;

    final people = <String, ContactPick>{...saved};
    for (final p in book.people) {
      people.putIfAbsent(p.phone, () => p);
    }

    if (people.isEmpty) {
      _reportEmptyBook(book.access);
      return;
    }

    // The picker speaks in strings, so hold the row each label came from
    // rather than trying to read the number back out of it afterwards.
    final labels = <String, ContactPick>{};
    for (final p in people.values) {
      labels['${p.name} · ${p.phone}'] = p;
    }
    final options = labels.keys.toList()..sort();

    final fromPhone = people.length - saved.length;
    final picked = await pickFromCatalog(
      context,
      title: 'Add from contacts'.tr,
      subtitle: [
        if (saved.isNotEmpty) '{0} on record'.trf([saved.length]),
        if (fromPhone > 0) '{0} in your phone'.trf([fromPhone]),
      ].join(' · '),
      options: options,
      selected: null,
    );
    if (picked == null || !mounted) return;

    final person = labels[picked];
    if (person == null) {
      // Typed in rather than picked. Digits are a number, anything else is a
      // name; either way it beats dropping the entry on the floor.
      final typed = picked.trim();
      final phone = DeviceContacts.mobile(typed);
      setState(() {
        if (phone.isEmpty) {
          _name.text = typed;
        } else {
          _phone.text = phone;
        }
      });
      if (phone.isNotEmpty) _applyCustomerByPhone();
      return;
    }

    setState(() {
      _name.text = person.name;
      _phone.text = person.phone;
      if (person.email.isNotEmpty) _email.text = person.email;
    });
    // Through the number, so a saved customer brings their address, GSTIN
    // and vehicles too — not just the three fields the picker carries.
    _applyCustomerByPhone();
  }

  /// Why the list came back empty, and what can be done about it.
  void _reportEmptyBook(ContactsAccess access) {
    switch (access) {
      case ContactsAccess.blocked:
        GFeedback.toast(
          context,
          'Contacts are blocked for this app'.tr,
          icon: Icons.contacts_rounded,
          actionLabel: 'Settings'.tr,
          onAction: FlutterContacts.permissions.openSettings,
        );
      case ContactsAccess.denied:
        GFeedback.info(
          context,
          'Allow contacts to pull a customer in from your phone'.tr,
        );
      case ContactsAccess.failed:
        GFeedback.error(context, 'Could not read your contacts'.tr);
      case ContactsAccess.ok:
      case ContactsAccess.unsupported:
        GFeedback.info(context, 'No saved customers yet'.tr);
    }
  }

  // --- 2 · vehicle --------------------------------------------------------

  Widget _vehicleStep() {
    final p = context.c;
    final data = ref.read(adminProvider);
    final owner = data.customerById(_ownerId);
    final theirs = owner == null
        ? const <Vehicle>[]
        : data.vehiclesOf(owner.id);
    final plateTyped = _reg.text.trim();

    return _stepFrame(
      children: [
        _Band(
          label: 'Vehicle Details'.tr,
          blurb: 'What came in'.tr,
          icon: Icons.directions_car_filled_rounded,
          tone: GTone.accent,
        ),
        const SizedBox(height: Gap.sm),
        const _PrintHint(
          printed: true,
          what: 'Make year, brand and model are printed on the invoice',
        ),
        const SizedBox(height: Gap.md),
        // Everything the customer typed, whole and first. The fields below
        // hold it too, but spread down a long form.
        if (_booking != null) ...[
          _BookedCard(booking: _booking!),
          const SizedBox(height: Gap.md),
        ],

        // A returning customer's cars, one tap each — most of them have one
        // or two, and the counter should not be asked to spell a plate the
        // workshop already knows.
        if (theirs.isNotEmpty) ...[
          Text(
            'ON RECORD FOR {0}'.trf([owner!.name.toUpperCase()]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.over.c(p.inkFaint),
          ),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final v in theirs)
                _Choice(
                  label: [
                    Fmt.plate(v.regNo),
                    v.model,
                  ].where((e) => e.trim().isNotEmpty).join(' · '),
                  icon: Icons.directions_car_filled_rounded,
                  selected:
                      _matchedVehicle &&
                      data.vehicleByReg(plateTyped)?.id == v.id,
                  onTap: () => _applyLookup(reg: v.regNo),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
        ],

        GField(
          // Optional only while the vehicle is declared to have no plate;
          // the moment one is typed it is the card's identity again.
          label: _noPlate && plateTyped.isEmpty
              ? 'Vehicle Number'.tr
              : 'Vehicle Number *'.tr,
          hint: _noPlate
              ? 'Found one on the chassis? Type it here'.tr
              : 'RJ14CX4455',
          controller: _reg,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          prefix: const _IndBadge(),
          suffix: Pressable(
            // Live whenever there is something to look up. Gating this on
            // the toggle meant a counter who flipped it by mistake had to
            // find the toggle again before they could search at all.
            onTap: plateTyped.isEmpty ? null : _applyLookup,
            scale: 0.92,
            child: Opacity(
              opacity: plateTyped.isEmpty ? 0.45 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: R.all(R.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, size: 15, color: p.onAccent),
                    const SizedBox(width: 4),
                    Text('Search'.tr, style: AppType.labelM.c(p.onAccent)),
                  ],
                ),
              ),
            ),
          ),
          // Typing a plate is itself the statement that there is one, so
          // the toggle gives way rather than fighting it.
          onChanged: (v) => setState(() {
            _searched = false;
            if (v.trim().isNotEmpty) _noPlate = false;
          }),
          onSubmitted: (_) => _applyLookup(),
        ),
        const SizedBox(height: Gap.sm),
        _NoPlateRow(
          value: _noPlate,
          onChanged: (v) => setState(() {
            _noPlate = v;
            _searched = false;
            if (v) {
              _reg.clear();
              _matchedVehicle = false;
            }
          }),
        ),
        if (_searched && !_matchedVehicle && _booking == null) ...[
          const SizedBox(height: Gap.md),
          Entrance(child: _NewVehicleNote(noPlate: _noPlate)),
        ],
        const SizedBox(height: Gap.lg),

        // The vehicle as it currently reads, above the fields that spell it
        // out. It is the fastest check there is that the counter is opening
        // a card on the right thing: the picture redraws on every pick
        // below, so a mis-tapped model or body style is seen rather than
        // discovered at handover.
        GVehicleCard(
          plate: Fmt.plate(plateTyped),
          title: [
            _brand.text,
            _model.text,
            _variant.text,
          ].where((e) => e.trim().isNotEmpty).join(' '),
          shape: _shape,
          photo: VehicleMedia.photoFor(_brand.text, _model.text, _shape),
          logo: VehicleMedia.logoFor(_brand.text),
          subtitle: [
            _shape.label,
            _fuel.label,
            if (_transmission != null) _transmission!.label,
            if (_year != null && _year! > 0) '$_year',
          ].join('  •  '),
          badge: _matchedVehicle
              ? GPill(label: 'On record'.tr, tone: GTone.success, compact: true)
              : null,
        ),
        const SizedBox(height: Gap.lg),
        GPickerField(
          label: 'Search make, model or variant'.tr,
          value: _brand.text.isEmpty
              ? null
              : [
                  _brand.text,
                  _model.text,
                  _variant.text,
                ].where((e) => e.isNotEmpty).join(' '),
          placeholder: 'Search the catalogue'.tr,
          leadingIcon: Icons.search_rounded,
          onTap: _pickMake,
        ),
        const SizedBox(height: Gap.lg),
        Text('VEHICLE TYPE'.tr, style: AppType.over.c(p.inkFaint)),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            for (final shape in VehicleShape.values) ...[
              Expanded(
                child: VehicleShapeChip(
                  shape: shape,
                  selected: _shape == shape,
                  onTap: () => setState(() => _shape = shape),
                ),
              ),
              if (shape != VehicleShape.values.last)
                const SizedBox(width: Gap.sm),
            ],
          ],
        ),
        const SizedBox(height: Gap.lg),
        // Two to a row: three pickers across a 360dp phone left each one
        // too narrow to show "Maruti Suzuki" without an ellipsis.
        Row(
          children: [
            Expanded(
              child: GPickerField(
                label: 'Make Year *'.tr,
                value: _year == null || _year! <= 0 ? null : '$_year',
                placeholder: 'Select'.tr,
                icon: Icons.calendar_month_rounded,
                onTap: _pickYear,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: GPickerField(
                label: 'Brand *'.tr,
                value: _brand.text.isEmpty ? null : _brand.text,
                placeholder: 'Select'.tr,
                onTap: _pickMake,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: GPickerField(
                label: 'Model *'.tr,
                value: _model.text.isEmpty ? null : _model.text,
                placeholder: 'Select'.tr,
                onTap: _brand.text.isEmpty ? null : _pickModel,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: GPickerField(
                label: 'Variant'.tr,
                value: _variant.text.isEmpty ? null : _variant.text,
                placeholder: 'Select'.tr,
                onTap: _model.text.isEmpty ? null : _pickVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xl),
        Text('FUEL'.tr, style: AppType.over.c(p.inkFaint)),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final f in FuelType.values)
              _Choice(
                label: f.label,
                selected: _fuel == f,
                onTap: () => setState(() => _fuel = f),
              ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GField(
                label: 'Kilometers'.tr,
                hint: '45000',
                controller: _km,
                keyboardType: TextInputType.number,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Flexible, because at three digits the reading and
                      // its label together are wider than half a narrow
                      // phone.
                      Flexible(
                        child: Text(
                          'Fuel Level'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelM.c(p.inkSoft),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(
                        '$_fuelLevel %',
                        style: AppType.money.s(14).c(p.accentInk),
                      ),
                    ],
                  ),
                  Slider(
                    value: _fuelLevel.toDouble(),
                    max: 100,
                    divisions: 20,
                    onChanged: (v) => setState(() => _fuelLevel = v.round()),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        Text('GEARBOX'.tr, style: AppType.over.c(p.inkFaint)),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final t in Transmission.values)
              _Choice(
                label: t.label,
                selected: _transmission == t,
                // A second tap takes it back to "not recorded", which is a
                // real answer for a car nobody has looked at yet.
                onTap: () => setState(
                  () => _transmission = _transmission == t ? null : t,
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.xxl),
        _Band(
          label: 'Vehicle Photos'.tr,
          blurb: 'The condition it came in'.tr,
          icon: Icons.photo_camera_rounded,
          tone: GTone.info,
          action: _photos.isEmpty ? 'Add'.tr : 'Add more'.tr,
          actionIcon: Icons.add_a_photo_rounded,
          onAction: _pickPhotos,
        ),
        const SizedBox(height: Gap.md),
        _PhotoStrip(
          paths: _photos,
          busy: _pickingPhotos,
          onAdd: _pickPhotos,
          onRemove: (path) => setState(() => _photos.remove(path)),
        ),
        const SizedBox(height: Gap.xl),
        _insuranceSection(),
      ],
      bar: _StepNav(
        onBack: () => _goTo(0),
        ready: _vehicleMissing == null,
        onNext: () => _next(1, _vehicleMissing),
      ),
    );
  }

  /// The policy, folded away: most cards are not claim jobs, and six empty
  /// fields at the foot of every intake is six fields to scroll past.
  Widget _insuranceSection() {
    final p = context.c;
    final has =
        _insurer.text.trim().isNotEmpty ||
        _policy.text.trim().isNotEmpty ||
        _policyExpiry != null;
    return Column(
      children: [
        Pressable(
          onTap: () => setState(() => _insuranceOpen = !_insuranceOpen),
          scale: 0.98,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.md,
            ),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: R.all(R.md),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_rounded, size: 18, color: p.info),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Add Insurance Policy Details (optional)'.tr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                ),
                // Said even while folded, so a policy carried in from the
                // record is not mistaken for no policy at all.
                if (has && !_insuranceOpen) ...[
                  GPill(label: 'Added'.tr, tone: GTone.success, compact: true),
                  const SizedBox(width: Gap.xs),
                ],
                AnimatedRotation(
                  turns: _insuranceOpen ? 0.5 : 0,
                  duration: Motion.fast,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: p.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.emphasized,
          child: _insuranceOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: Gap.lg),
                  child: Column(
                    children: [
                      const _PrintHint(printed: true),
                      const SizedBox(height: Gap.md),
                      GField(
                        label: 'Insurer Name'.tr,
                        hint: 'ICICI Lombard'.tr,
                        controller: _insurer,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: Gap.lg),
                      GField(
                        label: 'Policy No'.tr,
                        hint: 'POL1234567',
                        controller: _policy,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: Gap.lg),
                      Row(
                        children: [
                          Expanded(
                            child: GPickerField(
                              label: 'Policy Date'.tr,
                              value: _policyFrom == null
                                  ? null
                                  : Fmt.date(_policyFrom!),
                              placeholder: 'Select'.tr,
                              icon: Icons.event_rounded,
                              onTap: () => _pickPolicyDate(expiry: false),
                            ),
                          ),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: GPickerField(
                              label: 'Expiry Date'.tr,
                              value: _policyExpiry == null
                                  ? null
                                  : Fmt.date(_policyExpiry!),
                              placeholder: 'Select'.tr,
                              icon: Icons.event_rounded,
                              onTap: () => _pickPolicyDate(expiry: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.lg),
                      GField(
                        label: 'Insurer Address'.tr,
                        hint: 'Branch office address'.tr,
                        controller: _insurerAddress,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: Gap.lg),
                      GField(
                        label: 'Insurer GSTIN'.tr,
                        hint: '27AAACI7904G1ZN',
                        controller: _insurerGstin,
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// A policy runs a year, so the start is looked for in the past and the
  /// expiry in the future — each picker opens where its answer usually is.
  Future<void> _pickPolicyDate({required bool expiry}) async {
    final now = DateTime.now();
    final current = expiry ? _policyExpiry : _policyFrom;
    final first = expiry
        ? now.subtract(const Duration(days: 365))
        : now.subtract(const Duration(days: 365 * 5));
    final last = expiry
        ? now.add(const Duration(days: 365 * 5))
        : now.add(const Duration(days: 365));
    var initial = current ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (expiry) {
        _policyExpiry = picked;
      } else {
        _policyFrom = picked;
        // A start date with no expiry is almost always a one-year policy;
        // offering that saves the second picker on most claim jobs.
        _policyExpiry ??= DateTime(
          picked.year + 1,
          picked.month,
          picked.day,
        ).subtract(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickYear() async {
    final picked = await pickMakeYear(context, selected: _year);
    if (picked == null || !mounted) return;
    setState(() => _year = picked);
  }

  /// Camera or gallery, asked before either opens. Nothing is written to the
  /// card here — the card does not exist yet — so the paths are held and
  /// attached once [_create] has an id.
  Future<void> _pickPhotos() async {
    if (_pickingPhotos) return;
    setState(() => _pickingPhotos = true);
    try {
      final paths = await addPhotos(context);
      if (!mounted || paths.isEmpty) return;
      setState(() => _photos.addAll(paths));
    } finally {
      if (mounted) setState(() => _pickingPhotos = false);
    }
  }

  Future<void> _pickMake() async {
    final picked = await pickFromCatalog(
      context,
      title: 'Make'.tr,
      subtitle: '{0} {1} marques, including the ones no longer sold here'.trf([
        VehicleCatalog.makesFor(_shape).length,
        _shape.label.toLowerCase(),
      ]),
      options: VehicleCatalog.makesFor(_shape),
      selected: _brand.text.isEmpty ? null : _brand.text,
      // The marque's own badge, where one is bundled. It is what the counter
      // is scanning for — nobody reads twenty names, they look for the logo.
      logoOf: VehicleMedia.logoFor,
    );
    if (picked == null) return;
    // What the list actually offered, captured before [_shape] can move.
    final offered = VehicleCatalog.makesFor(_shape);
    setState(() {
      _brand.text = picked;
      // The make list was already filtered to the body style the counter
      // chose, so a make taken off it is by definition right for that style.
      // Re-guessing it from the name is how picking Suzuki under Two Wheeler
      // landed in the car table — which has no Suzuki, only Maruti Suzuki —
      // and handed back an empty model list. Same for Mahindra and Force
      // Motors under Truck, and Bajaj and TVS under Three Wheeler: eight
      // pairs in all, each one either blank or showing the wrong catalogue.
      //
      // A make typed in free-hand was on no list, so there is nothing to
      // trust but the guess, and there it still earns its keep.
      if (!offered.contains(picked)) {
        _shape = VehicleMedia.shapeFor(picked);
      }
      if (!VehicleCatalog.modelsOf(picked, _shape).contains(_model.text)) {
        _model.clear();
        _variant.clear();
      }
    });

    // Nobody picks a make and stops. The model was the next tap every single
    // time, so it opens on its own — and because the sheet raises its own
    // keyboard now, the counter is typing 'swi' before the list has settled.
    //
    // Only when the model is genuinely open. Changing the make on a card
    // that already names a model this marque still sells is a correction,
    // not the start of a run, and reopening the list there would be the app
    // arguing with the counter.
    if (!mounted || _model.text.isNotEmpty) return;
    if (VehicleCatalog.modelsOf(picked, _shape).isEmpty) return;
    await _pickModel();
  }

  Future<void> _pickModel() async {
    final picked = await pickFromCatalog(
      context,
      title: 'Model'.tr,
      subtitle: _brand.text,
      options: VehicleCatalog.modelsOf(_brand.text, _shape),
      selected: _model.text.isEmpty ? null : _model.text,
      // This is the answer to "pick Swift and get the Swift": the picture is
      // in the list, so the counter sees what they are choosing before they
      // choose it rather than finding out afterwards on the card.
      photoOf: (model) => VehicleMedia.photoFor(_brand.text, model, _shape),
      exactOf: (model) => VehicleMedia.exactPhotoFor(model) != null,
    );
    if (picked == null) return;
    setState(() {
      _model.text = picked;
      if (!VehicleCatalog.variantsOf(picked).contains(_variant.text)) {
        _variant.clear();
      }
    });
  }

  Future<void> _pickVariant() async {
    final picked = await pickFromCatalog(
      context,
      title: 'Variant'.tr,
      subtitle: '${_brand.text} ${_model.text}',
      options: VehicleCatalog.variantsOf(_model.text),
      selected: _variant.text.isEmpty ? null : _variant.text,
    );
    if (picked == null) return;
    setState(() => _variant.text = picked);
  }

  // --- 3 · damage ---------------------------------------------------------

  /// What was already wrong with the vehicle when it came in.
  ///
  /// Shown on the step itself rather than behind a button: the old slab
  /// said "Dent Marks 3" and nothing else, so checking what had been marked
  /// meant opening the drawing again. Here the marks are read as sentences
  /// — "Rear Right Door — Dent" — which is how they get read back to the
  /// customer before they sign.
  Widget _damageStep() {
    final p = context.c;
    return _stepFrame(
      children: [
        _OwnerStrip(
          name: _name.text,
          vehicle: '${_brand.text} ${_model.text}'.trim(),
          phone: _phone.text,
          history: ref.read(adminProvider).vehicleByReg(_reg.text)?.id,
        ),
        const SizedBox(height: Gap.xl),
        _Band(
          label: 'Dent Marks / Damage'.tr,
          blurb: 'What is already wrong with it'.tr,
          icon: Icons.car_crash_rounded,
          tone: GTone.danger,
        ),
        const SizedBox(height: Gap.sm),
        const _PrintHint(printed: false, optional: true),
        const SizedBox(height: Gap.md),
        const DamageLegend(),
        const SizedBox(height: Gap.md),
        DamageAreaMap(
          marks: _dents,
          shape: _shape,
          onTap: _editDents,
          onArea: (a) => _editDents(area: a),
        ),
        const SizedBox(height: Gap.md),
        GButton.accent(
          label: _dents.isEmpty
              ? 'Mark damage on the car'.tr
              : 'Mark more damage'.tr,
          icon: Icons.draw_rounded,
          onPressed: _editDents,
        ),
        const SizedBox(height: Gap.xl),
        if (_dents.isEmpty)
          Text(
            'Nothing marked. Scratches, dents, broken glass and rust found at handover go here — by area: front, driver, passenger, rear, roof, interior, underbody.'
                .tr,
            style: AppType.bodyS.c(p.inkFaint),
          )
        else ...[
          Text(
            Tr.plural(_dents.length, '{0} MARK', '{0} MARKS'),
            style: AppType.over.c(p.inkFaint),
          ),
          const SizedBox(height: Gap.sm),
          DamageMarkList(
            marks: _dents,
            onRemove: (m) => setState(() => _dents.remove(m)),
          ),
        ],
      ],
      bar: _StepNav(
        onBack: () => _goTo(1),
        onNext: () => _goTo(3),
        nextLabel: _dents.isEmpty ? 'Skip'.tr : 'Next'.tr,
      ),
    );
  }

  Future<void> _editDents({VehicleArea? area}) async {
    final result = await Navigator.of(context).push<List<DentMark>>(
      MaterialPageRoute(
        builder: (_) =>
            DraftDentsPage(marks: _dents, shape: _shape, initialArea: area),
      ),
    );
    if (result == null) return;
    setState(() {
      _dents
        ..clear()
        ..addAll(result);
    });
  }

  // --- 4 · voice and accessories ------------------------------------------

  Widget _voiceStep() {
    final p = context.c;
    final empty = _voices.isEmpty && _accessories.isEmpty;
    return _stepFrame(
      children: [
        _Band(
          label: 'Customer Voice'.tr,
          blurb: 'What the customer says is wrong'.tr,
          icon: Icons.record_voice_over_rounded,
          tone: GTone.info,
          action: 'Skip'.tr,
          actionIcon: Icons.redo_rounded,
          onAction: () => _goTo(4),
        ),
        const SizedBox(height: Gap.sm),
        const _PrintHint(printed: false, optional: true),
        const SizedBox(height: Gap.md),
        QuickList(
          values: _voices,
          tint: p.info,
          hint: 'Type a complaint and add'.tr,
          empty: 'Nothing the customer reported yet.'.tr,
          onAdd: (v) => setState(() => _voices.add(v)),
          onRemove: (v) => setState(() => _voices.remove(v)),
          onMore: _editVoices,
        ),
        const SizedBox(height: Gap.xxl),
        _Band(
          label: 'Vehicle Accessories'.tr,
          blurb: 'What came in with the vehicle'.tr,
          icon: Icons.inventory_2_rounded,
          tone: GTone.accent,
          action: 'Skip'.tr,
          actionIcon: Icons.redo_rounded,
          onAction: () => _goTo(4),
        ),
        const SizedBox(height: Gap.sm),
        const _PrintHint(printed: false, optional: true),
        const SizedBox(height: Gap.md),
        QuickList(
          values: _accessories,
          tint: p.accent,
          hint: 'Type an item and add'.tr,
          empty: 'Nothing recorded as coming in with the vehicle.'.tr,
          onAdd: (v) => setState(() => _accessories.add(v)),
          onRemove: (v) => setState(() => _accessories.remove(v)),
          onMore: _editAccessories,
          moreLabel: '+ Enter details'.tr,
        ),
      ],
      bar: _StepNav(
        onBack: () => _goTo(2),
        onNext: () => _goTo(4),
        nextLabel: empty ? 'Skip'.tr : 'Next'.tr,
      ),
    );
  }

  Future<void> _editVoices() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChecklistPage(
          title: 'Customer Voice'.tr,
          subtitle:
              'Tick what the customer reported. These print on the mechanic copy in the order you add them.'
                  .tr,
          emptyHint: 'Nothing recorded yet — tap a complaint to add it.'.tr,
          icon: Icons.record_voice_over_rounded,
          presets: Seed.voices,
          selected: _voices,
          onSave: (v) => setState(() {
            _voices
              ..clear()
              ..addAll(v);
          }),
        ),
      ),
    );
  }

  Future<void> _editAccessories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChecklistPage(
          title: 'Vehicle Accessories'.tr,
          subtitle:
              'What came in with the vehicle. Ticking it here is what settles an argument at handover.'
                  .tr,
          emptyHint: 'Nothing listed yet — tap an item to add it.'.tr,
          icon: Icons.inventory_2_rounded,
          presets: Seed.accessories,
          selected: _accessories,
          onSave: (v) => setState(() {
            _accessories
              ..clear()
              ..addAll(v);
          }),
        ),
      ),
    );
  }

  // --- 5 · services -------------------------------------------------------

  double get _quoted => double.tryParse(_estimate.text.trim()) ?? 0;

  /// Money down — only once the box says some was taken.
  double get _advanceTaken =>
      _advanceOn ? (double.tryParse(_advance.text.trim()) ?? 0) : 0;

  /// How the quote sits against the lines, said in words instead of left for
  /// the counter to work out.
  ///
  /// The quote is allowed to differ — workshops round off and knock money
  /// off at the counter — but a silent difference is how a card goes out at
  /// the wrong price, so the gap is always named.
  String get _quoteNote {
    final lines = _itemsTotal;
    // Short on purpose: a GField helper is one line and ellipsises the rest,
    // so a note that does not fit is a note nobody reads.
    if (lines <= 0) return 'Becomes the card’s one labour line.'.tr;
    final diff = _quoted - lines;
    if (diff.abs() < 0.01) return 'Matches the lines above.'.tr;
    return diff > 0
        ? '{0} above the lines.'.trf([Fmt.money2(diff)])
        : '{0} under the lines.'.trf([Fmt.money2(-diff)]);
  }

  /// What the card costs and who picks it up.
  ///
  /// Laid out as a bill rather than as a form. The money stays pinned at the
  /// top where it can be read out across the counter, and every figure below
  /// it appears exactly once, so there is nothing to reconcile in your head.
  Widget _servicesStep() {
    final staff = ref.watch(staffProvider);
    final assigned = _mechanics
        .map((id) => staff.firstWhereOrNull((s) => s.id == id))
        .whereType<Staff>()
        .toList();

    return _stepFrame(
      // Pinned, not scrolled. "How much?" gets asked across the counter
      // while the rest of this screen is still being filled in, and an
      // answer you have to scroll for is not an answer.
      pinned: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 0),
        child: AnimatedBuilder(
          // Only the masthead redraws as the money fields are typed into.
          // Rebuilding the step would rebuild the list under your thumb.
          animation: Listenable.merge([_estimate, _advance]),
          builder: (context, _) =>
              _BillMasthead(quoted: _quoted, advance: _advanceTaken),
        ),
      ),
      children: [
        _Band(
          label: 'Add Services'.tr,
          blurb: 'Spares, jobs and the mechanic'.tr,
          icon: Icons.build_rounded,
          tone: GTone.accent,
        ),
        const SizedBox(height: Gap.sm),
        const _PrintHint(printed: true),
        const SizedBox(height: Gap.md),
        _BillSheet(
          items: _items,
          onAdd: _addLines,
          onRemove: (li) => setState(() {
            _items.remove(li);
            _estimate.text = _itemsTotal.toStringAsFixed(2);
          }),
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Quoted to customer *'.tr,
          hint: '0.00',
          controller: _estimate,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          helper: _quoteNote,
          // The note under the field is the whole point of it, so it has to
          // keep up with what is being typed.
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Gap.xl),
        _Band(
          label: 'On the floor'.tr,
          blurb: 'Who is doing the work'.tr,
          icon: Icons.engineering_rounded,
          tone: GTone.accent,
        ),
        const SizedBox(height: Gap.md),
        _MechanicRow(
          assigned: assigned,
          // Inactive staff are off the roll for new work (see the Staff
          // screen); they stay on cards they are already on.
          onAdd: () => _pickMechanics(staff.where((s) => s.active).toList()),
          onRemove: (s) => setState(() => _mechanics.remove(s.id)),
        ),
      ],
      bar: _StepNav(onBack: () => _goTo(3), onNext: () => _goTo(5)),
    );
  }

  Future<void> _addLines(LineKind kind) async {
    final picked = await openBillPicker(context, kind);
    if (picked == null || picked.isEmpty) return;
    setState(() {
      _items.addAll(picked);
      _estimate.text = _itemsTotal.toStringAsFixed(2);
    });
  }

  /// Assign the floor. More than one mechanic can be on a card, so this is
  /// a checklist rather than a picker.
  ///
  /// Built on a plain [Dialog] rather than an [AlertDialog]: the action bar
  /// of an AlertDialog measures its buttons before laying them out, and a
  /// [GButton] cannot be measured that way — the dialog threw on every
  /// layout pass and the screen sat there dead behind it.
  Future<void> _pickMechanics(List<Staff> staff) async {
    if (staff.isEmpty) {
      GFeedback.info(
        context,
        'No active mechanics. Add one, or mark one active, under Staff.'.tr,
      );
      return;
    }
    final draft = [..._mechanics];
    await showDialog<void>(
      context: context,
      barrierColor: context.c.scrim,
      builder: (context) {
        final p = context.c;
        return Dialog(
          backgroundColor: p.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: Gap.xxl,
            vertical: Gap.h2,
          ),
          shape: RoundedRectangleBorder(borderRadius: R.all(R.md)),
          clipBehavior: Clip.antiAlias,
          child: StatefulBuilder(
            builder: (context, setDialog) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: Gap.md),
                  color: p.surfaceSunken,
                  child: Text(
                    'Select Mechanic'.tr,
                    textAlign: TextAlign.center,
                    style: AppType.h2.c(p.ink),
                  ),
                ),
                // Flexible, so a long team scrolls inside the dialog instead
                // of pushing DONE off the bottom of the phone.
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                    children: [
                      for (final s in staff)
                        CheckboxListTile(
                          value: draft.contains(s.id),
                          title: Text(s.name, style: AppType.labelL.c(p.ink)),
                          subtitle: s.skill.isEmpty
                              ? null
                              : Text(
                                  s.skill,
                                  style: AppType.bodyS.c(p.inkMuted),
                                ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: p.accent,
                          onChanged: (v) => setDialog(() {
                            if (v ?? false) {
                              draft.add(s.id);
                            } else {
                              draft.remove(s.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.sm,
                    Gap.lg,
                    Gap.lg,
                  ),
                  child: GButton(
                    label: 'DONE',
                    kind: GButtonKind.primary,
                    size: GButtonSize.md,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _mechanics
        ..clear()
        ..addAll(draft);
    });
  }

  // --- 6 · delivery -------------------------------------------------------

  Widget _deliveryStep() {
    final p = context.c;
    final bank = ref.read(adminProvider).primaryBank?.title;
    return _stepFrame(
      children: [
        _Band(
          label: 'Delivery'.tr,
          blurb: 'What the customer was told at the counter'.tr,
          icon: Icons.event_available_rounded,
          tone: GTone.info,
        ),
        const SizedBox(height: Gap.md),
        // Two pickers, not one that runs date-then-time: the time is the
        // thing most often changed on its own ("make it 6, not 10"), and a
        // combined picker made that a trip through the calendar first.
        Row(
          children: [
            Expanded(
              flex: 3,
              child: GPickerField(
                label: 'Delivery Date'.tr,
                value: Fmt.date(_promised),
                placeholder: 'Set'.tr,
                icon: Icons.event_rounded,
                onTap: _pickPromisedDate,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              flex: 2,
              child: GPickerField(
                label: 'Time'.tr,
                value: Fmt.time(_promised),
                placeholder: 'Set'.tr,
                icon: Icons.schedule_rounded,
                onTap: _pickPromisedTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xl),
        Container(
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: R.all(R.lg),
            border: Border.all(
              color: _advanceOn ? p.success.withValues(alpha: 0.45) : p.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: _advanceOn,
                onChanged: (v) => setState(() => _advanceOn = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: p.success,
                shape: RoundedRectangleBorder(borderRadius: R.all(R.lg)),
                title: Text('Advance taken'.tr, style: AppType.labelL.c(p.ink)),
                subtitle: Text(
                  'Settles against the invoice'.tr,
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ),
              AnimatedSize(
                duration: Motion.base,
                curve: Motion.emphasized,
                child: !_advanceOn
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Gap.lg,
                          0,
                          Gap.lg,
                          Gap.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GField(
                              label: 'Amount *'.tr,
                              hint: '0',
                              controller: _advance,
                              keyboardType: TextInputType.number,
                              textCapitalization: TextCapitalization.none,
                              prefix: Text(
                                '₹',
                                style: AppType.money.s(15).c(p.inkSoft),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                            ),
                            const SizedBox(height: Gap.md),
                            Wrap(
                              spacing: Gap.sm,
                              runSpacing: Gap.sm,
                              children: [
                                for (final m in _advanceModes)
                                  _Choice(
                                    label: m.label,
                                    icon: m.icon,
                                    selected: _advanceMode == m,
                                    onTap: () =>
                                        setState(() => _advanceMode = m),
                                  ),
                              ],
                            ),
                            const SizedBox(height: Gap.sm),
                            // Where the money lands in the books, so the
                            // counter knows which drawer — or which account
                            // — it has to tally against tonight.
                            Row(
                              children: [
                                Icon(
                                  _advanceMode == PayMode.cash
                                      ? Icons.payments_rounded
                                      : Icons.account_balance_rounded,
                                  size: 14,
                                  color: p.inkFaint,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _advanceMode == PayMode.cash
                                        ? 'Goes to Cash in Hand'.tr
                                        : 'Goes to {0}'.trf([
                                            bank ?? 'your bank account'.tr,
                                          ]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.bodyS.c(p.inkMuted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        _Band(
          label: 'Notes for the floor'.tr,
          blurb: 'Read before the spanner comes out'.tr,
          icon: Icons.sticky_note_2_rounded,
          tone: GTone.warning,
        ),
        const SizedBox(height: Gap.md),
        GField(
          hint: 'Customer is waiting — wash before delivery…'.tr,
          controller: _notes,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
      bar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Beside Create rather than buried in the form: this is something
          // that happens when you press the button, not a field you fill in.
          _SmsRow(
            value: _sms,
            phone: _phone.text.trim(),
            onChanged: (v) => setState(() => _sms = v),
          ),
          const SizedBox(height: Gap.md),
          // The money, read out in full on its own line. It used to ride on
          // the button and was cut to "₹1,5…" — the one figure the counter
          // reads to the customer before tapping.
          AnimatedBuilder(
            animation: Listenable.merge([_estimate, _advance]),
            builder: (context, _) => _MoneyStrip(
              quoted: _quoted,
              advance: _advanceTaken,
            ),
          ),
          const SizedBox(height: Gap.md),
          _StepNav(
            onBack: () => _goTo(4),
            onNext: _create,
            nextLabel: 'Open Job Card'.tr,
            nextIcon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }

  Future<void> _pickPromisedDate() async {
    final now = DateTime.now();
    final first = now.subtract(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: _promised.isBefore(first) ? now : _promised,
      firstDate: first,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    setState(
      () => _promised = DateTime(
        date.year,
        date.month,
        date.day,
        _promised.hour,
        _promised.minute,
      ),
    );
  }

  Future<void> _pickPromisedTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_promised),
    );
    if (time == null || !mounted) return;
    setState(
      () => _promised = DateTime(
        _promised.year,
        _promised.month,
        _promised.day,
        time.hour,
        time.minute,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/// High-tech Cockpit Intake Header with segmented telemetry stage indicators.
/// The paint the intake screen is finished in.
///
/// The dashboard opens on a warm orange canopy, and opening a card is the
/// action that canopy is built around — so the intake wears the same coat
/// rather than the carbon console it used to. Every value is derived from the
/// palette's accent, so retinting the app retints both screens together.
class _Intake {
  const _Intake._();

  static Color top(AppPalette p) => Color.lerp(p.accent, Colors.white, 0.10)!;
  static Color mid(AppPalette p) => Color.lerp(p.accent, Colors.black, 0.08)!;
  static Color deep(AppPalette p) => Color.lerp(p.accent, Colors.black, 0.28)!;

  static LinearGradient gradient(AppPalette p) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [top(p), mid(p), deep(p)],
    stops: const [0.0, 0.52, 1.0],
  );

  /// The button that moves the card forward, everywhere it appears.
  static LinearGradient forward(AppPalette p) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [top(p), deep(p)],
  );
}

/// The intake masthead: an orange panel with a wave cut out of its foot, and
/// the six steps laid out underneath it.
///
/// The stepper is on the canvas rather than on the orange, which is not just
/// taste. Five of the six nodes are always inactive, and an inactive node
/// has to be low-contrast to read as inactive — on a saturated panel there is
/// no low-contrast grey that is still legible, so they would all have to be
/// white and the thing would stop showing which step you are on.
class _CockpitIntakeHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const _CockpitIntakeHeader({
    required this.step,
    required this.onBack,
    required this.onHelp,
    required this.onStep,
  });

  final int step;
  final VoidCallback onBack;
  final VoidCallback onHelp;

  /// Jumping back to a step already finished. Forward is not offered — the
  /// steps validate in order, and a stepper that lets you skip validation is
  /// a stepper that hands the counter a half-built card.
  final ValueChanged<int> onStep;

  /// One word each: six nodes share a 320dp track on a 360dp phone, and a
  /// label that wraps pushes the page under the masthead down a line.
  static const _labels = [
    'Customer',
    'Vehicle',
    'Damage',
    'Voice',
    'Services',
    'Delivery',
  ];
  static const _blurbs = [
    'Who the card is for',
    'What came in, and its insurance',
    'Mark what is already damaged',
    'What they said, what came with it',
    'Spares, jobs and who does them',
    'When it is due back, and money down',
  ];

  /// Panel, wave overhang and stepper. Fixed, because a masthead that changes
  /// height between steps makes the page under it jump on every Next.
  @override
  Size get preferredSize => const Size.fromHeight(206);

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    // The height is fixed (see [preferredSize]), so the copy inside it can
    // only grow so far with the system font before it runs out of room.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: _masthead(p),
    );
  }

  Widget _masthead(AppPalette p) {
    return Container(
      color: p.canvas,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipPath(
            clipper: const _WaveFoot(),
            child: Container(
              decoration: BoxDecoration(gradient: _Intake.gradient(p)),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.md,
                    Gap.sm,
                    Gap.md,
                    30,
                  ),
                  child: Stack(
                    children: [
                      // The vehicle, low in the corner and low in contrast:
                      // it is wallpaper, and the title has to win. A drawn car
                      // rather than a glyph, because a glyph at this size
                      // reads as a button somebody forgot to make tappable.
                      Positioned(
                        right: -16,
                        bottom: -20,
                        child: IgnorePointer(
                          child: GArt(Art.vehicle, height: 116, opacity: 0.30),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _Glass(
                                icon: Icons.arrow_back_rounded,
                                onTap: onBack,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'New Job Card'.tr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.h1
                                          .s(21)
                                          .c(Colors.white)
                                          .w(FontWeight.w800),
                                    ),
                                    const SizedBox(height: 1),
                                    // Cross-faded rather than swapped. The
                                    // rails and nodes below already ease
                                    // between steps; a line of text that
                                    // changes instantly in the middle of
                                    // that is the one thing on screen that
                                    // does not move.
                                    AnimatedSwitcher(
                                      duration: Motion.fast,
                                      child: Text(
                                        _blurbs[step.clamp(
                                              0,
                                              _blurbs.length - 1,
                                            )]
                                            .tr,
                                        key: ValueKey(step),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: AppType.bodyS
                                            .s(11.5)
                                            .c(
                                              Colors.white.withValues(
                                                alpha: 0.88,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _Glass(
                                icon: Icons.question_mark_rounded,
                                onTap: onHelp,
                              ),
                            ],
                          ),
                          const SizedBox(height: Gap.sm),
                          // The shop's line, hand-lettered on the wall.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IgnorePointer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final line in const [
                                    'IN TODAY',
                                    'OUT RIGHT',
                                    'BACK SOON',
                                  ])
                                    Text(
                                      line,
                                      style: AppType.over
                                          .s(9.5)
                                          .c(
                                            Colors.white.withValues(alpha: 0.9),
                                          )
                                          .w(FontWeight.w700)
                                          .copyWith(
                                            fontStyle: FontStyle.italic,
                                            height: 1.35,
                                            letterSpacing: 1.6,
                                          ),
                                    ),
                                  const SizedBox(height: 3),
                                  Container(
                                    height: 2,
                                    width: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                      borderRadius: R.all(R.pill),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
            child: _StepTrack(
              step: step,
              labels: [for (final l in _labels) l.tr],
              onStep: onStep,
            ),
          ),
        ],
      ),
    );
  }
}

/// A frosted round button on the orange.
class _Glass extends StatelessWidget {
  const _Glass({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.34),
            width: 1.2,
          ),
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }
}

/// The wave cut out of the bottom of the masthead.
///
/// Two cubics rather than one, so the curve rises on the left and falls again
/// on the right instead of sagging symmetrically like a hammock. The overhang
/// is 30 logical pixels, which is why the panel's bottom padding is 30: the
/// content sits above the deepest point of the cut, never inside it.
class _WaveFoot extends CustomClipper<Path> {
  const _WaveFoot();

  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;
    return Path()
      ..lineTo(0, h - 26)
      ..cubicTo(w * 0.22, h - 2, w * 0.38, h - 34, w * 0.58, h - 22)
      ..cubicTo(w * 0.78, h - 11, w * 0.9, h - 2, w, h - 12)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// Six numbered nodes and the rails between them.
///
/// Each node owns an equal share of the width and draws its own half-rails,
/// left and right of the circle. The rails used to be separate flexible
/// pieces between fixed-width nodes, which worked for four short labels;
/// with six, the labels alone ate the track and the rails shrank to nothing
/// on a narrow phone. Equal cells keep the circles evenly spaced whatever
/// the labels say, and a label too long for its cell scales down instead of
/// overflowing.
class _StepTrack extends StatelessWidget {
  const _StepTrack({
    required this.step,
    required this.labels,
    required this.onStep,
  });

  final int step;
  final List<String> labels;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: _StepNode(
              index: i,
              label: labels[i],
              step: step,
              last: i == labels.length - 1,
              onTap: i < step ? () => onStep(i) : null,
            ),
          ),
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.label,
    required this.step,
    required this.last,
    required this.onTap,
  });

  final int index;
  final String label;
  final int step;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final done = index < step;
    final here = index == step;

    final fill = done || here ? p.accent : (p.isDark ? p.surfaceAlt : p.line);
    final ink = done || here ? p.onAccent : p.inkMuted;

    // A half-rail is lit once the step it leads *to* has been reached: the
    // left one when this node is, the right one when the next node is.
    Widget rail({required bool show, required bool lit}) => Expanded(
      child: show
          ? AnimatedContainer(
              duration: Motion.base,
              curve: Motion.enter,
              height: 2.5,
              color: lit ? p.accent : p.line,
            )
          : const SizedBox.shrink(),
    );

    return Pressable(
      onTap: onTap,
      scale: onTap == null ? 1.0 : 0.9,
      haptic: onTap != null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                rail(show: index != 0, lit: index <= step),
                AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.enter,
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    boxShadow: here
                        ? [
                            BoxShadow(
                              color: p.accent.withValues(alpha: 0.38),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: done
                        ? Icon(Icons.check_rounded, size: 16, color: ink)
                        : Text(
                            '${index + 1}',
                            style: AppType.labelM
                                .s(12.5)
                                .c(ink)
                                .w(FontWeight.w800),
                          ),
                  ),
                ),
                rail(show: !last, lit: index < step),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppType.labelS
                    .s(10.5)
                    .c(here ? p.ink : p.inkMuted)
                    .w(here ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The customer's booking, as they filled it in on their app: who, the car,
/// the slot, and what they asked for.
class _BookedCard extends StatelessWidget {
  const _BookedCard({required this.booking, this.onContinue});

  final Booking booking;

  /// Offered on the customer step only; the vehicle step is already there.
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final b = booking;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.isDark
            ? Color.alphaBlend(p.accent.withValues(alpha: 0.1), p.surface)
            : Colors.white,
        borderRadius: R.all(R.xl),
        border: Border.all(color: p.accent.withValues(alpha: 0.35), width: 1.4),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: R.all(R.xs),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  size: 16,
                  color: p.accent,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  'BOOKED IN THE CUSTOMER APP'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.over.s(10).c(p.accentInk).w(FontWeight.w800),
                ),
              ),
              GPill(
                label: Fmt.friendlyDay(b.at),
                tone: GTone.warning,
                compact: true,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            b.name.isEmpty ? 'Customer'.tr : b.name,
            style: AppType.h2.s(16).c(p.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (b.phone.isNotEmpty)
            Text(b.phone, style: AppType.bodyS.c(p.inkMuted)),
          const SizedBox(height: Gap.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: R.all(R.sm),
            ),
            child: BookingDetails(booking: b),
          ),
          if (onContinue != null) ...[
            const SizedBox(height: Gap.lg),
            GButton.accent(
              label: 'CONTINUE TO VEHICLE'.tr,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: onContinue,
            ),
          ],
        ],
      ),
    );
  }
}

/// The heading on a section of the form.
///
/// A round tinted glyph, a title, a line saying what the section is for, and
/// — where the section has one — the shortcut that fills it in for you.
///
/// The old band was a tinted strip with a dot on it. It marked where a
/// section began and said nothing else, so every form on this screen needed a
/// second line of grey text underneath explaining itself. Folding that line
/// into the heading costs nothing and takes a row out of four separate
/// sections.
/// The pictures taken at the counter, with the tile that adds more sitting
/// first — an empty strip still shows a target to tap, so the section reads
/// the same whether or not anything has been shot yet.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.paths,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> paths;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Pressable(
              onTap: busy ? null : onAdd,
              scale: 0.95,
              child: Container(
                height: 92,
                width: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: p.isDark ? 0.16 : 0.08),
                  borderRadius: R.all(R.md),
                  border: Border.all(
                    color: p.accent.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    // Scaled down rather than clipped: at a large system
                    // font the two lines no longer fit the square.
                    : Padding(
                        padding: const EdgeInsets.all(Gap.xs),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_a_photo_rounded,
                                size: 22,
                                color: p.accent,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Camera or\ngallery'.tr,
                                textAlign: TextAlign.center,
                                style: AppType.bodyS.s(10).c(p.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            );
          }
          final path = paths[i - 1];
          return Pressable(
            onTap: () => previewPhoto(context, path),
            scale: 0.96,
            child: Container(
              height: 92,
              width: 92,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: p.surfaceSunken,
                borderRadius: R.all(R.md),
                border: Border.all(color: p.line),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  localImage(
                    path,
                    fallback: () => Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 20,
                        color: p.inkFaint,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Pressable(
                      onTap: () => onRemove(path),
                      scale: 0.85,
                      child: Container(
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          color: p.scrim,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({
    required this.label,
    required this.tone,
    this.blurb,
    this.icon,
    this.action,
    this.actionIcon,
    this.onAction,
  });

  final String label;
  final GTone tone;

  /// What this section is for, in one line. Null where the title already
  /// says it.
  final String? blurb;

  /// The section's glyph. Falls back to a neutral form icon, so a section
  /// added later still gets a heading that lines up with the others.
  final IconData? icon;

  final String? action;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = toneOf(context, tone);

    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: p.isDark
                ? t.fg.withValues(alpha: 0.18)
                : Color.alphaBlend(t.fg.withValues(alpha: 0.10), t.bg),
            borderRadius: R.all(R.md),
          ),
          child: Icon(icon ?? Icons.description_rounded, size: 22, color: t.fg),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.h2.s(16.5).c(p.ink).w(FontWeight.w800),
              ),
              if (blurb != null)
                Text(
                  blurb!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyS.s(11.5).c(p.inkMuted),
                ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: Gap.sm),
          Pressable(
            onTap: onAction,
            scale: 0.94,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: p.isDark ? t.fg.withValues(alpha: 0.16) : t.bg,
                borderRadius: R.all(R.pill),
                border: Border.all(color: t.fg.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actionIcon != null) ...[
                    Icon(actionIcon, size: 15, color: t.fg),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    action!,
                    style: AppType.labelM.s(12).c(t.fg).w(FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The control that moves the card on to the next step, and the one that
/// takes it back.
///
/// One widget, because Back and Next appeared as a hand-built Row on three
/// separate steps and had drifted apart — different heights, different labels,
/// different idea of which side Back sits on.
class _StepNav extends StatelessWidget {
  const _StepNav({
    required this.onNext,
    this.onBack,
    this.nextLabel,
    this.nextIcon = Icons.arrow_forward_rounded,
    this.ready = true,
  });

  /// Null disables the button outright.
  final VoidCallback? onNext;

  /// False dims the button while leaving it tappable, for a step that is not
  /// finished yet: the tap then says what is missing, where a dead button
  /// left the counter scrolling the form for the field that was holding it.
  final bool ready;

  /// Null drops Back entirely, for the first step, where back means leaving.
  final VoidCallback? onBack;

  /// Defaults to "Next".
  final String? nextLabel;
  final IconData nextIcon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final live = onNext != null && ready;

    return Row(
      children: [
        if (onBack != null) ...[
          Expanded(
            flex: 2,
            child: Pressable(
              onTap: onBack,
              scale: 0.96,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: p.isDark ? p.surface : Colors.white,
                  borderRadius: R.all(R.pill),
                  border: Border.all(color: p.line, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 18, color: p.inkSoft),
                    const SizedBox(width: 6),
                    // Flexible: on a narrow phone this button is a quarter of
                    // the row, and the word has to give before the icon does.
                    Flexible(
                      child: Text(
                        'Back'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelL
                            .s(14.5)
                            .c(p.ink)
                            .w(FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Gap.md),
        ],
        Expanded(
          flex: onBack == null ? 1 : 5,
          child: Pressable(
            onTap: onNext,
            scale: onNext != null ? 0.96 : 1.0,
            haptic: live,
            child: Opacity(
              opacity: live ? 1 : 0.45,
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  gradient: _Intake.forward(p),
                  borderRadius: R.all(R.pill),
                  boxShadow: live
                      ? [
                          BoxShadow(
                            color: p.accent.withValues(alpha: 0.34),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 38),
                    // Shrinks rather than cuts off: "Open Job Card · ₹2,…"
                    // hid the very figure the button exists to show.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          nextLabel ?? 'Next'.tr,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: AppType.labelL
                              .s(15)
                              .c(Colors.white)
                              .w(FontWeight.w800),
                        ),
                      ),
                    ),
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      child: Icon(nextIcon, size: 19, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Customer strip at the top of the damage step, with the two ways to reach
/// them while the car is on the ramp — the step where a question about a
/// scratch most often needs asking.
class _OwnerStrip extends ConsumerWidget {
  const _OwnerStrip({
    required this.name,
    required this.vehicle,
    required this.phone,
    required this.history,
  });

  final String name;
  final String vehicle;
  final String phone;
  final String? history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    // WhatsApp is offered only while it is switched on in Settings.
    final whatsapp = ref.watch(adminProvider.select((s) => s.whatsappEnabled));
    final visits = history == null
        ? 0
        : ref.watch(adminDataProvider).historyOf(history!).length;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Column(
            children: [
              GAvatar(
                initials: Fmt.initials(name.isEmpty ? 'NA' : name),
                size: 44,
                tone: GTone.accent,
              ),
              const SizedBox(height: 4),
              Text(
                visits == 0 ? 'First visit'.tr : 'Last History'.tr,
                style: AppType.labelS.s(9.5).c(p.accentInk),
              ),
            ],
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Customer'.tr : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelL.c(p.ink),
                ),
                Text(
                  'Model: ${vehicle.isEmpty ? '—' : vehicle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyS.c(p.inkMuted),
                ),
                Text(phone, style: AppType.bodyS.c(p.inkMuted)),
              ],
            ),
          ),
          // Through the shared launchers, which tell the counter when there
          // is no app to open; `canLaunchUrl` used to say no and the tap did
          // nothing at all.
          if (phone.length >= 10) ...[
            if (whatsapp) ...[
              _Round(
                icon: Icons.chat_rounded,
                tint: p.success,
                onTap: () => launchWhatsApp(context, phone),
              ),
              const SizedBox(width: Gap.sm),
            ],
            _Round(
              icon: Icons.call_rounded,
              tint: p.inkSoft,
              onTap: () => launchDial(context, phone),
            ),
          ],
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.tint, required this.onTap});

  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: p.line),
        ),
        child: Icon(icon, size: 18, color: tint),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final ink = selected ? (p.isDark ? p.canvas : Colors.white) : p.inkSoft;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppType.labelM.c(ink),
    );
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? p.ink : p.surface,
          borderRadius: R.all(R.pill),
          border: Border.all(color: selected ? p.ink : p.line),
        ),
        child: icon == null
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: ink),
                  const SizedBox(width: 6),
                  Flexible(child: text),
                ],
              ),
      ),
    );
  }
}

/// Whether what is on this step reaches the customer's invoice.
///
/// Said on every step because the counter fills them very differently: an
/// invoice field is typed carefully and spelled right, a handover note is
/// typed fast and for the floor.
class _PrintHint extends StatelessWidget {
  const _PrintHint({required this.printed, this.optional = false, this.what});

  final bool printed;

  /// Adds "optional" — the step can be skipped when there is nothing to say.
  final bool optional;

  /// Overrides the default wording. Passed untranslated; translated here.
  final String? what;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tint = printed ? p.success : p.inkMuted;
    final say =
        what?.tr ??
        (printed
            ? 'Printed on the invoice'.tr
            : optional
            ? 'Optional · not printed on the invoice'.tr
            : 'Not printed on the invoice'.tr);
    return Row(
      children: [
        Icon(
          printed ? Icons.receipt_long_rounded : Icons.visibility_off_rounded,
          size: 14,
          color: tint,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            say,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.labelS.s(11).c(tint),
          ),
        ),
      ],
    );
  }
}

/// The blue IND strip at the left of an Indian number plate, so the field
/// reads as a plate before anything is typed into it.
class _IndBadge extends StatelessWidget {
  const _IndBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3E8C),
        borderRadius: R.all(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 6,
            width: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFCC00),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'IND',
            style: AppType.over.s(7.5).c(Colors.white).w(FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

/// The switch for a vehicle that genuinely has no plate — a walk-in in
/// transit, a new bike off the showroom floor.
class _NoPlateRow extends StatelessWidget {
  const _NoPlateRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.only(left: Gap.md, right: Gap.xs),
      decoration: BoxDecoration(
        color: p.isDark ? p.surfaceAlt : const Color(0xFFF7F8FA),
        borderRadius: R.all(R.md),
        border: Border.all(color: p.lineSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.car_crash_rounded, size: 16, color: p.inkMuted),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Vehicle Number'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelM.s(12.5).c(p.ink).w(FontWeight.w600),
                ),
                Text(
                  'Walk-in transit or unnumbered vehicle'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyS.s(10).c(p.inkFaint),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: p.accent,
            activeTrackColor: p.accent.withValues(alpha: 0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// What a plate search that found nothing means: a new vehicle, to be filled
/// in below — a normal outcome, said as one rather than as an error.
class _NewVehicleNote extends StatelessWidget {
  const _NewVehicleNote({required this.noPlate});

  final bool noPlate;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.fiber_new_rounded, size: 22, color: p.accentInk),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noPlate
                      ? 'No registration number'.tr
                      : 'Vehicle not registered yet'.tr,
                  style: AppType.labelL.c(p.ink),
                ),
                Text(
                  'Fill in the details below — it is saved with the card.'.tr,
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The money, pinned above the bill.
///
/// Three figures and no controls. Balance is the one said out loud at the
/// counter, and the old screen never showed it at all — it had you subtract
/// the advance from the estimate in your head, with the customer waiting.
class _BillMasthead extends StatelessWidget {
  const _BillMasthead({required this.quoted, required this.advance});

  final double quoted;
  final double advance;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final balance = quoted - advance;
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QUOTED', style: AppType.over.s(9).c(p.inkMuted)),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.money2(quoted),
                    maxLines: 1,
                    style: AppType.moneyL.s(24).c(p.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          _MastheadFigure(
            label: 'ADVANCE',
            value: Fmt.money(advance),
            tint: p.inkSoft,
          ),
          Container(
            width: 1,
            height: 26,
            color: p.line,
            margin: const EdgeInsets.symmetric(horizontal: Gap.md),
          ),
          _MastheadFigure(
            label: 'BALANCE',
            value: Fmt.money(balance),
            // Nothing left to collect is good news and reads as such.
            tint: balance > 0 ? p.accentInk : p.success,
          ),
        ],
      ),
    );
  }
}

class _MastheadFigure extends StatelessWidget {
  const _MastheadFigure({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: AppType.over.s(9).c(p.inkMuted)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, style: AppType.money.s(14).c(tint)),
      ],
    );
  }
}

/// The bill: one card, lines grouped under their kind, and a single row of
/// buttons that adds to any of the three.
///
/// The old screen gave each kind its own boxed list with its own coloured
/// header and its own total — three near-identical cards to scroll past and
/// four totals on screen for one bill. Here a kind with no lines takes up no
/// room at all, and the only total is the one at the foot.
class _BillSheet extends StatelessWidget {
  const _BillSheet({
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final List<LineItem> items;
  final ValueChanged<LineKind> onAdd;
  final ValueChanged<LineItem> onRemove;

  static Color _tint(AppPalette p, LineKind kind) => switch (kind) {
    LineKind.job => p.success,
    LineKind.spare => p.info,
    LineKind.lube => p.accent,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final total = items.fold<double>(0, (s, e) => s + e.amount);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.xl,
                Gap.xl,
                Gap.xl,
                Gap.lg,
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 24, color: p.inkFaint),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Nothing on the bill yet'.tr,
                    style: AppType.labelL.c(p.inkSoft),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add the jobs and the spares — or leave it empty and quote a figure below.'
                        .tr,
                    textAlign: TextAlign.center,
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                ],
              ),
            )
          else
            for (final kind in LineKind.values)
              if (items.any((e) => e.kind == kind))
                _KindGroup(
                  kind: kind,
                  tint: _tint(p, kind),
                  lines: items.where((e) => e.kind == kind).toList(),
                  onRemove: onRemove,
                ),

          // One control cluster instead of an Add button per card: adding a
          // spare is the same gesture wherever you are on the bill. A Wrap,
          // because the three in a row ran a few pixels past a 360dp phone.
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final kind in kBillKinds)
                    _AddChip(
                      label: kind.label,
                      tint: _tint(p, kind),
                      onTap: () => onAdd(kind),
                    ),
                ],
              ),
            ),
          ),
          if (items.isNotEmpty)
            Container(
              color: p.surfaceSunken,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      Tr.plural(items.length, '{0} line', '{0} lines'),
                      style: AppType.over.s(9.5).c(p.inkMuted),
                    ),
                  ),
                  Text(
                    Fmt.money2(total),
                    style: AppType.money.s(15).c(p.accentInk),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One kind's lines, under a rule and a label rather than a filled header
/// bar. A band of saturated colour per kind is what made the old screen read
/// as three separate documents stacked on top of each other.
class _KindGroup extends StatelessWidget {
  const _KindGroup({
    required this.kind,
    required this.tint,
    required this.lines,
    required this.onRemove,
  });

  final LineKind kind;
  final Color tint;
  final List<LineItem> lines;
  final ValueChanged<LineItem> onRemove;

  /// The second line of a row, or null when there is nothing to say.
  ///
  /// At a quantity of one the amount already is the rate, so the old
  /// 'Qt*Unit Price: 1 * 1800' under every row was noise in developer
  /// shorthand. A part number, on the other hand, is what somebody actually
  /// reads off the bill at the parts counter.
  static String? _sub(LineItem li) {
    final bits = [
      if (li.qty != 1) '${li.qtyLabel} × ${Fmt.money2(li.rate)}',
      if (li.partNo.isNotEmpty) li.partNo,
    ];
    return bits.isEmpty ? null : bits.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final subtotal = lines.fold<double>(0, (s, e) => s + e.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
          child: Row(
            children: [
              Container(
                height: 7,
                width: 7,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  kind.label.toUpperCase(),
                  style: AppType.over.s(9.5).c(p.inkSoft),
                ),
              ),
              Text(
                Fmt.money2(subtotal),
                style: AppType.labelS.s(11).c(p.inkMuted),
              ),
            ],
          ),
        ),
        for (final li in lines)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.sm, Gap.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        li.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelM.c(p.ink),
                      ),
                      if (_sub(li) case final sub?) ...[
                        const SizedBox(height: 1),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelS.s(10.5).c(p.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Text(Fmt.money2(li.amount), style: AppType.moneyS.c(p.ink)),
                Pressable(
                  onTap: () => onRemove(li),
                  scale: 0.85,
                  // Sized for a thumb, not for the glyph. A draft line is
                  // cheap to remove and cheap to add back, so this does not
                  // need the weight of a red button.
                  child: SizedBox(
                    height: 36,
                    width: 36,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: p.inkFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// `+ Spare`, tinted to match the group it files into.
class _AddChip extends StatelessWidget {
  const _AddChip({
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: R.all(R.pill),
          border: Border.all(color: tint.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 15, color: tint),
            const SizedBox(width: 3),
            Text(label, style: AppType.labelS.c(tint)),
          ],
        ),
      ),
    );
  }
}

/// Who is on the card, as chips you can take off where they stand.
///
/// The old version was a button that opened a dialog, plus a line of text
/// underneath reading `Selected Mech: [Ramesh, Suresh]`, brackets and all —
/// and taking one name off meant reopening the dialog to hunt for it.
class _MechanicRow extends StatelessWidget {
  const _MechanicRow({
    required this.assigned,
    required this.onAdd,
    required this.onRemove,
  });

  final List<Staff> assigned;
  final VoidCallback onAdd;
  final ValueChanged<Staff> onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final s in assigned)
          _MechChip(staff: s, onRemove: () => onRemove(s)),
        Pressable(
          onTap: onAdd,
          scale: 0.94,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            decoration: BoxDecoration(
              borderRadius: R.all(R.pill),
              border: Border.all(color: p.accent.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_add_alt_1_rounded, size: 16, color: p.accent),
                const SizedBox(width: Gap.sm),
                // Flexible: a Wrap bounds its children by the row's width,
                // and at a large system font the label alone outgrew it.
                Flexible(
                  child: Text(
                    assigned.isEmpty ? 'Select Mechanic'.tr : 'Add another'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelM.c(p.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MechChip extends StatelessWidget {
  const _MechChip({required this.staff, required this.onRemove});

  final Staff staff;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: R.all(R.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 30,
            width: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
            child: Text(
              Fmt.initials(staff.name),
              style: AppType.labelS.s(10.5).c(p.onAccent),
            ),
          ),
          const SizedBox(width: Gap.sm),
          // Bounded, because a Wrap hands its children infinite width and a
          // long name would otherwise run straight off the screen.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              staff.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelM.c(p.accentInk),
            ),
          ),
          Pressable(
            onTap: onRemove,
            scale: 0.85,
            child: SizedBox(
              height: 34,
              width: 30,
              child: Icon(Icons.close_rounded, size: 15, color: p.accentInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quote, advance and what is left to collect, side by side.
class _MoneyStrip extends StatelessWidget {
  const _MoneyStrip({required this.quoted, required this.advance});

  final double quoted;
  final double advance;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final due = (quoted - advance).clamp(0, double.infinity).toDouble();
    Widget cell(String label, double v, Color c, {bool strong = false}) =>
        Expanded(
          child: Column(
            children: [
              Text(label, style: AppType.labelS.c(p.inkMuted)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  Fmt.money(v),
                  style: (strong ? AppType.money.s(20) : AppType.money.s(16))
                      .c(c),
                ),
              ),
            ],
          ),
        );
    Widget rule() => Container(width: 1, height: 34, color: p.line);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm + 2),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          cell('Quoted'.tr, quoted, p.ink),
          rule(),
          cell('Advance'.tr, advance, p.success),
          rule(),
          cell('Balance due'.tr, due, p.accentInk, strong: true),
        ],
      ),
    );
  }
}

/// The one thing on this screen that happens to somebody else.
class _SmsRow extends StatelessWidget {
  const _SmsRow({
    required this.value,
    required this.phone,
    required this.onChanged,
  });

  final bool value;
  final String phone;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
      children: [
        Icon(
          value ? Icons.sms_rounded : Icons.sms_failed_outlined,
          size: 17,
          color: value ? p.accent : p.inkFaint,
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(
            // Honest about how it goes: the phone's SMS app opens with the
            // message typed in, and the counter taps Send. Nothing is sent
            // from a server.
            !value
                ? 'No text will be sent'.tr
                : phone.isEmpty
                ? 'Open an SMS to the customer after creating'.tr
                : 'Open an SMS to {0} after creating'.trf([phone]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.bodyS.c(value ? p.inkSoft : p.inkMuted),
          ),
        ),
        // Scaled down, because a full-size switch beside a primary button
        // reads as a second button.
        Transform.scale(
          scale: 0.82,
          child: Switch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
