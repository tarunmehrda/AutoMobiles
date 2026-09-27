import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/g_art.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/g_surface.dart';
import '../../../core/widgets/pressable.dart';
import '../../../state/admin_state.dart';
import '../../../state/providers.dart';

/// The free-text half of a job card: what the advisor wants the floor to
/// know, plus the odometer, fuel and promised-ready time that everything
/// else keys off.
class WorkNotePage extends ConsumerStatefulWidget {
  const WorkNotePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<WorkNotePage> createState() => _WorkNotePageState();
}

class _WorkNotePageState extends ConsumerState<WorkNotePage> {
  late final TextEditingController _note;
  late final TextEditingController _km;
  late int _fuel;
  DateTime? _promised;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final card = ref.read(jobCardProvider(widget.id));
    _note = TextEditingController(text: card?.workNote ?? '');
    _km = TextEditingController(text: '${card?.odometerKm ?? 0}');
    _fuel = card?.fuelPercent ?? 0;
    _promised = card?.promisedAt;
    _loaded = card != null;
  }

  @override
  void dispose() {
    _note.dispose();
    _km.dispose();
    super.dispose();
  }

  void _save() {
    final ctrl = ref.read(adminProvider.notifier);
    ctrl.setWorkNote(widget.id, _note.text.trim());
    ctrl.setOdometer(
      widget.id,
      km: int.tryParse(_km.text.trim()),
      fuelPercent: _fuel,
    );
    ctrl.setPromisedAt(widget.id, _promised);
  }

  Future<void> _pickPromised() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _promised ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _promised ?? now.add(const Duration(days: 1)),
      ),
    );
    if (!mounted) return;
    setState(
      () => _promised = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 10,
        time?.minute ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (!_loaded) {
      return Scaffold(
        appBar: GHeader(
          title: 'Work Note'.tr,
          subtitle: 'Notes, odometer and the promised time'.tr,
        ),
        body: GEmptyState(
          icon: Icons.sticky_note_2_outlined,
          title: 'Job card not found'.tr,
          art: Art.searching,
          message: 'Nothing to attach this to.'.tr,
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Work note'.tr,
        subtitle: 'Notes, odometer and the promised time'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          GField(
            label: 'Note for the floor'.tr,
            hint:
                'What to check first, what the customer mentioned, anything the mechanic should know.'
                    .tr,
            controller: _note,
            maxLines: 6,
          ),
          const SizedBox(height: Gap.xxl),
          Text('ODOMETER AND FUEL'.tr, style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.md),
          GField(
            label: 'Kilometres on the clock'.tr,
            hint: '45000',
            controller: _km,
            keyboardType: TextInputType.number,
            textCapitalization: TextCapitalization.none,
            suffix: Text('km', style: AppType.labelM.c(p.inkMuted)),
          ),
          const SizedBox(height: Gap.lg),
          GCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_gas_station_rounded,
                      size: 18,
                      color: p.inkMuted,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        'Fuel at handover'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelL.c(p.ink),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Text('$_fuel%', style: AppType.money.c(p.accentInk)),
                  ],
                ),
                Slider(
                  value: _fuel.toDouble(),
                  max: 100,
                  divisions: 20,
                  onChanged: (v) => setState(() => _fuel = v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Empty'.tr, style: AppType.labelS.c(p.inkFaint)),
                    Text('Full'.tr, style: AppType.labelS.c(p.inkFaint)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xxl),
          Text('PROMISED READY'.tr, style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.sm),
          Text(
            'The card shows as overdue past this time, so the counter can see it slipping before the customer calls.'
                .tr,
            style: AppType.bodyS.c(p.inkMuted),
          ),
          const SizedBox(height: Gap.md),
          GPickerField(
            label: 'Ready by'.tr,
            value: _promised == null ? null : Fmt.fullDateTime(_promised!),
            placeholder: 'Not set'.tr,
            icon: Icons.event_rounded,
            onTap: _pickPromised,
          ),
          if (_promised != null) ...[
            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                onTap: () => setState(() => _promised = null),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                  child: Text('Clear'.tr, style: AppType.labelM.c(p.accentInk)),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: 'Save'.tr,
          onPressed: () {
            _save();
            GFeedback.success(context, 'Work note saved'.tr);
            context.pop();
          },
        ),
      ),
    );
  }
}
