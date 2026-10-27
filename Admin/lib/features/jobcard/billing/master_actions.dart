import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_net_image.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../data/seed/part_media.dart';
import '../../../state/admin_state.dart';

/// What can be done to a catalogue row from the screen that is billing it.
///
/// Deleting is here rather than only in Inventory because of where the
/// mistakes are made. A part is typed in at the counter, mid-card, against a
/// customer who is standing there — which is exactly when it gets typed in
/// twice, or spelled wrong, or priced with a digit missing. Sending somebody
/// to a different screen to undo the thing they did ten seconds ago on this
/// one is how a catalogue fills up with `Air Filterr` and `Air Filter (new)`.
///
/// The sheet is the confirmation. There is no second "are you sure?" over the
/// top of it: it shows the row, names what deleting does, and the destructive
/// button is the only one that is coloured — which is a clearer stop than a
/// dialog nobody reads.
///
/// Returns true when the row was deleted, so the caller can take it off the
/// cart as well. A cart holding an id that no longer exists bills nothing and
/// still counts as a line.
Future<bool> showMasterActions(
  BuildContext context,
  WidgetRef ref,
  MasterItem item, {
  required Color tint,
}) async {
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    // Sized to its content rather than capped at 9/16 of the screen, which
    // a large font on a small phone runs past.
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final p = sheetContext.c;
      return Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(R.xxl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.md,
              Gap.page,
              Gap.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 44,
                    decoration: BoxDecoration(
                      color: p.line,
                      borderRadius: R.all(R.pill),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    GNetImage(
                      url: PartMedia.urlFor(item.kind, item.name),
                      fallbackIcon: item.kind.icon,
                      tint: tint,
                      height: 52,
                      width: 52,
                      radius: R.sm,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.labelL.s(15).c(p.ink),
                          ),
                          Text(
                            [
                              if (item.make.isNotEmpty) item.make,
                              if (item.partNo.isNotEmpty) item.partNo,
                              Fmt.money(item.rate),
                            ].join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.labelS.c(p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: p.dangerSoft,
                    borderRadius: R.all(R.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_rounded, size: 18, color: p.danger),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          // Said plainly, because it is the one thing people
                          // are afraid of when they delete from a catalogue.
                          'Deleting takes it off this list only. Cards already billed for it keep their line and their price.',
                          style: AppType.labelS.s(11.5).c(p.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),
                GButton(
                  label: 'Delete from {0} list'.trf([item.kind.label]),
                  kind: GButtonKind.danger,
                  icon: Icons.delete_outline_rounded,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
                const SizedBox(height: Gap.sm),
                GButton(
                  label: 'Keep it'.tr,
                  kind: GButtonKind.ghost,
                  size: GButtonSize.lg,
                  expand: true,
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (deleted != true) return false;
  ref.read(adminProvider.notifier).removeMaster(item.id);
  if (context.mounted) {
    GFeedback.success(context, '{0} deleted'.trf([item.name]));
  }
  return true;
}
