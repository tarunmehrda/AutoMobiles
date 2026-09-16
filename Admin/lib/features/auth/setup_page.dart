import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_field.dart';
import '../../data/models/entities.dart';
import '../../data/seed/seed.dart';
import '../../state/admin_state.dart';

/// One-time workshop details. Everything here prints on the estimate, the
/// invoice and the mechanic copy, so it is worth getting right once.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pin = TextEditingController();
  final _gstin = TextEditingController();
  final _upi = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _email,
      _address,
      _city,
      _state,
      _pin,
      _gstin,
      _upi,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _phone.text.trim().length >= 10;

  void _save() {
    if (!_valid) return;
    ref.read(adminProvider.notifier).saveGarage(Garage(
          id: newId('garage'),
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          addressLine: _address.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          pin: _pin.text.trim(),
          gstin: _gstin.text.trim().toUpperCase(),
          upiId: _upi.text.trim(),
          terms: Seed.terms.join('\n'),
          planExpiry: DateTime.now().add(const Duration(days: 365)),
        ));
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Gap.page, Gap.xxl, Gap.page, Gap.h2),
          children: [
            Entrance(
              child: Text('Set up your workshop', style: AppType.d1.c(p.ink)),
            ),
            const SizedBox(height: Gap.sm),
            Entrance(
              index: 1,
              child: Text(
                'These details head every document you hand a customer.',
                style: AppType.bodyL.c(p.inkMuted),
              ),
            ),
            const SizedBox(height: Gap.h1),
            Entrance(
              index: 2,
              child: GField(
                label: 'Workshop name',
                hint: 'Vikas Automobiles',
                controller: _name,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: Gap.lg),
            Entrance(
              index: 3,
              child: GField(
                label: 'Contact number',
                hint: '10-digit number',
                controller: _phone,
                keyboardType: TextInputType.phone,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: Gap.lg),
            Entrance(
              index: 4,
              child: GField(
                label: 'Email',
                hint: 'Optional',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
              ),
            ),
            const SizedBox(height: Gap.lg),
            Entrance(
              index: 5,
              child: GField(
                label: 'Address',
                hint: 'Street and area',
                controller: _address,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: Gap.lg),
            Entrance(
              index: 6,
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: GField(label: 'City', controller: _city)),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    flex: 2,
                    child: GField(
                      label: 'PIN',
                      controller: _pin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            Entrance(
              index: 7,
              child: GField(label: 'State', controller: _state),
            ),
            const SizedBox(height: Gap.lg),
            Entrance(
              index: 8,
              child: GField(
                label: 'GSTIN',
                hint: 'Leave blank if not registered',
                controller: _gstin,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(15)],
              ),
            ),
            const SizedBox(height: Gap.lg),
            Entrance(
              index: 9,
              child: GField(
                label: 'UPI ID',
                hint: 'Used for the payment QR on invoices',
                controller: _upi,
                textCapitalization: TextCapitalization.none,
              ),
            ),
            const SizedBox(height: Gap.h1),
            Entrance(
              index: 10,
              child: GButton.accent(
                label: 'Open the console',
                onPressed: _valid ? _save : null,
                trailingIcon: Icons.arrow_forward_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
