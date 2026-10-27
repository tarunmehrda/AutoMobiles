import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/books.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import 'payment_sheets.dart';
import 'trade_form_page.dart';
import 'trade_line_sheet.dart';

/// Where a document's list lives, so the detail page knows its way back
/// and the share text can say what it is.
String tradeListRoute(TradeKind k) => switch (k) {
  TradeKind.estimate => '/estimates',
  TradeKind.saleReturn => '/sales?tab=return',
  TradeKind.saleOrder => '/sales?tab=order',
  TradeKind.purchaseBill => '/purchase?tab=bill',
  TradeKind.purchaseReturn => '/purchase?tab=return',
};

/// Status of a document in a word: what the list pill and the hero say.
({String label, GTone tone}) tradeStatus(TradeDoc d) {
  if (d.kind == TradeKind.estimate) {
    return d.fulfilled
        ? (label: 'Converted'.tr, tone: GTone.success)
        : (label: 'Open'.tr, tone: GTone.info);
  }
  if (d.kind == TradeKind.saleOrder && !d.fulfilled) {
    return (label: 'Pending delivery'.tr, tone: GTone.warning);
  }
  if (d.settled) return (label: 'Settled'.tr, tone: GTone.success);
  if (d.paid > 0) return (label: 'Part paid'.tr, tone: GTone.warning);
  return (label: 'Unpaid'.tr, tone: GTone.danger);
}

/// The paper itself: who, what, the tax, the money, and what can be done
/// with it next.
class TradeDetailPage extends ConsumerWidget {
  const TradeDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final data = ref.watch(adminProvider);
    final doc = data.tradeDocs.where((d) => d.id == id).firstOrNull;

