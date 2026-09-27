import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/directory.dart';
import '../../data/repo/directory_gateway.dart';
import '../../data/repo/location_service.dart';
import 'widgets/garage_result_card.dart';
import 'widgets/garage_sheet.dart';

/// The radius chips. `null` is "any distance", which is where the screen
/// starts — a customer in a town with four workshops should see all four
/// before being asked to narrow anything.
const _radii = <double?>[null, 1, 5, 10];

String _radiusLabel(double? km) => km == null ? 'Any' : '${km.round()} km';

/// Find a workshop that is not the one you are already with.
///
/// Two ways in, because a customer who will not share their location still
/// deserves to find a garage:
///
///   * a GPS fix, which sorts the register by real distance and puts a
///     "2.4 km" on every row, and
///   * typed text — a name, a locality or a PIN code — which searches the
///     register without any distance at all.
///
/// The distance chips only mean something on the first path, so on the
/// second they are disabled rather than silently filtering nothing: a
/// "within 1 km" that cannot measure anything would return an empty list and
/// blame the town for it.
class GarageSearchPage extends ConsumerStatefulWidget {
  const GarageSearchPage({super.key, this.pick = false});

  /// True when the booking flow sent the customer here to choose a workshop.
  /// The garage they pick is handed straight back rather than opening a
  /// second slot picker on top of the one already waiting for it.
  final bool pick;

  @override
  ConsumerState<GarageSearchPage> createState() => _GarageSearchPageState();
}

class _GarageSearchPageState extends ConsumerState<GarageSearchPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  LocationFix? _fix;
  double? _radius;
  bool _loading = true;
  bool _locating = false;
  String? _error;
  List<NearbyGarage> _rows = const [];

  bool get _hasFix => _fix?.ok ?? false;

  @override
  void initState() {
    super.initState();
    // A fix from earlier in the session is good enough to open on. Only when
    // there is none does the screen load without distances and offer the
    // button.
    _fix = LocationService.instance.last;
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ref.read(directoryGatewayProvider).nearby(
          lat: _hasFix ? _fix!.lat : null,
          lng: _hasFix ? _fix!.lng : null,
          radiusKm: _hasFix ? _radius : null,
          query: _search.text,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _rows = res.rows;
      _error = res.error;
    });
  }

  /// Typing re-runs the search, but not on every keystroke — a register
  /// search is a round trip, and "Bal" should not cost three of them.
  void _onTyped(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _run);
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final fix = await LocationService.instance.fix();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _fix = fix;
    });
    if (fix.ok) {
      await _run();
    } else if (mounted) {
      await _explainRefusal(fix);
    }
  }

  /// A refused permission is not an error to swallow. It is a thing the
  /// customer chose, with a way back — and the way back is in the OS, so the
  /// only useful thing this screen can do is open it.
  ///
  /// Blocked for good gets a popup rather than a snackbar: Android will
  /// never ask again on its own, so Settings is the only door left and it
  /// should not slide away after six seconds.
  Future<void> _explainRefusal(LocationFix fix) async {
    if (fix.problem == LocationProblem.deniedForever) {
      final open = await GFeedback.confirm(
        context,
        title: 'Allow location',
        message: 'Location is blocked for this app. Open Settings, tap '
            'Permissions, then Location, and choose "Allow". Or search by '
            'PIN code instead.',
        confirmLabel: 'Open Settings',
        cancelLabel: 'Not now',
        icon: Icons.location_off_rounded,
      );
      if (open) await LocationService.instance.openSettings();
      return;
    }
    if (!mounted) return;
    final p = context.c;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(fix.message, style: AppType.bodyS.c(p.onInverse)),
      backgroundColor: p.inverse,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: fix.problem == LocationProblem.serviceOff
          ? SnackBarAction(
              label: 'Settings',
              textColor: p.accentInk,
              onPressed: LocationService.instance.openLocationSettings,
            )
          : null,
    ));
  }

  Future<void> _open(NearbyGarage g) async {
    final booking = await showGarageSheet(context, g);
    if (!mounted || booking != true) return;
    if (widget.pick) {
      context.pop(g);
    } else {
      context.push('/book?garage=${Uri.encodeComponent(g.id)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Find a garage',
        subtitle: _hasFix ? 'Nearest to you first' : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
            child: GSearchBar(
              hint: 'Garage name, area or PIN code',
              controller: _search,
              onChanged: _onTyped,
              onClear: _search.text.isEmpty
                  ? null
                  : () {
                      _search.clear();
                      _run();
                    },
            ),
          ),
          const SizedBox(height: Gap.md),
          _chips(p),
          if (!_hasFix) _locateBar(p),
          Expanded(child: _body(p)),
        ],
      ),
    );
  }

  Widget _chips(AppPalette p) => SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.page),
          itemCount: _radii.length,
          separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
          itemBuilder: (context, i) {
            final km = _radii[i];
            final on = _radius == km;
            // Without a fix there is nothing to measure against, so every
            // chip but "Any" is inert and looks it.
            final live = _hasFix || km == null;
            return Pressable(
              enabled: live,
              onTap: () {
                setState(() => _radius = km);
                _run();
              },
              scale: 0.96,
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? p.accent : p.surface,
                  borderRadius: R.all(R.pill),
                  border: Border.all(color: on ? p.accent : p.line),
                ),
                child: Text(
                  _radiusLabel(km),
                  style: AppType.labelM.c(on
                      ? p.onAccent
                      : live
                          ? p.inkMuted
                          : p.inkFaint),
                ),
              ),
            );
          },
        ),
      );

  Widget _locateBar(AppPalette p) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 0),
        child: Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: p.accentSoft,
            borderRadius: R.rMd,
            border: Border.all(color: p.accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Icon(Icons.my_location_rounded, size: 18, color: p.accentInk),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  'Share your location to sort by distance',
                  style: AppType.bodyS.c(p.accentInk),
                ),
              ),
              const SizedBox(width: Gap.sm),
              GButton(
                label: 'Use',
                size: GButtonSize.sm,
                kind: GButtonKind.accent,
                expand: false,
                loading: _locating,
                onPressed: _locating ? null : _locate,
              ),
            ],
          ),
        ),
      );

  Widget _body(AppPalette p) {
    if (_loading) {
      return ListView.separated(
        padding: const EdgeInsets.all(Gap.page),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
        itemBuilder: (_, _) => const GSkeleton(height: 86),
      );
    }

    if (_error != null) {
      return GEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not search',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _run,
        tone: p.danger,
      );
    }

    if (_rows.isEmpty) {
      final narrowed = _radius != null;
      return GEmptyState(
        icon: Icons.store_mall_directory_outlined,
        title: narrowed ? 'None within ${_radiusLabel(_radius)}' : 'No garages found',
        message: narrowed
            ? 'No registered garage is that close. Try a wider distance.'
            : _search.text.trim().isEmpty
                ? 'No garages are listed in the register yet.'
                : 'Nothing matched "${_search.text.trim()}". Try an area or a '
                    'PIN code.',
        actionLabel: narrowed ? 'Search any distance' : null,
        onAction: narrowed
            ? () {
                setState(() => _radius = null);
                _run();
              }
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _run,
      color: p.accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
        itemBuilder: (context, i) => Entrance(
          index: i.clamp(0, 8),
          child: GarageResultCard(
            garage: _rows[i],
            onTap: () => _open(_rows[i]),
          ),
        ),
      ),
    );
  }
}
