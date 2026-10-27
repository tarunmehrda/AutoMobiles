import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/directions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/workshop.dart';
import '../../../state/providers.dart';
import 'rate_sheet.dart';

/// One job card as the customer sees it: what is being done, when it is
/// promised, what it comes to, and how to reach the people doing it.
Future<void> showBookingDetailsSheet(
  BuildContext context,
  WorkshopCard card,
) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BookingDetailsSheet(card: card),
    );

class _BookingDetailsSheet extends ConsumerWidget {
  const _BookingDetailsSheet({required this.card});

  final WorkshopCard card;

  Future<void> _open(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// What the floor is actually doing, in the customer's words.
  String get _status {
    if (card.isClosed) return 'Completed';
    if (card.isComplete) return 'Ready for Delivery';
    if (card.items.any((e) => e.isFinished)) return 'Work In Progress';
    return 'Work Not Yet Started';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final shop = ref.watch(workshopProvider);
    // This card's own garage first. The linked workshop is only a fallback
    // for cards from before the letterhead travelled with them — for a
    // customer of two garages it is the other one's address half the time.
    final where = card.garageWhere.isNotEmpty ? card.garageWhere : shop.address;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(
        color: p.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xxl)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
                Gap.page, Gap.lg, Gap.page, Gap.lg),
            decoration: BoxDecoration(gradient: p.inverseGradient),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Booking Details',
                          style: AppType.h1.c(p.onInverse)),
                      Text('#${card.number}',
                          style: AppType.bodyS
                              .c(p.onInverse.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md, vertical: 5),
                  decoration: BoxDecoration(
                    color: card.isComplete ? p.success : p.info,
                    borderRadius: R.all(R.pill),
                  ),
                  child: Text(_status,
                      style: AppType.labelS.c(Colors.white)),
                ),
                const SizedBox(width: Gap.sm),
                Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  scale: 0.9,
                  child: Icon(Icons.close_rounded,
                      size: 22, color: p.onInverse),
                ),
              ],
            ),
          ),

          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.lg, Gap.page, Gap.lg),
              children: [
                _Section(
                  icon: Icons.directions_car_rounded,
                  title: 'Vehicle Information',
                  rows: [
                    ('Vehicle', card.vehicleName),
                    ('Number', Fmt.plate(card.regNo)),
                    (
                      'Service Type',
                      card.items.isEmpty
                          ? (card.voices.isEmpty
                              ? 'General service'
                              : card.voices.first)
                          : card.items.first.name,
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                _Section(
                  icon: Icons.calendar_month_rounded,
                  title: 'Schedule',
                  rows: [
                    ('Drop-off Date', Fmt.date(card.openedAt)),
                    ('Drop-off Time', Fmt.time(card.openedAt)),
                    // Date and time: "ready by evening" is a different promise
                    // from "ready tomorrow".
                    if (card.promisedAt != null)
                      ('Expected Delivery', Fmt.fullDateTime(card.promisedAt!)),
                  ],
                ),
                if (card.hasInsurance) ...[
                  const SizedBox(height: Gap.lg),
                  _Section(
                    icon: Icons.verified_user_rounded,
                    title: 'Insurance',
                    rows: [
                      if (card.insurer.trim().isNotEmpty)
                        ('Insurer', card.insurer.trim()),
                      if (card.policyNo.trim().isNotEmpty)
                        ('Policy No', card.policyNo.trim()),
                      if (card.insuranceExpiry != null)
                        ('Valid Till', Fmt.date(card.insuranceExpiry!)),
                    ],
                  ),
                ],
                if (card.dents.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  _DentsSection(dents: card.dents),
                ],

                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 18, color: p.accent),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text('Invoice Details',
                          style: AppType.h2.c(p.ink)),
                    ),
                    Pressable(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/workshop/${card.id}/invoice');
                      },
                      scale: 0.9,
                      child: Icon(Icons.download_rounded,
                          size: 20, color: p.inkSoft),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Container(
                  padding: const EdgeInsets.all(Gap.lg),
                  decoration: BoxDecoration(
                    color: p.surfaceSunken,
                    borderRadius: R.all(R.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Parts and Labour',
                          style: AppType.labelM.c(p.inkMuted)),
                      const SizedBox(height: Gap.sm),
                      if (card.items.isEmpty)
                        Text('Nothing billed yet.',
                            style: AppType.bodyS.c(p.inkFaint))
                      else
                        for (final li in card.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(li.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.bodyM.c(p.ink)),
                                ),
                                Text(Fmt.money(li.qty * li.rate),
                                    style: AppType.moneyS.c(p.ink)),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Expanded(
                      child:
                          Text('Subtotal', style: AppType.bodyM.c(p.inkMuted)),
                    ),
                    Text(Fmt.money(card.subTotal),
                        style: AppType.moneyS.c(p.inkSoft)),
                  ],
                ),
                Divider(height: Gap.xl, color: p.line),
                Row(
                  children: [
                    Expanded(
                      child:
                          Text('Total Amount', style: AppType.h2.c(p.ink)),
                    ),
                    Text(Fmt.money(card.total),
                        style: AppType.money.c(p.accentInk)),
                  ],
                ),
                if (card.advance > 0 || card.payments.isNotEmpty) ...[
                  const SizedBox(height: Gap.md),
                  _Payments(card: card),
                ],

                const SizedBox(height: Gap.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg, vertical: Gap.md),
                  decoration: BoxDecoration(
                    color: card.settled ? p.successSoft : p.surfaceSunken,
                    borderRadius: R.all(R.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Payment Status',
                            style: AppType.labelL.c(p.ink)),
                      ),
                      GPill(
                        label: card.settled ? 'Paid' : 'Unpaid',
                        tone: card.settled ? GTone.success : GTone.neutral,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                if (card.isClosed) ...[
                  const SizedBox(height: Gap.md),
                  RateButton(card: card),
                ],

                const SizedBox(height: Gap.xl),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 18, color: p.accent),
                    const SizedBox(width: Gap.sm),
                    Text('Workshop Details', style: AppType.h2.c(p.ink)),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  card.garageName.isEmpty || card.garageName == shop.name
                      ? shop.label
                      : card.garageName,
                  style: AppType.labelL.c(p.ink),
                ),
                if (card.garagePhone.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.call_rounded, size: 14, color: p.inkMuted),
                      const SizedBox(width: 5),
                      Text(card.garagePhone,
                          style: AppType.bodyS.c(p.inkMuted)),
                    ],
                  ),
                if (where.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place_rounded, size: 14, color: p.inkMuted),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(where,
                            style: AppType.bodyS.c(p.inkMuted)),
                      ),
                    ],
                  ),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Expanded(
                      child: GButton(
                        label: 'Call',
                        kind: GButtonKind.outline,
                        icon: Icons.call_rounded,
                        onPressed: card.garagePhone.isEmpty
                            ? null
                            : () => _open(
                                Uri.parse('tel:${card.garagePhone}')),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GButton(
                        label: 'Directions',
                        kind: GButtonKind.outline,
                        icon: Icons.navigation_rounded,
                        onPressed: where.isEmpty
                            ? null
                            : () async {
                                if (!await openDirections(address: where) &&
                                    context.mounted) {
                                  GFeedback.error(
                                    context,
                                    'Could not open maps on this phone.',
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  GButton.accent(
                    label: 'Download Invoice',
                    icon: Icons.download_rounded,
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/workshop/${card.id}/invoice');
                    },
                  ),
                  const SizedBox(height: Gap.sm),
                  GButton(
                    label: 'Need Help?',
                    kind: GButtonKind.outline,
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/help');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: p.accent),
            const SizedBox(width: Gap.sm),
            Text(title, style: AppType.h2.c(p.ink)),
          ],
        ),
        const SizedBox(height: Gap.sm),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(r.$1, style: AppType.bodyM.c(p.inkMuted)),
                ),
                Flexible(
                  child: Text(r.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppType.labelL.c(p.ink)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// What has been paid against the card: the advance taken at the counter
/// on its own line, then every payment with its mode and date.
class _Payments extends StatelessWidget {
  const _Payments({required this.card});

  final WorkshopCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final via = card.advanceVia;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: R.all(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (card.advance > 0)
            Text(
              'Advance paid ${Fmt.money(card.advance)}'
              '${via.isEmpty ? '' : ' via $via'}',
              style: AppType.labelL.c(p.ink),
            ),
          if (card.payments.isNotEmpty) ...[
            if (card.advance > 0) const SizedBox(height: Gap.sm),
            Text('Payments', style: AppType.labelM.c(p.inkMuted)),
            const SizedBox(height: Gap.xs),
            for (final e in card.payments)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          if (e.at != null) Fmt.date(e.at!),
                          if (e.modeLabel.isNotEmpty) e.modeLabel,
                          if (e.advance) 'Advance',
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyS.c(p.inkSoft),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Text(Fmt.money(e.amount),
                        style: AppType.moneyS.c(p.ink)),
                  ],
                ),
              ),
          ],
          if (card.items.isNotEmpty) ...[
            Divider(height: Gap.lg, color: p.line),
            Row(
              children: [
                Expanded(
                  child: Text('Balance', style: AppType.labelL.c(p.ink)),
                ),
                Text(Fmt.money(card.balance),
                    style: AppType.moneyS.c(p.accentInk)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The workshop's colour key, as printed on its intake sheet: scratch red,
/// dent yellow, broken green, rust blue. Fixed rather than taken from the
/// palette so it matches the console and the paper copy in either theme.
Color _dentColor(String severity) => switch (severity) {
      'dent' => const Color(0xFFF2C744),
      'crack' => const Color(0xFF30A46C),
      'rust' => const Color(0xFF3E7BFA),
      _ => const Color(0xFFE5484D),
    };

/// The damage sheet the counter filled in when the car came in, one mark a
/// line: "Dent — Front bumper", with whatever they noted under it.
///
/// It is the list both sides point at when the car is handed back, so the
/// customer gets to read it before then rather than at the counter.
class _DentsSection extends StatelessWidget {
  const _DentsSection({required this.dents});

  final List<WorkshopDent> dents;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.car_crash_rounded, size: 18, color: p.accent),
            const SizedBox(width: Gap.sm),
            Text('Damage noted at check-in', style: AppType.h2.c(p.ink)),
          ],
        ),
        const SizedBox(height: Gap.sm),
        // The key, so a colour on the console's sheet means the same here.
        Wrap(
          spacing: Gap.md,
          runSpacing: Gap.xs,
          children: [
            for (final (sev, label) in const [
              ('scratch', 'Scratch'),
              ('dent', 'Dent'),
              ('crack', 'Broken'),
              ('rust', 'Rust'),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(color: _dentColor(sev)),
                  const SizedBox(width: 5),
                  Text(label, style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        for (final d in dents)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _Dot(color: _dentColor(d.severity)),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.label.isEmpty
                            ? d.severityLabel
                            : '${d.severityLabel} — ${d.label}',
                        style: AppType.labelL.c(p.ink),
                      ),
                      if (d.note.trim().isNotEmpty)
                        Text(d.note.trim(),
                            style: AppType.bodyS.c(p.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
