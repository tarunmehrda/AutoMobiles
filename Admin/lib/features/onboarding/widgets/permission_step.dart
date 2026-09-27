import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/anim/entrance.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/decor.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';

/// What the console asks the phone for, and why. Each card says what the
/// permission buys before the system dialog appears, so the answer is an
/// informed one rather than a reflex.
///
/// [perms] is what the button actually asks the OS for. A card is asked for
/// only when its own button is pressed — sliding to the next card never
/// raises a dialog on its own.
final _asks = <({String title, String why, IconData icon, List<Permission> perms})>[
  (
    title: 'Contacts'.tr,
    why:
        'So a customer already in your phone can be added to a job card without retyping their number.',
    icon: Icons.contacts_rounded,
    perms: [Permission.contacts],
  ),
  (
    title: 'Location'.tr,
    why:
        'So your workshop address fills itself in, customers can find you from your online garage page, and the team can punch in only when they are actually at the workshop.',
    icon: Icons.location_on_rounded,
    perms: [Permission.locationWhenInUse],
  ),
  (
    title: 'Notifications'.tr,
    why:
        'So a booking raised on a customer phone rings at the counter straight away, instead of waiting to be found the next time somebody opens the app.',
    icon: Icons.notifications_active_rounded,
    perms: [Permission.notification],
  ),
  (
    title: 'Camera and photos'.tr,
    why:
        'So you can photograph damage at handover and scan a part number instead of typing it.',
    icon: Icons.photo_camera_rounded,
    perms: [Permission.camera, Permission.photos],
  ),
];

/// Keeps a card off the screen where the platform has nothing to ask for.
///
/// This used to carry a special case for SMS, which was the wrong shape of
/// answer to the wrong problem. `SEND_SMS` is hard-restricted from Android
/// 10: short of being the handset's default messaging app, the system says
/// no on the phone's behalf and disables the switch in Settings, so the card
/// could never go green there either — and the owner was sent to a page that
/// would not let them say yes, with no way back. The app never sent a
/// message itself in any case; it hands the text to the counter's own
/// messaging app over an `sms:` intent. So the ask is gone, and what stands
/// in its place is the permission that actually carries a booking to the
/// counter.
///
/// Photos on Android is the remaining case: below Android 13 there is no
/// separate grant — the media read rides along with storage — and asking
/// returns a denial that no amount of tapping will clear.
bool _supported(Permission p) =>
    p != Permission.photos ||
    kIsWeb ||
    defaultTargetPlatform != TargetPlatform.android;

class PermissionStep extends StatefulWidget {
  const PermissionStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<PermissionStep> createState() => _PermissionStepState();
}

class _PermissionStepState extends State<PermissionStep> {
  final _pager = PageController();
  int _index = 0;

  /// Which cards have been answered, and whether the phone said yes. Drives
  /// the tick in the list, the button label, and whether the card lets go.
  final _answered = <int, bool>{};
  bool _busy = false;

