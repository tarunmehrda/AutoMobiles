import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/strings.dart';
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
    GFeedback.error(context, 'No dialler on this device.'.tr);
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
    'https://wa.me/$number${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}',
  );
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    GFeedback.error(context, 'WhatsApp is not installed.'.tr);
  }
}

/// Opens the phone's SMS app on [phone] with [body] typed in, ready for the
/// counter to tap Send.
///
/// Returns whether the SMS app actually opened, so a caller that records the
/// message as sent (see `markSmsSent`) only does so when it really could be.
/// A failure is already reported to the user here.
Future<bool> launchSms(
  BuildContext context,
  String phone, {
  String body = '',
}) async {
  final uri = Uri(
    scheme: 'sms',
    path: phone,
    queryParameters: body.isEmpty ? null : {'body': body},
  );
  final opened = await launchUrl(uri);
  if (!opened && context.mounted) {
    GFeedback.error(context, 'No messaging app on this device.'.tr);
  }
  return opened;
}

/// The two ways to reach Balaji Automobiles support, as one sheet.
///
/// The number itself is on show rather than hidden behind the buttons: half
/// the time somebody wants to ring from a different handset, and a number you
/// cannot read is not support.
Future<void> showSupportSheet(BuildContext context) => GFeedback.sheet<void>(
  context,
  title: 'Support'.tr,
  subtitle: 'We answer between 9 am and 8 pm, every day.'.tr,
  child: const _SupportBody(),
);

class _SupportBody extends StatelessWidget {
  const _SupportBody();

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _SupportAction(
                  label: 'WhatsApp'.tr,
                  blurb: 'Send a screenshot'.tr,
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
                  label: 'Call'.tr,
                  blurb: 'Talk it through'.tr,
                  icon: Icons.call_rounded,
                  onTap: () {
                    Navigator.of(context).pop();
                    launchDial(context, AppConfig.supportPhone);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Pressable(
            onTap: () {
              Clipboard.setData(
                const ClipboardData(text: AppConfig.supportPhone),
              );
              GFeedback.success(context, 'Number copied'.tr);
            },
            scale: 0.98,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.md,
              ),
              decoration: BoxDecoration(
                color: p.surfaceSunken,
                borderRadius: R.all(R.md),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    size: 19,
                    color: p.inkMuted,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support line'.tr,
                          style: AppType.labelS.c(p.inkMuted),
                        ),
                        Text(
                          AppConfig.supportPhone,
                          style: AppType.money.s(16).c(p.ink),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.copy_rounded, size: 17, color: p.inkFaint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
          horizontal: Gap.lg,
          vertical: Gap.xl,
        ),
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
            Text(
              blurb,
              textAlign: TextAlign.center,
              style: AppType.bodyS.c(p.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
