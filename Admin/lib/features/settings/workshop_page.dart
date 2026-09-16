import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
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

  void _save() {
    final g = ref.read(garageProvider);
    if (g == null) return;
    ref.read(adminProvider.notifier).saveGarage(g.copyWith(
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
        ));
    GFeedback.success(context, 'Workshop details saved');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (!_ready) {
      return const Scaffold(
        appBar: GHeader(title: 'Business details'),
        body: GEmptyState(
          icon: Icons.storefront_outlined,
          title: 'No workshop set up',
          message: 'Sign in again to run through setup.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: const GHeader(
        title: 'Business details',
        subtitle: 'Printed on every estimate, invoice and copy',
      ),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          GField(
            label: 'Workshop name',
            controller: _name,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: GField(
                  label: 'Phone',
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
                  label: 'Alternate',
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
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Address',
            controller: _address,
            maxLines: 2,
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: GField(label: 'City', controller: _city),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                flex: 2,
                child: GField(
                  label: 'PIN',
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
          GField(label: 'State', controller: _state),

          const SizedBox(height: Gap.xxl),
          Text('BILLING', style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.md),
          GField(
            label: 'GSTIN',
            hint: 'Leave blank if not registered',
            controller: _gstin,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(15)],
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'UPI ID',
            hint: 'Drives the payment QR on invoices',
            controller: _upi,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Terms and conditions',
            hint: 'One per line',
            controller: _terms,
            maxLines: 5,
          ),

          const SizedBox(height: Gap.xxl),
          Text('SUBSCRIPTION', style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.md),
          GPickerField(
            label: 'Plan expires on',
            value: _expiry == null ? null : Fmt.date(_expiry!),
            placeholder: 'Not set',
            icon: Icons.event_rounded,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _expiry ?? DateTime.now(),
                firstDate: DateTime.now()
                    .subtract(const Duration(days: 365)),
                lastDate:
                    DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) setState(() => _expiry = picked);
            },
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(label: 'Save', onPressed: _save),
      ),
    );
  }
}
