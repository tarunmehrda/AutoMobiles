import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/entities.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../i18n/strings.dart';
import '../utils/alert_chime.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'g_badge.dart';

/// How a notification kind reads on screen. Shared by the banner and the
/// feed so an alert looks the same in the moment it lands and afterwards.
class AlertLook {
  const AlertLook._();

  static IconData icon(String kind) => switch (kind) {
    'booking' => Icons.event_available_rounded,
    'review' => Icons.star_rounded,
    _ => Icons.notifications_active_rounded,
  };

  static GTone tone(String kind) => switch (kind) {
    'booking' => GTone.accent,
    'review' => GTone.warning,
    _ => GTone.ink,
  };
}

/// Announces alerts as they arrive, over whatever is on screen.
///
/// Wrapped around the navigator rather than dropped into a page, because
/// the counter is never on the page the news is about. A booking lands
/// while somebody is halfway through billing a card, and a red dot on a
/// dashboard two taps away is not being told.
///
/// It deliberately does not use a SnackBar. A SnackBar belongs to the
/// nearest ScaffoldMessenger, which here would be whichever route happened
/// to be on top — so it would vanish the moment that route was popped, and
/// a full-screen sheet would cover it entirely.
class AlertHost extends ConsumerStatefulWidget {
  const AlertHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AlertHost> createState() => _AlertHostState();
}

class _AlertHostState extends ConsumerState<AlertHost> {
  /// Long enough to read a name and a vehicle, short enough not to sit over
  /// the field somebody is typing into.
  static const Duration _dwell = Duration(seconds: 6);

  GarageNotification? _showing;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _announce(GarageNotification n) {
    // The newest alert replaces the one on screen rather than queueing
    // behind it. Two requests arriving together is one thing to go and look
    // at, and a queue would hold the second banner over the screen for
    // twelve seconds to say so.
    _hide?.cancel();
    HapticFeedback.heavyImpact();
    // The alert's own chime, not the platform click. `SystemSoundType.alert`
    // is a UI tick on Android -- on a phone face-down on a bench, next to a
    // car, it may as well be silent, and it sounded nothing like the push
    // for the same event. [AlertChime] plays the very WAV that alert's
    // notification channel uses, so a booking sounds like a booking whether
    // the console was open or not.
    unawaited(AlertChime.play(n.kind));
    setState(() => _showing = n);
    _hide = Timer(_dwell, _dismiss);
  }

  void _dismiss() {
    _hide?.cancel();
    if (mounted) setState(() => _showing = null);
  }

  void _open(GarageNotification n) {
    _dismiss();
    final route = n.route;
    if (route == null || route.isEmpty) return;
    // Through the router rather than this context's Navigator: the banner
    // sits above the navigator, so it has no route of its own to push from.
    ref.read(routerProvider).push(route);
    unawaited(
      ref.read(adminProvider.notifier).markNotificationsRead([n.id]),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(garageAlertProvider, (_, next) {
      final n = next.valueOrNull;
      if (n != null) _announce(n);
    });

    // A push the counter tapped on the lock screen. It does not raise a
    // banner — they have already been told, and by the OS — it just takes
    // them where the notification pointed.
    ref.listen(pushOpenedProvider, (_, next) {
      final route = next.valueOrNull;
      if (route != null && route.isNotEmpty) {
        ref.read(routerProvider).push(route);
      }
    });

    final showing = _showing;
    return Stack(
      children: [
        widget.child,
        if (showing != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _AlertBanner(
              key: ValueKey(showing.id),
              alert: showing,
              onOpen: () => _open(showing),
              onDismiss: _dismiss,
            ),
          ),
      ],
    );
  }
}

class _AlertBanner extends StatefulWidget {
  const _AlertBanner({
    super.key,
    required this.alert,
    required this.onOpen,
    required this.onDismiss,
  });

  final GarageNotification alert;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: Motion.base,
  )..forward();

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final n = widget.alert;
    final t = toneOf(context, AlertLook.tone(n.kind));

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _slide, curve: Motion.spring)),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
            // Up is the only direction that dismisses: the banner came from
            // the top edge and going back the way it came is the gesture
            // people already make. A sideways swipe would fight the
            // back-gesture on both edges of the screen.
            child: Dismissible(
              key: ValueKey('alert-${n.id}'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: GestureDetector(
                onTap: widget.onOpen,
                child: Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: R.all(R.lg),
                    border: Border.all(color: t.fg.withValues(alpha: 0.35)),
                    boxShadow: Shadows.lifted(p),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: t.bg,
                          borderRadius: R.all(R.md),
                        ),
                        child: Icon(
                          AlertLook.icon(n.kind),
                          color: t.fg,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.labelL.c(p.ink),
                            ),
                            if (n.body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.bodyS.c(p.inkMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(
                        'Open'.tr,
                        style: AppType.labelM.c(p.accent),
                      ),
                      const SizedBox(width: Gap.xs),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: p.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
