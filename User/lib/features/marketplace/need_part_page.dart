import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../data/models/entities.dart';
import '../../data/repo/marketplace_gateway.dart';
import '../../state/providers.dart';
import 'widgets/photo_strip.dart';
import 'widgets/vehicle_picker.dart';

/// "I need this part" — the customer describes what they are after and the
/// platform comes back with a price.
///
/// Nothing here quotes anything. A parts price depends on the variant, the
/// year and what is actually in a warehouse this week, and a screen that
/// guessed would be wrong often enough to cost the platform the customer.
class NeedPartPage extends ConsumerStatefulWidget {
  const NeedPartPage({super.key});

  @override
  ConsumerState<NeedPartPage> createState() => _NeedPartPageState();
}

class _NeedPartPageState extends ConsumerState<NeedPartPage> {
  final _part = TextEditingController();
  final _detail = TextEditingController();
  final _otherVehicle = TextEditingController();

  Vehicle? _vehicle;
  bool _otherCar = false;
  List<String> _photos = const [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Whatever car they were last looking at is the overwhelmingly likely
    // answer, so it is filled in rather than asked for.
    _vehicle = ref.read(activeVehicleProvider);
  }

  @override
  void dispose() {
    _part.dispose();
    _detail.dispose();
    _otherVehicle.dispose();
    super.dispose();
  }

  String get _vehicleText => _otherCar
      ? _otherVehicle.text.trim()
      : [_vehicle?.brand, _vehicle?.model, _vehicle?.variant]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .join(' ');

  bool get _valid =>
      _part.text.trim().length >= 2 && _vehicleText.isNotEmpty && !_sending;

  Future<void> _submit() async {
    setState(() => _sending = true);
    final sent = await ref.read(marketplaceGatewayProvider).createRequest(
          partName: _part.text,
          detail: _detail.text,
          vehicleText: _vehicleText,
          vehicleId: _otherCar ? null : _vehicle?.id,
          photoPaths: _photos,
        );
    if (!mounted) return;
    setState(() => _sending = false);

    if (sent == null) {
      GFeedback.error(
        context,
        'Could not send that. Check your connection and try again — nothing '
        'was lost.',
      );
      return;
    }

    // The code is the whole point of the screen that follows: it is what the
    // customer quotes on the phone, so it is shown big and on its own.
    await _showCode(sent.code, photosFailed: sent.photosFailed);
    if (mounted) Navigator.of(context).pop();
  }

  /// The reference, and — when some of the pictures did not make it up —
  /// how many. Said on the sheet itself: a toast would sit behind it.
  Future<void> _showCode(String code, {int photosFailed = 0}) {
    final p = context.c;
    return GFeedback.sheet<void>(
      context,
      title: 'Request sent',
      subtitle: 'We will come back to you with a price.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: Gap.xxl),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: R.rLg,
                border: Border.all(color: p.accent.withValues(alpha: 0.22)),
              ),
              child: Column(
                children: [
                  Text('YOUR REFERENCE',
                      style: AppType.over.c(p.accentInk)),
                  const SizedBox(height: Gap.sm),
                  Text(code, style: AppType.d2.c(p.accentInk)),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text(
              'Quote this code when you call. You can also find it any time '
              'under Parts.',
              textAlign: TextAlign.center,
              style: AppType.bodyS.c(p.inkMuted),
            ),
            if (photosFailed > 0) ...[
              const SizedBox(height: Gap.md),
              Text(
                '${photosFailed == 1 ? '1 photo' : '$photosFailed photos'} '
                'could not be uploaded, so the request went without '
                '${photosFailed == 1 ? 'it' : 'them'}.',
                textAlign: TextAlign.center,
                style: AppType.bodyS.c(p.warning),
              ),
            ],
            const SizedBox(height: Gap.xxl),
            GButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: const GHeader(
        title: 'I need this part',
        subtitle: 'Tell us what you are after',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
        children: [
          VehiclePicker(
            vehicles: vehicles,
            selected: _vehicle,
            other: _otherCar,
            otherController: _otherVehicle,
            onSelect: (v) => setState(() {
              _vehicle = v;
              _otherCar = false;
            }),
            onOther: () => setState(() => _otherCar = true),
            onOtherChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.xxl),
          GField(
            label: 'Part needed',
            hint: 'Front brake pads, headlight assembly…',
            controller: _part,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Anything else we should know',
            hint: 'Original or aftermarket, how urgent, part number if you '
                'have it',
            controller: _detail,
            maxLines: 4,
          ),
          const SizedBox(height: Gap.xxl),
          PhotoStrip(
            paths: _photos,
            onChanged: (next) => setState(() => _photos = next),
          ),
          const SizedBox(height: Gap.h1),
          GButton(
            label: 'Send request',
            icon: Icons.send_rounded,
            loading: _sending,
            onPressed: _valid ? _submit : null,
          ),
          const SizedBox(height: Gap.md),
          Text(
            'Sending this does not commit you to buying anything.',
            textAlign: TextAlign.center,
            style: AppType.bodyS.c(p.inkFaint),
          ),
        ],
      ),
    );
  }
}
