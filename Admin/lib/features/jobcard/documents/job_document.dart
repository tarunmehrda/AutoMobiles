import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/words.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';

/// The printable face of a job card.
///
/// All three documents are the same sheet with different rules about what is
/// on it: the estimate and the invoice carry money, the mechanic copy carries
/// the complaint, the accessories and a column for the floor to write in —
/// and deliberately no prices at all.
class JobDocument extends StatelessWidget {
  const JobDocument({
    super.key,
    required this.kind,
    required this.card,
    required this.garage,
    required this.customer,
    required this.vehicle,
    required this.staff,
  });

  final DocKind kind;
  final JobCard card;
  final Garage garage;
  final Customer? customer;
  final Vehicle? vehicle;
  final List<Staff> staff;

  String _staffNames(Iterable<String> ids) {
    final names = <String>[];
    for (final id in ids) {
      for (final s in staff) {
        if (s.id == id) names.add(s.name);
      }
    }
    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Letterhead(kind: kind, card: card, garage: garage),
          _Parties(
            kind: kind,
            card: card,
            customer: customer,
            vehicle: vehicle,
            mechanics: _staffNames(card.mechanicIds),
          ),
          if (kind == DocKind.mechanicCopy) ...[
            _VoiceAndAccessories(card: card),
          ],
          _Particulars(kind: kind, card: card, staff: staff),
          if (kind.showsPricing)
            _Totals(kind: kind, card: card)
          else
            _MechanicFooter(card: card),
          if (kind.showsPricing) _AmountInWords(card: card),
          _DocFooter(kind: kind, card: card, garage: garage),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Letterhead extends StatelessWidget {
  const _Letterhead({
    required this.kind,
    required this.card,
    required this.garage,
  });

  final DocKind kind;
  final JobCard card;
  final Garage garage;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: R.all(R.sm),
              border: Border.all(color: p.line),
            ),
            child: Text(
              Fmt.initials(garage.name),
              style: AppType.h3.c(p.inkMuted),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(garage.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.h2.c(p.accentInk)),
                const SizedBox(height: 2),
                Text(garage.phone, style: AppType.bodyS.c(p.inkMuted)),
                if (garage.postal.isNotEmpty)
                  Text(garage.postal,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.s(11).c(p.inkFaint)),
                if (garage.gstin.isNotEmpty)
                  Text('GSTIN ${garage.gstin}',
                      style: AppType.bodyS.s(11).c(p.inkFaint)),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(kind.label, style: AppType.h2.c(p.ink)),
              const SizedBox(height: 4),
              _MetaRow(label: 'Number', value: card.number),
              _MetaRow(label: 'Date', value: Fmt.date(card.createdAt)),
              _MetaRow(label: 'Time', value: Fmt.time(card.createdAt)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: AppType.labelS.s(10).c(p.inkFaint)),
          Text(value, style: AppType.moneyS.s(11).c(p.inkSoft)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Two-up block: who is being billed, and what came in.
class _Parties extends StatelessWidget {
  const _Parties({
    required this.kind,
    required this.card,
    required this.customer,
    required this.vehicle,
    required this.mechanics,
  });

  final DocKind kind;
  final JobCard card;
  final Customer? customer;
  final Vehicle? vehicle;
  final String mechanics;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final billTo = kind != DocKind.mechanicCopy;

    return Column(
      children: [
        _BandHeader(
          left: billTo ? 'Bill to' : 'Vehicle info',
          right: billTo ? 'Vehicle info' : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (billTo) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer?.name ?? '—',
                          style: AppType.labelL.c(p.ink)),
                      Text(customer?.phone ?? '',
                          style: AppType.bodyS.c(p.inkMuted)),
                      if ((customer?.address ?? '').isNotEmpty)
                        Text(customer!.address,
                            style: AppType.bodyS.s(11).c(p.inkFaint)),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Veh. No: ${Fmt.plate(vehicle?.regNo ?? '—')}',
                        style: AppType.labelM.c(p.ink)),
                    Text(vehicle?.title ?? '',
                        style: AppType.bodyS.c(p.inkSoft)),
                    const SizedBox(height: 2),
                    Text(
                      'Km read: ${Fmt.km(card.odometerKm)}  •  Fuel: ${card.fuelPercent}%',
                      style: AppType.bodyS.s(11).c(p.inkMuted),
                    ),
                    if (kind == DocKind.mechanicCopy && mechanics.isNotEmpty)
                      Text('Assigned: $mechanics',
                          style: AppType.bodyS.s(11).c(p.inkMuted)),
                    if (card.promisedAt != null)
                      Text(
                        'Ready by: ${Fmt.fullDateTime(card.promisedAt!)}',
                        style: AppType.labelS.s(10.5).c(p.warning),
                      ),
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

/// Thin tinted band used as a table/section head throughout the document.
class _BandHeader extends StatelessWidget {
  const _BandHeader({required this.left, this.right});

  final String left;
  final String? right;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      width: double.infinity,
      color: p.accentSoft,
      padding:
          const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(left.toUpperCase(),
                style: AppType.over.s(10).c(p.accentInk)),
          ),
          if (right != null)
            Expanded(
              child: Text(right!.toUpperCase(),
                  style: AppType.over.s(10).c(p.accentInk)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Mechanic copy only: the complaint on the left, what came in on the right.
class _VoiceAndAccessories extends StatelessWidget {
  const _VoiceAndAccessories({required this.card});

  final JobCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      children: [
        const _BandHeader(left: 'Customer voice', right: 'Accessories'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _NumberedList(
                  items: card.voices,
                  empty: 'Nothing noted',
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: _NumberedList(
                  items: card.accessories,
                  empty: 'None recorded',
                ),
              ),
            ],
          ),
        ),
        if (card.workNote.trim().isNotEmpty) ...[
          const _BandHeader(left: 'Work note'),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(card.workNote,
                  style: AppType.bodyS.c(p.inkSoft)),
            ),
          ),
        ],
      ],
    );
  }
}

class _NumberedList extends StatelessWidget {
  const _NumberedList({required this.items, required this.empty});

  final List<String> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (items.isEmpty) {
      return Text(empty, style: AppType.bodyS.s(11.5).c(p.inkFaint));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 16,
                  child: Text('${i + 1}',
                      style: AppType.labelS.s(10.5).c(p.inkFaint)),
                ),
                Expanded(
                  child: Text(items[i],
                      style: AppType.bodyS.s(12).c(p.inkSoft)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// The line table. Money columns on the customer documents; status, mechanic
/// and a remark column on the copy that goes to the floor.
class _Particulars extends StatelessWidget {
  const _Particulars({
    required this.kind,
    required this.card,
    required this.staff,
  });

  final DocKind kind;
  final JobCard card;
  final List<Staff> staff;

  String _mechanic(String? id) {
    if (id == null) return '';
    for (final s in staff) {
      if (s.id == id) return s.name.split(' ').first;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final priced = kind.showsPricing;
    final rows = card.items;

    return Column(
      children: [
        Container(
          color: p.accentSoft,
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg, vertical: Gap.sm),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child:
                    Text('#', style: AppType.over.s(10).c(p.accentInk)),
              ),
              Expanded(
                flex: 4,
                child: Text('PARTICULARS',
                    style: AppType.over.s(10).c(p.accentInk)),
              ),
              if (priced) ...[
                Expanded(
                  child: Text('QTY',
                      textAlign: TextAlign.right,
                      style: AppType.over.s(10).c(p.accentInk)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('RATE',
                      textAlign: TextAlign.right,
                      style: AppType.over.s(10).c(p.accentInk)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('AMOUNT',
                      textAlign: TextAlign.right,
                      style: AppType.over.s(10).c(p.accentInk)),
                ),
              ] else ...[
                Expanded(
                  flex: 2,
                  child: Text('STATUS',
                      style: AppType.over.s(10).c(p.accentInk)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('MECHANIC',
                      style: AppType.over.s(10).c(p.accentInk)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('REMARK',
                      style: AppType.over.s(10).c(p.accentInk)),
                ),
              ],
            ],
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xl),
            child: Text(
              priced
                  ? 'Nothing billed on this card yet'
                  : 'No work listed yet',
              style: AppType.bodyS.c(p.inkFaint),
            ),
          )
        else
          for (var i = 0; i < rows.length; i++)
            Container(
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: i == rows.length - 1
                            ? Colors.transparent
                            : p.lineSoft)),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg, vertical: Gap.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: Text('${i + 1}',
                        style: AppType.moneyS.s(11).c(p.inkFaint)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].name,
                            style: AppType.bodyS.s(12.5).c(p.ink)),
                        if (rows[i].partNo.isNotEmpty)
                          Text(rows[i].partNo,
                              style: AppType.labelS.s(9.5).c(p.inkFaint)),
                      ],
                    ),
                  ),
                  if (priced) ...[
                    Expanded(
                      child: Text(rows[i].qtyLabel,
                          textAlign: TextAlign.right,
                          style: AppType.moneyS.s(11.5).c(p.inkSoft)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(Fmt.money2(rows[i].rate),
                          textAlign: TextAlign.right,
                          style: AppType.moneyS.s(11.5).c(p.inkSoft)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(Fmt.money2(rows[i].amount),
                          textAlign: TextAlign.right,
                          style: AppType.moneyS.s(12).c(p.ink)),
                    ),
                  ] else ...[
                    Expanded(
                      flex: 2,
                      child: Text(rows[i].state.label,
                          style: AppType.labelS.s(10.5).c(p.inkMuted)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(_mechanic(rows[i].mechanicId),
                          style: AppType.labelS.s(10.5).c(p.inkMuted)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        rows[i].remark.isEmpty ? '—' : rows[i].remark,
                        style: AppType.bodyS.s(11).c(p.inkFaint),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _Totals extends StatelessWidget {
  const _Totals({required this.kind, required this.card});

  final DocKind kind;
  final JobCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final invoice = kind == DocKind.invoice;
    return Container(
      color: p.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
      child: Column(
        children: [
          _Line(label: 'Sub total', value: Fmt.money2(card.subTotal)),
          if (card.discount > 0)
            _Line(
              label: 'Discount',
              value: '- ${Fmt.money2(card.discount)}',
              color: p.success,
            ),
          if (card.taxRate > 0)
            _Line(
              label: 'GST ${(card.taxRate * 100).toStringAsFixed(0)}%',
              value: Fmt.money2(card.taxAmount),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: Divider(height: 1, color: p.line),
          ),
          _Line(
            label: invoice ? 'Payable' : 'Estimated total',
            value: Fmt.money2(card.total),
            emphasize: true,
          ),
          if (invoice) ...[
            _Line(label: 'Paid', value: Fmt.money2(card.paid)),
            _Line(
              label: 'Balance',
              value: Fmt.money2(card.balance),
              emphasize: true,
              color: card.settled ? p.success : p.danger,
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          const Spacer(),
          Text(
            label,
            style: emphasize
                ? AppType.labelL.c(color ?? p.ink)
                : AppType.bodyS.c(p.inkMuted),
          ),
          const SizedBox(width: Gap.lg),
          SizedBox(
            width: 92,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: emphasize
                  ? AppType.money.s(15).c(color ?? p.ink)
                  : AppType.moneyS.c(color ?? p.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// The copy that goes to the floor ends with somewhere to sign off the work.
class _MechanicFooter extends StatelessWidget {
  const _MechanicFooter({required this.card});

  final JobCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final done = card.items.where((e) => e.state == WorkState.done).length;
    return Container(
      color: p.surfaceAlt,
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Icon(Icons.checklist_rounded, size: 16, color: p.inkMuted),
          const SizedBox(width: Gap.sm),
          Text('$done of ${card.items.length} complete',
              style: AppType.labelM.c(p.inkSoft)),
          const Spacer(),
          Text('No pricing on this copy',
              style: AppType.labelS.s(10.5).c(p.inkFaint)),
        ],
      ),
    );
  }
}

class _AmountInWords extends StatelessWidget {
  const _AmountInWords({required this.card});

  final JobCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg, vertical: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AMOUNT IN WORDS', style: AppType.over.s(9.5).c(p.inkFaint)),
          const SizedBox(height: 2),
          Text(Words.rupees(card.total),
              style: AppType.labelM.c(p.inkSoft)),
        ],
      ),
    );
  }
}

class _DocFooter extends StatelessWidget {
  const _DocFooter({
    required this.kind,
    required this.card,
    required this.garage,
  });

  final DocKind kind;
  final JobCard card;
  final Garage garage;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final terms = garage.terms
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (card.nextServiceAt != null) ...[
          Container(
            color: p.infoSoft,
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg, vertical: Gap.sm),
            child: Text(
              'Next service due on ${Fmt.date(card.nextServiceAt!)}'
              '${card.nextServiceKm == null ? '' : ' or at ${Fmt.km(card.nextServiceKm!)}'}'
              ', whichever is earlier.',
              textAlign: TextAlign.center,
              style: AppType.labelS.s(11).c(p.info),
            ),
          ),
        ],
        if (kind != DocKind.mechanicCopy && terms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TERMS', style: AppType.over.s(9.5).c(p.inkFaint)),
                const SizedBox(height: 3),
                for (final t in terms)
                  Text('• $t',
                      style: AppType.bodyS.s(11).c(p.inkFaint)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.lg),
          child: Row(
            children: [
              Expanded(
                child: _SignSlot(
                  label: kind == DocKind.mechanicCopy
                      ? 'Mechanic signature'
                      : 'Customer signature',
                ),
              ),
              const SizedBox(width: Gap.xl),
              const Expanded(
                child: _SignSlot(label: 'Authorised signature'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignSlot extends StatelessWidget {
  const _SignSlot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Container(height: 1, color: p.line),
        const SizedBox(height: 5),
        Text(label, style: AppType.labelS.s(10).c(p.inkFaint)),
      ],
    );
  }
}
