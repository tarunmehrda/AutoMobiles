import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';

class _Panel {
  const _Panel(this.label, this.icon, this.path, this.countOf);
  final String label;
  final IconData icon;
  final String path;
  final int Function(JobCard) countOf;
}

final _panels = <_Panel>[
  _Panel(
    'Items',
    Icons.add_shopping_cart_rounded,
    'items',
    (c) => c.items.length,
  ),
  _Panel(
    'Customer voice',
    Icons.record_voice_over_rounded,
    'voices',
    (c) => c.voices.length,
  ),
  _Panel(
    'Accessories',
    Icons.luggage_rounded,
    'accessories',
    (c) => c.accessories.length,
  ),
  _Panel(
    'Work note',
    Icons.sticky_note_2_rounded,
    'note',
    (c) => c.workNote.trim().isEmpty ? 0 : 1,
  ),
  _Panel('Dent marks', Icons.car_crash_rounded, 'dents', (c) => c.dents.length),
  _Panel(
    'Photos',
    Icons.photo_camera_rounded,
    'photos',
    (c) => c.photos.length,
  ),
  _Panel(
    'Mechanics',
    Icons.engineering_rounded,
    'mechanics',
    (c) => c.mechanicIds.length,
  ),
];

/// The row of everything attached to a job card, with a count so the counter
/// can see what has been filled in without opening each one.
class PanelStrip extends StatelessWidget {
  const PanelStrip({super.key, required this.card});

  final JobCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: SizedBox(
        // Icon (42) + gap (5) + a two-line label, plus the 8 of padding
        // above and below. 'Customer voice' wraps, so the two lines are
        // what the strip has to be tall enough for.
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.page,
            vertical: Gap.sm,
          ),
          itemCount: _panels.length,
          separatorBuilder: (_, _) => const SizedBox(width: Gap.lg),
          itemBuilder: (context, i) {
            final panel = _panels[i];
            final count = panel.countOf(card);
            return _PanelButton(
              label: panel.label,
              icon: panel.icon,
              count: count,
              onTap: () => context.push('/job/${card.id}/${panel.path}'),
            );
          },
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final filled = count > 0;
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: filled ? p.accentSoft : p.surfaceSunken,
                    borderRadius: R.all(R.md),
                    border: Border.all(
                      color: filled ? p.accent.withValues(alpha: 0.3) : p.line,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: filled ? p.accentInk : p.inkMuted,
                  ),
                ),
                if (filled)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      decoration: BoxDecoration(
                        color: p.ink,
                        borderRadius: R.all(R.pill),
                        border: Border.all(color: p.surface, width: 1.6),
                      ),
                      child: Center(
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: AppType.labelS
                              .s(9)
                              .c(p.isDark ? p.canvas : Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelS.s(9.5).c(filled ? p.ink : p.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
