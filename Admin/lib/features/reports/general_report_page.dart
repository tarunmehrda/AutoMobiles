import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_surface.dart';

/// The two reports that answer "who" rather than "how much": the customer
/// ledger and the mechanic's output.
class GeneralReportPage extends ConsumerWidget {
  const GeneralReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'General Report'.tr,
        subtitle: 'The shop at a glance, on one page'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          Entrance(
            index: 0,
            child: GCard(
              padding: EdgeInsets.zero,
              child: GTile(
                title: 'Customer Report'.tr,
                subtitle: 'Every customer billed inside a window'.tr,
                icon: Icons.people_alt_rounded,
                iconColor: toneOf(context, GTone.accent).fg,
                iconBg: toneOf(context, GTone.accent).bg,
                onTap: () => context.push('/reports/customer'),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Entrance(
            index: 1,
            child: GCard(
              padding: EdgeInsets.zero,
              child: GTile(
                title: 'Mechanic Report'.tr,
                subtitle: 'Vehicles worked and value earned per mechanic'.tr,
                icon: Icons.engineering_rounded,
                iconColor: toneOf(context, GTone.info).fg,
                iconBg: toneOf(context, GTone.info).bg,
                onTap: () => context.push('/reports/mechanic'),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Entrance(
            index: 2,
            child: GCard(
              padding: EdgeInsets.zero,
              child: GTile(
                title: 'Customers'.tr,
                subtitle: 'The full customer and vehicle directory'.tr,
                icon: Icons.contacts_rounded,
                iconColor: toneOf(context, GTone.ink).fg,
                iconBg: toneOf(context, GTone.ink).bg,
                onTap: () => context.push('/customers'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
