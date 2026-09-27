import '../../core/i18n/strings.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/attendance.dart';
import '../../data/repo/attendance_gate.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// Where attendance may be marked, and how tight the circle is.
///
/// Set once, from the workshop, by whoever runs it. It rides on the garage
/// row, so it reaches every phone in the shop and no phone can quietly give
/// itself a different one.
class AttendanceSitePage extends ConsumerStatefulWidget {
  const AttendanceSitePage({super.key});

  @override
  ConsumerState<AttendanceSitePage> createState() => _AttendanceSitePageState();
}

class _AttendanceSitePageState extends ConsumerState<AttendanceSitePage> {
  final _label = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();

  double _radius = AttendanceSite.defaultRadiusM;
  double _ceiling = AttendanceSite.defaultMaxAccuracyM;
  bool _locating = false;

  /// The accuracy of the fix the pin was taken from, when it came from one.
  /// Worth showing: a site pinned from a ±40 m fix is a site in the wrong
  /// place, and every refusal afterwards will be blamed on the employee.
  double? _pinnedAccuracy;

  @override
  void initState() {
    super.initState();
    final site = ref.read(attendanceSiteProvider);
    if (site == null) return;
    _label.text = site.label;
    _lat.text = site.lat.toStringAsFixed(6);
    _lng.text = site.lng.toStringAsFixed(6);
    _radius = site.radiusM;
    _ceiling = site.maxAccuracyM;
  }

  @override
  void dispose() {
    _label.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  double? get _latValue => double.tryParse(_lat.text.trim());
  double? get _lngValue => double.tryParse(_lng.text.trim());

  bool get _valid {
    final lat = _latValue;
    final lng = _lngValue;
    return lat != null &&
        lng != null &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        !(lat == 0 && lng == 0);
  }

  /// Pins the spot the phone is standing on.
  ///
  /// Takes the sharpest of three readings rather than the first, because
  /// the first fix after a cold start is routinely the worst one, and a
  /// site pinned from it moves the circle by more than the circle is wide.
  Future<void> _useHere() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted) return;

      if (perm == LocationPermission.deniedForever) {
        final go = await GFeedback.confirm(
          context,
          icon: Icons.location_off_rounded,
          title: 'Location is switched off for this app'.tr,
          message:
              'It was refused for good, so the app can no longer ask. Open the permission page and allow it, or type the coordinates below.'
                  .tr,
          confirmLabel: 'Open settings'.tr,
          cancelLabel: 'I will type them'.tr,
        );
        if (go) await Geolocator.openAppSettings();
        return;
      }
      if (perm == LocationPermission.denied) {
        GFeedback.info(
          context,
          'Allow location to pin where you are standing.'.tr,
        );
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        final go = await GFeedback.confirm(
          context,
          icon: Icons.gps_off_rounded,
          title: 'GPS is off'.tr,
          message:
              'The phone itself has location turned off, so there is nothing to read. Switch it on and tap Use where I am standing again.'
                  .tr,
          confirmLabel: 'Turn on GPS'.tr,
          cancelLabel: 'Not now'.tr,
        );
        if (go) await Geolocator.openLocationSettings();
        return;
      }

