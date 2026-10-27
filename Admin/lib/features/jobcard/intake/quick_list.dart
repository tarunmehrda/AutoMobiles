import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/pressable.dart';

/// A short list the counter builds while the customer is talking: what is
/// already on it, a line to type the next one into, and the way to the full
/// checklist of presets.
///
/// The checklist page alone made every entry a trip — open it, find the
/// complaint among forty presets or type it there, save, come back. Most
/// cards carry one or two lines in the customer's own words, and those go
/// in fastest typed straight onto the step.
class QuickList extends StatefulWidget {
  const QuickList({
    super.key,
    required this.values,
    required this.tint,
    required this.hint,
    required this.empty,
    required this.onAdd,
    required this.onRemove,
    required this.onMore,
    this.moreLabel,
  });

  final List<String> values;
  final Color tint;
  final String hint;
  final String empty;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  /// Opens the full checklist.
  final VoidCallback onMore;
  final String? moreLabel;

  @override
  State<QuickList> createState() => _QuickListState();
}

class _QuickListState extends State<QuickList> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _add() {
    final v = _typed.text.trim();
    if (v.isEmpty) return;
    // A repeat is dropped quietly: it is already on the list, which is what
    // the counter wanted.
    if (!widget.values.contains(v)) widget.onAdd(v);
    _typed.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tint = widget.tint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.values.isEmpty)
          Text(widget.empty, style: AppType.bodyS.c(p.inkFaint))
        else
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final v in widget.values)
                Container(
                  padding: const EdgeInsets.only(left: Gap.md),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.10),
                    borderRadius: R.all(R.pill),
                    border: Border.all(color: tint.withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bounded, because a Wrap hands its children unbounded
                      // width and a long complaint would run off the phone.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width - 110,
                        ),
                        child: Text(
                          v,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelM.c(p.ink),
                        ),
                      ),
                      Pressable(
                        onTap: () => widget.onRemove(v),
                        scale: 0.85,
                        child: SizedBox(
                          height: 34,
                          width: 34,
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: p.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: Gap.md),
        Container(
          padding: const EdgeInsets.only(left: Gap.md),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: R.all(R.md),
            border: Border.all(color: p.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _typed,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  style: AppType.bodyM.c(p.ink),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: AppType.bodyS.c(p.inkFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _add(),
                ),
              ),
              Pressable(
                onTap: _typed.text.trim().isEmpty ? null : _add,
                scale: 0.9,
                child: SizedBox(
                  height: 44,
                  width: 48,
                  child: Icon(
                    Icons.add_circle_rounded,
                    size: 24,
                    color: _typed.text.trim().isEmpty ? p.inkFaint : tint,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.sm),
        Pressable(
          onTap: widget.onMore,
          scale: 0.96,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xs),
            child: Text(
              widget.moreLabel ?? '+ Enter all details'.tr,
              style: AppType.labelL
                  .c(tint)
                  .copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
      ],
    );
  }
}
