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
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NotifyKind? _filter;

  GTone _tone(NotifyKind k) => switch (k) {
        NotifyKind.booking => GTone.info,
        NotifyKind.service => GTone.accent,
        NotifyKind.approval => GTone.warning,
        NotifyKind.payment => GTone.success,
        NotifyKind.maintenance => GTone.neutral,
        NotifyKind.offer => GTone.danger,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final all = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);
    final items =
        _filter == null ? all : all.where((n) => n.kind == _filter).toList();

    // Bucket by recency so a long list stays scannable.
    final now = DateTime.now();
    final today = items
        .where((n) => now.difference(n.at).inHours < 24)
        .toList();
    final week = items
        .where((n) =>
            now.difference(n.at).inHours >= 24 &&
            now.difference(n.at).inDays < 7)
        .toList();
    final older =
        items.where((n) => now.difference(n.at).inDays >= 7).toList();

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Notifications',
        subtitle: unread == 0 ? 'All caught up' : '$unread unread',
        actions: [
          if (unread > 0)
            GButton.ghost(
              label: 'Mark all read',
              size: GButtonSize.sm,
              onPressed: () => ref
                  .read(appControllerProvider.notifier)
                  .markAllNotificationsRead(),
            ),
        ],
      ),
      body: all.isEmpty
          ? GEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Nothing here yet',
              message:
                  'Booking confirmations, inspection updates, approvals and '
                  'payment receipts all land here.',
              actionLabel: 'Book a service',
              // Pushed so booking's back arrow returns here; `go` left it
              // as the only route, with nothing underneath to pop to.
              onAction: () => context.push('/book'),
            )
          : Column(
              children: [
                GChoiceChips<NotifyKind?>(
                  options: [null, ...NotifyKind.values],
                  selected: _filter,
                  onSelect: (k) => setState(() => _filter = k),
                  labelOf: (k) => k?.label ?? 'All',
                  iconOf: (k) => k?.icon,
                  countOf: (k) => k == null
                      ? '${all.length}'
                      : '${all.where((n) => n.kind == k).length}',
                ),
                const SizedBox(height: Gap.md),
                Expanded(
                  child: items.isEmpty
                      ? const GEmptyState(
                          icon: Icons.filter_alt_off_rounded,
                          title: 'Nothing in this filter',
                          message: 'Pick another category above.',
                          compact: true,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                              Gap.page, 0, Gap.page, Gap.h2),
                          children: [
                            if (today.isNotEmpty) ...[
                              _header(context, 'Today'),
                              for (var i = 0; i < today.length; i++)
                                _tile(today[i], i),
                            ],
                            if (week.isNotEmpty) ...[
                              _header(context, 'This week'),
                              for (var i = 0; i < week.length; i++)
                                _tile(week[i], i),
                            ],
                            if (older.isNotEmpty) ...[
                              _header(context, 'Earlier'),
                              for (var i = 0; i < older.length; i++)
                                _tile(older[i], i),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _header(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(2, Gap.md, 0, Gap.sm),
        child: Text(label.toUpperCase(),
            style: AppType.over.c(context.c.inkFaint)),
      );

  Widget _tile(AppNotification n, int index) {
    final p = context.c;
    final t = toneOf(context, _tone(n.kind));

    return Entrance(
      index: index,
      stagger: const Duration(milliseconds: 35),
      child: Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Dismissible(
          key: ValueKey(n.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: Gap.xl),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: R.all(R.lg),
            ),
            child: Icon(Icons.done_all_rounded, color: p.inkMuted),
          ),
          confirmDismiss: (_) async {
            ref
                .read(appControllerProvider.notifier)
                .markNotificationRead(n.id);
            return false;
          },
          child: GCard(
            padding: const EdgeInsets.all(Gap.md),
            color: n.read ? p.surface : p.accentSoft.withValues(alpha: 0.5),
            borderColor: n.read ? null : p.accent.withValues(alpha: 0.25),
            onTap: () {
              ref
                  .read(appControllerProvider.notifier)
                  .markNotificationRead(n.id);
              // Everything a notification can be about lives on the
              // Bookings tab now, so that is where it lands.
              if (n.bookingId != null) context.go('/bookings');
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration:
                      BoxDecoration(color: t.bg, borderRadius: R.all(R.sm)),
                  child: Icon(n.kind.icon, size: 19, color: t.fg),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(n.title,
                                style: AppType.labelL.c(p.ink),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (!n.read) ...[
                            const SizedBox(width: Gap.sm),
                            Container(
                              height: 7,
                              width: 7,
                              decoration: BoxDecoration(
                                  color: p.accent, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(n.body,
                          style: AppType.bodyS.c(p.inkMuted),
                          maxLines: 3),
                      const SizedBox(height: 5),
                      Text(Fmt.relative(n.at),
                          style: AppType.labelS.s(10).c(p.inkFaint)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
