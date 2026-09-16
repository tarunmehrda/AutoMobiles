import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/pressable.dart';

/// A searchable list in a sheet, used for the make and the model on the job
/// card form.
///
/// Typing something the list does not have is allowed and returned as-is —
/// a workshop sees imports and rebuilds that no catalogue will ever cover,
/// and the counter must not be stuck behind a dropdown.
Future<String?> pickFromCatalog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<String> options,
  String? selected,
}) async {
  final controller = TextEditingController();
  String? chosen;

  await GFeedback.sheet<void>(
    context,
    title: title,
    subtitle: subtitle,
    child: StatefulBuilder(
      builder: (context, setSheet) {
        final p = context.c;
        final q = controller.text.trim().toLowerCase();
        final matches = q.isEmpty
            ? options
            : options
                .where((o) => o.toLowerCase().contains(q))
                .toList();
        final exact = options.any((o) => o.toLowerCase() == q);

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, Gap.lg, Gap.page, Gap.md),
                child: GSearchBar(
                  hint: 'Search or type a new one',
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setSheet(() {}),
                  onClear: q.isEmpty
                      ? null
                      : () {
                          controller.clear();
                          setSheet(() {});
                        },
                ),
              ),
              if (q.isNotEmpty && !exact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.page, 0, Gap.page, Gap.md),
                  child: _Row(
                    label: 'Use "${controller.text.trim()}"',
                    subtitle: 'Not in the list — added to this card only',
                    icon: Icons.edit_rounded,
                    selected: false,
                    onTap: () {
                      chosen = controller.text.trim();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              Flexible(
                child: matches.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: Gap.h1),
                        child: GEmptyState(
                          compact: true,
                          icon: Icons.search_off_rounded,
                          title: 'No match',
                          message: 'Type it in and carry on.',
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                            Gap.page, 0, Gap.page, Gap.h1),
                        itemCount: matches.length,
                        itemBuilder: (context, i) => _Row(
                          label: matches[i],
                          selected: matches[i] == selected,
                          onTap: () {
                            chosen = matches[i];
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
              ),
              if (matches.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: Text('${matches.length} of ${options.length}',
                      style: AppType.labelS.c(p.inkFaint)),
                ),
            ],
          ),
        );
      },
    ),
  );

  controller.dispose();
  return chosen;
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        decoration: BoxDecoration(
          color: selected ? p.surfaceSunken : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: selected ? p.ink : p.line),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: p.accentInk),
              const SizedBox(width: Gap.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppType.labelL.c(p.ink)),
                  if (subtitle != null)
                    Text(subtitle!, style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 19, color: p.accent),
          ],
        ),
      ),
    );
  }
}
