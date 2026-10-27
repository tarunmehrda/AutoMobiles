import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/save_file.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/books.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../documents/doc_sections.dart';
import '../documents/doc_text.dart';
import '../documents/invoice_format.dart';
import '../documents/pdf_builder.dart';
import 'template_picker.dart';

/// Everything the counter can do with a finished document.
///
/// The PDF is generated from the document model, so what prints matches what
/// is on screen. The image route captures the rendered card instead, which is
/// what people actually paste into WhatsApp.
class ShareSheet {
  const ShareSheet._();

  /// What the counter last chose. Kept for the session so the shop that
  /// always prints 80mm rolls is not picking it again on every bill.
  static InvoiceFormat lastFormat = InvoiceFormat.simpleA4;

  static Future<void> show(
    BuildContext context, {
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
    bool jobCardCopy = false,
    List<BankAccount> banks = const [],
    GlobalKey? captureKey,
    InvoiceFormat? format,
    Set<DocSection>? sections,
    void Function(InvoiceFormat, Set<DocSection>)? onTemplate,
  }) {
    var chosen = format ?? lastFormat;
    var on =
        sections ??
        DocSectionX.defaultsFor(chosen, kind, jobCardCopy: jobCardCopy);
    final title = docTitle(kind, chosen, jobCardCopy: jobCardCopy);
    // Every action below closes the sheet first and then does its work —
    // building a PDF takes seconds. Its results used to be reported through
    // the sheet's own context, which is unmounted by then, so "Saved to…"
    // and every error were swallowed and the button looked dead. They are
    // reported through the page that opened the sheet instead.
    final host = context;
    return GFeedback.sheet<void>(
      context,
      title: 'Share {0}'.trf([title.toLowerCase()]),
      subtitle: '${card.number} • ${customer?.name ?? ''}',
      child: StatefulBuilder(
        builder: (context, setSheet) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.lg,
            Gap.page,
            Gap.h1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Which shape of document everything below hands on, and what is
              // on it. Edited here or on the card itself; both write through to
              // the same pair of values, so the preview and the PDF agree.
              TemplatePicker(
                kind: kind,
                card: card,
                garage: garage,
                format: chosen,
                sections: on,
                compact: true,
                onBeforeEdit: () => Navigator.of(context).pop(),
                onChanged: (f, next) {
                  setSheet(() {
                    chosen = f;
                    on = next;
                    lastFormat = f;
                  });
                  onTemplate?.call(f, next);
                },
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: _Action(
                      label: 'WhatsApp'.tr,
                      icon: Icons.chat_rounded,
                      tint: const Color(0xFF25D366),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await _sharePdf(
                          host,
                          kind: kind,
                          format: chosen,
                          sections: on,
                          card: card,
                          garage: garage,
                          customer: customer,
                          vehicle: vehicle,
                          staff: staff,
                          jobCardCopy: jobCardCopy,
                          banks: banks,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: _Action(
                      label: 'Email'.tr,
                      icon: Icons.mail_rounded,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await _email(host, kind, card, garage, customer, on);
                      },
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: _Action(
                      label: 'Print'.tr,
                      icon: Icons.print_rounded,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await _print(
                          host,
                          kind: kind,
                          format: chosen,
                          sections: on,
                          card: card,
                          garage: garage,
                          customer: customer,
                          vehicle: vehicle,
                          staff: staff,
                          jobCardCopy: jobCardCopy,
                          banks: banks,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: _Action(
                      label: 'Download PDF'.tr,
                      icon: Icons.picture_as_pdf_rounded,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await _savePdf(
                          host,
                          kind: kind,
                          format: chosen,
                          sections: on,
                          card: card,
                          garage: garage,
                          customer: customer,
                          vehicle: vehicle,
                          staff: staff,
                          jobCardCopy: jobCardCopy,
                          banks: banks,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: _Action(
                      label: 'Share image'.tr,
                      icon: Icons.image_rounded,
                      onTap: captureKey == null
                          ? null
                          : () async {
                              Navigator.of(context).pop();
                              await _shareImage(
                                host,
                                captureKey,
                                card,
                                kind,
                              );
                            },
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: _Action(
                      label: 'Copy text'.tr,
                      icon: Icons.notes_rounded,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await SharePlus.instance.share(
                          ShareParams(
                            text: _summary(kind, card, garage, customer, on),
                            subject: '${kind.label} ${card.number}',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- pdf -----------------------------------------------------------------

  static Future<Uint8List> _bytes({
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    InvoiceFormat format = InvoiceFormat.simpleA4,
    Set<DocSection>? sections,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
    bool jobCardCopy = false,
    List<BankAccount> banks = const [],
  }) => JobPdf.build(
    kind: kind,
    card: card,
    garage: garage,
    format: format,
    sections: sections,
    customer: customer,
    vehicle: vehicle,
    staff: staff,
    jobCardCopy: jobCardCopy,
    banks: banks,
    // A wedged font load or plugin call used to leave the button doing
    // nothing at all. Bounded, it becomes an error somebody can report.
    // Photographs are read off the disk inside this, so the budget is
    // the whole document rather than just the font.
  ).timeout(const Duration(seconds: 30));

  /// `mechanicCopy-simpleA4-JC-001.pdf`, or `jobCardCopy-…` for the
  /// customer's copy, so the two floor copies are told apart in Downloads.
  static String _fileName(
    DocKind kind,
    JobCard card,
    InvoiceFormat format, {
    bool jobCardCopy = false,
  }) =>
      '${jobCardCopy && kind == DocKind.mechanicCopy ? 'jobCardCopy' : kind.name}-${format.name}-${card.number}.pdf';

  static Future<void> _print(
    BuildContext context, {
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    InvoiceFormat? format,
    Set<DocSection>? sections,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
    bool jobCardCopy = false,
    List<BankAccount> banks = const [],
  }) async {
    try {
      await Printing.layoutPdf(
        name: _fileName(
          kind,
          card,
          format ?? lastFormat,
          jobCardCopy: jobCardCopy,
        ),
        onLayout: (_) => _bytes(
          kind: kind,
          card: card,
          garage: garage,
          format: format ?? lastFormat,
          sections: sections,
          customer: customer,
          vehicle: vehicle,
          staff: staff,
          jobCardCopy: jobCardCopy,
          banks: banks,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        GFeedback.error(
          context,
          'Could not open the print preview — {0}'.trf([e]),
        );
      }
    }
  }

  static Future<void> _sharePdf(
    BuildContext context, {
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    InvoiceFormat? format,
    Set<DocSection>? sections,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
    bool jobCardCopy = false,
    List<BankAccount> banks = const [],
  }) async {
    try {
      final bytes = await _bytes(
        kind: kind,
        card: card,
        garage: garage,
        format: format ?? lastFormat,
        sections: sections,
        customer: customer,
        vehicle: vehicle,
        staff: staff,
        jobCardCopy: jobCardCopy,
        banks: banks,
      );
      final file = _fileName(
        kind,
        card,
        format ?? lastFormat,
        jobCardCopy: jobCardCopy,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, name: file, mimeType: 'application/pdf'),
          ],
          // XFile's own `name` is dropped everywhere except the web — the
          // bytes land in a temp file and share_plus falls back to a random
          // UUID, so the bill arrived in WhatsApp called `4f2a1c…pdf`. This
          // is the one channel that carries the name through.
          fileNameOverrides: [file],
          text: _summary(kind, card, garage, customer, sections ?? const {}),
          subject: '${kind.label} ${card.number}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        GFeedback.error(context, 'Could not build the PDF — {0}'.trf([e]));
      }
    }
  }

  /// Writes the PDF into the phone's own Downloads folder and tells the user
  /// exactly where it landed — a share sheet is not a save, and "Saved" with
  /// no path is not an answer when somebody goes looking for the file.
  /// Saves the document straight to Downloads, without the sheet. The app
  /// bar's download button is the short way to the same place.
  static Future<void> download(
    BuildContext context, {
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    InvoiceFormat? format,
    Set<DocSection>? sections,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
    bool jobCardCopy = false,
    List<BankAccount> banks = const [],
  }) => _savePdf(
    context,
    kind: kind,
    card: card,
    garage: garage,
    format: format,
    sections: sections,
    customer: customer,
    vehicle: vehicle,
    staff: staff,
    jobCardCopy: jobCardCopy,
    banks: banks,
  );

  static Future<void> _savePdf(
    BuildContext context, {
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    InvoiceFormat? format,
    Set<DocSection>? sections,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
    bool jobCardCopy = false,
    List<BankAccount> banks = const [],
  }) async {
    try {
      final bytes = await _bytes(
        kind: kind,
        card: card,
        garage: garage,
        format: format ?? lastFormat,
        sections: sections,
        customer: customer,
        vehicle: vehicle,
        staff: staff,
        jobCardCopy: jobCardCopy,
        banks: banks,
      );
      final file = _fileName(
        kind,
        card,
        format ?? lastFormat,
        jobCardCopy: jobCardCopy,
      );
      final path = await saveToDownloads(file, bytes);
      if (path == null) {
        // Nowhere this app may write — the web, or a locked-down device.
        // Hand the bytes to the system so the save still happens somewhere,
        // and say so rather than leaving the button looking dead.
        if (context.mounted) {
          GFeedback.info(context, 'Choose where to keep the PDF.'.tr);
        }
        await Printing.sharePdf(bytes: bytes, filename: file);
        return;
      }
      if (context.mounted) {
        // Where it landed, and one tap to go and look at it. Through
        // GFeedback like every other toast, so it lands above a sheet too.
        GFeedback.toast(
          context,
          'Saved to {0}'.trf([path]),
          tone: GTone.success,
          icon: Icons.check_circle_rounded,
          actionLabel: 'Open'.tr,
          onAction: () => Printing.sharePdf(bytes: bytes, filename: file),
          duration: const Duration(seconds: 6),
        );
      }
    } catch (e) {
      if (context.mounted) {
        GFeedback.error(context, 'Could not save the PDF — {0}'.trf([e]));
      }
    }
  }

  // --- image ---------------------------------------------------------------

  static Future<void> _shareImage(
    BuildContext context,
    GlobalKey key,
    JobCard card,
    DocKind kind,
  ) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (context.mounted) {
          GFeedback.error(context, 'Nothing to capture yet.'.tr);
        }
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final file = '${kind.name}-${card.number}.png';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data.buffer.asUint8List(),
              name: file,
              mimeType: 'image/png',
            ),
          ],
          fileNameOverrides: [file],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        GFeedback.error(context, 'Could not capture the document.'.tr);
      }
    }
  }

  // --- email ---------------------------------------------------------------

  static Future<void> _email(
    BuildContext context,
    DocKind kind,
    JobCard card,
    Garage garage,
    Customer? customer,
    Set<DocSection> on,
  ) async {
    // mailto with no address opens the composer with an empty To field,
    // which is the right outcome for a walk-in with no email on file — but
    // say so first, because "nothing happened" is what it looks like.
    if ((customer?.email ?? '').trim().isEmpty && context.mounted) {
      GFeedback.info(
        context,
        'No email on file — add the address yourself.'.tr,
      );
    }
    // Built by hand rather than with `queryParameters`, which encodes to
    // form rules: every space in the bill came out of it as a literal `+`,
    // so the mail composer opened with a body nobody would send.
    final query =
        'subject=${Uri.encodeComponent('${kind.label} ${card.number} — ${garage.name}')}&body=${Uri.encodeComponent(_summary(kind, card, garage, customer, on))}';
    final uri = Uri.parse('mailto:${(customer?.email ?? '').trim()}?$query');
    if (!await launchUrl(uri) && context.mounted) {
      GFeedback.error(context, 'No email app on this device.'.tr);
    }
  }

  /// The plain-text version that goes in the message body.
  ///
  /// Follows the same ticks as the document, so a bill sent with the
  /// customer voice on it reads the same in WhatsApp as it does on paper.
  static String _summary(
    DocKind kind,
    JobCard card,
    Garage garage,
    Customer? customer, [
    Set<DocSection> on = const {},
  ]) {
    final lines = <String>[
      garage.name,
      '${kind.label} ${card.number} — ${Fmt.date(card.createdAt)}',
      '',
      if (customer != null) 'Customer: ${customer.name}',
      if (on.contains(DocSection.odometer))
        'Odometer: ${Fmt.km(card.odometerKm)}',
      if (on.contains(DocSection.voices) && card.voices.isNotEmpty) ...[
        '',
        'Reported:',
        for (final v in card.voices) '• $v',
      ],
      '',
      for (final item in card.items)
        kind.showsPricing
            ? '${item.name} x${qtyWithUnit(item)} — ${Fmt.money2(item.amount)}'
            : floorLine(item),
    ];

    if (kind.showsPricing) {
      lines.addAll([
        '',
        'Total: ${Fmt.money2(card.total)}',
        if (kind == DocKind.invoice && card.advancePaid > 0)
          'Advance: ${Fmt.money2(card.advancePaid)}',
        if (kind == DocKind.invoice) 'Paid: ${Fmt.money2(card.paid)}',
        if (kind == DocKind.invoice) 'Balance: ${Fmt.money2(card.balance)}',
      ]);
    }
    if (card.nextServiceAt != null) {
      lines.addAll(['', 'Next service due ${Fmt.date(card.nextServiceAt!)}.']);
    }
    lines.addAll(['', 'Thank you for choosing ${garage.name}.']);
    return lines.join('\n');
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tint,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final c = onTap == null ? p.inkFaint : (tint ?? p.ink);
    return Pressable(
      onTap: onTap,
      enabled: onTap != null,
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
        ),
        child: Column(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: c),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelS.s(10.5).c(p.ink),
            ),
          ],
        ),
      ),
    );
  }
}
