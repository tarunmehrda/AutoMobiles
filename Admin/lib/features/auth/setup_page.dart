import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/vehicle_art.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/seed/vehicle_media.dart';
import '../../data/seed/seed.dart';
import '../../state/admin_state.dart';
import 'widgets/terms_sheet.dart';

/// Registration, in the three steps the counter expects:
///
/// 1. the shop — its name, its PIN code, what it works on,
/// 2. who runs it and the number to reach them on,
/// 3. where it is, then the terms.
///
/// Name and PIN come first because together they are how customers tell
/// workshops apart: the customer app shows every workshop as
/// "Balaji-333503".
///
/// The number is taken as given; there is no code to type back. Nothing here
/// authenticates, so an SMS round trip would only be theatre.
///
/// Everything here heads every document the workshop hands a customer, so it
/// is worth getting right once.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  int _step = 0;

  // --- step 1 ------------------------------------------------------------
  final _shop = TextEditingController();
  final _pin = TextEditingController();

  /// The bodies this shop works on. A shop that does two-wheelers and cars
  /// ticks both, and the job card's own picker offers the same four.
  final _types = <VehicleShape>{VehicleShape.twoWheeler};

  // --- step 2 ------------------------------------------------------------
  final _phone = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _alt = TextEditingController();

  // --- step 3 ------------------------------------------------------------
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _phone,
      _shop,
      _first,
      _last,
      _email,
      _alt,
      _address,
      _city,
      _state,
      _pin,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The PIN is required: the customer app shows it beside the workshop's
  /// name, and a customer can search for workshops by it.
  bool get _step1Valid =>
      _shop.text.trim().isNotEmpty && Fmt.isPin(_pin.text) && _types.isNotEmpty;

  bool get _step2Valid =>
      _phone.text.trim().length == 10 && _first.text.trim().isNotEmpty;

  bool get _step3Valid => _address.text.trim().isNotEmpty;

  void _go(int step) => setState(() => _step = step.clamp(0, 2));

  bool _locating = false;

  /// Fills the address block from where the phone actually is.
  ///
  /// Four things can stop it and each needs a different sentence: the
  /// permission was refused, the permission was refused for good, GPS is
  /// switched off at the system level, or the fix simply did not arrive.
  /// "Could not get location" for all four leaves somebody poking at the
  /// wrong setting.
  /// Where the phone said the workshop is, once the owner has tapped "Use
  /// current location". Null when they typed the address by hand instead,
  /// and the workshop is then reachable by name but not by distance.
  double? _lat;
  double? _lng;
  String? _district;

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted) return;

      // Both dead ends open the right page themselves. Telling somebody to
      // "enable location in Settings" and leaving them to find it is three
      // taps and a guess, on a screen that varies by phone.
      if (perm == LocationPermission.deniedForever) {
        final go = await GFeedback.confirm(
          context,
          icon: Icons.location_off_rounded,
          title: 'Location is switched off for this app'.tr,
          message:
              'It was refused for good, so the app can no longer ask. Open the permission page and allow it, or type the address below instead.'
                  .tr,
          confirmLabel: 'Open settings'.tr,
          cancelLabel: 'I will type it'.tr,
        );
        if (go) await Geolocator.openAppSettings();
        return;
      }
      if (perm == LocationPermission.denied) {
        GFeedback.info(context, 'Allow location to fill this in for you.'.tr);
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        final go = await GFeedback.confirm(
          context,
          icon: Icons.gps_off_rounded,
          title: 'GPS is off'.tr,
          message:
              'The phone itself has location turned off, so there is nothing for the app to read. Switch it on and tap Use Current Location again.'
                  .tr,
          confirmLabel: 'Turn on GPS'.tr,
          cancelLabel: 'I will type it'.tr,
        );
        if (go) await Geolocator.openLocationSettings();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // A cold fix under a workshop roof can take a while; giving up
          // early and saying nothing is worse than waiting.
          timeLimit: Duration(seconds: 25),
        ),
      );
      // Kept, not just geocoded. This is the coordinate the customer app
      // measures distance against; the address below is only what it reads
      // out underneath the name. Throwing it away here is what put
      // workshops on the register that no radius search could find.
      _lat = pos.latitude;
      _lng = pos.longitude;

      final places = await Geocoding().placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;

      if (places.isEmpty) {
        GFeedback.info(
          context,
          'Found you, but no street address came back. Type it below.'.tr,
        );
        return;
      }
      _fill(places.first);
      GFeedback.success(
        context,
        'Address filled in — check it before you go on.'.tr,
      );
    } catch (e) {
      if (!mounted) return;
      GFeedback.error(
        context,
        'Could not read the location. Check GPS and try again, or type the address below.'
            .tr,
      );
      debugPrint('location lookup failed: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Nothing already typed is overwritten — a lookup is a helper, not a
  /// correction of what the owner knows about their own shop.
  void _fill(Placemark place) {
    void put(TextEditingController c, String? value) {
      final v = value?.trim() ?? '';
      if (v.isNotEmpty && c.text.trim().isEmpty) c.text = v;
    }

    final street = [
      place.name,
      place.street,
      place.subLocality,
      place.locality,
    ].whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty);

    setState(() {
      // `name` and `street` often repeat each other; the set keeps one.
      put(_address, street.toSet().join(', '));
      put(_city, place.locality);
      put(_state, place.administrativeArea);
    });
    _district = place.subAdministrativeArea?.trim();
  }

  Future<void> _finish() async {
    final agreed = await showTermsSheet(context);
    if (!agreed || !mounted) return;

    final owner = [
      _first.text.trim(),
      _last.text.trim(),
    ].where((e) => e.isNotEmpty).join(' ');

    final pinError = await ref
        .read(adminProvider.notifier)
        .saveGarage(
          Garage(
            id: newId('garage'),
            name: _shop.text.trim(),
            phone: _phone.text.trim(),
            altPhone: _alt.text.trim(),
            email: _email.text.trim(),
            addressLine: _address.text.trim(),
            city: _city.text.trim(),
            state: _state.text.trim(),
            pin: _pin.text.trim(),
            terms: [
              if (owner.isNotEmpty) 'Proprietor: $owner',
              ...Seed.terms,
            ].join('\n'),
            planExpiry: DateTime.now().add(const Duration(days: 365)),
          ),
          lat: _lat,
          lng: _lng,
          district: _district,
        );
    if (!mounted) return;
    // The workshop is saved either way; only the pin can be missing, and a
    // workshop without one never appears in a customer's "near me" search.
    if (pinError != null) {
      GFeedback.error(
        context,
        'Workshop saved, but its map location was not: {0} Set it again '
                'under Settings → Business Details.'
            .trf([pinError]),
      );
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step - 1);
      },
      child: Scaffold(
        backgroundColor: p.canvas,
        appBar: GHeader(
          title: 'Registration'.tr,
          showBack: _step > 0,
          onBack: () => _go(_step - 1),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Stepper(step: _step),
              const SizedBox(height: Gap.h1),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  switchInCurve: Motion.emphasized,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: switch (_step) {
                    0 => _shopStep(),
                    1 => _ownerStep(),
                    _ => _addressStep(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- step 1 ------------------------------------------------------------

  Widget _shopStep() {
    final p = context.c;
    return ListView(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      children: [
        GField(
          label: 'WorkShop Name'.tr,
          hint: 'Sharma Auto Works'.tr,
          controller: _shop,
          textCapitalization: TextCapitalization.words,
          suffix: _shop.text.trim().isNotEmpty
              ? Icon(Icons.check_circle_rounded, size: 19, color: p.success)
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Pin code'.tr,
          hint: '560001',
          controller: _pin,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          // Next stays off until this is right, so say why.
          helper: Fmt.isPin(_pin.text)
              ? null
              : _pin.text.isEmpty
              ? 'Required. Customers see it next to your workshop name.'.tr
              : 'A PIN code is 6 digits and does not start with 0.'.tr,
          suffix: Fmt.isPin(_pin.text)
              ? Icon(Icons.check_circle_rounded, size: 19, color: p.success)
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Gap.xl),
        Text('WorkShop Type'.tr, style: AppType.labelL.c(p.inkSoft)),
        const SizedBox(height: Gap.sm),
        // Each row shows a photograph of the body rather than a Material
        // glyph of it — a bike, an auto, a car, a truck — because four grey
        // icons on one screen read as one grey smudge. It is the same
        // photograph the job card will show them later, so what they tick
        // here is what they will see there.
        for (final shape in VehicleShape.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Pressable(
              onTap: () => setState(() {
                if (!_types.remove(shape)) _types.add(shape);
              }),
              scale: 0.98,
              child: AnimatedContainer(
                duration: Motion.fast,
                curve: Motion.emphasized,
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm,
                ),
                decoration: BoxDecoration(
                  color: _types.contains(shape) ? p.successSoft : p.surface,
                  borderRadius: R.rMd,
                  border: Border.all(
                    color: _types.contains(shape) ? p.success : p.line,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: R.all(R.xs),
                      child: SizedBox(
                        width: 74,
                        height: 48,
                        child: VehicleArt(
                          shape: shape,
                          photo: VehicleMedia.bodyPhotoFor(null, null, shape),
                          height: 48,
                          // The photograph is the same in both states; only
                          // the tile around it moves. Sliding it in and out
                          // on every tick would be motion for its own sake.
                          animate: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.lg),
                    Expanded(
                      child: Text(shape.label, style: AppType.bodyL.c(p.ink)),
                    ),
                    AnimatedContainer(
                      duration: Motion.fast,
                      height: 24,
                      width: 24,
                      decoration: BoxDecoration(
                        color: _types.contains(shape)
                            ? p.success
                            : Colors.transparent,
                        borderRadius: R.all(R.xs),
                        border: Border.all(
                          color: _types.contains(shape)
                              ? p.success
                              : p.inkFaint,
                          width: 2,
                        ),
                      ),
                      child: _types.contains(shape)
                          ? const Icon(
                              Icons.check_rounded,
                              size: 17,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: Gap.h1),
        GButton.accent(
          label: 'Next'.tr,
          onPressed: _step1Valid ? () => _go(1) : null,
        ),
      ],
    );
  }

  // --- step 2 ------------------------------------------------------------

  Widget _ownerStep() {
    final p = context.c;
    return ListView(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      children: [
        GField(
          label: 'Mobile Number'.tr,
          hint: '9876543210',
          controller: _phone,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          prefix: Padding(
            padding: const EdgeInsets.only(right: Gap.sm),
            child: Text('🇮🇳  +91', style: AppType.labelL.c(p.inkSoft)),
          ),
          suffix: _phone.text.trim().length == 10
              ? Icon(Icons.check_circle_rounded, size: 19, color: p.success)
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'First Name'.tr,
          hint: 'Rahul'.tr,
          controller: _first,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Last Name'.tr,
          hint: 'Sharma'.tr,
          controller: _last,
          textCapitalization: TextCapitalization.words,
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
          label: 'Mobile Number 2'.tr,
          hint: '9876543211',
          controller: _alt,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        const SizedBox(height: Gap.h1),
        GButton.accent(
          label: 'Next'.tr,
          onPressed: _step2Valid ? () => _go(2) : null,
        ),
      ],
    );
  }

  // --- step 3 ------------------------------------------------------------

  Widget _addressStep() {
    final p = context.c;
    return ListView(
      key: const ValueKey(2),
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      children: [
        Pressable(
          onTap: _locating ? null : _useCurrentLocation,
          scale: 0.98,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.lg,
            ),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: R.all(R.md),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                if (_locating)
                  SizedBox(
                    height: 21,
                    width: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.accent,
                    ),
                  )
                else
                  Icon(Icons.my_location_rounded, size: 21, color: p.inkSoft),
                const SizedBox(width: Gap.md),
                Text(
                  _locating ? 'Finding you…'.tr : 'Use Current Location'.tr,
                  style: AppType.labelL.c(p.ink),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Address'.tr,
          hint: '12, MG Road'.tr,
          controller: _address,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'City'.tr,
          hint: 'Bengaluru'.tr,
          controller: _city,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'State'.tr,
          hint: 'Karnataka'.tr,
          controller: _state,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: Gap.h1),
        GButton.accent(
          label: 'Continue'.tr,
          onPressed: _step3Valid ? _finish : null,
        ),
      ],
    );
  }
}

/// The three numbered dots with the rail between them.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});

  static const _count = 3;

  final int step;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.h2),
      child: Row(
        children: [
          for (var i = 0; i < _count; i++) ...[
            Entrance(
              index: i,
              child: AnimatedContainer(
                duration: Motion.base,
                curve: Motion.spring,
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: i <= step ? p.info : p.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i <= step ? p.info : p.line,
                    width: 1.6,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: AppType.labelL.c(
                      i <= step ? Colors.white : p.inkFaint,
                    ),
                  ),
                ),
              ),
            ),
            if (i != _count - 1)
              Expanded(
                child: AnimatedContainer(
                  duration: Motion.base,
                  height: 2,
                  color: i < step ? p.info : p.line,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
