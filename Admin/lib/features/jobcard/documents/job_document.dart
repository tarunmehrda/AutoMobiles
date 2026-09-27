import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/upi_intent.dart';
import '../../../core/utils/words.dart';
import '../../../core/widgets/local_image.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import 'doc_sections.dart';
import 'invoice_format.dart';

/// The printable face of a job card.
///
/// All three documents are the same sheet with different rules about what is
/// on it: the estimate and the invoice carry money, the mechanic copy carries
/// the complaint, the accessories and a column for the floor to write in —
/// and deliberately no prices at all.
///
/// On top of that, [format] picks one of the five templates and [sections]
/// says which optional blocks ride along. This widget and [JobPdf] are read
/// off the same two inputs on purpose: what the counter sees here is what
/// comes out of the printer, so the preview is worth looking at.
class JobDocument extends StatelessWidget {
  const JobDocument({
    super.key,
    required this.kind,
    required this.card,
    required this.garage,
    required this.customer,
    required this.vehicle,
    required this.staff,
    this.format = InvoiceFormat.simpleA4,
    this.sections,
  });

  final DocKind kind;
  final JobCard card;
  final Garage garage;
  final Customer? customer;
  final Vehicle? vehicle;
  final List<Staff> staff;

  /// Which of the five templates this is a preview of.
  final InvoiceFormat format;

  /// The optional blocks, or null for whatever the template starts with.
  final Set<DocSection>? sections;

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
    final on = DocSectionX.carryOver(
      sections ?? DocSectionX.defaultsFor(format, kind),
      format,
      kind,
    );

