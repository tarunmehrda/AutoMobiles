import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/g_art.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../state/admin_state.dart';
import '../../../state/providers.dart';

/// Who is working on this vehicle.
///
/// The card was carrying mechanics from the moment it was opened and printing
/// them on the documents, but there was nowhere to change them afterwards —
/// the man who actually did the job is rarely the one who was free when the
/// key came over the counter.
class MechanicsPage extends ConsumerWidget {
  const MechanicsPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final card = ref.watch(jobCardProvider(id));
    final staff = ref.watch(staffProvider);

    if (card == null) {
      return Scaffold(
        appBar: GHeader(
          title: 'Mechanics'.tr,
          subtitle: 'Who is on this vehicle'.tr,
        ),
        body: GEmptyState(
          icon: Icons.engineering_outlined,
          title: 'Job card not found'.tr,
          art: Art.searching,
          message: 'Nothing to attach this to.'.tr,
        ),
      );
    }

    final active = staff.where((s) => s.active).toList();
    final picked = card.mechanicIds;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Mechanics'.tr,
        subtitle: picked.isEmpty
            ? 'Nobody assigned yet'.tr
            : '{0} on this card'.trf([picked.length]),
      ),
      body: active.isEmpty
          ? GEmptyState(
              icon: Icons.engineering_rounded,
              title: 'No staff on the roll'.tr,
              message:
                  'Add the floor staff once, and they can be put on every job card after that.'
                      .tr,
              actionLabel: 'Open staff'.tr,
              onAction: () => context.push('/staff'),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.md,
                Gap.page,
                Gap.h2,
              ),
              itemCount: active.length,
              separatorBuilder: (context, i) => const SizedBox(height: Gap.sm),
              itemBuilder: (context, i) {
                final s = active[i];
                final on = picked.contains(s.id);
                return Pressable(
                  onTap: () {
                    final next = [...picked];
                    if (!next.remove(s.id)) next.add(s.id);
                    ref.read(adminProvider.notifier).setMechanics(id, next);
                  },
                  scale: 0.98,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: on ? p.accent.withValues(alpha: 0.10) : p.surface,
                      borderRadius: R.all(R.md),
                      border: Border.all(color: on ? p.accent : p.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 38,
                          width: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on ? p.accentSoft : p.surfaceSunken,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            Fmt.initials(s.name),
                            style: AppType.labelM.c(
                              on ? p.accentInk : p.inkMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: AppType.labelL.c(p.ink)),
                              if (s.skill.isNotEmpty)
                                Text(
                                  s.skill,
                                  style: AppType.bodyS.c(p.inkMuted),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          on
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 20,
                          color: on ? p.accent : p.inkFaint,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
