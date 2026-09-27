import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';

/// What the app knows about a customer, and who else can see it.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static const _sections = <({String title, String body})>[
    (
      title: 'What we store',
      body: 'Your name and mobile number, the vehicles you add, the '
          'appointments you book, and the job cards the workshop opens for '
          'those vehicles.'
    ),
    (
      title: 'Who can see it',
      body: 'Only you, and the workshop you have linked to. A workshop can '
          'only see the customer record it created for you, and only after '
          'you have entered the code it gave you.'
    ),
    (
      title: 'Linking a workshop',
      body: 'A phone number alone is not proof of who you are — anyone could '
          'type yours. The code the counter reads out is issued against one '
          'customer record, lasts a day and burns on first use, so your '
          'service history only ever reaches the person the workshop actually '
          'handed it to.'
    ),
    (
      title: 'Your bookings',
      body: 'When you book a slot, your name, number, vehicle and what you '
          'asked for go to the workshop so the counter can prepare. Nothing '
          'else does.'
    ),
    (
      title: 'On this device',
      body: 'Everything is written to your phone so the app works with no '
          'signal. Signing out clears it from this device.'
    ),
    (
      title: 'Contact',
      body: 'Questions go to support, from Help & Support on your profile.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: const GHeader(title: 'Privacy Policy'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          Text(
            '${AppConfig.appName} keeps your vehicles and their service '
            'history. Here is exactly what that means.',
            style: AppType.bodyL.c(p.inkSoft),
          ),
          const SizedBox(height: Gap.xl),
          for (final s in _sections) ...[
            Text(s.title, style: AppType.h2.c(p.ink)),
            const SizedBox(height: Gap.sm),
            Text(s.body, style: AppType.bodyM.c(p.inkMuted)),
            const SizedBox(height: Gap.xl),
          ],
          Text('Version ${AppConfig.version}',
              style: AppType.labelS.c(p.inkFaint)),
        ],
      ),
    );
  }
}