    if (format.isThermal) {
      return _RollDocument(
        kind: kind,
        card: card,
        garage: garage,
        customer: customer,
        vehicle: vehicle,
        mechanics: _staffNames(card.mechanicIds),
        format: format,
        on: on,
      );
    }

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
          _Letterhead(kind: kind, card: card, garage: garage, format: format),
          _Parties(
            kind: kind,
            card: card,
            customer: customer,
            vehicle: vehicle,
            mechanics: _staffNames(card.mechanicIds),
            on: on,
          ),
          _VoiceAndAccessories(card: card, on: on),
          _Particulars(kind: kind, card: card, staff: staff),
          if (kind.showsPricing)
            _Totals(
              kind: kind,
              card: card,
              taxed: format == InvoiceFormat.taxA4,
            )
          else
            _MechanicFooter(card: card),
          if (kind.showsPricing) _AmountInWords(card: card),
          _Handover(card: card, on: on),
          if (on.contains(DocSection.photos) && card.photos.isNotEmpty)
            _PhotoWall(card: card),
          _LedgerBlocks(card: card, garage: garage, kind: kind, on: on),
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
    required this.format,
  });

  final DocKind kind;
  final JobCard card;
  final Garage garage;
  final InvoiceFormat format;

  /// The tax template says TAX INVOICE on it because that is the wording the
  /// rule asks for; the detailed one is a job card whatever tab it was
  /// opened from. The rest are named after the document.
  String get _title => switch (format) {
    InvoiceFormat.taxA4 => 'Tax Invoice',
    InvoiceFormat.detailedA4 => 'Job Card',
    _ => kind.label,
  };

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
                Text(
                  garage.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.h2.c(p.accentInk),
                ),
                const SizedBox(height: 2),
                Text(garage.phone, style: AppType.bodyS.c(p.inkMuted)),
                if (garage.postal.isNotEmpty)
                  Text(
                    garage.postal,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodyS.s(11).c(p.inkFaint),
                  ),
                if (garage.gstin.isNotEmpty)
                  Text(
                    'GSTIN {0}'.trf([garage.gstin]),
                    style: AppType.bodyS.s(11).c(p.inkFaint),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _title,
                textAlign: TextAlign.end,
                style: AppType.h2.c(p.ink),
              ),
              const SizedBox(height: 4),
              _MetaRow(label: 'Number'.tr, value: card.number),
              _MetaRow(label: 'Date'.tr, value: Fmt.date(card.createdAt)),
              _MetaRow(label: 'Time'.tr, value: Fmt.time(card.createdAt)),
              if (card.completedAt != null)
                _MetaRow(
                  label: 'Completed'.tr,
                  value: Fmt.date(card.completedAt!),
                ),
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
    required this.on,
  });

  final DocKind kind;
  final JobCard card;
  final Customer? customer;
  final Vehicle? vehicle;
  final String mechanics;
  final Set<DocSection> on;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final billTo = kind != DocKind.mechanicCopy;
    // Locals so the null checks below promote: public fields do not.
    final gstin = (customer?.gstin ?? '').trim();
    final v = vehicle;
    final insurance = v == null ? '' : _insurance(v);

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
                      Text(
                        customer?.name ?? '—',
                        style: AppType.labelL.c(p.ink),
                      ),
                      Text(
                        customer?.phone ?? '',
                        style: AppType.bodyS.c(p.inkMuted),
                      ),
                      if ((customer?.address ?? '').isNotEmpty)
                        Text(
                          customer!.address,
                          style: AppType.bodyS.s(11).c(p.inkFaint),
                        ),
                      // The buyer's GSTIN is what lets a business customer
                      // claim input tax on this bill, so it is on the
                      // preview wherever it will be on the PDF.
                      if (gstin.isNotEmpty)
                        Text(
                          'GSTIN {0}'.trf([gstin]),
                          style: AppType.labelS.s(11).c(p.inkSoft),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Veh. No: ${Fmt.plate(vehicle?.regNo ?? '—')}',
                      style: AppType.labelM.c(p.ink),
                    ),
                    Text(
                      vehicle?.title ?? '',
                      style: AppType.bodyS.c(p.inkSoft),
                    ),
                    if (v != null)
                      Text(
                        _fuelAndGearbox(v),
                        style: AppType.bodyS.s(11).c(p.inkMuted),
                      ),
                    if (insurance.isNotEmpty)
                      Text(
                        insurance,
                        style: AppType.bodyS.s(11).c(p.inkMuted),
                      ),
                    const SizedBox(height: 2),
                    if (on.contains(DocSection.odometer))
                      Text(
                        'Km read: {0}  •  Fuel: {1}%'.trf([
                          Fmt.km(card.odometerKm),
                          card.fuelPercent,
                        ]),
                        style: AppType.bodyS.s(11).c(p.inkMuted),
                      ),
                    if (on.contains(DocSection.mechanics) &&
                        mechanics.isNotEmpty)
                      Text(
                        'Assigned: {0}'.trf([mechanics]),
                        style: AppType.bodyS.s(11).c(p.inkMuted),
                      ),
                    if (card.promisedAt != null)
                      Text(
                        'Ready by: {0}'.trf([
                          Fmt.fullDateTime(card.promisedAt!),
                        ]),
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

/// `Petrol · Manual` — what the vehicle burns and how it changes gear.
///
/// The gearbox rides next to the fuel because the two together are what the
/// floor needs before it quotes: an automatic takes a different fluid and a
/// different service. It is left off when nobody recorded it rather than
/// guessed — most vehicles predate the question, and every two-wheeler. The
/// same string as `JobPdf._fuelAndGearbox`, so the preview and the paper say
/// the same thing, and the same order as the vehicle header in the app.
String _fuelAndGearbox(Vehicle vehicle) => [
  vehicle.fuel.label,
  if (vehicle.transmission != null) vehicle.transmission!.label,
].join(' · ');

/// `Insurance: ICICI Lombard · Policy 3001/1234`, or empty when neither was
/// taken down.
///
/// An insurance claim job is filed against these two and the surveyor reads
/// them off the job card, so they are on the document as soon as the counter
/// has them. Either half prints on its own — a policy number with no insurer
/// is still what a claim is looked up by. Mirrors `JobPdf._insurance`.
String _insurance(Vehicle vehicle) {
  final parts = [
    vehicle.insurer.trim(),
    if (vehicle.policyNo.trim().isNotEmpty)
      'Policy {0}'.trf([vehicle.policyNo.trim()]),
  ].where((e) => e.isNotEmpty);
  return parts.isEmpty ? '' : 'Insurance: {0}'.trf([parts.join(' · ')]);
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
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left.toUpperCase(),
              style: AppType.over.s(10).c(p.accentInk),
            ),
          ),
          if (right != null)
            Expanded(
              child: Text(
                right!.toUpperCase(),
                style: AppType.over.s(10).c(p.accentInk),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The complaint on the left, what came in with the vehicle on the right.
///
/// Both blocks are optional now, and either one can be on without the other,
/// so the row collapses to a single column rather than printing a "Nothing
/// noted" placeholder for a block the counter deliberately left off.
class _VoiceAndAccessories extends StatelessWidget {
  const _VoiceAndAccessories({required this.card, required this.on});

  final JobCard card;
  final Set<DocSection> on;

  @override
  Widget build(BuildContext context) {
    final voices = on.contains(DocSection.voices)
        ? card.voices
        : const <String>[];
    final kit = on.contains(DocSection.accessories)
        ? card.accessories
        : const <String>[];
    if (voices.isEmpty && kit.isEmpty) return const SizedBox.shrink();

    final both = voices.isNotEmpty && kit.isNotEmpty;
    return Column(
      children: [
        _BandHeader(
          left: voices.isNotEmpty ? 'Customer voice' : 'Accessories',
          right: both ? 'Accessories' : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _NumberedList(
                  items: voices.isNotEmpty ? voices : kit,
                  empty: 'Nothing noted',
                ),
              ),
              if (both) ...[
                const SizedBox(width: Gap.md),
                Expanded(
                  child: _NumberedList(items: kit, empty: '—'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// What the vehicle came in looking like, and the counter's own note.
class _Handover extends StatelessWidget {
  const _Handover({required this.card, required this.on});

  final JobCard card;
  final Set<DocSection> on;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final dents = on.contains(DocSection.dents)
        ? card.dents
        : const <DentMark>[];
    final note = on.contains(DocSection.workNote) ? card.workNote.trim() : '';
    if (dents.isEmpty && note.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dents.isNotEmpty) ...[
          const _BandHeader(left: 'Damage noted at handover'),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
            child: _NumberedList(
              items: [
                for (final d in dents)
                  [
                    d.severity.label,
                    'on ${d.where}',
                    if (d.note.isNotEmpty) '— ${d.note}',
                  ].join(' '),
              ],
              empty: 'None',
            ),
          ),
        ],
        if (note.isNotEmpty) ...[
          const _BandHeader(left: 'Work note'),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(note, style: AppType.bodyS.c(p.inkSoft)),
            ),
          ),
        ],
      ],
    );
  }
}

/// `fourWheeler.side` reads as `side view` on the sheet.
/// The handover photographs, the same six the PDF carries.
class _PhotoWall extends StatelessWidget {
  const _PhotoWall({required this.card});

  final JobCard card;

  /// Two rows of three, which is what fits on a page.
  static const _max = 6;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final shown = card.photos.take(_max).toList();
    final left = card.photos.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BandHeader(left: 'Photographs at handover'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final path in shown)
                    ClipRRect(
                      borderRadius: R.all(R.sm),
                      child: Container(
                        height: 74,
                        width: 104,
                        color: p.surfaceSunken,
                        child: localImage(
                          path,
                          height: 74,
                          width: 104,
                          fallback: () => Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 18,
                              color: p.inkFaint,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (left > 0) ...[
                const SizedBox(height: Gap.sm),
                Text(
                  '{0} more on this job card in the app.'.trf([left]),
                  style: AppType.bodyS.s(10.5).c(p.inkFaint),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Money in, messages out, and the code for whatever is still owed.
class _LedgerBlocks extends StatelessWidget {
  const _LedgerBlocks({
    required this.card,
    required this.garage,
    required this.kind,
    required this.on,
  });

  final JobCard card;
  final Garage garage;
  final DocKind kind;
  final Set<DocSection> on;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final payments = on.contains(DocSection.payments)
        ? card.payments
        : const <Payment>[];
    final sms = on.contains(DocSection.sms) ? card.sms : const <SmsEvent>[];
    final pay =
        on.contains(DocSection.paymentQr) &&
        kind.showsPricing &&
        garage.upiId.trim().isNotEmpty;

    if (payments.isEmpty && sms.isEmpty && !pay) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (payments.isNotEmpty) ...[
          const _BandHeader(left: 'Transactions'),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
            child: Column(
              children: [
                for (final e in payments)
                  _FactRow(
                    left:
                        "${Fmt.dateTime(e.at)}  •  ${e.mode.label}${e.note.isEmpty ? '' : '  •  ${e.note}'}",
                    right: Fmt.money2(e.amount),
                  ),
                _FactRow(
                  left: 'Total paid',
                  right: Fmt.money2(card.paid),
                  strong: true,
                ),
              ],
            ),
          ),
        ],
        if (sms.isNotEmpty) ...[
          const _BandHeader(left: 'SMS detail'),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
            child: Column(
              children: [
                for (final e in sms)
                  _FactRow(
                    left: '${e.label}  •  ${Fmt.dateTime(e.at)}',
                    right: e.state.label,
                  ),
              ],
            ),
          ),
        ],
        if (pay) ...[
          _BandHeader(left: card.balance > 0 ? 'Scan to pay' : 'Paid in full'),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
            child: Row(
              children: [
                if (card.balance > 0)
                  Container(
                    padding: const EdgeInsets.all(Gap.sm),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: R.all(R.sm),
                      border: Border.all(color: p.line),
                    ),
                    child: QrImageView(
                      data: upiIntent(
                        upiId: garage.upiId,
                        payee: garage.name,
                        amount: card.balance,
                        note: 'Job card {0}'.trf([card.number]),
                      ),
                      size: 74,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0D1117),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0D1117),
                      ),
                    ),
                  ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.balance > 0
                            ? '{0} due'.trf([Fmt.money2(card.balance)])
                            : 'Nothing due on this card'.tr,
                        style: AppType.labelL.c(
                          card.balance > 0 ? p.ink : p.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        garage.upiId,
                        style: AppType.bodyS.s(11).c(p.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A fact on the left and its figure on the right — the shape every row in
/// the ledger blocks takes.
class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.left,
    required this.right,
    this.strong = false,
  });

  final String left;
  final String right;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              left,
              style: strong
                  ? AppType.labelM.s(11.5).c(p.ink)
                  : AppType.bodyS.s(11.5).c(p.inkSoft),
            ),
          ),
          const SizedBox(width: Gap.md),
          Text(
            right,
            style: strong
                ? AppType.moneyS.s(12).c(p.ink)
                : AppType.moneyS.s(11.5).c(p.inkSoft),
          ),
        ],
      ),
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
                  child: Text(
                    '${i + 1}',
                    style: AppType.labelS.s(10.5).c(p.inkFaint),
                  ),
                ),
                Expanded(
                  child: Text(
                    items[i],
                    style: AppType.bodyS.s(12).c(p.inkSoft),
                  ),
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
            horizontal: Gap.lg,
            vertical: Gap.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: Text('#', style: AppType.over.s(10).c(p.accentInk)),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'PARTICULARS',
                  style: AppType.over.s(10).c(p.accentInk),
                ),
              ),
              if (priced) ...[
                Expanded(
                  child: Text(
                    'QTY',
                    textAlign: TextAlign.right,
                    style: AppType.over.s(10).c(p.accentInk),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'RATE',
                    textAlign: TextAlign.right,
                    style: AppType.over.s(10).c(p.accentInk),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'AMOUNT',
                    textAlign: TextAlign.right,
                    style: AppType.over.s(10).c(p.accentInk),
                  ),
                ),
              ] else ...[
                Expanded(
                  flex: 2,
                  child: Text(
                    'STATUS',
                    style: AppType.over.s(10).c(p.accentInk),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'MECHANIC',
                    style: AppType.over.s(10).c(p.accentInk),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'REMARK',
                    style: AppType.over.s(10).c(p.accentInk),
                  ),
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
                  ? 'Nothing billed on this card yet'.tr
                  : 'No work listed yet'.tr,
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
                        : p.lineSoft,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${i + 1}',
                      style: AppType.moneyS.s(11).c(p.inkFaint),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].name,
                          style: AppType.bodyS.s(12.5).c(p.ink),
                        ),
                        if (rows[i].partNo.isNotEmpty)
                          Text(
                            rows[i].partNo,
                            style: AppType.labelS.s(9.5).c(p.inkFaint),
                          ),
                      ],
                    ),
                  ),
                  if (priced) ...[
                    Expanded(
                      child: Text(
                        rows[i].qtyLabel,
                        textAlign: TextAlign.right,
                        style: AppType.moneyS.s(11.5).c(p.inkSoft),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        Fmt.money2(rows[i].rate),
                        textAlign: TextAlign.right,
                        style: AppType.moneyS.s(11.5).c(p.inkSoft),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        Fmt.money2(rows[i].amount),
                        textAlign: TextAlign.right,
                        style: AppType.moneyS.s(12).c(p.ink),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      flex: 2,
                      child: Text(
                        rows[i].state.label,
                        style: AppType.labelS.s(10.5).c(p.inkMuted),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _mechanic(rows[i].mechanicId),
                        style: AppType.labelS.s(10.5).c(p.inkMuted),
                      ),
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
  const _Totals({required this.kind, required this.card, this.taxed = false});

  final DocKind kind;
  final JobCard card;

  /// The GST template splits the tax the way a compliant invoice has to:
  /// taxable value, then CGST and SGST as separate halves.
  final bool taxed;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final invoice = kind == DocKind.invoice;
    final half = card.taxAmount / 2;
    return Container(
      color: p.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
      child: Column(
        children: [
          _Line(label: 'Sub total'.tr, value: Fmt.money2(card.subTotal)),
          if (card.discount > 0)
            _Line(
              label: 'Discount'.tr,
              value: '- ${Fmt.money2(card.discount)}',
              color: p.success,
            ),
          if (taxed && card.taxRate > 0) ...[
            _Line(label: 'Taxable value'.tr, value: Fmt.money2(card.taxable)),
            _Line(label: 'CGST', value: Fmt.money2(half)),
            _Line(label: 'SGST', value: Fmt.money2(half)),
          ] else if (card.taxRate > 0)
            _Line(
              label: 'GST {0}%'.trf([(card.taxRate * 100).toStringAsFixed(0)]),
              value: Fmt.money2(card.taxAmount),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: Divider(height: 1, color: p.line),
          ),
          _Line(
            label: invoice ? 'Payable'.tr : 'Estimated total'.tr,
            value: Fmt.money2(card.total),
            emphasize: true,
          ),
          if (invoice) ...[
            _Line(label: 'Paid'.tr, value: Fmt.money2(card.paid)),
            _Line(
              label: 'Balance'.tr,
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
      // The label takes whatever the figure does not, right-aligned against
      // it. A Spacer here meant a long label pushed the row wider than the
      // document.
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: emphasize
                  ? AppType.labelL.c(color ?? p.ink)
                  : AppType.bodyS.c(p.inkMuted),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Icon(Icons.checklist_rounded, size: 16, color: p.inkMuted),
          const SizedBox(width: Gap.sm),
          // Both sides flex: a bill with forty lines on it and a wide
          // typeface pushed this row past the edge of the document, and the
          // count is the half worth keeping when there is not room for both.
          Expanded(
            child: Text(
              '{0} of {1} complete'.trf([done, card.items.length]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelM.c(p.inkSoft),
            ),
          ),
          const SizedBox(width: Gap.md),
          Text(
            'No pricing on this copy'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.labelS.s(10.5).c(p.inkFaint),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AMOUNT IN WORDS'.tr, style: AppType.over.s(9.5).c(p.inkFaint)),
          const SizedBox(height: 2),
          Text(Words.rupees(card.total), style: AppType.labelM.c(p.inkSoft)),
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
            padding: EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
            child: Text(
              "Next service due on ${Fmt.date(card.nextServiceAt!)}${card.nextServiceKm == null ? '' : ' or at ${Fmt.km(card.nextServiceKm!)}'}, whichever is earlier.",
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
                  Text('• $t', style: AppType.bodyS.s(11).c(p.inkFaint)),
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
                      ? 'Mechanic signature'.tr
                      : 'Customer signature'.tr,
                ),
              ),
              const SizedBox(width: Gap.xl),
              Expanded(child: _SignSlot(label: 'Authorised signature'.tr)),
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

// ---------------------------------------------------------------------------
// The thermal roll, on screen
// ---------------------------------------------------------------------------

/// What comes out of a 58 or 80mm counter printer.
///
/// A different document from the A4 sheet rather than a narrow version of it:
/// no tables, no rules, everything centred or in two columns, and the paper
/// as long as the bill needs. It mirrors `JobPdf._roll` block for block, so
/// the counter can see on screen that a 58mm bill is going to lose the QR
/// before they walk to the printer and find out.
class _RollDocument extends StatelessWidget {
  const _RollDocument({
    required this.kind,
    required this.card,
    required this.garage,
    required this.customer,
    required this.vehicle,
    required this.mechanics,
    required this.format,
    required this.on,
  });

  final DocKind kind;
  final JobCard card;
  final Garage garage;
  final Customer? customer;
  final Vehicle? vehicle;
  final String mechanics;
  final InvoiceFormat format;
  final Set<DocSection> on;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tight = format == InvoiceFormat.thermal58;
    final priced = kind.showsPricing;
    final size = tight ? 10.0 : 11.0;

    Widget mid(String t, {double? s, bool bold = false}) => Text(
      t,
      textAlign: TextAlign.center,
      style: bold
          ? AppType.labelM.s(s ?? size).c(p.ink)
          : AppType.bodyS.s(s ?? size).c(p.inkSoft),
    );

    Widget lead(String t, {bool bold = false}) => Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t,
        style: bold
            ? AppType.labelM.s(size).c(p.ink)
            : AppType.bodyS.s(size).c(p.inkSoft),
      ),
    );

    Widget pair(String l, String r, {bool bold = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              l,
              style: bold
                  ? AppType.labelM.s(size + 0.5).c(p.ink)
                  : AppType.bodyS.s(size).c(p.inkSoft),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Text(
            r,
            style: bold
                ? AppType.money.s(size + 1.5).c(p.ink)
                : AppType.moneyS.s(size).c(p.inkSoft),
          ),
        ],
      ),
    );

    Widget rule() => Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Container(height: 1, color: p.line),
    );

    return Center(
      child: Container(
        // Drawn to scale against each other: 58mm of paper is visibly
        // narrower than 80mm, and that difference is the whole reason a shop
        // owns one printer rather than the other.
        width: tight ? 208 : 272,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.symmetric(
          horizontal: tight ? Gap.md : Gap.lg,
          vertical: Gap.lg,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.sm),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mid(garage.name, s: tight ? 13 : 15, bold: true),
            if (garage.addressLine.isNotEmpty)
              mid(
                [
                  garage.addressLine,
                  garage.city,
                ].where((e) => e.isNotEmpty).join(', '),
              ),
            mid('Ph: ${garage.phone}'),
            if (garage.gstin.isNotEmpty) mid('GSTIN: ${garage.gstin}'),
            rule(),
            mid(kind.label.toUpperCase(), bold: true),
            rule(),
            pair('No.', card.number),
            pair('Date', Fmt.date(card.createdAt)),
            pair('Time', Fmt.time(card.createdAt)),
            if (customer != null) pair('Name', customer!.name),
            if (customer != null && customer!.phone.isNotEmpty)
              pair('Phone', customer!.phone),
            if (customer != null && customer!.gstin.trim().isNotEmpty)
              pair('GSTIN', customer!.gstin.trim()),
            // Block for block with JobPdf._roll: fuel and gearbox under the
            // plate with no label of their own, insurance on a line that can
            // wrap, because 58mm is narrower than an insurer and a policy.
            if (vehicle != null) ...[
              pair('Vehicle', Fmt.plate(vehicle!.regNo)),
              pair('', _fuelAndGearbox(vehicle!)),
              if (_insurance(vehicle!).isNotEmpty) lead(_insurance(vehicle!)),
            ],
            if (on.contains(DocSection.odometer)) ...[
              pair('Km', Fmt.km(card.odometerKm)),
              pair('Fuel', '${card.fuelPercent}%'),
            ],
            if (on.contains(DocSection.mechanics) && mechanics.isNotEmpty)
              pair('Attended by', mechanics),
            if (card.promisedAt != null)
              pair('Ready by', Fmt.dateTime(card.promisedAt!)),
            rule(),
            if (on.contains(DocSection.voices) && card.voices.isNotEmpty) ...[
              lead('CUSTOMER VOICE', bold: true),
              for (final v in card.voices) lead('• $v'),
              rule(),
            ],
            if (on.contains(DocSection.accessories) &&
                card.accessories.isNotEmpty) ...[
              lead('ACCESSORIES IN', bold: true),
              for (final a in card.accessories) lead('• $a'),
              rule(),
            ],
            if (on.contains(DocSection.dents) && card.dents.isNotEmpty) ...[
              lead('DAMAGE NOTED', bold: true),
              for (final d in card.dents)
                lead(
                  '• ${[d.severity.label, 'on ${d.where}', if (d.note.isNotEmpty) '— ${d.note}'].join(' ')}',
                ),
              rule(),
            ],
            if (on.contains(DocSection.workNote) &&
                card.workNote.trim().isNotEmpty) ...[
              lead('WORK NOTE', bold: true),
              for (final n in card.workNote.trim().split('\n')) lead(n),
              rule(),
            ],
            if (card.items.isEmpty)
              mid('Nothing billed yet.')
            else
              for (final item in card.items) ...[
                lead(item.name, bold: true),
                if (priced)
                  pair(
                    '  ${item.qtyLabel} × ${Fmt.money2(item.rate)}',
                    Fmt.money2(item.amount),
                  )
                else
                  lead('  ${item.state.label}'),
              ],
            if (priced) ...[
              rule(),
              pair('Sub total', Fmt.money2(card.subTotal)),
              if (card.discount > 0)
                pair('Discount', '− ${Fmt.money2(card.discount)}'),
              if (card.taxAmount > 0) ...[
                pair('CGST', Fmt.money2(card.taxAmount / 2)),
                pair('SGST', Fmt.money2(card.taxAmount / 2)),
              ],
              rule(),
              pair('TOTAL', Fmt.money2(card.total), bold: true),
              pair('Paid', Fmt.money2(card.paid)),
              pair('Balance', Fmt.money2(card.balance), bold: true),
              rule(),
              mid(Words.rupees(card.total)),
            ],
            if (on.contains(DocSection.payments) &&
                priced &&
                card.payments.isNotEmpty) ...[
              rule(),
              lead('TRANSACTIONS', bold: true),
              for (final e in card.payments)
                pair(
                  '${Fmt.dateShort(e.at)} ${e.mode.label}',
                  Fmt.money2(e.amount),
                ),
            ],
            if (on.contains(DocSection.sms) && card.sms.isNotEmpty) ...[
              rule(),
              lead('SMS DETAIL', bold: true),
              for (final e in card.sms)
                pair('${e.label} · ${Fmt.dateShort(e.at)}', e.state.label),
            ],
            if (on.contains(DocSection.paymentQr) &&
                priced &&
                card.balance > 0 &&
                garage.upiId.trim().isNotEmpty) ...[
              rule(),
              mid('SCAN TO PAY ${Fmt.money2(card.balance)}', bold: true),
              const SizedBox(height: Gap.sm),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(Gap.xs),
                  color: Colors.white,
                  child: QrImageView(
                    data: upiIntent(
                      upiId: garage.upiId,
                      payee: garage.name,
                      amount: card.balance,
                      note: 'Job card {0}'.trf([card.number]),
                    ),
                    size: tight ? 96 : 120,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0D1117),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0D1117),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              mid(garage.upiId),
            ],
            if (card.nextServiceAt != null) ...[
              rule(),
              mid('Next service: ${Fmt.date(card.nextServiceAt!)}'),
            ],
            rule(),
            mid('Thank you for choosing'),
            mid(garage.name, bold: true),
          ],
        ),
      ),
    );
  }
}
