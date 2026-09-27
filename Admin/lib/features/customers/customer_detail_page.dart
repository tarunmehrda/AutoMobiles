import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/vehicle_card.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/repo/admin_data.dart';
import '../../data/seed/vehicle_media.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../jobcard/widgets/job_card_tile.dart';
import '../shared/support_sheet.dart';

/// One customer: how to reach them, what they drive, and every visit.
class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);
    final customer = data.customerById(id);

    if (customer == null) {
      return Scaffold(
        appBar: GHeader(
          title: 'Customer'.tr,
          subtitle: 'Their vehicles and their history'.tr,
        ),
        body: GEmptyState(
          icon: Icons.person_off_rounded,
          title: 'Customer not found'.tr,
          art: Art.searching,
          message: 'They may have been removed.'.tr,
        ),
      );
    }

    final vehicles = data.vehiclesOf(id);
    final cards = data.jobCards.where((j) => j.customerId == id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final spend = cards.fold<double>(0, (s, j) => s + j.total);
    final due = cards.fold<double>(0, (s, j) => s + j.balance);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: customer.name,
        subtitle: customer.phone,
        actions: [
          GIconButton(
            icon: Icons.edit_rounded,
            size: 40,
            tooltip: 'Edit customer'.tr,
            onTap: () => _editCustomer(context, ref, customer),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          // --- reach them ------------------------------------------------
          Row(
            children: [
              Expanded(
                child: GButton(
                  label: 'Call'.tr,
                  kind: GButtonKind.ghost,
                  size: GButtonSize.md,
                  icon: Icons.call_rounded,
                  onPressed: () => launchDial(context, customer.phone),
                ),
              ),
              // The WhatsApp switch in settings is the workshop saying it does
              // not use WhatsApp — and nothing read that switch, so this
              // button went on offering a channel the shop had turned off.
              // Call takes the whole row when it goes.
              if (data.whatsappEnabled) ...[
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: GButton(
                    label: 'WhatsApp'.tr,
                    kind: GButtonKind.ghost,
                    size: GButtonSize.md,
                    icon: Icons.chat_rounded,
                    onPressed: () => launchWhatsApp(context, customer.phone),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Gap.lg),

          // --- lifetime --------------------------------------------------
          GCard(
            child: Row(
              children: [
                Expanded(
                  child: _Stat(label: 'Visits'.tr, value: '${cards.length}'),
                ),
                Expanded(
                  child: _Stat(label: 'Billed'.tr, value: Fmt.money(spend)),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Due'.tr,
                    value: Fmt.money(due),
                    color: due > 0 ? p.danger : p.success,
                  ),
                ),
              ],
            ),
          ),

          // --- vehicles --------------------------------------------------
          GSectionHeader(
            title: 'Vehicles'.tr,
            padding: EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
          ),
          if (vehicles.isEmpty)
            Text('No vehicle on record.'.tr, style: AppType.bodyS.c(p.inkFaint))
          else
            for (final v in vehicles)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Pressable(
                  onTap: () => context.push('/job/new?vehicle=${v.id}'),
                  scale: 0.985,
                  child: GVehicleCard.compact(
                    plate: Fmt.plate(v.regNo),
                    title: v.title,
                    shape: v.shape,
                    photo: VehicleMedia.photoFor(v.brand, v.model, v.shape),
                    logo: VehicleMedia.logoFor(v.brand),
                    subtitle: [
                      v.fuel.label,
                      if (v.transmission != null) v.transmission!.label,
                      if (v.year != null) '${v.year}',
                    ].join(' • '),
                    // Stacked rather than side by side: a second tag beside
                    // the first takes the width the plate needs on a narrow
                    // phone. The row itself still opens a new card; Edit is
                    // its own, smaller target inside it.
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GTag(
                          label: 'New card'.tr,
                          icon: Icons.add_rounded,
                          tone: GTone.accent,
                        ),
                        Pressable(
                          onTap: () => _editVehicle(context, ref, v),
                          scale: 0.94,
                          // The padding is part of the target, so the gap
                          // under New card opens the editor, not a card.
                          child: Padding(
                            padding: const EdgeInsets.only(top: Gap.xs),
                            child: GTag(
                              label: 'Edit'.tr,
                              icon: Icons.edit_rounded,
                              outlined: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

          // --- history ---------------------------------------------------
          GSectionHeader(
            title: 'Visit history'.tr,
            subtitle: cards.isEmpty
                ? null
                : '{0} job cards'.trf([cards.length]),
            padding: const EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
          ),
          if (cards.isEmpty)
            Text('Nothing billed yet.'.tr, style: AppType.bodyS.c(p.inkFaint))
          else
            for (final card in cards) JobCardTile(card: card),
        ],
      ),
    );
  }

  /// Change who the customer is and how to reach them.
  ///
  /// Nothing could, before. The job card form creates a customer and nothing
  /// ever opened one again, so a number mistyped at the counter stayed wrong
  /// on every SMS, bill and reminder after it — and the only way round it was
  /// a second customer, which the database refuses because the phone is
  /// unique on `norm_phone`.
  Future<void> _editCustomer(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final name = TextEditingController(text: customer.name);
    // Seeded as the last ten digits, not as stored. These fields take ten
    // digits and nothing else, like the job card form's, and a formatter
    // only filters what is typed: a booking's '+91 98123 45678' would sit in
    // the box failing the check, and the first keystroke would squash it
    // into the wrong ten digits.
    final phone = TextEditingController(
      text: AdminData.normPhone(customer.phone),
    );
    final altPhone = TextEditingController(
      text: AdminData.normPhone(customer.altPhone),
    );
    final email = TextEditingController(text: customer.email);
    final address = TextEditingController(text: customer.address);
    final gstin = TextEditingController(text: customer.gstin);

    final saved = await GFeedback.sheet<bool>(
      context,
      title: 'Edit customer'.tr,
      subtitle: customer.name,
      // Owned by the sheet, not by this function: its future completes
      // when the sheet starts closing, and the fields go on reading these
      // all the way through the exit transition.
      disposing: [name, phone, altPhone, email, address, gstin],
      child: StatefulBuilder(
        builder: (context, setSheet) {
          void save() {
            final n = name.text.trim();
            final ph = phone.text.trim();
            final alt = altPhone.text.trim();
            if (n.isEmpty) {
              GFeedback.error(context, "Enter the customer's name".tr);
              return;
            }
            if (ph.length != 10) {
              GFeedback.error(context, 'Enter a 10-digit mobile number'.tr);
              return;
            }
            if (alt.isNotEmpty && alt.length != 10) {
              GFeedback.error(
                context,
                'The alternate number must be 10 digits'.tr,
              );
              return;
            }
            // The database holds one customer per number, matched on the
            // last ten digits. Saved anyway, the clash would be refused on
            // every push after and the edit would live on this phone alone.
            final clash = ref
                .read(adminProvider)
                .customers
                .where(
                  (c) =>
                      c.id != customer.id && AdminData.normPhone(c.phone) == ph,
                )
                .firstOrNull;
            if (clash != null) {
              GFeedback.error(
                context,
                '{0} already has this number'.trf([clash.name]),
              );
              return;
            }
            ref
                .read(adminProvider.notifier)
                .updateCustomer(
                  customer.copyWith(
                    name: n,
                    phone: ph,
                    altPhone: alt,
                    email: email.text.trim(),
                    address: address.text.trim(),
                    // Upper case, the way the job card form saves it.
                    gstin: gstin.text.trim().toUpperCase(),
                  ),
                );
            Navigator.of(context).pop(true);
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              MediaQuery.of(context).viewInsets.bottom + Gap.h1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GField(
                  label: 'Full Name *'.tr,
                  hint: 'Rahul Sharma'.tr,
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Mobile Number *'.tr,
                  hint: '9876543210',
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Alternate Number'.tr,
                  hint: 'Optional'.tr,
                  controller: altPhone,
                  keyboardType: TextInputType.phone,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Email'.tr,
                  hint: 'xyz@gmail.com',
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Address'.tr,
                  hint: '12, MG Road, Bengaluru'.tr,
                  controller: address,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'GSTIN',
                  hint: '29ABCDE1234F1Z5',
                  controller: gstin,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: Gap.xxl),
                GButton.accent(
                  label: 'Save'.tr,
                  size: GButtonSize.md,
                  onPressed: save,
                ),
              ],
            ),
          );
        },
      ),
    );
    if (saved == true && context.mounted) {
      GFeedback.success(context, 'Customer updated'.tr);
    }
  }

  /// Correct a vehicle on record.
  ///
  /// The job card form is the only thing that ever wrote one, and it writes
  /// once: a plate typed wrong at check-in — or the 'NO-PLATE-…' stand-in
  /// for a car whose plate turned up later — stayed that way on every card
  /// and every search after it.
  ///
  /// The body shape is not offered here. It is picked on the job card,
  /// beside the damage sheet it decides, and is carried through untouched.
  Future<void> _editVehicle(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final reg = TextEditingController(text: vehicle.regNo);
    final brand = TextEditingController(text: vehicle.brand);
    final model = TextEditingController(text: vehicle.model);
    final variant = TextEditingController(text: vehicle.variant);
    // A booking with no year on it has been saved as 0 as well as null;
    // either way the box starts empty rather than failing its own check.
    final year = TextEditingController(
      text: (vehicle.year ?? 0) > 0 ? '${vehicle.year}' : '',
    );
    final colour = TextEditingController(text: vehicle.colour);
    final vin = TextEditingController(text: vehicle.vin);
    final engineNo = TextEditingController(text: vehicle.engineNo);
    final insurer = TextEditingController(text: vehicle.insurer);
    final policy = TextEditingController(text: vehicle.policyNo);
    var fuel = vehicle.fuel;
    var transmission = vehicle.transmission;
    var expiry = vehicle.insuranceExpiry;

    final saved = await GFeedback.sheet<bool>(
      context,
      title: 'Edit vehicle'.tr,
      subtitle: Fmt.plate(vehicle.regNo),
      // Owned by the sheet, not by this function: its future completes
      // when the sheet starts closing, and the fields go on reading these
      // all the way through the exit transition.
      disposing: [
        reg,
        brand,
        model,
        variant,
        year,
        colour,
        vin,
        engineNo,
        insurer,
        policy,
      ],
      child: StatefulBuilder(
        builder: (context, setSheet) {
          final p = context.c;

          Future<void> pickExpiry() async {
            final now = DateTime.now();
            final first = DateTime(now.year - 20);
            final last = DateTime(now.year + 10);
            final current = expiry;
            final picked = await showDatePicker(
              context: context,
              // A date from an old record outside the range trips the
              // picker's own assertion, so that one opens on today instead.
              initialDate:
                  current == null ||
                      current.isBefore(first) ||
                      current.isAfter(last)
                  ? now
                  : current,
              firstDate: first,
              lastDate: last,
            );
            if (picked != null) setSheet(() => expiry = picked);
          }

          void save() {
            final plate = reg.text.trim().toUpperCase();
            if (plate.isEmpty) {
              GFeedback.error(context, 'Enter the vehicle number'.tr);
              return;
            }
            final data = ref.read(adminProvider);
            // Compared the way `vehicleByReg` compares — spaces out, upper
            // case — because that is how the job card form finds a vehicle
            // by its plate. Two records it cannot tell apart would have the
            // counter opening cards against whichever it met first.
            String key(String r) => r.replaceAll(' ', '').toUpperCase();
            final clash = data.vehicles
                .where((o) => o.id != vehicle.id && key(o.regNo) == key(plate))
                .firstOrNull;
            if (clash != null) {
              GFeedback.error(
                context,
                '{0} is already on another vehicle'.trf([plate]),
              );
              return;
            }
            final typedYear = year.text.trim();
            final y = int.tryParse(typedYear);
            if (typedYear.isNotEmpty &&
                (y == null || y < 1950 || y > DateTime.now().year + 1)) {
              GFeedback.error(context, 'Enter a valid year'.tr);
              return;
            }
            // The record as it stands now, for the two fields this sheet
            // does not edit — not as it stood when the sheet opened.
            final latest = data.vehicleById(vehicle.id) ?? vehicle;
            // Built whole rather than through copyWith, which reads null as
            // "keep what is there" — so the gearbox, the year and the
            // insurance expiry could never be cleared through it.
            ref
                .read(adminProvider.notifier)
                .updateVehicle(
                  Vehicle(
                    id: vehicle.id,
                    customerId: latest.customerId,
                    regNo: plate,
                    brand: brand.text.trim(),
                    model: model.text.trim(),
                    variant: variant.text.trim(),
                    fuel: fuel,
                    transmission: transmission,
                    shape: latest.shape,
                    year: y,
                    vin: vin.text.trim().toUpperCase(),
                    engineNo: engineNo.text.trim().toUpperCase(),
                    colour: colour.text.trim(),
                    insurer: insurer.text.trim(),
                    policyNo: policy.text.trim(),
                    insuranceExpiry: expiry,
                  ),
                );
            Navigator.of(context).pop(true);
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              MediaQuery.of(context).viewInsets.bottom + Gap.h1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GField(
                  label: 'Vehicle Number *'.tr,
                  hint: 'MH12AB1234',
                  controller: reg,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: GField(
                        label: 'Make'.tr,
                        hint: 'Maruti Suzuki',
                        controller: brand,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GField(
                        label: 'Model'.tr,
                        hint: 'Swift',
                        controller: model,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: GField(
                        label: 'Variant'.tr,
                        hint: 'VXi',
                        controller: variant,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GField(
                        label: 'Year'.tr,
                        hint: '2019',
                        controller: year,
                        keyboardType: TextInputType.number,
                        textCapitalization: TextCapitalization.none,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                Text('FUEL', style: AppType.over.c(p.inkFaint)),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final f in FuelType.values)
                      _Choice(
                        label: f.label,
                        selected: fuel == f,
                        onTap: () => setSheet(() => fuel = f),
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
                        selected: transmission == t,
                        // A second tap takes it back to "not recorded", the
                        // same as on the job card form.
                        onTap: () => setSheet(
                          () => transmission = transmission == t ? null : t,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: GField(
                        label: 'Colour'.tr,
                        hint: 'White'.tr,
                        controller: colour,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GField(
                        label: 'Engine No'.tr,
                        controller: engineNo,
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'VIN / Chassis No'.tr,
                  controller: vin,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: Gap.xxl),
                Text('INSURANCE'.tr, style: AppType.over.c(p.inkFaint)),
                const SizedBox(height: Gap.sm),
                GField(
                  label: 'Insurance Name'.tr,
                  hint: 'ICICI Lombard'.tr,
                  controller: insurer,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Policy No'.tr,
                  hint: 'POL1234567',
                  controller: policy,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: GPickerField(
                        label: 'Expiry Date'.tr,
                        value: expiry == null ? null : Fmt.date(expiry!),
                        placeholder: 'Not set'.tr,
                        icon: Icons.event_rounded,
                        onTap: pickExpiry,
                      ),
                    ),
                    // A picker can only ever set a date. A policy that has
                    // lapsed, or was never this vehicle's, needs a way back
                    // to none.
                    if (expiry != null) ...[
                      const SizedBox(width: Gap.sm),
                      GIconButton(
                        icon: Icons.close_rounded,
                        size: 40,
                        tooltip: 'Clear'.tr,
                        onTap: () => setSheet(() => expiry = null),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Gap.xxl),
                GButton.accent(
                  label: 'Save'.tr,
                  size: GButtonSize.md,
                  onPressed: save,
                ),
              ],
            ),
          );
        },
      ),
    );
    if (saved == true && context.mounted) {
      GFeedback.success(context, 'Vehicle updated'.tr);
    }
  }
}

/// One option in a short pick-one row — fuel, gearbox.
///
/// The same pill the job card form draws for the same two questions, so a
/// vehicle reads the same being edited as it did being opened. That one is
/// private to its page, and [GChoiceChips] will not do instead: it scrolls
/// sideways and cannot be un-picked, and a gearbox nobody has recorded has
/// to be able to go back to "not recorded".
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
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
        child: Text(
          label,
          style: AppType.labelM.c(
            selected ? (p.isDark ? p.canvas : Colors.white) : p.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppType.over.s(9.5).c(p.inkFaint)),
        const SizedBox(height: 3),
        Text(value, style: AppType.money.s(16).c(color ?? p.ink)),
      ],
    );
  }
}
