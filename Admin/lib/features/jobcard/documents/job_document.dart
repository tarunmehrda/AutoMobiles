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
import '../../../data/models/books.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import 'doc_sections.dart';
import 'doc_text.dart';
import 'invoice_format.dart';

/// The printable face of a job card.
///
/// All three documents are the same sheet with different rules about what is
/// on it: the estimate and the invoice carry money, the floor copies carry
/// the complaint next to the list of work — and deliberately no prices at
/// all. The floor copy comes two ways on one [DocKind]: the mechanic's, and
/// the job card copy handed to the customer at check-in ([jobCardCopy]).
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
    this.jobCardCopy = false,
    this.banks = const [],
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

  /// The customer's copy of the floor document rather than the mechanic's.
  /// Only means anything on [DocKind.mechanicCopy].
  final bool jobCardCopy;

  /// The workshop's bank accounts, primary first. The ones marked to print
  /// go at the foot of a bill, and one marked for a UPI QR is what the
  /// scan-to-pay code pays into.
  final List<BankAccount> banks;

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
    final copy = jobCardCopy && kind == DocKind.mechanicCopy;
    final on = DocSectionX.carryOver(
      sections ?? DocSectionX.defaultsFor(format, kind, jobCardCopy: copy),
      format,
      kind,
    );
    final floor = kind == DocKind.mechanicCopy;
    final v = vehicle;

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
        jobCardCopy: copy,
        banks: banks,
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
          _Letterhead(
            kind: kind,
            card: card,
            garage: garage,
            format: format,
            jobCardCopy: copy,
          ),
          if (floor) ...[
            _VehicleDetails(
              card: card,
              customer: copy ? customer : null,
              vehicle: vehicle,
              mechanics: _staffNames(card.mechanicIds),
              on: on,
              promised: copy,
            ),
            _VoiceAndWork(card: card, on: on),
            // The voice already sits beside the work; what is left of the
            // pair is the accessories, when they are ticked on.
            _VoiceAndAccessories(
              card: card,
              on: on.difference(const {DocSection.voices}),
            ),
          ] else ...[
            _Parties(
              kind: kind,
              card: card,
              customer: customer,
              vehicle: vehicle,
              mechanics: _staffNames(card.mechanicIds),
              on: on,
            ),
            if (v != null && v.insured) _Insurance(vehicle: v),
            _VoiceAndAccessories(card: card, on: on),
            _Particulars(card: card),
          ],
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
          _LedgerBlocks(
            card: card,
            garage: garage,
            kind: kind,
            on: on,
            banks: banks,
          ),
          if (kind.showsPricing && invoiceBanks(banks).isNotEmpty)
            _BankDetails(banks: invoiceBanks(banks)),
          _DocFooter(kind: kind, card: card, garage: garage, jobCardCopy: copy),
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
    this.jobCardCopy = false,
  });

  final DocKind kind;
  final JobCard card;
  final Garage garage;
  final InvoiceFormat format;
  final bool jobCardCopy;

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
                docTitle(kind, format, jobCardCopy: jobCardCopy),
                textAlign: TextAlign.end,
                style: AppType.h2.c(p.ink),
              ),
              const SizedBox(height: 4),
              // The floor reads a job by its number, so the copies that go
              // there say "Job" where the bills say "Number".
              _MetaRow(
                label: kind == DocKind.mechanicCopy ? 'Job'.tr : 'Number'.tr,
                value: card.number,
              ),
              _MetaRow(label: 'Date'.tr, value: Fmt.date(card.createdAt)),
              if (kind != DocKind.mechanicCopy)
                _MetaRow(label: 'Time'.tr, value: Fmt.time(card.createdAt)),
              if (kind != DocKind.mechanicCopy && card.completedAt != null)
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
                      if ((customer?.email ?? '').trim().isNotEmpty)
                        Text(
                          customer!.email.trim(),
                          style: AppType.bodyS.s(11).c(p.inkMuted),
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
                    if (v != null)
                      Text(vehicleMake(v), style: AppType.bodyS.c(p.inkSoft)),
                    if (v != null)
                      Text(
                        _fuelAndGearbox(v),
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
                    // A promise of delivery belongs on the quote; on the
                    // invoice the vehicle has already gone out.
                    if (kind == DocKind.estimate && card.promisedAt != null)
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

/// The vehicle as the floor needs it: which one, what it is, what it burns
/// and how full, how far it has run.
///
/// The floor copies have no "bill to" — nobody on the floor bills anyone —
/// so the block is the vehicle alone. The job card copy, which goes to the
/// customer, also names them and says when the vehicle was promised back.
class _VehicleDetails extends StatelessWidget {
  const _VehicleDetails({
    required this.card,
    required this.customer,
    required this.vehicle,
    required this.mechanics,
    required this.on,
    required this.promised,
  });

  final JobCard card;
  final Customer? customer;
  final Vehicle? vehicle;
  final String mechanics;
  final Set<DocSection> on;
  final bool promised;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final v = vehicle;
    final c = customer;
    final odo = on.contains(DocSection.odometer);
    final rows = <(String, String)>[
      ('Reg No'.tr, Fmt.plate(v?.regNo ?? '—')),
      if (v != null && vehicleMake(v).isNotEmpty) ('Make'.tr, vehicleMake(v)),
      if (v != null)
        (
          'Fuel'.tr,
          odo
              ? '${_fuelAndGearbox(v)}  •  ${card.fuelPercent}%'
              : _fuelAndGearbox(v),
        ),
      if (odo) ('KM'.tr, Fmt.km(card.odometerKm)),
      if (c != null)
        (
          'Customer'.tr,
          [c.name, c.phone].where((e) => e.trim().isNotEmpty).join('  •  '),
        ),
      if (on.contains(DocSection.mechanics) && mechanics.isNotEmpty)
        ('Assigned'.tr, mechanics),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BandHeader(left: 'Vehicle details'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in rows)
                _KeyLine(label: label, value: value),
              if (promised && card.promisedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Promised delivery: {0}'.trf([
                      Fmt.fullDateTime(card.promisedAt!),
                    ]),
                    style: AppType.labelS.s(10.5).c(p.warning),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `Label   value` with the label in a fixed gutter, so a column of them
/// lines up the way a printed form does.
class _KeyLine extends StatelessWidget {
  const _KeyLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: AppType.labelS.s(10.5).c(p.inkFaint)),
          ),
          Expanded(child: Text(value, style: AppType.bodyS.s(12).c(p.inkSoft))),
        ],
      ),
    );
  }
}

