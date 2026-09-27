import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/g_art.dart';
import '../../../core/widgets/g_state.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/admin_state.dart';
import '../../../state/providers.dart';
import '../widgets/draft_dents_page.dart';
import '../widgets/vehicle_blueprint.dart';

/// Existing damage on a live job card, drawn onto the vehicle at handover.
///
/// The same sheet the create wizard uses. Strokes are collected on a copy and
/// only written back when the sheet is kept, so backing out of it leaves the
/// card exactly as it was found.
class DentsPage extends ConsumerStatefulWidget {
  const DentsPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DentsPage> createState() => _DentsPageState();
}

class _DentsPageState extends ConsumerState<DentsPage> {
  List<DentMark>? _marks;
  VehicleKind? _kind;
  DentSeverity _severity = DentSeverity.dent;
  bool _erasing = false;

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(jobCardProvider(widget.id));
    if (card == null) {
      return Scaffold(
        appBar: GHeader(
          title: 'Dent Marks'.tr,
          subtitle: 'Damage logged at handover'.tr,
        ),
        body: GEmptyState(
          icon: Icons.car_crash_outlined,
          title: 'Job card not found'.tr,
          art: Art.searching,
          message: 'Nothing to attach this to.'.tr,
        ),
      );
    }

    final marks = _marks ??= [...card.dents];
    final vehicle = ref.watch(vehicleProvider(card.vehicleId));
    // What the counter recorded, then what the existing marks were drawn on,
    // then the vehicle's own body style. Marks win over the record: a sheet
    // already marked up must not swap out from under them.
    final kind =
        _kind ??
        kindOfMarks(marks) ??
        (vehicle?.shape.sheet ?? VehicleShape.fourWheeler.sheet);

    return DentScaffold(
      title: 'Dent marks'.tr,
      marks: marks,
      kind: kind,
      severity: _severity,
      erasing: _erasing,
      onKind: (k) => setState(() => _kind = k),
      onSeverity: (s) => setState(() {
        _severity = s;
        _erasing = false;
      }),
      onErase: () => setState(() => _erasing = !_erasing),
      onPainted: (m) => setState(() => _marks = [...marks, m]),
      onErased: (ids) =>
          setState(() => _marks = [...marks.where((m) => !ids.contains(m.id))]),
      onDiscard: () => context.pop(),
      onSave: () {
        ref.read(adminProvider.notifier).setDents(widget.id, marks);
        context.pop();
      },
    );
  }
}
