import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/save_file.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../documents/pdf_builder.dart';

/// Everything the counter can do with a finished document.
///
/// The PDF is generated from the document model, so what prints matches what
/// is on screen. The image route captures the rendered card instead, which is
/// what people actually paste into WhatsApp.
class ShareSheet {
  const ShareSheet._();

  static Future<void> show(
    BuildContext context, {
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
    GlobalKey? captureKey,
  }) {
    return GFeedback.sheet<void>(
      context,
      title: 'Share ${kind.label.toLowerCase()}',
      subtitle: '${card.number} • ${customer?.name ?? ''}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Action(
                    label: 'WhatsApp',
                    icon: Icons.chat_rounded,
                    tint: const Color(0xFF25D366),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _sharePdf(context,
                          kind: kind,
                          card: card,
                          garage: garage,
                          customer: customer,
                          vehicle: vehicle,
                          staff: staff);
                    },
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _Action(
                    label: 'Email',
                    icon: Icons.mail_rounded,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _email(context, kind, card, garage, customer);
                    },
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _Action(
                    label: 'Print',
                    icon: Icons.print_rounded,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _print(context,
                          kind: kind,
                          card: card,
                          garage: garage,
                          customer: customer,
                          vehicle: vehicle,
                          staff: staff);
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
                    label: 'Save PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _savePdf(context,
                          kind: kind,
                          card: card,
                          garage: garage,
                          customer: customer,
                          vehicle: vehicle,
                          staff: staff);
                    },
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _Action(
                    label: 'Share image',
                    icon: Icons.image_rounded,
                    onTap: captureKey == null
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await _shareImage(context, captureKey, card, kind);
                          },
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _Action(
                    label: 'Copy text',
                    icon: Icons.notes_rounded,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await SharePlus.instance.share(
                        ShareParams(
                          text: _summary(kind, card, garage, customer),
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
    );
  }

  // --- pdf -----------------------------------------------------------------

  static Future<Uint8List> _bytes({
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
  }) =>
      JobPdf.build(
        kind: kind,
        card: card,
        garage: garage,
        customer: customer,
        vehicle: vehicle,
        staff: staff,
      );

  static String _fileName(DocKind kind, JobCard card) =>
      '${kind.name}-${card.number}.pdf';

  static Future<void> _print(
    BuildContext context, {
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
  }) async {
    try {
      await Printing.layoutPdf(
        name: _fileName(kind, card),
        onLayout: (_) => _bytes(
          kind: kind,
          card: card,
          garage: garage,
          customer: customer,
          vehicle: vehicle,
          staff: staff,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        GFeedback.error(context, 'Could not open the print preview.');
      }
    }
  }

  static Future<void> _sharePdf(
    BuildContext context, {
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
  }) async {
    try {
      final bytes = await _bytes(
        kind: kind,
        card: card,
        garage: garage,
        customer: customer,
        vehicle: vehicle,
        staff: staff,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: _fileName(kind, card),
              mimeType: 'application/pdf',
            ),
          ],
          text: _summary(kind, card, garage, customer),
          subject: '${kind.label} ${card.number}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        GFeedback.error(context, 'Could not build the PDF.');
      }
    }
  }

  /// Writes the PDF where the platform keeps documents and tells the user
  /// exactly where it landed — a share sheet is not a save.
  static Future<void> _savePdf(
    BuildContext context, {
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
  }) async {
    try {
      final bytes = await _bytes(
        kind: kind,
        card: card,
        garage: garage,
        customer: customer,
        vehicle: vehicle,
        staff: staff,
      );
      final path = await saveDocument(_fileName(kind, card), bytes);
      if (path == null) {
        // Nowhere to write (the web): hand it to the browser instead.
        await Printing.sharePdf(bytes: bytes, filename: _fileName(kind, card));
        return;
      }
      if (context.mounted) {
        GFeedback.success(context, 'Saved to $path');
      }
    } catch (e) {
      if (context.mounted) {
        GFeedback.error(context, 'Could not save the PDF.');
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
          GFeedback.error(context, 'Nothing to capture yet.');
        }
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data.buffer.asUint8List(),
              name: '${kind.name}-${card.number}.png',
              mimeType: 'image/png',
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        GFeedback.error(context, 'Could not capture the document.');
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
  ) async {
    final uri = Uri(
      scheme: 'mailto',
      path: customer?.email ?? '',
      queryParameters: {
        'subject': '${kind.label} ${card.number} — ${garage.name}',
        'body': _summary(kind, card, garage, customer),
      },
    );
    if (!await launchUrl(uri) && context.mounted) {
      GFeedback.error(context, 'No email app on this device.');
    }
  }

  /// The plain-text version that goes in the message body.
  static String _summary(
    DocKind kind,
    JobCard card,
    Garage garage,
    Customer? customer,
  ) {
    final lines = <String>[
      garage.name,
      '${kind.label} ${card.number} — ${Fmt.date(card.createdAt)}',
      '',
      if (customer != null) 'Customer: ${customer.name}',
      '',
      for (final item in card.items)
        kind.showsPricing
            ? '${item.name} x${item.qtyLabel} — ${Fmt.money2(item.amount)}'
            : '${item.name} — ${item.state.label}',
    ];

    if (kind.showsPricing) {
      lines.addAll([
        '',
        'Total: ${Fmt.money2(card.total)}',
        if (kind == DocKind.invoice) 'Paid: ${Fmt.money2(card.paid)}',
        if (kind == DocKind.invoice) 'Balance: ${Fmt.money2(card.balance)}',
      ]);
    }
    if (card.nextServiceAt != null) {
      lines.addAll(
          ['', 'Next service due ${Fmt.date(card.nextServiceAt!)}.']);
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
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.labelS.s(10.5).c(p.ink)),
          ],
        ),
      ),
    );
  }
}
