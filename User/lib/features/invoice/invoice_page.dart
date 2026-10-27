import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/save_file.dart';
import '../../core/utils/words.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../data/models/workshop.dart';
import '../../state/providers.dart';
import 'invoice_money.dart';
import 'invoice_pdf.dart';

/// The workshop's invoice, as the workshop would print it. Read-only by
/// construction: every figure comes off the job card the counter raised, so
/// the customer and the workshop are always looking at the same document.
class InvoicePage extends ConsumerWidget {
  const InvoicePage({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final card = ref.watch(workshopCardProvider(cardId));
    final shop = ref.watch(workshopProvider);
    final user = ref.watch(userProvider);

    if (card == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Invoice'),
        body: const GEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Invoice not found',
          message: 'This job card is no longer on your account.',
        ),
      );
    }

    final money = BillBlock.of(card);
    final head = Letterhead.of(card, shop);
    final party = BillParty.of(card,
        name: user?.name ?? '', phone: user?.phone ?? '');
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(title: card.number, subtitle: money.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: R.all(R.md),
              border: Border.all(color: p.line),
              boxShadow: Shadows.soft(p),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  // "Tax Invoice" only when the workshop actually charged
                  // tax on this card.
                  child: Text(money.title, style: AppType.h1.c(p.info)),
                ),
                const SizedBox(height: Gap.md),

