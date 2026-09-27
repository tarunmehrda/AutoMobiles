import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../documents/doc_sections.dart';
import '../documents/invoice_format.dart';

/// Picking one of the five templates, and ticking what rides along on it.
///
/// One control, used in two places: on the job card itself, where the preview
/// underneath redraws as it changes, and again on the share sheet, where the
/// counter is one tap from sending it. Both edit the same two values, so the
/// choice made in either is the choice that prints.
class TemplatePicker extends StatelessWidget {
  const TemplatePicker({
    super.key,
    required this.kind,
    required this.card,
    required this.garage,
    required this.format,
    required this.sections,
    required this.onChanged,
    this.compact = false,
    this.onBeforeEdit,
  });

  final DocKind kind;
  final JobCard card;
  final Garage garage;
  final InvoiceFormat format;
  final Set<DocSection> sections;

  /// Reports both values together, because changing the template rewrites
  /// the ticks and the caller needs them to arrive in step.
  final void Function(InvoiceFormat format, Set<DocSection> sections) onChanged;

  /// Drops the surrounding panel, for somewhere that already has one.
  final bool compact;

  /// Run before this control navigates to a panel.
  ///
  /// The share sheet is a modal route, and pushing an editor from under it
  /// leaves the sheet sitting on top of the screen somebody just asked for.
  /// It passes its own dismiss in here.
  final VoidCallback? onBeforeEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('TEMPLATE', style: AppType.over.s(9.5).c(p.inkFaint)),
            const SizedBox(width: Gap.md),
            // Flexible, because a 360pt phone inside this panel has barely
            // 280 to spend and the longer blurbs run past the edge.
            Flexible(
              child: Text(
                format.blurb,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.bodyS.s(10.5).c(p.inkFaint),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: InvoiceFormat.values.length,
            separatorBuilder: (context, i) => const SizedBox(width: Gap.sm),
            itemBuilder: (context, i) {
              final f = InvoiceFormat.values[i];
              return _FormatTile(
                format: f,
                selected: f == format,
                // A template is a preset, so switching to one hands back its
                // own shape rather than carrying the last one's ticks over.
                // Otherwise "Simple Bill" quietly keeps the photographs the
                // detailed card had on it.
                onTap: () => onChanged(f, DocSectionX.defaultsFor(f, kind)),
              );
            },
          ),
        ),
        const SizedBox(height: Gap.lg),
        Text('ON THIS DOCUMENT'.tr, style: AppType.over.s(9.5).c(p.inkFaint)),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final s in DocSectionX.offeredOn(format, kind))
              _SectionChip(
                section: s,
                on: sections.contains(s),
                // A switch for something the card has nothing to say about
                // would print an empty box, so an empty one is not a switch
                // at all: it opens the screen that fills it in. Nothing to
                // toggle, and the next tap after that is the useful one.
                empty: _isEmpty(s),
                onTap: () {
                  if (_isEmpty(s)) {
                    _edit(context, s);
                    return;
                  }
                  final next = {...sections};
                  if (!next.remove(s)) next.add(s);
                  onChanged(format, next);
                },
                // Held down, a filled block opens its editor too, so the
                // strip is a way into every panel and not only a switchboard.
                onEdit: () => _edit(context, s),
              ),
          ],
        ),
      ],
    );

    if (compact) return body;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.line),
      ),
      child: body,
    );
  }

  /// Whether there is anything behind this block on this card.
  bool _isEmpty(DocSection s) => switch (s) {
    DocSection.odometer => false,
    DocSection.mechanics => card.mechanicIds.isEmpty,
    DocSection.voices => card.voices.isEmpty,
    DocSection.accessories => card.accessories.isEmpty,
    DocSection.workNote => card.workNote.trim().isEmpty,
    DocSection.dents => card.dents.isEmpty,
    DocSection.photos => card.photos.isEmpty,
    DocSection.sms => card.sms.isEmpty,
    DocSection.payments => card.payments.isEmpty,
    DocSection.paymentQr => garage.upiId.trim().isEmpty,
  };

  /// Where each block is filled in.
  ///
  /// Odometer and fuel live on the work note screen, which is also where the
  /// promised time is — they are the three things an advisor sets in one
  /// pass. Payments are taken on the tab further down this same page, and
  /// the SMS log is written by the app rather than by anybody, so neither
  /// has a screen to send somebody to.
  String? _route(DocSection s) => switch (s) {
    DocSection.odometer => '/job/${card.id}/note',
    DocSection.mechanics => '/job/${card.id}/mechanics',
    DocSection.voices => '/job/${card.id}/voices',
    DocSection.accessories => '/job/${card.id}/accessories',
    DocSection.workNote => '/job/${card.id}/note',
    DocSection.dents => '/job/${card.id}/dents',
    DocSection.photos => '/job/${card.id}/photos',
    DocSection.paymentQr => '/workshop',
    DocSection.sms => null,
    DocSection.payments => null,
  };

  void _edit(BuildContext context, DocSection s) {
    final route = _route(s);
    if (route == null) {
      GFeedback.info(context, _nothingYet(s));
      return;
    }
    // The QR block is the one whose editor is nowhere near the card, so it
    // is also the one that reads as a dead chip. Say why before the screen
    // changes under them.
    if (s == DocSection.paymentQr) {
      GFeedback.info(context, 'Add a UPI ID and the QR prints on the bill.'.tr);
    }
    onBeforeEdit?.call();
    context.push(route);
  }

  String _nothingYet(DocSection s) => switch (s) {
    DocSection.sms => 'No messages have gone out on this card yet.',
    DocSection.payments =>
      'Nothing paid yet — take it on the Payments tab below.',
    _ => '',
  };
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final InvoiceFormat format;
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
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.12) : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(
            color: selected ? p.accent : p.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  format.isThermal
                      ? Icons.receipt_long_rounded
                      : Icons.description_rounded,
                  size: 13,
                  color: selected ? p.accent : p.inkFaint,
                ),
                const SizedBox(width: 5),
                Text(
                  format.label,
                  style: AppType.labelM.s(11.5).c(selected ? p.accent : p.ink),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(format.blurb, style: AppType.bodyS.s(9.5).c(p.inkFaint)),
          ],
        ),
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.section,
    required this.on,
    required this.empty,
    required this.onTap,
    required this.onEdit,
  });

  final DocSection section;
  final bool on;
  final bool empty;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final live = on && !empty;
    final tint = empty ? p.inkFaint : (live ? p.accent : p.inkMuted);
    return Pressable(
      onTap: onTap,
      onLongPress: onEdit,
      scale: 0.96,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: live ? p.accent.withValues(alpha: 0.12) : p.surfaceAlt,
          borderRadius: R.all(R.pill),
          border: Border.all(color: live ? p.accent : p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              empty
                  ? Icons.add_rounded
                  : (live ? Icons.check_circle_rounded : Icons.circle_outlined),
              size: 13,
              color: tint,
            ),
            const SizedBox(width: 5),
            Text(section.label, style: AppType.labelM.s(11).c(tint)),
          ],
        ),
      ),
    );
  }
}