  /// Set when the current card was refused with "don't ask again". The
  /// button can no longer raise the dialog, so it stops pretending to and
  /// sends the owner to Settings instead.
  bool _blocked = false;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  /// Ask for the card that is on screen, wait for the answer, then slide to
  /// the next card and stop. That card's dialog waits for its own tap.
  ///
  /// A refusal stays put, because moving on from a card that was not
  /// granted defers the same dead end to the moment the feature is actually
  /// needed, with no explanation attached. It stays put, not stuck: once the
  /// phone says "never" the card offers a way past as well as a way back,
  /// since a permission the owner cannot grant must never be the thing
  /// standing between them and their own counter.
  Future<void> _allow() async {
    if (_busy) return;
    final i = _index;
    final wanted = _asks[i].perms.where(_supported).toList();

    // Nothing to ask for on this platform, so there is nothing to withhold
    // either — holding the owner here would be a door with no handle.
    if (wanted.isEmpty) {
      _answered[i] = true;
      _advance();
      return;
    }

    setState(() => _busy = true);
    Map<Permission, PermissionStatus> result;
    try {
      result = await wanted.request();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;

    final granted = result.values.every((s) => s.isGranted || s.isLimited);
    setState(() => _answered[i] = granted);
    if (granted) {
      _advance();
      return;
    }

    // "Don't ask again" means the dialog will never open from here again,
    // so pointing at the button once more would be a lie.
    if (result.values.any((s) => s.isPermanentlyDenied)) {
      setState(() => _blocked = true);
      return;
    }
    GFeedback.info(
      context,
      '{0} is needed to carry on. Tap Allow Access.'.trf([_asks[i].title]),
    );
  }

  void _advance() {
    if (_index == _asks.length - 1) {
      widget.onDone();
      return;
    }
    _blocked = false;
    _pager.nextPage(duration: Motion.base, curve: Motion.enter);
  }

  /// Leaves a permanently refused card behind without its grant.
  ///
  /// Offered only once the phone has said "never", which is the one state the
  /// owner cannot argue with from this screen. Some refusals are not even
  /// theirs to reverse — a permission the platform restricts is switched off
  /// in Settings too, and a first-run screen that insists on it locks the
  /// shop out of the app it just installed. The feature named on the card
  /// stays off, asks again where it is used, and everything else opens.
  void _skip() {
    setState(() => _answered[_index] = false);
    _advance();
  }

  /// Hands over to the system settings page, then re-checks on the way back
  /// — the owner may well have allowed it while they were there.
  Future<void> _openSettings() async {
    await openAppSettings();
    if (!mounted) return;
    final i = _index;
    final wanted = _asks[i].perms.where(_supported);
    var granted = true;
    for (final perm in wanted) {
      final status = await perm.status;
      if (!status.isGranted && !status.isLimited) granted = false;
    }
    if (!mounted) return;
    setState(() {
      _answered[i] = granted;
      _blocked = !granted;
    });
    if (granted) _advance();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    // Only a grant unlocks the button; a refusal leaves it asking again.
    final granted = _answered[_index] == true;
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.lg,
                Gap.page,
                Gap.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Permission'.tr, style: AppType.d2.c(p.ink)),
                  const SizedBox(height: 4),
                  Text(
                    'All four are needed to run the counter. The phone asks one at a time, and only when you tap Allow Access.'
                        .tr,
                    style: AppType.bodyM.c(p.inkMuted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _asks.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.sm),
                      child: Row(
                        children: [
                          Flexible(
                            child: AnimatedDefaultTextStyle(
                              duration: Motion.fast,
                              style: AppType.bodyM
                                  .c(i == _index ? p.ink : p.inkFaint)
                                  .w(
                                    i == _index
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                              child: Text(
                                '{0}. Allow your {1}'.trf([
                                  i + 1,
                                  _asks[i].title.toLowerCase(),
                                ]),
                              ),
                            ),
                          ),
                          if (_answered[i] == true) ...[
                            const SizedBox(width: Gap.sm),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 17,
                              color: p.success,
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xl),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                // The button is the only way forward. Left swipeable, a
                // flick past the card would skip the permission the button
                // is there to collect.
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _asks.length,
                itemBuilder: (context, i) => _Card(ask: _asks[i]),
              ),
            ),
            // The dots sit in their own band of air. Pressed against the card
            // above and the button below they read as part of neither.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.xxl,
                Gap.page,
                Gap.xxl,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _asks.length; i++) ...[
                    AnimatedContainer(
                      duration: Motion.base,
                      curve: Motion.spring,
                      height: 7,
                      width: i == _index ? 22 : 7,
                      decoration: BoxDecoration(
                        color: i == _index ? p.ink : p.line,
                        borderRadius: R.all(R.pill),
                      ),
                    ),
                    if (i != _asks.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            // No SKIP. All four are required, and a way past them would
            // only move the refusal to the moment the feature is needed.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                0,
                Gap.page,
                Gap.xxl,
              ),
              child: Column(
                children: [
                  if (_blocked) ...[
                    Text(
                      '{0} was turned off for good. Open Settings, allow it, then come back.'
                          .trf([_asks[_index].title]),
                      textAlign: TextAlign.center,
                      style: AppType.bodyS.c(p.danger),
                    ),
                    const SizedBox(height: Gap.md),
                  ],
                  GButton.accent(
                    label: _blocked
                        ? 'Open Settings'.tr
                        : (granted ? 'Next'.tr : 'Allow Access'.tr),
                    loading: _busy,
                    onPressed: _busy
                        ? null
                        : (_blocked
                              ? _openSettings
                              : (granted ? _advance : _allow)),
                  ),
                  // The way out, and only from the one state the owner cannot
                  // argue with. Settings does not always have a switch to
                  // offer — where the platform restricts a permission it is
                  // greyed out there too — so without this the trip to
                  // Settings is a round trip back to the same locked card.
                  if (_blocked) ...[
                    const SizedBox(height: Gap.sm),
                    GButton(
                      label: 'Skip for now'.tr,
                      kind: GButtonKind.ghost,
                      onPressed: _busy ? null : _skip,
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'You can turn {0} on later from Settings.'.trf([
                        _asks[_index].title.toLowerCase(),
                      ]),
                      textAlign: TextAlign.center,
                      style: AppType.labelS.c(p.inkFaint),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.ask});

  final ({String title, String why, IconData icon, List<Permission> perms}) ask;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Entrance(
        scaleFrom: 0.94,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Gap.xl),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: R.all(R.xxl),
            border: Border.all(color: p.line),
            boxShadow: Shadows.soft(p),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '{0} permission'.trf([ask.title]),
                textAlign: TextAlign.center,
                style: AppType.h1.c(p.ink),
              ),
              const SizedBox(height: Gap.xl),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: p.infoSoft,
                    borderRadius: R.all(R.xl),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: R.all(R.xl),
                          child: CustomPaint(
                            painter: BlueprintPainter(
                              color: p.info,
                              opacity: 0.08,
                            ),
                          ),
                        ),
                      ),
                      Icon(ask.icon, size: 74, color: p.info),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gap.xl),
              Text(
                ask.why,
                textAlign: TextAlign.center,
                style: AppType.bodyM.c(p.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
