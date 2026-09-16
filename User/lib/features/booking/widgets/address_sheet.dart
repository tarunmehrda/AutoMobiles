import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../state/app_state.dart';
import '../../../state/providers.dart';

/// Create or edit a pickup address. Returns the saved address.
Future<Address?> showAddressEditor(
  BuildContext context, {
  Address? existing,
}) {
  return GFeedback.sheet<Address>(
    context,
    title: existing == null ? 'Add an address' : 'Edit address',
    subtitle: 'Our driver uses this to collect and return your car',
    child: _AddressForm(existing: existing),
  );
}

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({this.existing});

  final Address? existing;

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  late final _house = TextEditingController(text: widget.existing?.house);
  late final _street = TextEditingController(text: widget.existing?.street);
  late final _area = TextEditingController(text: widget.existing?.area);
  late final _city =
      TextEditingController(text: widget.existing?.city ?? 'Mohali');
  late final _state =
      TextEditingController(text: widget.existing?.state ?? 'Punjab');
  late final _pin = TextEditingController(text: widget.existing?.pin);
  late final _landmark = TextEditingController(text: widget.existing?.landmark);
  late final _contact =
      TextEditingController(text: widget.existing?.contactName);
  late final _phone = TextEditingController(
      text: widget.existing?.contactPhone ??
          ref.read(userProvider)?.phone.replaceAll('+91', ''));
  late String _label = widget.existing?.label ?? 'Home';

  static const _labels = ['Home', 'Office', 'Other'];

  bool get _valid =>
      _house.text.trim().isNotEmpty &&
      _area.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _pin.text.trim().length == 6;

  @override
  void dispose() {
    for (final c in [
      _house,
      _street,
      _area,
      _city,
      _state,
      _pin,
      _landmark,
      _contact,
      _phone
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_valid) return;
    final address = Address(
      id: widget.existing?.id ?? newId('addr'),
      label: _label,
      house: _house.text.trim(),
      street: _street.text.trim(),
      area: _area.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pin: _pin.text.trim(),
      landmark: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
      contactName:
          _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      contactPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      isDefault: widget.existing?.isDefault ?? false,
    );
    ref.read(appControllerProvider.notifier).saveAddress(address);
    Navigator.of(context).pop(address);
    GFeedback.success(context, 'Address saved');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page,
          Gap.xxl + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final l in _labels) ...[
                Pressable(
                  onTap: () => setState(() => _label = l),
                  scale: 0.94,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg, vertical: Gap.md),
                    decoration: BoxDecoration(
                      color: _label == l ? p.ink : p.surface,
                      borderRadius: R.all(R.md),
                      border:
                          Border.all(color: _label == l ? p.ink : p.line),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          l == 'Home'
                              ? Icons.home_rounded
                              : (l == 'Office'
                                  ? Icons.business_center_rounded
                                  : Icons.place_rounded),
                          size: 15,
                          color: _label == l
                              ? (p.isDark ? p.canvas : Colors.white)
                              : p.inkMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(l,
                            style: AppType.labelM.c(_label == l
                                ? (p.isDark ? p.canvas : Colors.white)
                                : p.inkSoft)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Gap.sm),
              ],
            ],
          ),
          const SizedBox(height: Gap.xl),
          GField(
            label: 'House / flat / building',
            hint: 'e.g. 402, Silver Oaks',
            controller: _house,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Street / road',
            hint: 'e.g. Sector 68 main road',
            controller: _street,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Area / locality',
            hint: 'e.g. Phase 8B',
            controller: _area,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: GField(
                  label: 'City',
                  controller: _city,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: GField(
                  label: 'PIN code',
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'State',
            controller: _state,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Landmark (optional)',
            hint: 'Helps the driver find you faster',
            controller: _landmark,
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: GField(
                  label: 'Contact person',
                  hint: 'Optional',
                  controller: _contact,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: GField(
                  label: 'Contact number',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xxl),
          GButton.accent(
            label: 'Save address',
            onPressed: _valid ? _save : null,
          ),
        ],
      ),
    );
  }
}