    if (doc == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: GHeader(title: 'Document'.tr),
        body: GEmptyState(
          icon: Icons.description_outlined,
          art: Art.noData,
          title: 'Not found'.tr,
          message: 'This document has been deleted or has not synced yet.'.tr,
        ),
      );
    }

    final status = tradeStatus(doc);
    final garage = data.garage;

    Future<void> share() => SharePlus.instance.share(
      ShareParams(
        text: tradeShareText(doc, from: garage?.name ?? ''),
        subject: '${doc.kind.label} ${doc.number}',
      ),
    );

    Future<void> delete() async {
      final ok = await GFeedback.confirm(
        context,
        title: 'Delete {0}?'.trf([doc.number]),
        message: doc.kind.isQuote
            ? 'The estimate is removed. Job cards made from it stay.'.tr
            : 'Its stock movement and payments are undone, and the supplier balance is put back.'
                  .tr,
        confirmLabel: 'Delete'.tr,
        destructive: true,
        icon: Icons.delete_outline_rounded,
      );
      if (!ok || !context.mounted) return;
      ref.read(adminProvider.notifier).removeTradeDoc(doc.id);
      GFeedback.info(context, '{0} deleted'.trf([doc.number]));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(tradeListRoute(doc.kind));
      }
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: doc.number,
        subtitle: doc.kind.label,
        actions: [
          GIconButton(
            icon: Icons.ios_share_rounded,
            size: 40,
            tooltip: 'Share'.tr,
            onTap: share,
          ),
          GIconButton(
            icon: Icons.delete_outline_rounded,
            size: 40,
            foreground: p.danger,
            tooltip: 'Delete'.tr,
            onTap: delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
        children: [
          Entrance(
            child: _Hero(doc: doc, status: status),
          ),
          const SizedBox(height: Gap.md),
          Entrance(index: 1, child: _PartyCard(doc: doc)),
          const SizedBox(height: Gap.md),
          Entrance(index: 2, child: _LinesTable(doc: doc)),
          const SizedBox(height: Gap.md),
          Entrance(
            index: 3,
            child: GCard(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                children: [
                  TaxBreakdown(doc: doc),
                  const Divider(height: Gap.lg),
                  GKeyValue(
                    label: 'Total'.tr,
                    value: Fmt.money2(doc.total),
                    emphasize: true,
                  ),
                  if (!doc.kind.isQuote) ...[
                    GKeyValue(
                      label: doc.kind.moneyIn ? 'Received'.tr : 'Paid'.tr,
                      value: Fmt.money2(doc.paid),
                      valueColor: p.success,
                    ),
                    GKeyValue(
                      label: 'Balance'.tr,
                      value: Fmt.money2(doc.balance),
                      emphasize: true,
                      valueColor: doc.balance > 0 ? p.danger : p.success,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (doc.note.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            GCard(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NOTE', style: AppType.over.c(p.inkFaint)),
                  const SizedBox(height: Gap.xs),
                  Text(doc.note, style: AppType.bodyM.c(p.inkSoft)),
                ],
              ),
            ),
          ],
          if (doc.kind == TradeKind.estimate) ...[
            const SizedBox(height: Gap.lg),
            Center(
              child: GLink(
                label: 'Copy to a Sale Order'.tr,
                icon: Icons.content_copy_rounded,
                onTap: () => context.push(
                  '/trade/new?kind=${TradeKind.saleOrder.name}&from=${doc.id}',
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _Actions(doc: doc, onShare: share),
    );
  }
}

/// What can be done next — one or two buttons, by kind and state.
class _Actions extends StatelessWidget {
  const _Actions({required this.doc, required this.onShare});

  final TradeDoc doc;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    if (doc.kind == TradeKind.estimate) {
      buttons.add(
        GButton.accent(
          label: doc.fulfilled
              ? 'Make another Job Card'.tr
              : 'Convert to Job Card'.tr,
          icon: Icons.build_circle_rounded,
          onPressed: () => context.push('/job/new?estimate=${doc.id}'),
        ),
      );
    } else {
      if (doc.kind == TradeKind.saleOrder && !doc.fulfilled) {
        buttons.add(
          GButton.accent(
            label: 'Fulfil order'.tr,
            icon: Icons.local_shipping_rounded,
            onPressed: () => showSettleSheet(context, doc, fulfil: true),
          ),
        );
      }
      if (doc.balance > 0) {
        final settle = GButton(
          label: switch (doc.kind) {
            TradeKind.saleReturn => 'Refund'.tr,
            TradeKind.purchaseReturn => 'Refund received'.tr,
            TradeKind.purchaseBill => 'Pay supplier'.tr,
            _ => 'Record payment'.tr,
          },
          kind: buttons.isEmpty ? GButtonKind.accent : GButtonKind.outline,
          icon: Icons.payments_rounded,
          onPressed: () => showSettleSheet(context, doc),
        );
        buttons.insert(0, settle);
      }
    }
    if (buttons.isEmpty) {
      buttons.add(
        GButton(
          label: 'Share'.tr,
          kind: GButtonKind.outline,
          icon: Icons.ios_share_rounded,
          onPressed: onShare,
        ),
      );
    }
    return GBottomBar(
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: Gap.md),
            Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.doc, required this.status});

  final TradeDoc doc;
  final ({String label, GTone tone}) status;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(p.accent.withValues(alpha: 0.14), p.surface),
            Color.alphaBlend(p.accent.withValues(alpha: 0.04), p.surface),
          ],
        ),
        borderRadius: R.all(R.xl),
        border: Border.all(color: p.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.kind.label.toUpperCase(),
                  style: AppType.over.c(p.accentInk),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.money(doc.total),
                    style: AppType.d1.s(28).c(p.ink).w(FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    Fmt.date(doc.at),
                    if (doc.refNo.isNotEmpty) 'Ref {0}'.trf([doc.refNo]),
                    if (doc.dueAt != null)
                      'Due {0}'.trf([Fmt.date(doc.dueAt!)]),
                  ].join('  ·  '),
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          GPill(label: status.label, tone: status.tone),
        ],
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.doc});

  final TradeDoc doc;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return GCard(
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        children: [
          GAvatar(
            initials: Fmt.initials(doc.party.isEmpty ? '?' : doc.party),
            size: 42,
            tone: doc.kind.isSale ? GTone.accent : GTone.info,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.party.isEmpty ? 'Walk-in'.tr : doc.party,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelL.c(p.ink),
                ),
                for (final s in [
                  doc.phone,
                  if (doc.gstin.isNotEmpty) 'GSTIN ${doc.gstin}',
                  doc.address,
                ])
                  if (s.isNotEmpty)
                    Text(
                      s,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// # | Item | Qty | Rate | GST | Amount. An estimate reads it in groups —
/// Jobs / Labour, Parts, Lube — as the client asked.
class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.doc});

  final TradeDoc doc;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final head = AppType.labelS.s(10.5).c(p.inkMuted);
    final cell = AppType.bodyS.s(12).c(p.inkSoft);

    TableRow header() => TableRow(
      decoration: BoxDecoration(color: p.surfaceSunken),
      children: [
        for (final h in [
          '#',
          'Item'.tr,
          'Qty'.tr,
          'Rate'.tr,
          'GST',
          'Amount'.tr,
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              h,
              textAlign: h == 'Item'.tr ? TextAlign.left : TextAlign.right,
              style: head,
            ),
          ),
      ],
    );

    Widget num(String s, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(s, style: style ?? cell),
      ),
    );

    TableRow row(int n, TradeLine l) => TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.lineSoft)),
      ),
      children: [
        num('$n'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.name, style: AppType.labelM.s(12.5).c(p.ink)),
              if (l.hsn.isNotEmpty)
                Text('HSN ${l.hsn}', style: AppType.labelS.c(p.inkFaint)),
            ],
          ),
        ),
        num('${Fmt.number(l.qty)} ${l.unit}'),
        num(Fmt.number(l.rate)),
        num(gstLabel(l.gstRate)),
        num(Fmt.number(l.total), style: AppType.moneyS.s(12.5).c(p.ink)),
      ],
    );

    final rows = <TableRow>[header()];
    var n = 0;
    if (doc.kind.isQuote) {
      for (final k in [LineKind.job, LineKind.spare, LineKind.lube]) {
        final group = doc.lines.where((l) => l.kind == k).toList();
        if (group.isEmpty) continue;
        rows.add(
          TableRow(
            children: [
              const SizedBox(),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                child: Text(
                  lineGroupLabel(k).toUpperCase(),
                  style: AppType.over.c(p.accentInk),
                ),
              ),
              for (var i = 0; i < 4; i++) const SizedBox(),
            ],
          ),
        );
        for (final l in group) {
          rows.add(row(++n, l));
        }
      }
    } else {
      for (final l in doc.lines) {
        rows.add(row(++n, l));
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(24),
          1: FlexColumnWidth(3.2),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.4),
          4: FlexColumnWidth(1),
          5: FlexColumnWidth(1.7),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }
}