      Position? best;
      for (var i = 0; i < 3; i++) {
        if (i > 0) await Future<void>.delayed(const Duration(seconds: 1));
        final fix = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 20),
          ),
        );
        if (best == null || fix.accuracy < best.accuracy) best = fix;
      }
      if (!mounted || best == null) return;

      setState(() {
        _lat.text = best!.latitude.toStringAsFixed(6);
        _lng.text = best.longitude.toStringAsFixed(6);
        _pinnedAccuracy = best.accuracy;
      });
      GFeedback.success(
        context,
        'Pinned to ±{0} m — check it before saving'.trf([
          best.accuracy.round(),
        ]),
      );
    } on TimeoutException {
      if (mounted) {
        GFeedback.error(
          context,
          'No fix arrived. Step outside and try again, or type the coordinates.'
              .tr,
        );
      }
    } catch (e) {
      debugPrint('attendance pin failed: $e');
      if (mounted) {
        GFeedback.error(context, 'Could not read the location.'.tr);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _save() {
    if (!_valid) return;
    ref
        .read(adminProvider.notifier)
        .setAttendanceSite(
          AttendanceSite(
            lat: _latValue!,
            lng: _lngValue!,
            radiusM: _radius,
            maxAccuracyM: _ceiling,
            label: _label.text.trim(),
          ),
        );
    GFeedback.success(context, 'Attendance location saved'.tr);
    Navigator.of(context).maybePop();
  }

  Future<void> _remove() async {
    final sure = await GFeedback.confirm(
      context,
      icon: Icons.location_off_rounded,
      title: 'Remove the attendance location?'.tr,
      message:
          'Nobody will be able to punch in or out until a new one is set. The register is kept.'
              .tr,
      confirmLabel: 'Remove'.tr,
      destructive: true,
    );
    if (!sure || !mounted) return;
    ref.read(adminProvider.notifier).setAttendanceSite(null);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final existing = ref.watch(attendanceSiteProvider);
    // How far the typed coordinates are from where they started, so an
    // accidental digit shows up as "1,400 km away" rather than as a
    // plausible-looking number.
    final moved = existing != null && _valid
        ? AttendanceGate.distanceM(
            existing.lat,
            existing.lng,
            _latValue!,
            _lngValue!,
          )
        : null;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Attendance location'.tr,
        subtitle: 'Where the team may punch in'.tr,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.md,
            Gap.page,
            Gap.h2,
          ),
          children: [
            GCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Stand in the workshop and pin it'.tr,
                    style: AppType.h2.c(p.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Everything else on this screen is a refinement of this one step. Pin it from the spot the team actually walks to — the bay, not the gate, not the office upstairs.'
                        .tr,
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                  const SizedBox(height: Gap.lg),
                  GButton.accent(
                    label: 'Use where I am standing'.tr,
                    icon: Icons.my_location_rounded,
                    size: GButtonSize.md,
                    loading: _locating,
                    onPressed: _locating ? null : _useHere,
                  ),
                  if (_pinnedAccuracy != null) ...[
                    const SizedBox(height: Gap.sm),
                    _Hint(
                      tone: _pinnedAccuracy! > 15
                          ? GTone.warning
                          : GTone.success,
                      icon: Icons.blur_circular_rounded,
                      text: _pinnedAccuracy! > 15
                          ? 'That fix was only good to ±${_pinnedAccuracy!.round()} m, so the pin may be that far off. Step into the open and pin again before saving.'
                          : 'Pinned from a ±${_pinnedAccuracy!.round()} m fix.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            GSectionHeader(
              title: 'The circle'.tr,
              subtitle: 'How close somebody has to be'.tr,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: Gap.sm),
            GCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Slider(
                    label: 'Allowed radius'.tr,
                    value: _radius,
                    min: 5,
                    max: 200,
                    divisions: 39,
                    format: AttendanceGate.metres,
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  // The honest caveat, on the screen where it can still be
                  // acted on. A five metre circle is what the brief asks
                  // for; it is also smaller than the instrument measuring
                  // it, and an owner who does not know that will spend a
                  // fortnight blaming their staff for the hardware.
                  if (_radius <= 10) ...[
                    const SizedBox(height: Gap.sm),
                    const _Hint(
                      tone: GTone.warning,
                      icon: Icons.info_outline_rounded,
                      text:
                          'A phone fix is typically good to five or ten metres in the open and worse under a roof, so a circle this tight will sometimes turn away somebody who is genuinely standing in it. Keep it if the team punches in outdoors; widen it if they do not.',
                    ),
                  ],
                  const SizedBox(height: Gap.lg),
                  _Slider(
                    label: 'Refuse fixes vaguer than'.tr,
                    value: _ceiling,
                    min: 10,
                    max: 100,
                    divisions: 18,
                    format: (v) => '±${v.round()} m',
                    onChanged: (v) => setState(() => _ceiling = v),
                  ),
                  const SizedBox(height: Gap.sm),
                  _Hint(
                    tone: GTone.info,
                    icon: Icons.shield_rounded,
                    text:
                        'A fix vaguer than this proves nothing about a ${AttendanceGate.metres(_radius)} circle, so it is refused rather than given the benefit of the doubt. Raising it makes attendance easier to mark and easier to fake.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            GSectionHeader(
              title: 'The pin'.tr,
              subtitle: 'Edit by hand if you have the coordinates'.tr,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: Gap.sm),
            GCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GField(
                    label: 'Name it'.tr,
                    hint: 'Main workshop'.tr,
                    controller: _label,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: Gap.lg),
                  Row(
                    children: [
                      Expanded(
                        child: GField(
                          label: 'Latitude'.tr,
                          hint: '26.912434',
                          controller: _lat,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: [_coord],
                          textCapitalization: TextCapitalization.none,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: GField(
                          label: 'Longitude'.tr,
                          hint: '75.787270',
                          controller: _lng,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: [_coord],
                          textCapitalization: TextCapitalization.none,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (moved != null && moved > 50) ...[
                    const SizedBox(height: Gap.md),
                    _Hint(
                      tone: GTone.danger,
                      icon: Icons.warning_amber_rounded,
                      text:
                          'This is ${AttendanceGate.metres(moved)} from the location currently saved. If that is not deliberate, nobody will be able to punch in tomorrow.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Gap.xxl),
            GButton.accent(
              label: existing == null
                  ? 'Set the location'.tr
                  : 'Save changes'.tr,
              onPressed: _valid ? _save : null,
            ),
            if (existing != null) ...[
              const SizedBox(height: Gap.md),
              GButton(
                label: 'Remove the location'.tr,
                kind: GButtonKind.ghost,
                size: GButtonSize.md,
                onPressed: _remove,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Digits, one dot, an optional leading minus. Anything else typed into a
  /// coordinate is a mistake being made in slow motion.
  static final _coord = FilteringTextInputFormatter.allow(
    RegExp(r'^-?[0-9]*\.?[0-9]*'),
  );
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppType.labelL.c(p.ink))),
            Text(format(value), style: AppType.h2.c(p.accent)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.tone, required this.icon, required this.text});

  final GTone tone;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = toneOf(context, tone);
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: R.all(R.sm),
        border: Border.all(color: t.fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: t.fg),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(text, style: AppType.bodyS.s(12).c(t.fg))),
        ],
      ),
    );
  }
}
