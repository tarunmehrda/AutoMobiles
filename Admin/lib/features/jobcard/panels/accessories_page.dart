import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/g_state.dart';
import '../../../data/seed/seed.dart';
import '../../../state/admin_state.dart';
import '../../../state/providers.dart';
import 'checklist_page.dart';

/// What came in with the car. Recorded at handover so there is no argument
/// about it at delivery.
class AccessoriesPage extends ConsumerWidget {
  const AccessoriesPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(jobCardProvider(id));
    if (card == null) {
      return const Scaffold(
        appBar: GHeader(title: 'Accessories'),
        body: GEmptyState(
          icon: Icons.luggage_outlined,
          title: 'Job card not found',
          message: 'Nothing to attach this to.',
        ),
      );
    }

    return ChecklistPage(
      title: 'Accessories',
      subtitle: 'Everything handed over with the vehicle. This list goes on '
          'the mechanic copy and is checked back at delivery.',
      emptyHint: 'Nothing recorded — tap an item to add it.',
      icon: Icons.luggage_rounded,
      presets: Seed.accessories,
      selected: card.accessories,
      onSave: (v) => ref.read(adminProvider.notifier).setAccessories(id, v),
    );
  }
}
