import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_language.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// What the console is available in.
///
/// The ones with a [language] behind them are shipped and switchable; the
/// rest are listed so the owner can see what is coming rather than
/// guessing. Nothing is offered as selectable until its copy is written —
/// a half-translated console is worse than an English one.
const languages = <({String name, String native, AppLanguage? language})>[
  (name: 'English', native: 'English', language: AppLanguage.en),
  (name: 'Hindi', native: 'हिन्दी', language: AppLanguage.hi),
  (name: 'Marathi', native: 'मराठी', language: null),
  (name: 'Gujarati', native: 'ગુજરાતી', language: null),
  (name: 'Tamil', native: 'தமிழ்', language: null),
  (name: 'Telugu', native: 'తెలుగు', language: null),
  (name: 'Kannada', native: 'ಕನ್ನಡ', language: null),
  (name: 'Bengali', native: 'বাংলা', language: null),
];

class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final current = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Language'.tr,
        subtitle: 'View the app in your language'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          GCard(
            padding: EdgeInsets.zero,
            child: GTile(
              title: 'Country'.tr,
              subtitle: 'Sets the currency and the date format'.tr,
              icon: Icons.public_rounded,
              iconColor: p.info,
              trailing: Text('India'.tr, style: AppType.labelL.c(p.inkSoft)),
              showChevron: false,
            ),
          ),
          const SizedBox(height: Gap.lg),
          Text('LANGUAGE'.tr, style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.sm),
          for (final l in languages)
            _LanguageRow(
              entry: l,
              selected: l.language == current,
              onTap: () {
                final next = l.language;
                if (next == null) {
                  GFeedback.info(context, '{0} is on the way'.trf([l.name]));
                  return;
                }
                if (next == current) return;
                // The whole tree is rebuilt off this — see the KeyedSubtree
                // in AdminApp — so the screen under the finger comes back in
                // the new language without a restart.
                ref.read(adminProvider.notifier).setLanguage(next);
              },
            ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final ({String name, String native, AppLanguage? language}) entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: Motion.fast,
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: selected ? p.accent : p.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: AppType.labelL.c(p.ink)),
                  Text(entry.native, style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 21, color: p.accent)
            else if (entry.language == null)
              Text('Coming soon'.tr, style: AppType.labelS.c(p.inkFaint)),
          ],
        ),
      ),
    );
  }
}
