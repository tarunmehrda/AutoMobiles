import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_surface.dart';

/// The two graphs the owner asks for: where the money came from, and what
/// came through the gate.
class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Analytics'.tr,
        subtitle: 'Where the work and the money went'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          // The page is two links. Without something above them it reads as a
          // menu that forgot its page, so the artwork does the work a hero
          // image would do and the links keep their whole width.
          const Entrance(child: Center(child: GArt(Art.noData, height: 128))),
          const SizedBox(height: Gap.xl),
          Entrance(
            index: 0,
            child: GCard(
              padding: EdgeInsets.zero,
              child: GTile(
                title: 'Revenue Analytics'.tr,
                subtitle: 'What the shop earned, month by month'.tr,
                icon: Icons.stacked_line_chart_rounded,
                iconColor: toneOf(context, GTone.success).fg,
                iconBg: toneOf(context, GTone.success).bg,
                onTap: () => context.push('/analytics/revenue'),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Entrance(
            index: 1,
            child: GCard(
              padding: EdgeInsets.zero,
              child: GTile(
                title: 'Vehicle Analytics'.tr,
                subtitle: 'What came through the gate, and how often'.tr,
                icon: Icons.directions_car_filled_rounded,
                iconColor: toneOf(context, GTone.info).fg,
                iconBg: toneOf(context, GTone.info).bg,
                onTap: () => context.push('/analytics/vehicle'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
