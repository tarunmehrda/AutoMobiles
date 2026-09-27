import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/g_art.dart';
import '../../../core/widgets/g_state.dart';
import '../../../data/seed/seed.dart';
import '../../../state/admin_state.dart';
import '../../../state/providers.dart';
import 'checklist_page.dart';

/// What the customer actually said, ticked at the counter. It prints on the
/// mechanic copy so the floor works from the complaint, not a guess.
class VoicesPage extends ConsumerWidget {
  const VoicesPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(jobCardProvider(id));
    if (card == null) {
      return Scaffold(
        appBar: GHeader(
          title: 'Customer Voice'.tr,
          subtitle: 'What the owner said was wrong'.tr,
        ),
        body: GEmptyState(
          icon: Icons.record_voice_over_outlined,
          title: 'Job card not found'.tr,
          art: Art.searching,
          message: 'Nothing to attach this to.'.tr,
        ),
      );
    }

    return ChecklistPage(
      title: 'Customer voice'.tr,
      subtitle:
          'Tick what the customer reported. These print on the mechanic copy in the order you add them.'
              .tr,
      emptyHint: 'Nothing recorded yet — tap a complaint to add it.',
      icon: Icons.record_voice_over_rounded,
      presets: Seed.voices,
      selected: card.voices,
      onSave: (v) => ref.read(adminProvider.notifier).setVoices(id, v),
    );
  }
}
