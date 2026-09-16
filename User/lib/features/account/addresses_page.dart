import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import '../booking/widgets/address_sheet.dart';

class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final addresses = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Addresses',
        subtitle: addresses.isEmpty
            ? 'Used for pickup and drop'
            : '${addresses.length} saved',
      ),
      body: addresses.isEmpty
          ? GEmptyState(
              icon: Icons.place_outlined,
              title: 'No addresses saved',
              message:
                  'Save where we should collect your car and the booking flow '
                  'gets two taps shorter.',
              actionLabel: 'Add an address',
              onAction: () => showAddressEditor(context),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.sm, Gap.page, Gap.h2),
              itemCount: addresses.length,
              separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
              itemBuilder: (context, i) {
                final a = addresses[i];
                return Entrance(
                  index: i,
                  child: GCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: p.surfaceSunken,
                                borderRadius: R.all(R.sm),
                              ),
                              child:
                                  Icon(a.icon, size: 18, color: p.inkSoft),
                            ),
                            const SizedBox(width: Gap.md),
                            Text(a.label, style: AppType.h3.c(p.ink)),
                            const SizedBox(width: Gap.sm),
                            if (a.isDefault)
                              const GPill(
                                  label: 'DEFAULT',
                                  tone: GTone.success,
                                  compact: true),
                            const Spacer(),
                            Pressable(
                              onTap: () => _menu(context, ref, a.id, a.isDefault),
                              child: Icon(Icons.more_horiz_rounded,
                                  color: p.inkMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.md),
                        Text(a.oneLine, style: AppType.bodyM.c(p.inkSoft)),
                        if (a.landmark != null) ...[
                          const SizedBox(height: 4),
                          Text('Landmark: ${a.landmark}',
                              style: AppType.bodyS.c(p.inkMuted)),
                        ],
                        if (a.contactPhone != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.call_rounded,
                                  size: 13, color: p.inkFaint),
                              const SizedBox(width: 5),
                              Text(
                                '${a.contactName ?? 'Contact'} • ${a.contactPhone}',
                                style: AppType.labelS.c(p.inkMuted),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: addresses.isEmpty
          ? null
          : GBottomBar(
              child: GButton.accent(
                label: 'Add another address',
                icon: Icons.add_rounded,
                onPressed: () => showAddressEditor(context),
              ),
            ),
    );
  }

  void _menu(
      BuildContext context, WidgetRef ref, String id, bool isDefault) {
    final address =
        ref.read(addressesProvider).where((a) => a.id == id).firstOrNull;
    if (address == null) return;

    GFeedback.sheet<void>(
      context,
      title: 'Address options',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GTile(
              title: 'Edit address',
              icon: Icons.edit_rounded,
              onTap: () {
                Navigator.of(context).pop();
                showAddressEditor(context, existing: address);
              },
            ),
            if (!isDefault)
              GTile(
                title: 'Set as default',
                icon: Icons.check_circle_outline_rounded,
                onTap: () {
                  ref.read(appControllerProvider.notifier).setDefaultAddress(id);
                  Navigator.of(context).pop();
                  GFeedback.success(context, 'Default address updated');
                },
              ),
            GTile(
              title: 'Delete',
              icon: Icons.delete_outline_rounded,
              iconColor: context.c.danger,
              onTap: () async {
                Navigator.of(context).pop();
                final ok = await GFeedback.confirm(
                  context,
                  title: 'Delete this address?',
                  message: 'Bookings already using it are not affected.',
                  confirmLabel: 'Delete',
                  destructive: true,
                  icon: Icons.delete_outline_rounded,
                );
                if (!ok || !context.mounted) return;
                ref.read(appControllerProvider.notifier).removeAddress(id);
                GFeedback.info(context, 'Address deleted');
              },
            ),
          ],
        ),
      ),
    );
  }
}
