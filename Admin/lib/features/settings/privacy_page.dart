import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';

/// What the console stores and where. Short, because the honest answer is
/// short: it stays on the device unless a backend is configured.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static final _sections = <({String title, String body})>[
    (
      title: 'What we store'.tr,
      body:
          'Your workshop details, your staff, your customers and their vehicles, every job card you open, and the messages the app sends on your behalf.',
    ),
    (
      title: 'Where it lives'.tr,
      body:
          'Everything is written to this device. When a backend is configured for your workshop, the same snapshot is mirrored to it so a second device stays in step. With no backend configured, nothing leaves the phone.',
    ),
    (
      title: 'Customer messages'.tr,
      body:
          'Messages are sent to the mobile number on the job card, and only about that job card — opening it, finishing it, closing it, and the service reminders you set when you close it. You can turn them off under Settings Option.',
    ),
    (
      title: 'Your online garage'.tr,
      body:
          'If you switch your online garage on, the page shows your workshop name, address, phone number and the services you choose to publish. A customer who opens the link can see the status of their own job card, and nobody else’s.',
    ),
    (
      title: 'Deleting your data'.tr,
      body:
          'Signing out clears this device. With no backend configured, that is the only copy, so make sure you have exported anything you still need first.',
    ),
    (
      title: 'Contact'.tr,
      body:
          'Questions about any of this go to support, from Help and Support in the menu.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Privacy Policy'.tr,
        subtitle: 'What this app keeps, and where'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          Text(
            '{0} keeps your workshop’s records for you. Here is exactly what that means.'
                .trf([AppConfig.appName]),
            style: AppType.bodyL.c(p.inkSoft),
          ),
          const SizedBox(height: Gap.xl),
          for (final s in _sections) ...[
            Text(s.title, style: AppType.h2.c(p.ink)),
            const SizedBox(height: Gap.sm),
            Text(s.body, style: AppType.bodyM.c(p.inkMuted)),
            const SizedBox(height: Gap.xl),
          ],
          Text(
            'Version {0}'.trf([AppConfig.version]),
            style: AppType.labelS.c(p.inkFaint),
          ),
        ],
      ),
    );
  }
}
