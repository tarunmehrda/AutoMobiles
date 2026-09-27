import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import 'documents/doc_sections.dart';
import 'documents/invoice_format.dart';
import 'documents/job_document.dart';
import 'widgets/close_sheet.dart';
import 'widgets/complete_sheet.dart';
import 'widgets/ledger_tabs.dart';
import 'widgets/panel_strip.dart';
import 'widgets/share_sheet.dart';
import 'widgets/template_picker.dart';
import 'widgets/vehicle_header.dart';

/// One job card, seen three ways. The document on screen is the thing that
/// gets shared, printed and handed over, so the whole screen is built around
/// keeping it accurate and one tap from going out.
class JobCardDetailPage extends ConsumerStatefulWidget {
  const JobCardDetailPage({
    super.key,
    required this.id,
    this.initialDoc = DocKind.estimate,
  });

  final String id;
  final DocKind initialDoc;

  @override
  ConsumerState<JobCardDetailPage> createState() => _JobCardDetailPageState();
}

class _JobCardDetailPageState extends ConsumerState<JobCardDetailPage> {
  late DocKind _doc = widget.initialDoc;
  final _captureKey = GlobalKey();

  /// Which of the five templates this card is being read and sent on, and
  /// which optional blocks ride on it.
  ///
  /// Held here rather than on the share sheet so the document underneath
  /// redraws as it is picked — the counter chooses a template by looking at
  /// one, not by reading its name off a chip and finding out at the printer.
  late InvoiceFormat _format = ShareSheet.lastFormat;
  late Set<DocSection> _sections = DocSectionX.defaultsFor(
    _format,
    widget.initialDoc,
  );

  void _setTemplate(InvoiceFormat format, Set<DocSection> sections) {
    setState(() {
      _format = format;
      _sections = sections;
      ShareSheet.lastFormat = format;
    });
  }

  /// The estimate, the invoice and the mechanic copy do not offer the same
  /// blocks — no money on the floor copy — so the ticks are re-derived when
  /// the tab changes rather than carried across and silently dropped.
  void _setDoc(DocKind doc) => setState(() {
    _doc = doc;
    _sections = DocSectionX.defaultsFor(_format, doc);
  });

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final card = ref.watch(jobCardProvider(widget.id));
    final garage = ref.watch(garageProvider);

