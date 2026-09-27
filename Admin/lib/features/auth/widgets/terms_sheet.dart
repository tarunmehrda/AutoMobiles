import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_button.dart';

/// The terms a workshop agrees to before its first job card. Declining backs
/// out of registration rather than quietly carrying on.
Future<bool> showTermsSheet(BuildContext context) async {
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => const _TermsSheet(),
  );
  return agreed ?? false;
}

final _sections = <({String title, String body})>[
  (
    title: '{0} usage terms'.trf([AppConfig.appName]),
    body:
        'By agreeing to these terms you confirm that you are of the age of majority in your state of residence, and that the workshop details you have entered are your own. You may not use the app for any unlawful purpose, nor transmit anything to it that is designed to damage it or the people who use it. A breach of these terms ends your access to the service.',
  ),
  (
    title: 'General conditions'.tr,
    body:
        'We may refuse service to anyone, for any reason, at any time. You understand that your content — never your payment details — may be transferred unencrypted across networks, and may be changed to fit the technical requirements of the networks it crosses. You agree not to reproduce, resell or exploit any part of the service without our written permission.',
  ),
  (
    title: 'Accuracy of information'.tr,
    body:
        'We are not responsible if information made available in the app is not accurate, complete or current. The material here is for general information and should not be the sole basis for a decision without consulting a more complete source. Historical information is, by its nature, not current and is provided for reference only.',
  ),
  (
    title: 'Changes to the service and prices'.tr,
    body:
        'Prices are subject to change without notice. We may modify or discontinue the service, or any part of it, at any time. We are not liable to you or to any third party for any modification, price change, suspension or discontinuation.',
  ),
  (
    title: 'Your records'.tr,
    body:
        'Your job cards, customers and inventory belong to you. We store them so the app can show them back to you, and we do not sell them. Signing out clears this device; with no backend configured for your workshop, there is no copy anywhere else.',
  ),
];

class _TermsSheet extends StatelessWidget {
  const _TermsSheet();

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xxl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.md),
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: p.line,
                borderRadius: R.all(R.pill),
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text('Terms of Service'.tr, style: AppType.h1.c(p.ink)),
            const SizedBox(height: Gap.md),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.md,
                  Gap.page,
                  Gap.lg,
                ),
                children: [
                  for (final s in _sections) ...[
                    Text(s.title, style: AppType.h2.c(p.ink)),
                    const SizedBox(height: Gap.sm),
                    Text(s.body, style: AppType.bodyM.c(p.inkMuted)),
                    const SizedBox(height: Gap.xl),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.md,
                Gap.page,
                Gap.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GButton(
                      label: 'Decline'.tr,
                      kind: GButtonKind.danger,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: GButton(
                      label: 'Agree'.tr,
                      kind: GButtonKind.volt,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
