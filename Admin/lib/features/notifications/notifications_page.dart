import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/alert_host.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// Everything the workshop has been told, newest first.
///
/// The feed is the durable half of the bell: the banner in [AlertHost] is
/// the moment an alert lands, and this is the answer to "what did I miss
/// while the phone was in a pocket". Rows come from the database, so the
/// same list is on every handset at the counter, and one person reading it
/// clears it for everybody.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  /// What was unread when this screen opened.
  ///
  /// Held for the life of the screen rather than read from the rows,
  /// because opening the bell marks everything read a frame later — so the
  /// rows themselves stop being able to answer "which of these was new?"
  /// almost immediately. Without this the highlights flash once and vanish,
  /// which tells the counter that something arrived but not what.
  late final Set<String> _wasNew = {
    for (final n in ref.read(notificationsProvider))
      if (!n.read) n.id,
  };

  @override
  void initState() {
    super.initState();
    // Opening the bell is reading it. Deferred past the first frame because
    // it writes state, and the list is already built from the cache.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(adminProvider.notifier).markNotificationsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final feed = ref.watch(notificationFeedProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Notifications'.tr,
        subtitle: feed.isEmpty
            ? 'Nothing yet'.tr
            : '{0} in the last 90 days'.trf([feed.length]),
      ),
      body: RefreshIndicator(
        color: p.accent,
        onRefresh: () => ref.read(adminProvider.notifier).refreshNotifications(),
        child: feed.isEmpty
            ? ListView(
                // A scrollable, so pull-to-refresh still works on an empty
                // feed — which is exactly when somebody wants to pull.
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                  GEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'All quiet'.tr,
                    art: Art.done,
                    message:
                        'Booking requests and new reviews land here the moment they happen.'
                            .tr,
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.md,
                  Gap.page,
                  Gap.h2,
                ),
                itemCount: feed.length,
                itemBuilder: (context, i) => Entrance(
                  index: i.clamp(0, 8),
                  child: _NotificationTile(
                    alert: feed[i],
                    isNew: _wasNew.contains(feed[i].id),
                  ),
                ),
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.alert, required this.isNew});

  final GarageNotification alert;

  /// Unread when this screen opened — see [_NotificationsPageState._wasNew].
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = toneOf(context, AlertLook.tone(alert.kind));
    final route = alert.route;

    return Pressable(
      onTap: route == null || route.isEmpty ? null : () => context.push(route),
      scale: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          // What was new when the screen opened keeps its tint for as long
          // as the screen is up, so the eye has time to find it.
          color: isNew ? p.surfaceSunken : p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(
            color: isNew ? t.fg.withValues(alpha: 0.3) : p.line,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(color: t.bg, borderRadius: R.all(R.md)),
              child: Icon(AlertLook.icon(alert.kind), color: t.fg, size: 20),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: AppType.labelL.c(p.ink),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(
                        Fmt.relative(alert.at),
                        style: AppType.labelS.c(p.inkFaint),
                      ),
                    ],
                  ),
                  if (alert.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(alert.body, style: AppType.bodyS.c(p.inkMuted)),
                  ],
                ],
              ),
            ),
            if (route != null && route.isNotEmpty) ...[
              const SizedBox(width: Gap.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: p.inkFaint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
