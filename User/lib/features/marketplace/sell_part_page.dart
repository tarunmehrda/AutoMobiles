import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/marketplace.dart';
import '../../data/repo/marketplace_gateway.dart';
import '../../state/providers.dart';
import 'widgets/photo_strip.dart';
import 'widgets/vehicle_picker.dart';

/// Listing a part for sale.
///
/// A listing goes into review, not straight onto the browse screen. The
/// screen says so before the button is pressed rather than after, because
/// "why isn't my listing showing" is the complaint that follows any queue
/// nobody was told about.
class SellPartPage extends ConsumerStatefulWidget {
  const SellPartPage({super.key});

  @override
  ConsumerState<SellPartPage> createState() => _SellPartPageState();
}

class _SellPartPageState extends ConsumerState<SellPartPage> {
  final _title = TextEditingController();
  final _detail = TextEditingController();
  final _partNo = TextEditingController();
  final _price = TextEditingController();
  final _city = TextEditingController();
  final _pin = TextEditingController();
  final _otherVehicle = TextEditingController();

  Vehicle? _vehicle;
  bool _otherCar = false;
  PartCondition _condition = PartCondition.used;
  List<String> _photos = const [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _vehicle = ref.read(activeVehicleProvider);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _detail,
      _partNo,
      _price,
      _city,
      _pin,
      _otherVehicle,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _vehicleText => _otherCar
      ? _otherVehicle.text.trim()
      : _vehicle == null
          ? ''
          : VehiclePicker.describe(_vehicle!);

  double get _priceValue => double.tryParse(_price.text.trim()) ?? 0;

  bool get _valid =>
      _title.text.trim().length >= 3 && _priceValue > 0 && !_sending;

  Future<void> _submit() async {
    setState(() => _sending = true);
    final filed = await ref.read(marketplaceGatewayProvider).createListing(
          title: _title.text,
          price: _priceValue,
          detail: _detail.text,
          partNo: _partNo.text,
          condition: _condition,
          vehicleText: _vehicleText,
          vehicleId: _otherCar ? null : _vehicle?.id,
          city: _city.text,
          pin: _pin.text,
          photoPaths: _photos,
        );
    if (!mounted) return;
    setState(() => _sending = false);

    if (filed == null) {
      GFeedback.error(
        context,
        'Could not publish that. Check your connection and try again.',
      );
      return;
    }
    // A photo that would not upload is left off rather than sinking the
    // listing — but the seller is told, instead of finding out from a
    // listing with fewer pictures than they picked.
    final lost = filed.photosFailed;
    if (lost > 0) {
      GFeedback.info(
        context,
        'Listing sent for review, but ${lost == 1 ? '1 photo' : '$lost photos'} '
        'could not be uploaded. You will see it under Parts.',
      );
    } else {
      GFeedback.success(
        context,
        'Listing sent for review. You will see it under Parts.',
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: const GHeader(
        title: 'Sell a part',
        subtitle: 'Listings are checked before they go live',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
        children: [
          VehiclePicker(
            vehicles: vehicles,
            selected: _vehicle,
            other: _otherCar,
            otherController: _otherVehicle,
            label: 'Which vehicle is it from',
            onSelect: (v) => setState(() {
              _vehicle = v;
              _otherCar = false;
            }),
            onOther: () => setState(() => _otherCar = true),
            onOtherChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.xxl),
          GField(
            label: 'What are you selling',
            hint: 'Alloy wheels, set of 4',
            controller: _title,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: Gap.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GField(
                  label: 'Price',
                  hint: '0',
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  prefix: Padding(
                    padding: const EdgeInsets.only(right: Gap.xs),
                    child: Text('₹', style: AppType.bodyM.c(p.inkMuted)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: GField(
                  label: 'Part number',
                  hint: 'Optional',
                  controller: _partNo,
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xxl),
          Text('Condition', style: AppType.labelM.c(p.ink)),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              for (final c in PartCondition.values) ...[
                Expanded(
                  child: Pressable(
                    onTap: () => setState(() => _condition = c),
                    scale: 0.97,
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      padding: const EdgeInsets.symmetric(vertical: Gap.md),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _condition == c ? p.accent : p.surface,
                        borderRadius: R.rMd,
                        border: Border.all(
                            color: _condition == c ? p.accent : p.line),
                      ),
                      child: Text(
                        c.label,
                        style: AppType.labelM
                            .c(_condition == c ? p.onAccent : p.ink),
                      ),
                    ),
                  ),
                ),
                if (c != PartCondition.values.last)
                  const SizedBox(width: Gap.sm),
              ],
            ],
          ),
          const SizedBox(height: Gap.xxl),
          GField(
            label: 'Description',
            hint: 'Age, wear, why you are selling',
            controller: _detail,
            maxLines: 4,
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: GField(
                  label: 'City',
                  hint: 'Where the part is',
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: GField(
                  label: 'PIN code',
                  hint: 'Optional',
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          PhotoStrip(
            paths: _photos,
            onChanged: (next) => setState(() => _photos = next),
            hint: 'Listings with photos sell. Show the actual part, not a '
                'catalogue picture.',
          ),
          const SizedBox(height: Gap.h1),
          GButton(
            label: 'Publish listing',
            icon: Icons.storefront_rounded,
            loading: _sending,
            onPressed: _valid ? _submit : null,
          ),
          const SizedBox(height: Gap.md),
          Text(
            'We check every listing before it goes live. This usually takes a '
            'day.',
            textAlign: TextAlign.center,
            style: AppType.bodyS.c(p.inkFaint),
          ),
        ],
      ),
    );
  }
}
