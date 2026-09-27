import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../shared/support_sheet.dart';
import 'booking_details.dart';

/// Slot requests coming in from the customer app. Accepting one opens a job
/// card pre-filled with everything the customer already typed.
class BookingsPage extends ConsumerWidget {
  const BookingsPage({super.key, this.focusId});

  /// The booking a tapped notification is about: shown first and outlined,
  /// so the counter is not left hunting for it in the list.
  final String? focusId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final open = ref.watch(openBookingsProvider);
    final bookings = [
      ...open.where((b) => b.id == focusId),
      ...open.where((b) => b.id != focusId),
    ];

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Bookings'.tr,
        subtitle: bookings.isEmpty
            ? 'Nothing waiting'.tr
            : '{0} waiting to be accepted'.trf([bookings.length]),
      ),
      // Pull to refresh, because the realtime channel is not always the
      // one that brings a booking in. On a project whose `garage_bookings`
      // is missing from the realtime publication the row lands in the
      // database immediately and no event ever reaches the console, and
      // this screen had no way to ask again -- four bookings confirmed on
      // a customer's phone showed up as one, and only a force-stop and
      // relaunch brought the rest. The counter should never have to
      // restart the app to see the work coming in.
      //
      // `AlwaysScrollableScrollPhysics` on both branches so the gesture
      // works on the empty state too, which is exactly when somebody is
      // most likely to try it.
      body: RefreshIndicator(
        onRefresh: () => ref.read(adminProvider.notifier).resync(),
        child: bookings.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.7,
                  child: GEmptyState(
                    icon: Icons.event_available_rounded,
                    title: 'All clear'.tr,
                    art: Art.done,
                    message:
                        'New slot requests from the customer app land here.'
                            .tr,
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.md,
                Gap.page,
                Gap.h2,
              ),
              itemCount: bookings.length,
              itemBuilder: (context, i) {
                final b = bookings[i];
                final focused = b.id == focusId;
                return Entrance(
                  index: i.clamp(0, 8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: Gap.md),
                    padding: const EdgeInsets.all(Gap.lg),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: R.all(R.lg),
                      border: Border.all(
                        color: focused ? p.accent : p.line,
                        width: focused ? 2 : 1,
                      ),
                      boxShadow: focused ? Shadows.lifted(p) : Shadows.soft(p),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.name, style: AppType.h2.c(p.ink)),
                                  Text(
                                    b.phone,
                                    style: AppType.bodyS.c(p.inkMuted),
                                  ),
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
                            horizontal: Gap.md,
                            vertical: Gap.sm,
                          ),
                          decoration: BoxDecoration(
                            color: p.surfaceSunken,
                            borderRadius: R.all(R.sm),
                          ),
                          child: BookingDetails(booking: b),
                        ),
                        const SizedBox(height: Gap.md),
                        Row(
                          children: [
                            Expanded(
                              child: GButton(
                                label: 'Call'.tr,
                                kind: GButtonKind.ghost,
                                size: GButtonSize.sm,
                                icon: Icons.call_rounded,
                                onPressed: () => launchDial(context, b.phone),
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            Expanded(
                              child: GButton(
                                label: 'Decline'.tr,
                                kind: GButtonKind.danger,
                                size: GButtonSize.sm,
                                onPressed: () async {
                                  final ok = await GFeedback.confirm(
                                    context,
                                    title: 'Decline this booking?'.tr,
                                    message:
                                        'It disappears from this list, and the customer app shows it as declined.'
                                            .tr,
                                    confirmLabel: 'Decline'.tr,
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
                                label: 'Open job card'.tr,
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
      ),
    );
  }
}
