import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../shared/sms_text.dart';
import '../shared/support_sheet.dart';

/// Every message in the cards' SMS trails, newest first, with the two ways
/// to follow it up.
///
/// Nothing here is sent by a server — there is no SMS gateway. A message
/// marked "Ready to send" goes when the counter taps Send, which opens it in
/// this phone's SMS app; "Sent" means it was handed to that app.
class SmsReportPage extends ConsumerStatefulWidget {
  const SmsReportPage({super.key});

  @override
  ConsumerState<SmsReportPage> createState() => _SmsReportPageState();
}

class _SmsReportPageState extends ConsumerState<SmsReportPage> {
  SmsState? _filter;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);

    final rows = <({JobCard card, SmsEvent sms})>[];
    for (final card in data.jobCards) {
      for (final s in card.sms) {
        if (_filter != null && s.state != _filter) continue;
        rows.add((card: card, sms: s));
      }
    }
    rows.sort((a, b) => b.sms.at.compareTo(a.sms.at));

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'SMS Report'.tr,
        subtitle: Tr.plural(rows.length, '{0} message', '{0} messages'),
        bottom: Padding(
          padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
          child: GSegmented<SmsState?>(
            options: const [null, ...SmsState.values],
            selected: _filter,
            onSelect: (v) => setState(() => _filter = v),
            labelOf: (v) => v?.label ?? 'All',
          ),
        ),
      ),
      body: rows.isEmpty
          ? GEmptyState(
              icon: Icons.sms_rounded,
              title: 'No messages yet'.tr,
              art: Art.noData,
              message:
                  'Messages are listed here when a card is opened, completed or closed. Tap Send to text one from this phone.'
                      .tr,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.md,
                Gap.page,
                Gap.h2,
              ),
              itemCount: rows.length,
              itemBuilder: (context, i) => Entrance(
                index: i.clamp(0, 8),
                child: _SmsCard(card: rows[i].card, sms: rows[i].sms),
              ),
            ),
    );
  }
}

class _SmsCard extends ConsumerWidget {
  const _SmsCard({required this.card, required this.sms});

  final JobCard card;
  final SmsEvent sms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final customer = ref.watch(customerProvider(card.customerId));
    final vehicle = ref.watch(vehicleProvider(card.vehicleId));
    final garage = ref.watch(garageProvider);
    final link = ref.watch(onlineLinkProvider);
    final whatsapp = ref.watch(
      adminProvider.select((s) => s.whatsappEnabled),
    );
    final phone = customer?.phone ?? '';
    final look = smsLook(sms);
    final due = smsIsDue(sms);

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?.name ?? 'Customer'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelL.c(p.ink),
                    ),
                    Text(
                      vehicle?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelM.c(p.success),
                    ),
                  ],
                ),
              ),
              if (phone.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelM.c(p.accentInk),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                // Only while the workshop has WhatsApp switched on in
                // Settings; that switch used to be read by nothing.
                if (whatsapp) ...[
                  _Action(
                    icon: Icons.chat_rounded,
                    color: p.success,
                    onTap: () => launchWhatsApp(context, phone),
                  ),
                  const SizedBox(width: Gap.xs),
                ],
                _Action(
                  icon: Icons.call_rounded,
                  color: p.inkSoft,
                  onTap: () => launchDial(context, phone),
                ),
              ],
            ],
          ),
          const SizedBox(height: Gap.sm),
          // Pills, then the timestamp — which gives way first when the
          // three of them will not fit.
          Row(
            children: [
              GPill(label: card.number, tone: GTone.info, compact: true),
              const SizedBox(width: Gap.sm),
              // Flexible: "Due <date>" is longer than the old one-word
              // states, and on a narrow phone it ellipsises rather than
              // pushing the row off the edge.
              Flexible(
                child: GPill(
                  label: look.label,
                  tone: look.tone,
                  icon: look.icon,
                  compact: true,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  Fmt.dateTime(sms.at),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelS.c(p.inkFaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text('Messages :'.tr, style: AppType.labelM.c(p.info)),
          const SizedBox(height: 4),
          Text(
            smsText(
              label: sms.label,
              card: card,
              garage: garage?.name ?? 'Workshop'.tr,
              vehicle: vehicle?.title ?? 'vehicle',
              link: link,
            ),
            style: AppType.bodyS.c(p.inkSoft),
          ),
          // Due and not yet handed to the SMS app: the counter sends it from
          // here. A reminder dated later reads "Due <date>" above and waits.
          if (due) ...[
            const SizedBox(height: Gap.md),
            Align(
              alignment: Alignment.centerRight,
              child: GButton.accent(
                label: 'Send'.tr,
                icon: Icons.send_rounded,
                size: GButtonSize.sm,
                expand: false,
                onPressed: () => sendCardSms(context, ref, card, sms),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: p.line),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
