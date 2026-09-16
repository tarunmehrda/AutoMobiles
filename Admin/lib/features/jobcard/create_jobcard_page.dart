import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../data/seed/seed.dart';
import '../../data/seed/vehicle_catalog.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import 'widgets/vehicle_picker.dart';

/// Opening a card is the busiest thirty seconds at the counter, so the form
/// is one page and recognises what it already knows: type a registration it
/// has seen and the vehicle and owner fill themselves in.
class CreateJobCardPage extends ConsumerStatefulWidget {
  const CreateJobCardPage({super.key, this.bookingId, this.vehicleId});

  final String? bookingId;
  final String? vehicleId;

  @override
  ConsumerState<CreateJobCardPage> createState() =>
      _CreateJobCardPageState();
}

class _CreateJobCardPageState extends ConsumerState<CreateJobCardPage> {
  final _reg = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _variant = TextEditingController();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _km = TextEditingController();

  FuelType _fuel = FuelType.petrol;
  int _fuelLevel = 50;
  DateTime? _promised;
  final _voices = <String>[];
  final _accessories = <String>[];
  final _mechanics = <String>[];

  /// True once a known registration or phone has filled the fields in, so the
  /// form can say so rather than looking like it guessed.
  bool _matchedVehicle = false;
  bool _matchedCustomer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    final data = ref.read(adminProvider);

    if (widget.vehicleId != null) {
      final v = data.vehicleById(widget.vehicleId);
      if (v != null) {
        _reg.text = v.regNo;
        _applyVehicle();
      }
    }

