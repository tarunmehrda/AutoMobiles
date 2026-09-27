import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_field.dart';
import '../../state/providers.dart';

/// Ready-made messages the workshop sends its customers — a festival wish or
/// an offer — with the workshop's own name already in them.
class GreetingsPage extends ConsumerStatefulWidget {
  const GreetingsPage({super.key});

  @override
  ConsumerState<GreetingsPage> createState() => _GreetingsPageState();
}

enum _Kind { greeting, offer }

class _GreetingsPageState extends ConsumerState<GreetingsPage> {
  _Kind _kind = _Kind.greeting;

  static final _greetings = <({String title, String body})>[
    (
      title: 'Diwali'.tr,
      body:
          'Wishing you and your family a bright and safe Diwali from {shop}. Drive safe — we are here whenever you need us.',
    ),
    (
      title: 'New Year'.tr,
      body:
          'Happy New Year from all of us at {shop}. May the road ahead be smooth and your service reminders always on time.',
    ),
    (
      title: 'Monsoon check'.tr,
      body:
          'The rains are here. Bring your vehicle to {shop} for a free wiper, brake and tyre check before the first big shower.',
    ),
    (
      title: 'Thank you'.tr,
      body:
          'Thank you for trusting {shop} with your vehicle. A quick rating helps us serve you better next time.',
    ),
  ];

  static final _offers = <({String title, String body})>[
    (
      title: 'Free pickup and drop'.tr,
      body:
          'This month at {shop}: free pickup and drop on every general service. Reply to book a slot.',
    ),
    (
      title: '10% off labour'.tr,
      body:
          'Flat 10% off labour at {shop} on all bookings made this week. Show this message at the counter.',
    ),
    (
      title: 'Free health check'.tr,
      body:
          'Free 20-point vehicle health check at {shop}. No appointment needed — walk in any day this week.',
    ),
    (
      title: 'Referral'.tr,
      body:
          'Refer a friend to {shop} and you both get a free wash on your next visit.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final garage = ref.watch(garageProvider);
    final shop = garage?.name ?? 'our workshop';
    final rows = _kind == _Kind.greeting ? _greetings : _offers;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Greetings & Offers'.tr,
        bottom: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
          child: GSegmented<_Kind>(
            options: _Kind.values,
            selected: _kind,
            onSelect: (k) => setState(() => _kind = k),
            labelOf: (k) => k == _Kind.greeting ? 'Greetings' : 'Offers',
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final r = rows[i];
          final body = r.body.replaceAll('{shop}', shop);
          return Entrance(
            index: i,
            child: Container(
              margin: const EdgeInsets.only(bottom: Gap.md),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: R.all(R.lg),
                border: Border.all(color: p.line),
                boxShadow: Shadows.soft(p),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 72,
                    width: double.infinity,
                    decoration: BoxDecoration(gradient: p.inverseGradient),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: BlueprintPainter(
                              color: p.onInverse,
                              opacity: 0.08,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(Gap.lg),
                          child: Row(
                            children: [
                              Icon(
                                _kind == _Kind.greeting
                                    ? Icons.celebration_rounded
                                    : Icons.local_offer_rounded,
                                size: 20,
                                color: p.volt,
                              ),
                              const SizedBox(width: Gap.sm),
                              Expanded(
                                child: Text(
                                  r.title,
                                  style: AppType.h2.c(p.onInverse),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(body, style: AppType.bodyM.c(p.inkSoft)),
                        const SizedBox(height: Gap.lg),
                        Row(
                          // Hindi runs longer than English on both halves of
                          // this row, so the counter gives way rather than
                          // pushing the Share button off the card.
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: GPill(
                                label: '{0} characters'.trf([body.length]),
                                tone: body.length > 160
                                    ? GTone.warning
                                    : GTone.success,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: Gap.md),
                            GButton(
                              label: 'Share'.tr,
                              kind: GButtonKind.outline,
                              size: GButtonSize.sm,
                              icon: Icons.ios_share_rounded,
                              expand: false,
                              onPressed: () => SharePlus.instance.share(
                                ShareParams(text: body),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