    if (card == null || garage == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: GHeader(
          title: 'Job Card'.tr,
          subtitle: 'Estimate, invoice and mechanic copy'.tr,
        ),
        body: GEmptyState(
          icon: Icons.description_outlined,
          title: 'Job card not found'.tr,
          art: Art.searching,
          message: 'It may have been deleted from another screen.'.tr,
        ),
      );
    }

    final customer = ref.watch(customerProvider(card.customerId));
    final vehicle = ref.watch(vehicleProvider(card.vehicleId));
    final staff = ref.watch(staffProvider);

    // An open card should default to the estimate; once it is billed, the
    // invoice is what the counter reaches for.
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: _doc.label,
        subtitle: '${card.number} • ${card.status.label}',
        actions: [
          // One tap to the PDF, rather than two through the share sheet:
          // downloading the bill is the thing a counter does most.
          GIconButton(
            icon: Icons.download_rounded,
            size: 40,
            tooltip: 'Download PDF'.tr,
            onTap: () => ShareSheet.download(
              context,
              kind: _doc,
              card: card,
              garage: garage,
              format: _format,
              sections: _sections,
              customer: customer,
              vehicle: vehicle,
              staff: staff,
            ),
          ),
          GIconButton(
            icon: Icons.more_horiz_rounded,
            size: 40,
            onTap: () => _menu(context, card.id),
          ),
        ],
      ),
      body: Column(
        children: [
          VehicleHeader(
            card: card,
            onEdit: () => context.push('/job/${card.id}/items'),
          ),
          PanelStrip(card: card),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.lg,
                Gap.page,
                Gap.xxl,
              ),
              children: [
                if (card.items.isNotEmpty && !card.settled)
                  _BalanceBanner(amount: card.balance),
                // The other way round: more taken than billed. A settled
                // card says nothing on its own, so the money owed back
                // would otherwise be invisible here.
                if (card.excess > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.lg),
                    child: ExcessNote(amount: card.excess),
                  ),

                GSegmented<DocKind>(
                  options: DocKind.values,
                  selected: _doc,
                  onSelect: _setDoc,
                  labelOf: (d) => d.label,
                ),
                const SizedBox(height: Gap.md),

                TemplatePicker(
                  kind: _doc,
                  card: card,
                  garage: garage,
                  format: _format,
                  sections: _sections,
                  onChanged: _setTemplate,
                ),
                const SizedBox(height: Gap.lg),

                // Captured as-is for "Share image", which is why the
                // boundary wraps only the document.
                RepaintBoundary(
                  key: _captureKey,
                  child: JobDocument(
                    kind: _doc,
                    card: card,
                    garage: garage,
                    customer: customer,
                    vehicle: vehicle,
                    staff: staff,
                    format: _format,
                    sections: _sections,
                  ),
                ),

                if (card.items.isEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  _EmptyBillPrompt(
                    onAdd: () => context.push('/job/${card.id}/items'),
                  ),
                ],

                if (card.items.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  LedgerTabs(card: card, garage: garage),
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
                label: 'Share'.tr,
                kind: GButtonKind.outline,
                size: GButtonSize.lg,
                icon: Icons.ios_share_rounded,
                expand: true,
                onPressed: () => ShareSheet.show(
                  context,
                  kind: _doc,
                  card: card,
                  garage: garage,
                  customer: customer,
                  vehicle: vehicle,
                  staff: staff,
                  captureKey: _captureKey,
                  format: _format,
                  sections: _sections,
                  onTemplate: _setTemplate,
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: _PrimaryAction(id: card.id, onDoc: _showInvoice),
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoice() => setState(() => _doc = DocKind.invoice);

  void _menu(BuildContext context, String id) {
    final card = ref.read(jobCardProvider(id));
    if (card == null) return;
    GFeedback.sheet<void>(
      context,
      title: 'Job card {0}'.trf([card.number]),
      subtitle: 'Opened {0}'.trf([Fmt.fullDateTime(card.createdAt)]),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GOptionRow(
              label: 'Edit items'.tr,
              subtitle: 'Jobs, spares and lubes'.tr,
              icon: Icons.edit_note_rounded,
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/job/$id/items');
              },
            ),
            if (!card.isOpen)
              GOptionRow(
                label: 'Reopen on the floor'.tr,
                subtitle:
                    'Moves it back to Open and drops pending reminders'.tr,
                icon: Icons.lock_open_rounded,
                selected: false,
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(adminProvider.notifier).reopenJobCard(id);
                  GFeedback.info(context, 'Back on the floor.'.tr);
                },
              ),
            GOptionRow(
              label: 'Delete job card'.tr,
              subtitle: 'Parts go back to stock. This cannot be undone.'.tr,
              icon: Icons.delete_outline_rounded,
              selected: false,
              onTap: () async {
                Navigator.of(context).pop();
                final ok = await GFeedback.confirm(
                  context,
                  title: 'Delete {0}?'.trf([card.number]),
                  message:
                      'The card, its bill and its message trail go for good. Any parts on it return to stock.'
                          .tr,
                  confirmLabel: 'Delete'.tr,
                  destructive: true,
                  icon: Icons.delete_outline_rounded,
                );
                if (!ok || !context.mounted) return;
                ref.read(adminProvider.notifier).deleteJobCard(id);
                if (context.mounted) context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// What the card needs next, as one button.
class _PrimaryAction extends ConsumerWidget {
  const _PrimaryAction({required this.id, required this.onDoc});

  final String id;
  final VoidCallback onDoc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(jobCardProvider(id));
    if (card == null) return const SizedBox.shrink();

    if (card.isClosed) {
      return GButton(
        label: 'Done'.tr,
        kind: GButtonKind.primary,
        onPressed: () => context.pop(),
      );
    }

    if (card.status == JobStatus.complete) {
      return GButton.accent(
        label: 'Close card'.tr,
        icon: Icons.lock_rounded,
        onPressed: () async {
          final closed = await showCloseSheet(context, ref, card);
          if (closed && context.mounted) {
            onDoc();
            GFeedback.success(context, '{0} closed.'.trf([card.number]));
          }
        },
      );
    }

    if (!card.canComplete) {
      return GButton.accent(
        label: 'Add items'.tr,
        icon: Icons.add_rounded,
        onPressed: () => context.push('/job/$id/items'),
      );
    }

    // One button covers both ends of the counter's day: saving the advance
    // and discount on a card still on the floor, and pushing a finished one
    // through to Complete.
    return GButton.accent(
      label: 'Update or Complete'.tr,
      icon: Icons.task_alt_rounded,
      onPressed: () async {
        final outcome = await showCompleteSheet(context, ref, card);
        if (outcome == CompleteOutcome.completed) onDoc();
      },
    );
  }
}

class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.lg),
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      decoration: BoxDecoration(
        color: p.dangerSoft,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded, size: 18, color: p.danger),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              'Pending balance {0}'.trf([Fmt.money2(amount)]),
              style: AppType.labelL.c(p.danger),
            ),
          ),
          GPill(label: 'Unsettled'.tr, tone: GTone.danger, compact: true),
        ],
      ),
    );
  }
}

class _EmptyBillPrompt extends StatelessWidget {
  const _EmptyBillPrompt({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onAdd,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.isDark
              ? Color.alphaBlend(p.accent.withValues(alpha: 0.10), p.surface)
              : Color.alphaBlend(
                  p.accent.withValues(alpha: 0.08),
                  Colors.white,
                ),
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            const GArt(Art.invoice, height: 70),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nothing billed yet'.tr,
                    style: AppType.labelL.s(14.5).c(p.ink).w(FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add jobs, spares and lubes to build the bill'.tr,
                    style: AppType.bodyS.s(11.5).c(p.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.accent,
              ),
              child: Icon(Icons.add_rounded, size: 19, color: p.onAccent),
            ),
          ],
        ),
      ),
    );
  }
}