                // --- who is billing --------------------------------
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(head.name, style: AppType.h2.c(p.accentInk)),
                      if (head.where.isNotEmpty)
                        Text(head.where,
                            textAlign: TextAlign.right,
                            style: AppType.bodyS.c(p.inkMuted)),
                      if (head.phone.isNotEmpty)
                        Text('Phone: ${head.phone}',
                            style: AppType.bodyS.c(p.inkMuted)),
                      if (head.email.isNotEmpty)
                        Text('Mail: ${head.email}',
                            style: AppType.bodyS.c(p.inkMuted)),
                      if (head.gstin.isNotEmpty)
                        Text('GSTIN: ${head.gstin}',
                            style: AppType.bodyS.c(p.inkMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),

                // --- the three headers ------------------------------
                // Side by side when there is room, IntrinsicHeight +
                // stretch so they read as one header band rather than three
                // unrelated boxes. On a narrow phone, or at a large font,
                // a third of the card is too thin for "RJ18CC1390" and the
                // words broke mid-number, so they stack instead.
                LayoutBuilder(builder: (context, box) {
                  final blocks = [
                    _Block(
                      title: 'Bill To:',
                      rows: party.billTo,
                    ),
                    _Block(
                      title: 'Vehicle Details:',
                      rows: [
                        card.vehicleLine,
                        if (card.odometerKm > 0)
                          'KM Reading: ${Fmt.km(card.odometerKm)}',
                      ],
                    ),
                    _Block(
                      title: 'Invoice Details:',
                      rows: [
                        'Number: ${card.number}',
                        'Date: ${Fmt.date(card.openedAt)}',
                        Fmt.time(card.openedAt),
                        if (money.taxed &&
                            BillBlock.placeOfSupply(card.supplyState)
                                .isNotEmpty)
                          'Place of Supply: '
                              '${BillBlock.placeOfSupply(card.supplyState)}',
                      ],
                    ),
                  ];
                  final narrow = box.maxWidth / 3 <
                      MediaQuery.textScalerOf(context).scale(100);
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < blocks.length; i++) ...[
                          if (i > 0) const SizedBox(height: Gap.xs),
                          blocks[i],
                        ],
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < blocks.length; i++) ...[
                          if (i > 0) const SizedBox(width: Gap.xs),
                          Expanded(child: blocks[i]),
                        ],
                      ],
                    ),
                  );
                }),

                // --- insurance, when the counter copied a policy --------
                if (party.insurance.isNotEmpty) ...[
                  const SizedBox(height: Gap.xs),
                  SizedBox(
                    width: double.infinity,
                    child: _Block(
                        title: 'Insurance Details:', rows: party.insurance),
                  ),
                ],

                const SizedBox(height: Gap.lg),

                // --- the lines --------------------------------------
                _Header(),
                for (var i = 0; i < card.items.length; i++)
                  _Line(
                    index: i + 1,
                    line: card.items[i],
                    gst: BillBlock.gstOf(card, card.items[i]),
                  ),
                if (card.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                    child: Text('Nothing billed on this card yet.',
                        style: AppType.bodyS.c(p.inkFaint)),
                  ),

                const SizedBox(height: Gap.lg),

                // --- the money ---------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total In Words:',
                              style: AppType.labelM.c(p.inkMuted)),
                          Text(Words.rupees(card.total),
                              style: AppType.labelL.c(p.ink)),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(Gap.md),
                        decoration: BoxDecoration(
                          color: p.infoSoft,
                          borderRadius: R.all(R.xs),
                        ),
                        child: Column(
                          children: [
                            Text('Bill Amount Details:',
                                style: AppType.labelM.c(p.info)),
                            const SizedBox(height: Gap.sm),
                            // Every row from the one block the PDF prints,
                            // so the screen and the download agree.
                            for (final row in money.rows) ...[
                              if (row.strong)
                                Divider(height: Gap.lg, color: p.line),
                              _Money(
                                  label: row.label,
                                  value: row.value,
                                  strong: row.strong),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (card.bank != null && card.bank!.rows.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  SizedBox(
                    width: double.infinity,
                    child: _Block(
                      title: 'Bank Details:',
                      rows: [
                        for (final (label, value) in card.bank!.rows)
                          '$label: $value',
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: Gap.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Authorized Signature',
                      style: AppType.labelM.c(p.inkMuted)),
                ),

                if (head.terms.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: p.surfaceSunken,
                      borderRadius: R.all(R.xs),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Terms and Conditions',
                            style: AppType.labelM.c(p.ink)),
                        const SizedBox(height: 4),
                        Text(head.terms,
                            style: AppType.bodyS.c(p.inkMuted)),
                      ],
                    ),
                  ),
                ],

                if (card.nextServiceAt != null) ...[
                  const SizedBox(height: Gap.md),
                  Center(
                    child: Text(
                      'Your next service is due on: '
                      '${Fmt.date(card.nextServiceAt!)}'
                      '${card.nextServiceKm == null ? ' or before No KM Reminder' : ' or before ${Fmt.km(card.nextServiceKm!)}'}',
                      textAlign: TextAlign.center,
                      style: AppType.labelM.c(p.info),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: Row(
          children: [
            Expanded(
              child: GButton(
                label: 'Share',
                kind: GButtonKind.outline,
                icon: Icons.ios_share_rounded,
                onPressed: () => _share(
                  context,
                  card,
                  shop,
                  user?.name ?? '',
                  user?.phone ?? '',
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              flex: 2,
              child: GButton.accent(
                label: 'Download Invoice',
                icon: Icons.download_rounded,
                onPressed: () => _download(
                  context,
                  card: card,
                  shop: shop,
                  name: user?.name ?? '',
                  phone: user?.phone ?? '',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Saves the invoice into the phone's Downloads folder and says exactly
  /// where it went — a share sheet is not a save, and "Downloaded" with no
  /// path is not an answer when somebody goes looking for the file.
  Future<void> _download(
    BuildContext context, {
    required WorkshopCard card,
    required Workshop shop,
    required String name,
    required String phone,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await InvoicePdf.build(
        card: card,
        shop: shop,
        customerName: name,
        customerPhone: phone,
      );
      final file = InvoicePdf.fileName(card);
      final where = await saveToDownloads(file, bytes);

      if (!context.mounted) return;
      if (where == null) {
        // Nowhere to write — hand it to the platform instead of losing it.
        await Printing.sharePdf(bytes: bytes, filename: file);
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved to $where'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () =>
                Printing.sharePdf(bytes: bytes, filename: file),
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        GFeedback.error(context, 'Could not save the invoice.');
      }
    }
  }

  /// Sends the invoice on as a PDF, so what the customer forwards is the
  /// document itself rather than a retyped summary of it.
  Future<void> _share(
    BuildContext context,
    WorkshopCard card,
    Workshop shop,
    String name,
    String phone,
  ) async {
    try {
      final bytes = await InvoicePdf.build(
        card: card,
        shop: shop,
        customerName: name,
        customerPhone: phone,
      );
      await Printing.sharePdf(
          bytes: bytes, filename: InvoicePdf.fileName(card));
    } catch (_) {
      if (context.mounted) {
        await SharePlus.instance
            .share(ShareParams(text: _asText(card, shop, name)));
      }
    }
  }

  /// The same document as plain text, for when the PDF cannot be made.
  String _asText(WorkshopCard card, Workshop shop, String name) {
    final b = StringBuffer()
      ..writeln(Letterhead.of(card, shop).name)
      ..writeln('Invoice ${card.number} • ${Fmt.date(card.openedAt)}')
      ..writeln([
        card.billName.trim().isEmpty ? name : card.billName.trim(),
        card.vehicleLine,
      ].where((s) => s.isNotEmpty).join(' • '))
      ..writeln('');
    for (final li in card.items) {
      b.writeln('${li.name}  ${li.qtyLabel} x '
          '${Fmt.money(li.rate)} = ${Fmt.money(li.amount)}');
    }
    b.writeln('');
    for (final row in BillBlock.of(card).rows) {
      b.writeln('${row.label} ${Fmt.money(row.value)}');
    }
    return b.toString();
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.rows});

  final String title;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: p.infoSoft,
        borderRadius: R.all(R.xs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.labelS.c(p.info)),
          const SizedBox(height: 3),
          for (final r in rows)
            if (r.trim().isNotEmpty)
              Text(r, style: AppType.bodyS.s(11).c(p.ink)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm, horizontal: Gap.sm),
      color: p.infoSoft,
      child: Row(
        children: [
          SizedBox(
              width: 20,
              child: Text('#', style: AppType.labelS.c(p.info))),
          Expanded(
            flex: _Cols.name,
            child: Text('Particulars', style: AppType.labelS.c(p.info)),
          ),
          for (final (label, flex, align) in const [
            ('GST', _Cols.gst, TextAlign.center),
            ('Qty', _Cols.qty, TextAlign.center),
            ('Rate', _Cols.rate, TextAlign.right),
            ('Amount', _Cols.amount, TextAlign.right),
          ])
            Expanded(
              flex: flex,
              child: _Fit(
                align: align,
                child: Text(label, style: AppType.labelS.c(p.info)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The table's column weights, shared by the header and every line so the
/// two cannot drift apart. Sized for a 360dp phone: the figures shrink to fit
/// before the particulars lose any more room.
abstract final class _Cols {
  static const name = 4;
  static const gst = 2;
  static const qty = 2;
  static const rate = 3;
  static const amount = 3;
}

/// One figure in its column, shrunk rather than wrapped or cut.
class _Fit extends StatelessWidget {
  const _Fit({required this.child, this.align = TextAlign.right});

  final Widget child;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final a = switch (align) {
      TextAlign.center => Alignment.center,
      TextAlign.left => Alignment.centerLeft,
      _ => Alignment.centerRight,
    };
    return Align(
      alignment: a,
      child: FittedBox(fit: BoxFit.scaleDown, alignment: a, child: child),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.index, required this.line, required this.gst});

  final int index;
  final WorkshopLine line;

  /// "18%", or a dash on an untaxed bill.
  final String gst;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm, horizontal: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 20,
              child: Text('$index', style: AppType.bodyS.c(p.inkMuted))),
          Expanded(
            flex: _Cols.name,
            child: Text(line.name, style: AppType.bodyS.c(p.ink)),
          ),
          Expanded(
            flex: _Cols.gst,
            child: _Fit(
              align: TextAlign.center,
              child: Text(gst, maxLines: 1, style: AppType.bodyS.c(p.inkMuted)),
            ),
          ),
          Expanded(
            flex: _Cols.qty,
            child: _Fit(
              align: TextAlign.center,
              child: Text(line.qtyLabel,
                  maxLines: 1, style: AppType.bodyS.c(p.ink)),
            ),
          ),
          Expanded(
            flex: _Cols.rate,
            child: _Fit(
              child: Text(Fmt.money(line.rate),
                  maxLines: 1, style: AppType.bodyS.c(p.ink)),
            ),
          ),
          Expanded(
            flex: _Cols.amount,
            child: _Fit(
              child: Text(Fmt.money(line.amount),
                  maxLines: 1, style: AppType.labelM.c(p.ink)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // The panel is half the page wide, so a long label ("Taxable
          // value") used to run straight into the rupees. Shrink the word
          // to fit rather than clipping it: a bill that says "Taxable
          // v..." is worse than one set a point smaller.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label,
                    maxLines: 1,
                    style: strong
                        ? AppType.labelL.c(p.ink)
                        : AppType.bodyS.c(p.inkMuted)),
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
          // The amount is shrunk to fit too, for the same reason: a
          // six-figure total at a large font is wider than the panel.
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(Fmt.money(value),
                  maxLines: 1,
                  style: strong
                      ? AppType.money.s(15).c(p.accentInk)
                      : AppType.moneyS.c(p.ink)),
            ),
          ),
        ],
      ),
    );
  }
}
