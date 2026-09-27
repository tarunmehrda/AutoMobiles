import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/directions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_state.dart';
import '../../../data/models/directory.dart';
import '../../../data/repo/directory_gateway.dart';

/// The public page of a garage the customer found by searching — opened
/// before they have any dealings with it, so everything on it comes from
/// `garage_card()` rather than from a table they cannot read.
/// Resolves true when the customer tapped Book here, so the caller can carry
/// them on to the slot picker — or hand this garage back to the booking flow
/// that sent them looking in the first place.
Future<bool?> showGarageSheet(BuildContext context, NearbyGarage garage) =>
    GFeedback.sheet<bool>(
      context,
      title: garage.label,
      subtitle: [
        if (garage.where.isNotEmpty) garage.where,
        if (garage.distanceLabel.isNotEmpty) '${garage.distanceLabel} away',
      ].join('  •  '),
      child: _GarageSheet(garage: garage),
    );

class _GarageSheet extends ConsumerStatefulWidget {
  const _GarageSheet({required this.garage});

  final NearbyGarage garage;

  @override
  ConsumerState<_GarageSheet> createState() => _GarageSheetState();
}

class _GarageSheetState extends ConsumerState<_GarageSheet> {
  GarageCard? _card;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final card = await ref.read(directoryGatewayProvider).card(widget.garage.id);
    if (!mounted) return;
    setState(() {
      _card = card;
      _loading = false;
    });
  }

  Future<void> _call() async {
    final phone = widget.garage.phone.trim();
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Routes to the workshop's pin, or to its name and locality for a garage
  /// that has not dropped one yet.
  Future<void> _directions() async {
    final g = widget.garage;
    final opened = await openDirections(
      lat: g.lat,
      lng: g.lng,
      address: [g.name, g.where].where((s) => s.isNotEmpty).join(', '),
    );
    if (!opened && mounted) {
      GFeedback.error(context, 'Could not open maps on this phone.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final services = _card?.services ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: GButton(
                  label: 'Call',
                  icon: Icons.call_rounded,
                  kind: GButtonKind.outline,
                  size: GButtonSize.md,
                  onPressed: widget.garage.phone.isEmpty ? null : _call,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: GButton(
                  label: 'Directions',
                  icon: Icons.directions_rounded,
                  kind: GButtonKind.outline,
                  size: GButtonSize.md,
                  onPressed: _directions,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xxl),
          Text('Services', style: AppType.labelL.c(p.ink)),
          const SizedBox(height: Gap.md),
          if (_loading)
            const GSkeletonGroup(
              child: Column(
                children: [
                  GSkeleton(height: 56),
                  SizedBox(height: Gap.sm),
                  GSkeleton(height: 56),
                ],
              ),
            )
          else if (services.isEmpty)
            Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                color: p.surfaceSunken,
                borderRadius: R.rMd,
                border: Border.all(color: p.line),
              ),
              child: Text(
                "This workshop hasn't published a price list yet. Call them "
                'and they will quote you directly.',
                style: AppType.bodyS.c(p.inkMuted),
              ),
            )
          else
            for (final s in services) ...[
              Container(
                margin: const EdgeInsets.only(bottom: Gap.sm),
                padding: const EdgeInsets.all(Gap.lg),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: R.rMd,
                  border: Border.all(color: p.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: AppType.labelM.c(p.ink)),
                          if (s.blurb.isNotEmpty) ...[
                            const SizedBox(height: Gap.xxs),
                            Text(s.blurb,
                                style: AppType.bodyS.c(p.inkMuted)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Text(Fmt.money(s.price), style: AppType.money.c(p.ink)),
                  ],
                ),
              ),
            ],
          const SizedBox(height: Gap.xxl),
          // The front door. This used to say "call the workshop to book" and
          // send the customer off for a code — a phone call to arrange being
          // allowed to do the thing the app is for. Now the request goes
          // straight to their front desk, where it arrives as a notification
          // the counter can accept or decline. Still only ever a request:
          // nothing here books a slot the workshop has not agreed to.
          GButton.accent(
            label: 'Book here',
            icon: Icons.event_available_rounded,
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Gap.md),
          Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: p.infoSoft,
              borderRadius: R.rMd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: p.info),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    'The workshop sees your request straight away. Once they '
                    'accept it, this garage appears in your app and every job '
                    'card they open for your vehicle shows up with it.',
                    style: AppType.bodyS.c(p.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
