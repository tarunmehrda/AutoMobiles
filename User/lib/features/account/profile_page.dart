import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final _name =
      TextEditingController(text: ref.read(userProvider)?.name ?? '');
  late final _email =
      TextEditingController(text: ref.read(userProvider)?.email ?? '');
  late DateTime? _dob = ref.read(userProvider)?.dob;
  late String? _gender = ref.read(userProvider)?.gender;
  bool _dirty = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().length < 2) {
      GFeedback.error(context, 'Please enter your name');
      return;
    }
    ref.read(appControllerProvider.notifier).saveProfile(
          name: _name.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          dob: _dob,
          gender: _gender,
        );
    setState(() => _dirty = false);
    GFeedback.success(context, 'Profile updated');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final user = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Profile',
        subtitle: user?.phone,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          Entrance(
            child: Center(
              child: Column(
                children: [
                  GAvatar(
                    initials: Fmt.initials(
                        _name.text.isEmpty ? 'G' : _name.text),
                    size: 82,
                    tone: GTone.accent,
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    user?.createdAt == null
                        ? 'Member'
                        : 'Customer since ${Fmt.monthName(user!.createdAt!)}',
                    style: AppType.labelM.c(p.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.h1),
          Entrance(
            index: 1,
            child: GField(
              label: 'Full name',
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _dirty = true),
              prefix:
                  Icon(Icons.person_outline_rounded, size: 19, color: p.inkMuted),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Entrance(
            index: 2,
            child: GField(
              label: 'Mobile number',
              initialValue: user?.phone ?? '',
              enabled: false,
              helper: 'Contact support to change your registered number',
              suffix:
                  Icon(Icons.verified_rounded, size: 18, color: p.success),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Entrance(
            index: 3,
            child: GField(
              label: 'Email',
              hint: 'name@email.com',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              onChanged: (_) => setState(() => _dirty = true),
              prefix:
                  Icon(Icons.mail_outline_rounded, size: 19, color: p.inkMuted),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Entrance(
            index: 4,
            child: GPickerField(
              label: 'Date of birth',
              value: _dob == null ? null : Fmt.date(_dob!),
              placeholder: 'Not set',
              leadingIcon: Icons.cake_outlined,
              icon: Icons.calendar_month_rounded,
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(now.year - 28),
                  firstDate: DateTime(now.year - 90),
                  lastDate: DateTime(now.year - 16),
                );
                if (picked != null) {
                  setState(() {
                    _dob = picked;
                    _dirty = true;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: Gap.lg),
          Entrance(
            index: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gender', style: AppType.labelM.c(p.inkSoft)),
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
                        backgroundColor: p.surface,
                        selectedColor: p.ink,
                        side: BorderSide(color: _gender == g ? p.ink : p.line),
                        labelStyle: AppType.labelM.c(_gender == g
                            ? (p.isDark ? p.canvas : Colors.white)
                            : p.inkSoft),
                        onSelected: (v) => setState(() {
                          _gender = v ? g : null;
                          _dirty = true;
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xxl),
          Entrance(
            index: 6,
            child: GButton(
              label: 'Delete my account',
              kind: GButtonKind.danger,
              size: GButtonSize.md,
              expand: true,
              icon: Icons.delete_outline_rounded,
              onPressed: () async {
                final ok = await GFeedback.confirm(
                  context,
                  title: 'Delete account?',
                  message:
                      'This clears your profile, vehicles and saved addresses '
                      'from this device. Invoices are retained by the workshop '
                      'as tax law requires.',
                  confirmLabel: 'Delete',
                  destructive: true,
                  icon: Icons.warning_amber_rounded,
                );
                if (!ok || !context.mounted) return;
                await ref.read(appControllerProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: 'Save changes',
          onPressed: _dirty ? _save : null,
        ),
      ),
    );
  }
}
