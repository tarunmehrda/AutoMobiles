import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/pressable.dart';

/// The report index. Transaction opens in place rather than pushing a screen
/// that holds nothing but three more links.
class ReportSummaryPage extends ConsumerStatefulWidget {
  const ReportSummaryPage({super.key});

  @override
  ConsumerState<ReportSummaryPage> createState() => _ReportSummaryPageState();
}

class _ReportSummaryPageState extends ConsumerState<ReportSummaryPage> {
  bool _transactionOpen = false;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Reports'.tr,
        subtitle: 'Every figure the shop can print'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          Entrance(
            index: 0,
            child: _ReportCard(
              title: 'SMS Report'.tr,
              blurb: 'Every message the shop has sent'.tr,
              icon: Icons.sms_rounded,
              tone: GTone.success,
              onTap: () => context.push('/reports/sms'),
            ),
          ),
          const SizedBox(height: Gap.md),
          Entrance(
            index: 1,
            child: _ReportCard(
              title: 'Stock & Jobs Report'.tr,
              blurb: 'What was fitted, and what it earned'.tr,
              icon: Icons.inventory_rounded,
              tone: GTone.info,
              onTap: () => context.push('/reports/stock'),
            ),
          ),
          const SizedBox(height: Gap.md),

          // --- transaction, which opens in place --------------------
          Entrance(
            index: 2,
            child: AnimatedContainer(
              duration: Motion.base,
              curve: Motion.emphasized,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: R.all(R.lg),
                border: Border.all(color: p.line),
                boxShadow: Shadows.soft(p),
              ),
              child: Column(
                children: [
                  _ReportCard(
                    title: 'Transaction Report'.tr,
                    blurb: 'Sales, counter sales and what is still owed'.tr,
                    icon: Icons.swap_horiz_rounded,
                    tone: GTone.danger,
                    flat: true,
                    trailing: AnimatedRotation(
                      turns: _transactionOpen ? 0.5 : 0,
                      duration: Motion.base,
                      curve: Motion.emphasized,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 22,
                        color: p.inkFaint,
                      ),
                    ),
                    onTap: () =>
                        setState(() => _transactionOpen = !_transactionOpen),
                  ),
                  AnimatedSize(
                    duration: Motion.base,
                    curve: Motion.emphasized,
                    child: _transactionOpen
                        ? Column(
                            children: [
                              _SubRow(
                                title: 'Sale Report'.tr,
                                blurb: 'Everything billed inside a window'.tr,
                                onTap: () => context.push('/reports/sale'),
                              ),
                              _SubRow(
                                title: 'Counter Sales Report'.tr,
                                blurb: 'Everything sold across the counter'.tr,
                                onTap: () =>
                                    context.push('/reports/counter-sales'),
                              ),
                              _SubRow(
                                title: 'Pending Balance'.tr,
                                blurb: 'Who still owes, and how much'.tr,
                                onTap: () => context.push('/pending'),
                              ),
                              const SizedBox(height: Gap.sm),
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Gap.md),
          Entrance(
            index: 3,
            child: _ReportCard(
              title: 'General'.tr,
              blurb: 'Customers, mechanics and the directory'.tr,
              icon: Icons.assessment_rounded,
              tone: GTone.ink,
              onTap: () => context.push('/reports/general'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.blurb,
    required this.icon,
    required this.tone,
    required this.onTap,
    this.trailing,
    this.flat = false,
  });

  final String title;
  final String blurb;
  final IconData icon;
  final GTone tone;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = toneOf(context, tone);
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: flat
            ? null
            : BoxDecoration(
                color: p.surface,
                borderRadius: R.all(R.lg),
                border: Border.all(color: p.line),
                boxShadow: Shadows.soft(p),
              ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: p.isDark
                    ? t.fg.withValues(alpha: 0.18)
                    : Color.alphaBlend(t.fg.withValues(alpha: 0.10), t.bg),
                borderRadius: R.all(R.md),
              ),
              child: Icon(icon, size: 21, color: t.fg),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppType.labelL.s(14.5).c(p.ink).w(FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(blurb, style: AppType.bodyS.s(11.5).c(p.inkMuted)),
                ],
              ),
            ),
            trailing ??
                Container(
                  height: 26,
                  width: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.isDark ? p.surfaceSunken : p.canvas,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: p.inkMuted,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.title,
    required this.blurb,
    required this.onTap,
  });

  final String title;
  final String blurb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xxl, Gap.sm, Gap.lg, Gap.sm),
        child: Row(
          children: [
            Container(
              height: 9,
              width: 9,
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: R.all(2),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.labelL.c(p.accentInk)),
                  Text(blurb, style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}
