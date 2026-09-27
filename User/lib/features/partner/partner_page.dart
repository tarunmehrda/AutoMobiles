import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../data/repo/location_service.dart';
import '../../data/repo/partner_gateway.dart';

/// "Register as a partner" — a customer who also runs a workshop.
///
/// This screen registers the garage and pins it on the map. It does not try
/// to be a console: running the workshop happens in the Balaji Garage app,
/// and pretending otherwise would mean rebuilding job cards, billing and
/// stock inside the customer app.
///
/// The pin is the part that matters here. A workshop with no coordinate can
/// still be found by name, but it can never appear in a "within 5 km"
/// result, so the screen pushes for it rather than treating it as optional.
class PartnerPage extends ConsumerStatefulWidget {
  const PartnerPage({super.key});

  @override
  ConsumerState<PartnerPage> createState() => _PartnerPageState();
}

class _PartnerPageState extends ConsumerState<PartnerPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pin = TextEditingController();
  final _gstin = TextEditingController();

  PartnerGarage? _existing;
  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _address,
      _city,
      _state,
      _pin,
      _gstin,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills every field `create_garage` will be sent, not only the ones
  /// shown in the header.
  ///
  /// `create_garage` writes each key it receives, and an empty string is a
  /// value, not an absence — so an address, state or GSTIN left out of this
  /// prefill went back up blank and wiped what the workshop had saved the
  /// first time it pressed "Save changes".
  Future<void> _load() async {
    final mine = await ref.read(partnerGatewayProvider).mine();
    if (!mounted) return;
    setState(() {
      _existing = mine;
      _loading = false;
      if (mine != null) {
        _name.text = mine.name;
        _phone.text = mine.phone;
        _address.text = mine.addressLine;
        _city.text = mine.city;
        _state.text = mine.state;
        _pin.text = mine.pin;
        _gstin.text = mine.gstin;
        _lat = mine.lat;
        _lng = mine.lng;
      }
    });
  }

  /// The name and PIN are what customers see on every search result, so
  /// neither is optional.
  bool get _valid =>
      _name.text.trim().length >= 3 &&
      _phone.text.trim().length >= 10 &&
      Fmt.isPin(_pin.text);

  bool get _located => _lat != null && _lng != null;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    // Precise, unlike the customer search: this coordinate is what every
    // distance in the directory will be measured from for as long as the
    // workshop is listed, so it is worth the extra few seconds.
    final fix = await LocationService.instance.fix(precise: true);
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix.ok) {
        _lat = fix.lat;
        _lng = fix.lng;
      }
    });
    if (!fix.ok && mounted) {
      GFeedback.error(context, fix.message);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final gw = ref.read(partnerGatewayProvider);
    final error = await gw.register(
      name: _name.text,
      phone: _phone.text,
      addressLine: _address.text,
      city: _city.text,
      state: _state.text,
      pin: _pin.text,
      gstin: _gstin.text,
      lat: _lat,
      lng: _lng,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      GFeedback.error(context, error);
      return;
    }
    GFeedback.success(
      context,
      _existing == null ? 'Workshop registered.' : 'Workshop updated.',
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: _existing == null ? 'Register as a partner' : 'My workshop',
        subtitle: _existing == null
            ? 'List your garage on Balaji Automobiles'
            : _existing!.name,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.lg, Gap.page, Gap.h3),
              children: [
                if (_existing != null) _status(p),
                GField(
                  label: 'Workshop name',
                  hint: 'As it should appear to customers',
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Phone',
                  hint: '10-digit number customers will call',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Address',
                  hint: 'Street and locality',
                  controller: _address,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: GField(
                        label: 'City',
                        controller: _city,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GField(
                        label: 'State',
                        controller: _state,
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
                        label: 'PIN code',
                        hint: '6 digits',
                        controller: _pin,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        // The register button stays off until this is
                        // right, so say why.
                        helper: Fmt.isPin(_pin.text)
                            ? null
                            : _pin.text.isEmpty
                                ? 'Required'
                                : 'Check the PIN code',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GField(
                        label: 'GSTIN',
                        hint: 'Optional',
                        controller: _gstin,
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xxl),
                _pinCard(p),
                const SizedBox(height: Gap.h1),
                GButton(
                  label: _existing == null
                      ? 'Register my workshop'
                      : 'Save changes',
                  icon: Icons.storefront_rounded,
                  loading: _saving,
                  onPressed: _valid && !_saving ? _save : null,
                ),
              ],
            ),
    );
  }

  /// Where the workshop stands in the register. Listing is the platform's
  /// call, so this reports it rather than offering a switch.
  Widget _status(AppPalette p) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.xxl),
        child: Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: R.rLg,
            border: Border.all(color: p.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Directory', style: AppType.labelM.c(p.ink)),
                  const Spacer(),
                  GPill(
                    label: _existing!.listed ? 'Listed' : 'Not listed yet',
                    tone: _existing!.listed ? GTone.success : GTone.warning,
                    compact: true,
                  ),
                  if (_existing!.verified) ...[
                    const SizedBox(width: Gap.xs),
                    const GPill(
                      label: 'Verified',
                      tone: GTone.accent,
                      compact: true,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(
                _existing!.listed
                    ? 'Customers searching nearby can find your workshop.'
                    : 'We review every workshop before it appears in search. '
                        'Adding your location speeds this up.',
                style: AppType.bodyS.c(p.inkMuted),
              ),
            ],
          ),
        ),
      );

  Widget _pinCard(AppPalette p) => Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: _located ? p.successSoft : p.warningSoft,
          borderRadius: R.rLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _located
                      ? Icons.where_to_vote_rounded
                      : Icons.location_off_rounded,
                  size: 18,
                  color: _located ? p.success : p.warning,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    _located ? 'Location saved' : 'Location not set',
                    style: AppType.labelM
                        .c(_located ? p.success : p.warning),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              _located
                  ? 'Pinned at ${_lat!.toStringAsFixed(5)}, '
                      '${_lng!.toStringAsFixed(5)}. Stand at your workshop '
                      'and set it again if this is wrong.'
                  : 'Distance search uses your exact coordinates, not your '
                      'PIN code. Without this your workshop cannot appear in '
                      '"garages within 5 km".',
              style: AppType.bodyS.c(p.ink),
            ),
            const SizedBox(height: Gap.lg),
            GButton(
              label: _located ? 'Set location again' : 'Use my location',
              icon: Icons.my_location_rounded,
              kind: GButtonKind.outline,
              size: GButtonSize.md,
              loading: _locating,
              onPressed: _locating ? null : _useMyLocation,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Stand inside the workshop when you tap this.',
              style: AppType.labelS.c(p.inkMuted),
            ),
          ],
        ),
      );
}
