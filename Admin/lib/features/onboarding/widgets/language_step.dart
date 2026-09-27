import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/anim/entrance.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/decor.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../../state/admin_state.dart';
import '../../../state/providers.dart';
import '../../settings/language_page.dart' show languages;

/// The first thing a first run asks: what country, and what language.
///
/// Picking here switches the console immediately rather than storing a
/// preference for later — the rest of onboarding is then read in the
/// language the owner just chose, which is the only way to know it worked.
class LanguageStep extends ConsumerWidget {
  const LanguageStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final p = context.c;
    final current = ref.read(languageProvider);
    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(R.xxl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: Gap.lg),
            children: [
              for (final l in languages)
                ListTile(
                  enabled: l.language != null,
                  title: Text(
                    l.name,
                    style: AppType.labelL.c(
                      l.language != null ? p.ink : p.inkFaint,
                    ),
                  ),
                  subtitle: Text(
                    l.language != null ? l.native : 'Coming soon'.tr,
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                  trailing: l.language == current
                      ? Icon(Icons.check_rounded, color: p.accent)
                      : null,
                  onTap: () => Navigator.of(context).pop(l.language),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != current) {
      ref.read(adminProvider.notifier).setLanguage(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final language = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: Gap.lg),
            Text(
              'View your App in'.tr,
              textAlign: TextAlign.center,
              style: AppType.h1.c(p.ink),
            ),
            Text(
              'Your Language'.tr,
              textAlign: TextAlign.center,
              style: AppType.h1.c(p.ink),
            ),
            const SizedBox(height: Gap.xl),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: Entrance(
                  scaleFrom: 0.94,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: p.inverseGradient,
                      borderRadius: R.all(R.xxl),
                      boxShadow: Shadows.lifted(p),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: R.all(R.xxl),
                            child: CustomPaint(
                              painter: BlueprintPainter(
                                color: p.onInverse,
                                opacity: 0.08,
                              ),
                            ),
                          ),
                        ),
                        Icon(Icons.translate_rounded, size: 84, color: p.volt),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Gap.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: R.all(R.lg),
                  border: Border.all(color: p.line),
                  boxShadow: Shadows.soft(p),
                ),
                child: Column(
                  children: [
                    _Row(
                      icon: Icons.public_rounded,
                      label: 'Country'.tr,
                      value: 'India'.tr,
                      onTap: null,
                    ),
                    Divider(height: 1, color: p.lineSoft),
                    _Row(
                      icon: Icons.translate_rounded,
                      label: 'Language'.tr,
                      value: language.nativeName,
                      onTap: () => _pickLanguage(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.lg,
                Gap.page,
                Gap.xxl,
              ),
              child: GButton.accent(
                label: 'Continue'.tr,
                onPressed: onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      enabled: onTap != null,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: p.inkSoft),
            const SizedBox(width: Gap.md),
            Expanded(child: Text(label, style: AppType.labelL.c(p.ink))),
            Text(value, style: AppType.labelL.c(p.inkSoft)),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 20, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}