    final booking = widget.bookingId == null
        ? null
        : data.bookings.where((b) => b.id == widget.bookingId).firstOrNull;
    if (booking != null) {
      _name.text = booking.name;
      _phone.text = booking.phone;
      if (booking.regNo.isNotEmpty) {
        _reg.text = booking.regNo;
        _applyVehicle();
      }
      final parts = booking.vehicle.split(' ');
      if (parts.length > 1 && _brand.text.isEmpty) {
        _brand.text = parts.first;
        _model.text = parts.sublist(1).join(' ');
      }
      if (booking.note.isNotEmpty && _voices.isEmpty) {
        _voices.add(booking.note);
      }
      setState(() {});
    }
  }

  /// Look the registration up and fill everything that follows from it.
  void _applyVehicle() {
    final data = ref.read(adminProvider);
    final v = data.vehicleByReg(_reg.text);
    if (v == null) {
      if (_matchedVehicle) setState(() => _matchedVehicle = false);
      return;
    }
    _brand.text = v.brand;
    _model.text = v.model;
    _variant.text = v.variant;
    _fuel = v.fuel;

    final owner = data.customerById(v.customerId);
    if (owner != null) {
      _name.text = owner.name;
      _phone.text = owner.phone;
      _matchedCustomer = true;
    }

    // Carry the last reading forward so the counter only types the difference.
    final last = data.historyOf(v.id).firstOrNull;
    if (last != null && _km.text.isEmpty) {
      _km.text = '${last.odometerKm}';
    }
    setState(() => _matchedVehicle = true);
  }

  void _applyCustomer() {
    final existing = ref.read(adminProvider).customerByPhone(_phone.text);
    if (existing == null) {
      if (_matchedCustomer) setState(() => _matchedCustomer = false);
      return;
    }
    _name.text = existing.name;
    setState(() => _matchedCustomer = true);
  }

  @override
  void dispose() {
    for (final c in [_reg, _brand, _model, _variant, _phone, _name, _km]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _reg.text.trim().length >= 4 &&
      _brand.text.trim().isNotEmpty &&
      _model.text.trim().isNotEmpty &&
      _name.text.trim().isNotEmpty &&
      _phone.text.trim().length >= 10;

  Future<void> _pickPromised() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _promised ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (!mounted) return;
    setState(() => _promised = DateTime(date.year, date.month, date.day,
        time?.hour ?? 18, time?.minute ?? 0));
  }

  Future<void> _pickMake() async {
    final picked = await pickFromCatalog(
      context,
      title: 'Make',
      subtitle: '${VehicleCatalog.makes.length} marques, including the ones '
          'no longer sold here',
      options: VehicleCatalog.makes,
      selected: _brand.text.isEmpty ? null : _brand.text,
    );
    if (picked == null) return;
    setState(() {
      _brand.text = picked;
      // A different make means the old model no longer applies.
      if (!VehicleCatalog.modelsOf(picked).contains(_model.text)) {
        _model.clear();
        _variant.clear();
      }
    });
  }

  Future<void> _pickModel() async {
    final options = VehicleCatalog.modelsOf(_brand.text);
    final picked = await pickFromCatalog(
      context,
      title: 'Model',
      subtitle: _brand.text,
      options: options,
      selected: _model.text.isEmpty ? null : _model.text,
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
    final options = VehicleCatalog.variantsOf(_model.text);
    final picked = await pickFromCatalog(
      context,
      title: 'Variant',
      subtitle: '${_brand.text} ${_model.text}',
      options: options,
      selected: _variant.text.isEmpty ? null : _variant.text,
    );
    if (picked == null) return;
    setState(() => _variant.text = picked);
  }

  void _create() {
    if (!_valid) return;
    final ctrl = ref.read(adminProvider.notifier);

    final customer = ctrl.upsertCustomer(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
    );
    final vehicle = ctrl.upsertVehicle(
      customerId: customer.id,
      regNo: _reg.text.trim(),
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      variant: _variant.text.trim(),
      fuel: _fuel,
    );
    final card = ctrl.createJobCard(
      customerId: customer.id,
      vehicleId: vehicle.id,
      odometerKm: int.tryParse(_km.text.trim()) ?? 0,
      fuelPercent: _fuelLevel,
      promisedAt: _promised,
      voices: _voices,
      accessories: _accessories,
      mechanicIds: _mechanics,
    );

    if (widget.bookingId != null) {
      ctrl.acceptBooking(widget.bookingId!, jobCardId: card.id);
    }

    GFeedback.success(context, '${card.number} opened');
    context.pushReplacement('/job/${card.id}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final staff = ref.watch(staffProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: const GHeader(
        title: 'New job card',
        subtitle: 'The number is minted when you open it',
      ),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          // --- vehicle ---------------------------------------------------
          _SectionLabel(
            label: 'Vehicle',
            hint: _matchedVehicle ? 'Recognised from a previous visit' : null,
          ),
          GField(
            label: 'Registration number',
            hint: 'RJ14 4C 2626',
            controller: _reg,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) {
              _applyVehicle();
              setState(() {});
            },
            suffix: _matchedVehicle
                ? Icon(Icons.check_circle_rounded,
                    size: 18, color: p.success)
                : null,
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: GPickerField(
                  label: 'Make',
                  value: _brand.text.isEmpty ? null : _brand.text,
                  placeholder: 'Pick a make',
                  onTap: _pickMake,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: GPickerField(
                  label: 'Model',
                  value: _model.text.isEmpty ? null : _model.text,
                  placeholder: _brand.text.isEmpty ? 'Make first' : 'Pick one',
                  onTap: _brand.text.isEmpty ? null : _pickModel,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          GPickerField(
            label: 'Variant',
            value: _variant.text.isEmpty ? null : _variant.text,
            placeholder: 'Optional',
            onTap: _model.text.isEmpty ? null : _pickVariant,
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
                  selected: _fuel == f,
                  onTap: () => setState(() => _fuel = f),
                ),
            ],
          ),

          const SizedBox(height: Gap.xxl),

          // --- customer --------------------------------------------------
          _SectionLabel(
            label: 'Customer',
            hint: _matchedCustomer ? 'Existing customer' : null,
          ),
          GField(
            label: 'Mobile number',
            controller: _phone,
            keyboardType: TextInputType.phone,
            textCapitalization: TextCapitalization.none,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) {
              _applyCustomer();
              setState(() {});
            },
            suffix: _matchedCustomer
                ? Icon(Icons.check_circle_rounded,
                    size: 18, color: p.success)
                : null,
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Name',
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: Gap.xxl),

          // --- intake ----------------------------------------------------
          const _SectionLabel(label: 'At handover'),
          GField(
            label: 'Odometer',
            controller: _km,
            keyboardType: TextInputType.number,
            textCapitalization: TextCapitalization.none,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            suffix: Text('km', style: AppType.labelM.c(p.inkMuted)),
          ),
          const SizedBox(height: Gap.lg),
          GCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.local_gas_station_rounded,
                        size: 18, color: p.inkMuted),
                    const SizedBox(width: Gap.sm),
                    Text('Fuel level', style: AppType.labelL.c(p.ink)),
                    const Spacer(),
                    Text('$_fuelLevel%',
                        style: AppType.money.c(p.accentInk)),
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
          const SizedBox(height: Gap.lg),
          GPickerField(
            label: 'Promised ready by',
            value: _promised == null ? null : Fmt.fullDateTime(_promised!),
            placeholder: 'Not set',
            icon: Icons.event_rounded,
            onTap: _pickPromised,
          ),

          const SizedBox(height: Gap.xxl),

          // --- complaint -------------------------------------------------
          _SectionLabel(
            label: 'Customer voice',
            hint: _voices.isEmpty ? null : '${_voices.length} selected',
          ),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final v in Seed.voices.take(10))
                _Choice(
                  label: v,
                  selected: _voices.contains(v),
                  onTap: () => setState(() =>
                      _voices.contains(v) ? _voices.remove(v) : _voices.add(v)),
                ),
            ],
          ),

          const SizedBox(height: Gap.xxl),
          _SectionLabel(
            label: 'Accessories in',
            hint: _accessories.isEmpty
                ? null
                : '${_accessories.length} selected',
          ),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final a in Seed.accessories.take(8))
                _Choice(
                  label: a,
                  selected: _accessories.contains(a),
                  onTap: () => setState(() => _accessories.contains(a)
                      ? _accessories.remove(a)
                      : _accessories.add(a)),
                ),
            ],
          ),

          if (staff.isNotEmpty) ...[
            const SizedBox(height: Gap.xxl),
            const _SectionLabel(label: 'Assign to'),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final s in staff)
                  _Choice(
                    label: s.name,
                    selected: _mechanics.contains(s.id),
                    onTap: () => setState(() => _mechanics.contains(s.id)
                        ? _mechanics.remove(s.id)
                        : _mechanics.add(s.id)),
                  ),
              ],
            ),
          ],

          const SizedBox(height: Gap.xxl),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: p.inkFaint),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  'Photos, dent marks and the bill are added once the card '
                  'is open.',
                  style: AppType.bodyS.c(p.inkFaint),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: 'Open job card',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: _valid ? _create : null,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: AppType.over.c(p.inkFaint)),
          if (hint != null) ...[
            const SizedBox(width: Gap.sm),
            GPill(label: hint!, tone: GTone.success, compact: true),
          ],
        ],
      ),
    );
  }
}

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
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
        decoration: BoxDecoration(
          color: selected ? p.ink : p.surface,
          borderRadius: R.all(R.pill),
          border: Border.all(color: selected ? p.ink : p.line),
        ),
        child: Text(
          label,
          style: AppType.labelM.c(
              selected ? (p.isDark ? p.canvas : Colors.white) : p.inkSoft),
        ),
      ),
    );
  }
}
