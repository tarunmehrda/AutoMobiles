import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// The team. Mechanics are assigned per job card and per line, which is what
/// makes the mechanic copy worth printing.
class StaffPage extends ConsumerWidget {
  const StaffPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final staff = ref.watch(staffProvider);
    final data = ref.watch(adminDataProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Mechanics',
        subtitle: '${staff.length} on the team',
        actions: [
          GIconButton(
            icon: Icons.add_rounded,
            size: 40,
            onTap: () => _editor(context, ref, null),
          ),
        ],
      ),
      body: staff.isEmpty
          ? GEmptyState(
              icon: Icons.engineering_rounded,
              title: 'No mechanics yet',
              message:
                  'Add the team so work can be assigned per job card and per '
                  'line on the mechanic copy.',
              actionLabel: 'Add a mechanic',
              onAction: () => _editor(context, ref, null),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.md, Gap.page, Gap.h2),
              itemCount: staff.length,
              itemBuilder: (context, i) {
                final s = staff[i];
                // How much work is sitting with this mechanic right now.
                final live = data.jobCards
                    .where((j) =>
                        j.isOpen &&
                        (j.mechanicIds.contains(s.id) ||
                            j.items.any((e) => e.mechanicId == s.id)))
                    .length;

                return Pressable(
                  onTap: () => _editor(context, ref, s),
                  scale: 0.985,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: Gap.sm),
                    padding: const EdgeInsets.all(Gap.lg),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: R.all(R.md),
                      border: Border.all(color: p.line),
                      boxShadow: Shadows.soft(p),
                    ),
                    child: Row(
                      children: [
                        GAvatar(
                          initials: Fmt.initials(s.name),
                          size: 42,
                          tone: s.active ? GTone.ink : GTone.neutral,
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: AppType.h2.c(p.ink)),
                              Text(
                                [
                                  if (s.skill.isNotEmpty) s.skill,
                                  if (s.phone.isNotEmpty) s.phone,
                                ].join('  •  '),
                                style: AppType.bodyS.c(p.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        if (!s.active)
                          GPill(
                            label: 'Inactive',
                            tone: GTone.neutral,
                            compact: true,
                          )
                        else if (live > 0)
                          GPill(
                            label: '$live on the floor',
                            tone: GTone.accent,
                            compact: true,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editor(
    BuildContext context,
    WidgetRef ref,
    Staff? existing,
  ) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final skill = TextEditingController(text: existing?.skill ?? '');
    var active = existing?.active ?? true;

    await GFeedback.sheet<void>(
      context,
      title: existing == null ? 'Add a mechanic' : existing.name,
      child: StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page,
              MediaQuery.of(context).viewInsets.bottom + Gap.h1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GField(
                label: 'Name',
                controller: name,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: Gap.lg),
              GField(
                label: 'Phone',
                hint: 'Optional',
                controller: phone,
                keyboardType: TextInputType.phone,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: Gap.lg),
              GField(
                label: 'Speciality',
                hint: 'Engine, electrical, denting…',
                controller: skill,
                textCapitalization: TextCapitalization.words,
              ),
              if (existing != null) ...[
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active',
                              style:
                                  AppType.labelL.c(context.c.ink)),
                          Text('Inactive mechanics stay on old job cards '
                              'but cannot be assigned new work',
                              style: AppType.bodyS.c(context.c.inkMuted)),
                        ],
                      ),
                    ),
                    Switch(
                      value: active,
                      onChanged: (v) => setSheet(() => active = v),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Gap.xxl),
              Row(
                children: [
                  if (existing != null) ...[
                    Expanded(
                      child: GButton(
                        label: 'Remove',
                        kind: GButtonKind.danger,
                        size: GButtonSize.md,
                        onPressed: () {
                          ref
                              .read(adminProvider.notifier)
                              .removeStaff(existing.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: GButton.accent(
                      label: existing == null ? 'Add' : 'Save',
                      size: GButtonSize.md,
                      onPressed: () {
                        if (name.text.trim().isEmpty) return;
                        final ctrl = ref.read(adminProvider.notifier);
                        if (existing == null) {
                          ctrl.addStaff(
                            name: name.text.trim(),
                            phone: phone.text.trim(),
                            skill: skill.text.trim(),
                          );
                        } else {
                          ctrl.updateStaff(existing.copyWith(
                            name: name.text.trim(),
                            phone: phone.text.trim(),
                            skill: skill.text.trim(),
                            active: active,
                          ));
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    for (final c in [name, phone, skill]) {
      c.dispose();
    }
  }
}
