import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../data/repo/auth_service.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// Settings → Delete account.
///
/// An owner loses the workshop and everything in it; a staff member loses
/// only their own login. Both are said in plain words, and nothing happens
/// until DELETE is typed — a tap alone must not be able to erase a shop.
Future<void> confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final deleted = await GFeedback.sheet<bool>(
    context,
    title: 'Delete account'.tr,
    subtitle: 'This cannot be undone'.tr,
    child: const _DeleteSheet(),
  );
  if (deleted != true) return;
  await localStore.forgetEverything();
  ref.read(adminProvider.notifier).wipe();
  if (context.mounted) {
    GFeedback.success(context, 'Account deleted. Everything is gone.'.tr);
  }
}

class _DeleteSheet extends ConsumerStatefulWidget {
  const _DeleteSheet();

  @override
  ConsumerState<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends ConsumerState<_DeleteSheet> {
  final _typed = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _armed => _typed.text.trim().toUpperCase() == 'DELETE';

  Future<void> _delete() async {
    setState(() => _busy = true);
    final error = await ref.read(authServiceProvider).deleteWorkshopAccount();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      GFeedback.error(context, error.tr);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final owner = ref.watch(accessProvider).isOwner;
    final data = ref.watch(adminDataProvider);
    final shop = data.garage?.name ?? '';

    final gone = owner
        ? [
            'The workshop {0}'.trf([shop.isEmpty ? '' : '"$shop"']).trim(),
            '{0} job cards, with their bills and payments'.trf([
              data.jobCards.length,
            ]),
            '{0} customers and their vehicles'.trf([data.customers.length]),
            '{0} staff, their logins and attendance'.trf([data.staff.length]),
            'Stock, bookings, expenses, cash book and reports'.tr,
            'Your login'.tr,
          ]
        : [
            'Your login and your access to {0}'.trf([
              shop.isEmpty ? 'this workshop'.tr : shop,
            ]),
          ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Gap.page,
        Gap.lg,
        Gap.page,
        MediaQuery.of(context).viewInsets.bottom + Gap.h1,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: p.dangerSoft,
              borderRadius: R.all(R.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: p.danger),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        'Deleted for good'.tr,
                        style: AppType.labelL.c(p.danger),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                for (final line in gone)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(Icons.circle, size: 6, color: p.danger),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(line, style: AppType.bodyM.c(p.ink)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          Text(
            owner
                ? 'Staff you gave the app to lose it too. Customers keep their own app account.'
                      .tr
                : 'The workshop and its job cards stay with the owner.'.tr,
            style: AppType.bodyS.c(p.inkMuted),
          ),
          const SizedBox(height: Gap.xl),
          GField(
            label: 'Type DELETE to confirm'.tr,
            hint: 'DELETE',
            controller: _typed,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.lg),
          GButton(
            label: 'Delete forever'.tr,
            kind: GButtonKind.danger,
            size: GButtonSize.lg,
            icon: Icons.delete_forever_rounded,
            expand: true,
            loading: _busy,
            onPressed: _armed && !_busy ? _delete : null,
          ),
          const SizedBox(height: Gap.sm),
          GButton(
            label: 'Keep my account'.tr,
            kind: GButtonKind.ghost,
            size: GButtonSize.md,
            expand: true,
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
