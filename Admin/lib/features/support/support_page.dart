import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_surface.dart';
import '../../state/providers.dart';
import '../shared/support_sheet.dart';
import '../../core/widgets/brand_logo.dart';

class _Faq {
  const _Faq(this.q, this.a);
  final String q;
  final String a;
}

const _faqs = [
  _Faq(
    'Why can I not edit a closed job card?',
    'Closing freezes the bill so the copy the customer holds stays the copy on record. Reopen it from the job card menu if something genuinely needs changing — reopening also drops any reminders that have not gone out yet.',
  ),
  _Faq(
    'Where does stock go when I add a part?',
    'It comes off the shelf the moment the line lands on a job card, and goes back if you remove the line or drop the quantity. Deleting a whole job card returns everything on it.',
  ),
  _Faq(
    'Why does the mechanic copy have no prices?',
    'It is the sheet that goes to the floor. It carries the complaint, the accessories, the work list and a column to sign off — but never what the customer is paying.',
  ),
  _Faq(
    'Can I close a card without collecting the money?',
    'Yes. The balance stays visible under Pending balance until it is collected, and the customer keeps showing on that list.',
  ),
  _Faq(
    'When do service reminders go out?',
    'Three go out around the next service date you set when closing the card — before, on, and after. The spacing is in Settings.',
  ),
  _Faq(
    'Is my data backed up anywhere?',
    'Not yet. Everything lives on this device until Supabase credentials are configured. Signing out clears it.',
  ),
];

/// Help, and the two ways to reach a human.
class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final garage = ref.watch(garageProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Help & Support'.tr,
        subtitle: 'Reach a human, or read the answers'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          Container(
            padding: const EdgeInsets.all(Gap.xl),
            decoration: BoxDecoration(
              gradient: p.inverseGradient,
              borderRadius: R.all(R.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandBadge(size: 40, onDark: true),
                const SizedBox(height: Gap.lg),
                Text(
                  'We answer 9 am to 8 pm, every day'.tr,
                  style: AppType.h1.c(p.onInverse),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  garage == null
                      ? 'Tell us what you were doing when it went wrong.'.tr
                      : 'Registered to {0}.'.trf([garage.name]),
                  style: AppType.bodyM.c(p.onInverse.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: GButton(
                        label: 'WhatsApp'.tr,
                        kind: GButtonKind.volt,
                        size: GButtonSize.md,
                        icon: Icons.chat_rounded,
                        onPressed: () =>
                            launchWhatsApp(context, AppConfig.supportWhatsapp),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GButton(
                        label: 'Call'.tr,
                        kind: GButtonKind.outline,
                        size: GButtonSize.md,
                        // The card behind it is carbon.
                        onDark: true,
                        expand: true,
                        icon: Icons.call_rounded,
                        onPressed: () =>
                            launchDial(context, AppConfig.supportPhone),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GSectionHeader(
            title: 'Common questions'.tr,
            padding: EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
          ),
          for (final faq in _faqs)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: GCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg,
                      vertical: 2,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      0,
                      Gap.lg,
                      Gap.lg,
                    ),
                    title: Text(faq.q, style: AppType.labelL.c(p.ink)),
                    iconColor: p.accent,
                    collapsedIconColor: p.inkFaint,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(faq.a, style: AppType.bodyM.c(p.inkMuted)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: Gap.xxl),
          Center(
            child: Text(
              "${AppConfig.appName} ${AppConfig.version}\n${AppConfig.hasSupabase ? 'Syncing to Supabase' : 'Running on this device only'}",
              textAlign: TextAlign.center,
              style: AppType.labelS.c(p.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}
