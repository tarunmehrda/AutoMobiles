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
import '../../core/widgets/g_state.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../shared/support_sheet.dart';

/// Slot requests coming in from the customer app. Accepting one opens a job
/// card pre-filled with everything the customer already typed.
class BookingsPage extends ConsumerWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final bookings = ref.watch(openBookingsProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Bookings',
        subtitle: bookings.isEmpty
            ? 'Nothing waiting'
            : '${bookings.length} waiting to be accepted',
      ),
      body: bookings.isEmpty
          ? const GEmptyState(
              icon: Icons.event_available_rounded,
              title: 'All clear',
              message: 'New slot requests from the customer app land here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.md, Gap.page, Gap.h2),
              itemCount: bookings.length,
              itemBuilder: (context, i) {
                final b = bookings[i];
                return Entrance(
                  index: i.clamp(0, 8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: Gap.md),
                    padding: const EdgeInsets.all(Gap.lg),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: R.all(R.lg),
                      border: Border.all(color: p.line),
                      boxShadow: Shadows.soft(p),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GAvatar(
                              initials: Fmt.initials(b.name),
                              size: 40,
                              tone: GTone.accent,
                            ),
                            const SizedBox(width: Gap.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(b.name,
                                      style: AppType.h2.c(p.ink)),
                                  Text(b.phone,
                                      style:
                                          AppType.bodyS.c(p.inkMuted)),
                                ],
                              ),
                            ),
                            GPill(
                              label: Fmt.friendlyDay(b.at),
                              tone: GTone.warning,
                              compact: true,
                              icon: Icons.schedule_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Gap.md, vertical: Gap.sm),
                          decoration: BoxDecoration(
                            color: p.surfaceSunken,
                            borderRadius: R.all(R.sm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (b.vehicle.isNotEmpty)
                                Text(
                                  '${b.vehicle}'
                                  '${b.regNo.isEmpty ? '' : '  •  ${Fmt.plate(b.regNo)}'}',
                                  style: AppType.labelM.c(p.ink),
                                ),
                              Text('Slot: ${Fmt.fullDateTime(b.at)}',
                                  style: AppType.bodyS.c(p.inkMuted)),
                              if (b.note.isNotEmpty)
                                Text(b.note,
                                    style: AppType.bodyS.c(p.inkSoft)),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gap.md),
                        Row(
                          children: [
                            Expanded(
                              child: GButton(
                                label: 'Call',
                                kind: GButtonKind.ghost,
                                size: GButtonSize.sm,
                                icon: Icons.call_rounded,
                                onPressed: () =>
                                    launchDial(context, b.phone),
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            Expanded(
                              child: GButton(
                                label: 'Decline',
                                kind: GButtonKind.danger,
                                size: GButtonSize.sm,
                                onPressed: () async {
                                  final ok = await GFeedback.confirm(
                                    context,
                                    title: 'Decline this booking?',
                                    message:
                                        'It disappears from this list. The '
                                        'customer is not told automatically.',
                                    confirmLabel: 'Decline',
                                    destructive: true,
                                  );
                                  if (!ok) return;
                                  ref
                                      .read(adminProvider.notifier)
                                      .removeBooking(b.id);
                                },
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            Expanded(
                              flex: 2,
                              child: GButton.accent(
                                label: 'Open job card',
                                size: GButtonSize.sm,
                                expand: true,
                                onPressed: () =>
                                    context.push('/job/new?booking=${b.id}'),
                              ),
                            ),
                          ],
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
