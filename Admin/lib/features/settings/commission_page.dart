import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/g_appbar.dart';
import '../../data/repo/platform_gateway.dart';
import '../platform/widgets/commission_section.dart';

/// The one place commission is shown, reached from Settings.
///
/// The platform account picks one partner at a time; a workshop owner sees
/// their own workshop and no other.
class CommissionPage extends ConsumerWidget {
  const CommissionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final platform = ref.watch(isPlatformAdminProvider).valueOrNull;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Commission'.tr,
        subtitle: platform == true
            ? 'One partner at a time'
            : 'Private to this workshop'.tr,
      ),
      body: switch (platform) {
        null => const Center(child: CircularProgressIndicator()),
        true => const CommissionSection(),
        false => const OwnCommissionView(),
      },
    );
  }
}
