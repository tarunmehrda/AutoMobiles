import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../../state/providers.dart';

/// The workshop switcher behind the name in the header. One console holds one
/// workshop today, so the sheet shows the signed-in workshop as the live one
/// and nothing else.
///
/// It used to end in an "Add Account" button that closed the sheet, said
/// "sign out first" and dropped the counter on Settings — a button for a
/// feature that does not exist. There is no screen for more workshops or
/// more logins on one console (Staff is the mechanics roster, not accounts),
/// so the button is gone rather than pointing somewhere it cannot keep.
Future<void> showAccountSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _AccountSheet(),
    );

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final garage = ref.watch(garageProvider);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xxl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.md,
            Gap.page,
            Gap.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: p.line,
                  borderRadius: R.all(R.pill),
                ),
              ),
              const SizedBox(height: Gap.lg),
              Text('Select Account'.tr, style: AppType.h1.c(p.ink)),
              const SizedBox(height: Gap.lg),
              if (garage != null)
                _Row(
                  name: garage.name,
                  phone: garage.phone,
                  selected: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              const SizedBox(height: Gap.lg),
              GButton.outline(
                label: 'Close'.tr,
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.name,
    required this.phone,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String phone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surfaceAlt,
          borderRadius: R.all(R.md),
          border: Border.all(
            color: selected ? p.accent.withValues(alpha: 0.4) : p.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: p.surface,
                shape: BoxShape.circle,
                border: Border.all(color: p.line),
              ),
              child: Center(
                child: Text(
                  Fmt.initials(name),
                  style: AppType.labelM.c(p.inkSoft),
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  Text(phone, style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 22, color: p.success),
          ],
        ),
      ),
    );
  }
}
