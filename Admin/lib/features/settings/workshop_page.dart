import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// The details that head every document. Editing them changes what prints on
/// past job cards too — the workshop is one identity, not a snapshot per bill.
class WorkshopPage extends ConsumerStatefulWidget {
  const WorkshopPage({super.key});

  @override
  ConsumerState<WorkshopPage> createState() => _WorkshopPageState();
}

class _WorkshopPageState extends ConsumerState<WorkshopPage> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _altPhone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pin;
  late final TextEditingController _gstin;
  late final TextEditingController _upi;
  late final TextEditingController _terms;
  DateTime? _expiry;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final g = ref.read(garageProvider);
    _name = TextEditingController(text: g?.name ?? '');
    _phone = TextEditingController(text: g?.phone ?? '');
    _altPhone = TextEditingController(text: g?.altPhone ?? '');
    _email = TextEditingController(text: g?.email ?? '');
    _address = TextEditingController(text: g?.addressLine ?? '');
    _city = TextEditingController(text: g?.city ?? '');
    _state = TextEditingController(text: g?.state ?? '');
    _pin = TextEditingController(text: g?.pin ?? '');
    _gstin = TextEditingController(text: g?.gstin ?? '');
    _upi = TextEditingController(text: g?.upiId ?? '');
    _terms = TextEditingController(text: g?.terms ?? '');
    _expiry = g?.planExpiry;
    _ready = g != null;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _altPhone,
      _email,
      _address,
      _city,
      _state,
      _pin,
      _gstin,
      _upi,
      _terms,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Where the phone says this workshop is, once the owner has tapped "Use
  /// current location" on this screen. Null means leave whatever pin the
  /// garage already has — saving the address must not quietly unpin a
  /// workshop that was located properly at setup.
  double? _lat;
  double? _lng;
  String? _district;
  bool _locating = false;

  /// Puts this workshop on the customer app's map.
  ///
  /// The address fields above are what a customer reads; this is what they
  /// search by. `nearby_garages()` measures distance off a real coordinate
  /// and excludes a garage without one from every radius, so a workshop can
  /// be filled in perfectly and still be findable by nobody.
  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        GFeedback.info(
          context,
          'Location is needed to put your workshop on the map.'.tr,
        );
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        GFeedback.info(
          context,
          'Turn GPS on, then tap Use current location again.'.tr,
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      // Only the district is wanted here; the address stays as typed.
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (places.isNotEmpty) {
          _district = places.first.subAdministrativeArea?.trim();
        }
      } catch (e) {
        debugPrint('workshop district lookup failed: $e');
      }
      if (!mounted) return;
      GFeedback.success(context, 'Location set. Save to publish it.'.tr);
    } catch (e) {
      debugPrint('workshop locate failed: $e');
      if (!mounted) return;
      GFeedback.error(
        context,
        'Could not read the location. Check GPS and try again.'.tr,
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final g = ref.read(garageProvider);
    if (g == null) return;
    // The customer app shows the workshop by these two, so neither may be
    // blanked here after registration made them required.
    if (_name.text.trim().isEmpty) {
      GFeedback.error(context, 'Enter the workshop name.'.tr);
      return;
    }
    if (!Fmt.isPin(_pin.text)) {
      GFeedback.error(context, 'Enter a valid 6-digit PIN code.'.tr);
      return;
    }
    final pinError = await ref
        .read(adminProvider.notifier)
        .saveGarage(
          g.copyWith(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            altPhone: _altPhone.text.trim(),
            email: _email.text.trim(),
            addressLine: _address.text.trim(),
            city: _city.text.trim(),
            state: _state.text.trim(),
            pin: _pin.text.trim(),
            gstin: _gstin.text.trim().toUpperCase(),
            upiId: _upi.text.trim(),
            terms: _terms.text.trim(),
            planExpiry: _expiry,
          ),
          lat: _lat,
          lng: _lng,
          district: _district,
        );
    if (!mounted) return;
    // The details are saved on the phone regardless. A pin that did not
    // reach the server keeps the workshop out of every radius search, so
    // say so and stay here, where "Use current location" can be tried again.
    if (pinError != null) {
      GFeedback.error(
        context,
        'Details saved, but the map location was not: {0}'.trf([pinError]),
      );
      return;
    }
    GFeedback.success(context, 'Workshop details saved'.tr);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (!_ready) {
      return Scaffold(
        appBar: GHeader(
          title: 'Business Details'.tr,
          subtitle: 'Printed on every estimate and invoice'.tr,
        ),
        body: GEmptyState(
          icon: Icons.storefront_outlined,
          title: 'No workshop set up'.tr,
          art: Art.maintenance,
          message: 'Sign in again to run through setup.'.tr,
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Business details'.tr,
        subtitle: 'Printed on every estimate, invoice and copy'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          GField(
            label: 'Workshop name'.tr,
            hint: 'Sharma Auto Works'.tr,
            controller: _name,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: GField(
                  label: 'Phone'.tr,
                  hint: '9876543210',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: GField(
                  label: 'Alternate'.tr,
                  hint: '9876543211',
                  controller: _altPhone,
                  keyboardType: TextInputType.phone,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Email'.tr,
            hint: 'xyz@gmail.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Address'.tr,
            hint: '12, MG Road'.tr,
            controller: _address,
            maxLines: 2,
          ),
          const SizedBox(height: Gap.sm),
          GButton(
            label: _lat == null
                ? 'Use current location'.tr
                : 'Location set — save to publish'.tr,
            kind: GButtonKind.ghost,
            size: GButtonSize.sm,
            icon: Icons.my_location_rounded,
            loading: _locating,
            onPressed: _locating ? null : _locate,
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: GField(
                  label: 'City'.tr,
                  hint: 'Bengaluru'.tr,
                  controller: _city,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                flex: 2,
                child: GField(
                  label: 'PIN',
                  hint: '560001',
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          GField(label: 'State'.tr, hint: 'Karnataka'.tr, controller: _state),
          const SizedBox(height: Gap.xxl),
          Text('BILLING', style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.md),
          GField(
            label: 'GSTIN',
            hint: '29ABCDE1234F1Z5',
            helper: 'Leave blank if not registered'.tr,
            controller: _gstin,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(15)],
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'UPI ID'.tr,
            hint: 'Drives the payment QR on invoices'.tr,
            controller: _upi,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Terms and conditions'.tr,
            hint: 'One per line'.tr,
            controller: _terms,
            maxLines: 5,
          ),
          const SizedBox(height: Gap.xxl),
          Text('SUBSCRIPTION', style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.md),
          GPickerField(
            label: 'Plan expires on'.tr,
            value: _expiry == null ? null : Fmt.date(_expiry!),
            placeholder: 'Not set'.tr,
            icon: Icons.event_rounded,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _expiry ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) setState(() => _expiry = picked);
            },
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(label: 'Save'.tr, onPressed: _save),
      ),
    );
  }
}