/// The policy a claim invoice is billed against.
///
/// Its own block rather than a line under the vehicle: the surveyor reads
/// the policy dates and the insurer's GSTIN off it, and a single wrapped line
/// of six facts is not something anybody can read off.
class _Insurance extends StatelessWidget {
  const _Insurance({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final rows = insuranceRows(vehicle);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BandHeader(left: 'Insurance'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in rows)
                _KeyLine(label: label, value: value),
            ],
          ),
        ),
      ],
    );
  }
}

/// The floor copy's middle: what the customer said on the left, what is to
/// be done about it on the right.
///
/// Read side by side because that is how the mechanic uses it — "engine
/// noise" across from "engine mounting × 1". Names and quantities only: the
/// floor copy carries no prices, by design.
class _VoiceAndWork extends StatelessWidget {
  const _VoiceAndWork({required this.card, required this.on});

  final JobCard card;
  final Set<DocSection> on;

  @override
  Widget build(BuildContext context) {
    final voices = on.contains(DocSection.voices);
    final work = [for (final e in card.items) floorLine(e)];
    return Column(
      children: [
        _BandHeader(
          left: voices ? 'Customer voice' : 'Spare parts / jobs',
          right: voices ? 'Spare parts / jobs' : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (voices) ...[
                Expanded(
                  child: _NumberedList(
                    items: card.voices,
                    empty: 'Nothing noted',
                    bullets: true,
                  ),
                ),
                const SizedBox(width: Gap.md),
              ],
              Expanded(
                child: _NumberedList(
                  items: work,
                  empty: 'No work listed yet',
                  bullets: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where to send the money by bank transfer, for every account the shop has
/// marked to print. Primary first, the order the books keep them in.
class _BankDetails extends StatelessWidget {
  const _BankDetails({required this.banks});

  final List<BankAccount> banks;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BandHeader(left: 'Bank details'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final b in banks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'Bank Details: {0}'.trf([bankLine(b)]),
                    style: AppType.bodyS.s(11.5).c(p.inkSoft),
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
    this.banks = const [],
  });

  final JobCard card;
  final Garage garage;
  final DocKind kind;
  final Set<DocSection> on;
  final List<BankAccount> banks;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final target = payTarget(garage, banks);
    final payments = on.contains(DocSection.payments)
        ? card.payments
        : const <Payment>[];
    final sms = on.contains(DocSection.sms) ? card.sms : const <SmsEvent>[];
    final pay =
        on.contains(DocSection.paymentQr) &&
        kind.showsPricing &&
        target.upiId.isNotEmpty;

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
                        upiId: target.upiId,
                        payee: target.payee,
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
                        target.upiId,
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
  const _NumberedList({
    required this.items,
    required this.empty,
    this.bullets = false,
  });

  final List<String> items;
  final String empty;

  /// A bullet rather than a number — for the floor copy's two columns, where
  /// the numbers on one side would read as matching the other.
  final bool bullets;

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
                    bullets ? '•' : '${i + 1}',
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

/// The line table on the bills: `# | Particulars | GST | Qty | Rate | Amount`.
///
/// The GST column is per line because lines are taxed per line now — a
/// battery at 28% and the labour at 18% on one card. The floor copies do not
/// use this table at all: they list the work beside the complaint, unpriced.
class _Particulars extends StatelessWidget {
  const _Particulars({required this.card});

  final JobCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final rows = card.items;
    final head = AppType.over.s(10).c(p.accentInk);
    final cell = AppType.moneyS.s(11).c(p.inkSoft);

    // Flex rather than fixed widths so the six columns share a 360dp phone
    // without any of them running past the edge; a long figure wraps.
    Widget col(int flex, String text, TextStyle style, {bool end = true}) =>
        Expanded(
          flex: flex,
          child: Text(
            text,
            textAlign: end ? TextAlign.right : TextAlign.left,
            style: style,
          ),
        );

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
              SizedBox(width: 18, child: Text('#', style: head)),
              col(8, 'PARTICULARS', head, end: false),
              col(3, 'GST', head),
              col(3, 'QTY', head),
              col(5, 'RATE', head),
              col(5, 'AMOUNT', head),
            ],
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xl),
            child: Text(
              'Nothing billed on this card yet'.tr,
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
                    flex: 8,
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
                  col(3, lineGst(rows[i], card), cell),
                  col(3, qtyWithUnit(rows[i]), cell),
                  col(5, Fmt.money2(rows[i].rate), cell),
                  col(5, Fmt.money2(rows[i].amount), cell.c(p.ink)),
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
          // The tax is the sum of each line at its own rate (see
          // `JobCard.taxAmount`), so a card with no rate of its own can still
          // carry tax from a line that has one.
          if (taxed && card.taxAmount > 0) ...[
            _Line(label: 'Taxable value'.tr, value: Fmt.money2(card.taxable)),
            _Line(label: 'CGST', value: Fmt.money2(half)),
            _Line(label: 'SGST', value: Fmt.money2(half)),
          ] else if (card.taxAmount > 0)
            _Line(label: taxLabel(card), value: Fmt.money2(card.taxAmount)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: Divider(height: 1, color: p.line),
          ),
          _Line(
            label: invoice ? 'Total'.tr : 'Estimated total'.tr,
            value: Fmt.money2(card.total),
            emphasize: true,
          ),
          // The advance taken at check-in is shown apart from what was paid
          // at delivery, so the customer can see both the money they left
          // and what was left to pay after it.
          if (invoice) ...[
            _Line(label: 'Advance'.tr, value: Fmt.money2(card.advancePaid)),
            _Line(
              label: 'Payable'.tr,
              value: Fmt.money2(payableAfterAdvance(card)),
            ),
            _Line(
              label: 'Paid'.tr,
              value: Fmt.money2(paidExcludingAdvance(card)),
            ),
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
    this.jobCardCopy = false,
  });

  final DocKind kind;
  final JobCard card;
  final Garage garage;
  final bool jobCardCopy;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    // Only the mechanic's own copy is signed by the mechanic; the job card
    // copy is the customer's, and they sign it for the vehicle they left.
    final mechanic = kind == DocKind.mechanicCopy && !jobCardCopy;
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
        if (!mechanic && terms.isNotEmpty)
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
                  label: mechanic
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
    this.jobCardCopy = false,
    this.banks = const [],
  });

  final DocKind kind;
  final JobCard card;
  final Garage garage;
  final Customer? customer;
  final Vehicle? vehicle;
  final String mechanics;
  final InvoiceFormat format;
  final Set<DocSection> on;
  final bool jobCardCopy;
  final List<BankAccount> banks;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tight = format == InvoiceFormat.thermal58;
    final priced = kind.showsPricing;
    final size = tight ? 10.0 : 11.0;
    final target = payTarget(garage, banks);
    final printBanks = priced ? invoiceBanks(banks) : const <BankAccount>[];
    final v = vehicle;
    // Same rule as the A4 sheet: the quote and the customer's job card copy
    // say when the vehicle is promised back; the invoice and the mechanic's
    // copy do not.
    final promise = kind == DocKind.estimate || jobCardCopy;

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
            mid(
              docTitle(kind, format, jobCardCopy: jobCardCopy).toUpperCase(),
              bold: true,
            ),
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
            if (v != null) ...[
              pair('Vehicle', Fmt.plate(v.regNo)),
              if (vehicleMake(v).isNotEmpty) lead(vehicleMake(v)),
              pair('', _fuelAndGearbox(v)),
              if (priced)
                for (final (label, value) in insuranceRows(v))
                  lead('$label: $value'),
            ],
            if (on.contains(DocSection.odometer)) ...[
              pair('Km', Fmt.km(card.odometerKm)),
              pair('Fuel', '${card.fuelPercent}%'),
            ],
            if (on.contains(DocSection.mechanics) && mechanics.isNotEmpty)
              pair('Attended by', mechanics),
            if (promise && card.promisedAt != null)
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
                    '  ${qtyWithUnit(item)} × ${Fmt.money2(item.rate)} · GST ${lineGst(item, card)}',
                    Fmt.money2(item.amount),
                  )
                else
                  lead('  × ${qtyWithUnit(item)}'),
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
              if (kind == DocKind.invoice) ...[
                pair('Advance', Fmt.money2(card.advancePaid)),
                pair('Payable', Fmt.money2(payableAfterAdvance(card))),
                pair('Paid', Fmt.money2(paidExcludingAdvance(card))),
                pair('Balance', Fmt.money2(card.balance), bold: true),
              ],
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
                target.upiId.isNotEmpty) ...[
              rule(),
              mid('SCAN TO PAY ${Fmt.money2(card.balance)}', bold: true),
              const SizedBox(height: Gap.sm),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(Gap.xs),
                  color: Colors.white,
                  child: QrImageView(
                    data: upiIntent(
                      upiId: target.upiId,
                      payee: target.payee,
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
              mid(target.upiId),
            ],
            if (printBanks.isNotEmpty) ...[
              rule(),
              lead('BANK DETAILS', bold: true),
              for (final b in printBanks) lead(bankLine(b)),
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