/// The document as plain text, for WhatsApp and SMS — no PDF needed to
/// send a supplier what was returned or a customer what a job will cost.
String tradeShareText(TradeDoc d, {String from = ''}) {
  final b = StringBuffer();
  if (from.isNotEmpty) b.writeln('*$from*');
  b.writeln('${d.kind.label} ${d.number}  ·  ${Fmt.date(d.at)}');
  if (d.party.isNotEmpty) b.writeln('${'To'.tr}: ${d.party}');
  if (d.refNo.isNotEmpty) b.writeln('Ref: ${d.refNo}');
  b.writeln();
  var n = 0;
  void line(TradeLine l) {
    b.writeln(
      '${++n}. ${l.name} — ${Fmt.number(l.qty)} ${l.unit} × '
      '${Fmt.money2(l.rate)}${l.taxIncluded ? ' (incl. tax)' : ''}'
      ' @ GST ${gstLabel(l.gstRate)} = ${Fmt.money2(l.total)}',
    );
  }

  if (d.kind.isQuote) {
    for (final k in [LineKind.job, LineKind.spare, LineKind.lube]) {
      final group = d.lines.where((l) => l.kind == k).toList();
      if (group.isEmpty) continue;
      b.writeln('_${lineGroupLabel(k)}_');
      group.forEach(line);
    }
  } else {
    d.lines.forEach(line);
  }
  b.writeln();
  b.writeln('${'Taxable'.tr}: ${Fmt.money2(d.taxable)}');
  if (d.split == TaxSplit.intra) {
    if (d.cgst > 0) b.writeln('CGST: ${Fmt.money2(d.cgst)}');
    if (d.sgst > 0) b.writeln('SGST: ${Fmt.money2(d.sgst)}');
  } else if (d.igst > 0) {
    b.writeln('IGST: ${Fmt.money2(d.igst)}');
  }
  if (d.discount > 0) {
    b.writeln('${'Discount'.tr}: -${Fmt.money2(d.discount)}');
  }
  b.writeln('*${'Total'.tr}: ${Fmt.money2(d.total)}*');
  if (!d.kind.isQuote) {
    if (d.paid > 0) b.writeln('${'Paid'.tr}: ${Fmt.money2(d.paid)}');
    if (d.balance > 0) b.writeln('${'Balance'.tr}: ${Fmt.money2(d.balance)}');
  }
  if (d.note.isNotEmpty) {
    b.writeln();
    b.writeln(d.note);
  }
  return b.toString().trim();
}
