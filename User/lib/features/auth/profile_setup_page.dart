import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_field.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  /// Prefilled with whatever sign-in brought, which for a Google account is
  /// nothing — hence editable. The workshop finds a customer's bookings by
  /// this number, so an empty one is a customer it cannot match.
  late final _phone =
      TextEditingController(text: ref.read(userProvider)?.phone ?? '');
  DateTime? _dob;
  String? _gender;

  /// Optional like everything but the name, but a number that is typed has
  /// to be a whole one: nine digits matches nobody at the counter.
  bool get _phoneOk {
    final n = _phone.text.trim().length;
    return n == 0 || n == 10;
  }

  bool get _valid => _name.text.trim().length >= 2 && _phoneOk;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 28, now.month, now.day),
      firstDate: DateTime(now.year - 90),
      lastDate: DateTime(now.year - 16),
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _save() {
    if (!_valid) return;
    ref.read(appControllerProvider.notifier).saveProfile(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          dob: _dob,
          gender: _gender,
        );
    context.go('/vehicle/add');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, Gap.h1, Gap.page, Gap.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Entrance(
                      child: Row(
                        children: [
                          GAvatar(
                            initials: _name.text.trim().isEmpty
                                ? '?'
                                : Fmt.initials(_name.text),
                            size: 56,
                            tone: GTone.accent,
                          ),
                          const SizedBox(width: Gap.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Almost there',
                                    style: AppType.over.c(p.accentInk)),
                                const SizedBox(height: 4),
                                Text('Tell us who\nwe are serving',
                                    style: AppType.d2.c(p.ink)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    Entrance(
                      index: 1,
                      child: Text(
                        'This goes on your job cards and invoices. '
                        'Everything except your name is optional.',
                        style: AppType.bodyM.c(p.inkMuted),
                      ),
                    ),
                    const SizedBox(height: Gap.h1),
                    Entrance(
                      index: 2,
                      child: GField(
                        label: 'Full name',
                        hint: 'e.g. Rohit Verma',
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        prefix: Icon(Icons.person_outline_rounded,
                            size: 19, color: p.inkMuted),
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                    Entrance(
                      index: 3,
                      child: GField(
                        label: 'Mobile number',
                        hint: '10-digit number',
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textCapitalization: TextCapitalization.none,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        helper: 'So your garage can match your bookings '
                            'and reach you',
                        onChanged: (_) => setState(() {}),
                        prefix: Icon(Icons.phone_outlined,
                            size: 19, color: p.inkMuted),
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                    Entrance(
                      index: 4,
                      child: GField(
                        label: 'Email (optional)',
                        hint: 'name@email.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textCapitalization: TextCapitalization.none,
                        helper: 'Invoices and service reminders go here too',
                        prefix: Icon(Icons.mail_outline_rounded,
                            size: 19, color: p.inkMuted),
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                    Entrance(
                      index: 5,
                      child: GPickerField(
                        label: 'Date of birth (optional)',
                        value: _dob == null ? null : Fmt.date(_dob!),
                        placeholder: 'Pick a date',
                        leadingIcon: Icons.cake_outlined,
                        icon: Icons.calendar_month_rounded,
                        onTap: _pickDob,
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                    Entrance(
                      index: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gender (optional)',
                              style: AppType.labelM.c(p.inkSoft)),
                          const SizedBox(height: Gap.sm),
                          Wrap(
                            spacing: Gap.sm,
                            children: [
                              for (final g in const [
                                'Female',
                                'Male',
                                'Other',
                                'Prefer not to say'
                              ])
                                ChoiceChip(
                                  label: Text(g),
                                  selected: _gender == g,
                                  showCheckmark: false,
                                  labelStyle: AppType.labelM.c(
                                      _gender == g
                                          ? (p.isDark ? p.canvas : Colors.white)
                                          : p.inkSoft),
                                  backgroundColor: p.surface,
                                  selectedColor: p.ink,
                                  side: BorderSide(
                                      color: _gender == g ? p.ink : p.line),
                                  onSelected: (v) =>
                                      setState(() => _gender = v ? g : null),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.sm, Gap.page, Gap.lg),
              child: GButton.accent(
                label: 'Continue',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: _valid ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
