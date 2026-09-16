import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/pressable.dart';

/// Customer voice and accessories are the same interaction: tick from a
/// preset list, add anything that is not on it, reorder by removing. One
/// screen serves both so they cannot drift apart.
class ChecklistPage extends ConsumerStatefulWidget {
  const ChecklistPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emptyHint,
    required this.presets,
    required this.selected,
    required this.onSave,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String emptyHint;
  final List<String> presets;
  final List<String> selected;
  final ValueChanged<List<String>> onSave;
  final IconData icon;

  @override
  ConsumerState<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends ConsumerState<ChecklistPage> {
  late final List<String> _picked = [...widget.selected];
  final _custom = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _toggle(String value) {
    setState(() {
      if (_picked.contains(value)) {
        _picked.remove(value);
      } else {
        _picked.add(value);
      }
    });
    widget.onSave(_picked);
  }

  void _addCustom() {
    final value = _custom.text.trim();
    if (value.isEmpty) return;
    if (!_picked.any((e) => e.toLowerCase() == value.toLowerCase())) {
      setState(() => _picked.add(value));
      widget.onSave(_picked);
    }
    _custom.clear();
    setState(() => _query = '');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final q = _query.trim().toLowerCase();
    final options = widget.presets
        .where((e) => q.isEmpty || e.toLowerCase().contains(q))
        .toList();
    final exactMatch = widget.presets
        .any((e) => e.toLowerCase() == q) ||
        _picked.any((e) => e.toLowerCase() == q);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: widget.title,
        subtitle: '${_picked.length} selected',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Gap.page, Gap.sm, Gap.page, Gap.md),
            child: Text(widget.subtitle, style: AppType.bodyM.c(p.inkMuted)),
          ),

          // --- what is already on the card -------------------------------
          if (_picked.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final value in _picked)
                      Pressable(
                        onTap: () => _toggle(value),
                        scale: 0.94,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(
                              Gap.md, Gap.sm, Gap.sm, Gap.sm),
                          decoration: BoxDecoration(
                            color: p.ink,
                            borderRadius: R.all(R.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                value,
                                style: AppType.labelM
                                    .c(p.isDark ? p.canvas : Colors.white),
                              ),
                              const SizedBox(width: 5),
                              Icon(Icons.close_rounded,
                                  size: 14,
                                  color: (p.isDark ? p.canvas : Colors.white)
                                      .withValues(alpha: 0.7)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
            child: GSearchBar(
              hint: 'Search or type something new',
              controller: _custom,
              onChanged: (v) => setState(() => _query = v),
              onClear: _query.isEmpty
                  ? null
                  : () {
                      _custom.clear();
                      setState(() => _query = '');
                    },
            ),
          ),

          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
              children: [
                if (q.isNotEmpty && !exactMatch)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.md),
                    child: GButton(
                      label: 'Add "${_custom.text.trim()}"',
                      kind: GButtonKind.ghost,
                      size: GButtonSize.md,
                      icon: Icons.add_rounded,
                      onPressed: _addCustom,
                    ),
                  ),
                if (options.isEmpty && q.isNotEmpty)
                  GEmptyState(
                    compact: true,
                    icon: widget.icon,
                    title: 'Nothing preset matches',
                    message: 'Add it as a one-off with the button above.',
                  )
                else
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      for (final option in options)
                        _Chip(
                          label: option,
                          selected: _picked.contains(option),
                          onTap: () => _toggle(option),
                        ),
                    ],
                  ),
                if (_picked.isEmpty && q.isEmpty) ...[
                  const SizedBox(height: Gap.xxl),
                  Text(widget.emptyHint,
                      textAlign: TextAlign.center,
                      style: AppType.bodyS.c(p.inkFaint)),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: 'Done',
          onPressed: () {
            widget.onSave(_picked);
            GFeedback.success(context, '${widget.title} saved');
            context.pop();
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surface,
          borderRadius: R.all(R.pill),
          border: Border.all(color: selected ? p.accent : p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              size: 16,
              color: selected ? p.accentInk : p.inkFaint,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppType.labelM.c(selected ? p.accentInk : p.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
