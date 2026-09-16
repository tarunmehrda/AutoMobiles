import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/pressable.dart';

/// Dial or message a number, quietly doing nothing visible if the device has
/// no app that can handle it.
Future<void> launchDial(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (!await launchUrl(uri) && context.mounted) {
    GFeedback.error(context, 'No dialler on this device.');
  }
}

Future<void> launchWhatsApp(
  BuildContext context,
  String phone, {
  String text = '',
}) async {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final number = digits.length == 10 ? '91$digits' : digits;
  final uri = Uri.parse(
      'https://wa.me/$number${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    GFeedback.error(context, 'WhatsApp is not installed.');
  }
}

Future<void> launchSms(BuildContext context, String phone,
    {String body = ''}) async {
  final uri = Uri(
    scheme: 'sms',
    path: phone,
    queryParameters: body.isEmpty ? null : {'body': body},
  );
  if (!await launchUrl(uri) && context.mounted) {
    GFeedback.error(context, 'No messaging app on this device.');
  }
}

/// The two ways to reach Balaji Automobiles support, as one sheet.
Future<void> showSupportSheet(BuildContext context) => GFeedback.sheet<void>(
      context,
      title: 'Support',
      subtitle: 'We answer between 9 am and 8 pm, every day.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Row(
          children: [
            Expanded(
              child: _SupportAction(
                label: 'WhatsApp',
                blurb: 'Send a screenshot',
                icon: Icons.chat_rounded,
                tint: const Color(0xFF25D366),
                onTap: () {
                  Navigator.of(context).pop();
                  launchWhatsApp(context, AppConfig.supportWhatsapp);
                },
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: _SupportAction(
                label: 'Call',
                blurb: 'Talk it through',
                icon: Icons.call_rounded,
                onTap: () {
                  Navigator.of(context).pop();
                  launchDial(context, AppConfig.supportPhone);
                },
              ),
            ),
          ],
        ),
      ),
    );

class _SupportAction extends StatelessWidget {
  const _SupportAction({
    required this.label,
    required this.blurb,
    required this.icon,
    required this.onTap,
    this.tint,
  });

  final String label;
  final String blurb;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final c = tint ?? p.ink;
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: Gap.xl),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Column(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: c, size: 24),
            ),
            const SizedBox(height: Gap.md),
            Text(label, style: AppType.h2.c(p.ink)),
            const SizedBox(height: 2),
            Text(blurb,
                textAlign: TextAlign.center,
                style: AppType.bodyS.c(p.inkMuted)),
          ],
        ),
      ),
    );
  }
}
