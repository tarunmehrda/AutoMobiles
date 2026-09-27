import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/i18n/strings_hi.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_feedback.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import 'support_sheet.dart';

/// The text of one message in a card's SMS trail, as the customer gets it.
///
/// There is no SMS gateway behind this app. A message leaves only when the
/// counter opens it in the phone's own SMS app and taps Send, so this is the
/// one place its words are written: the SMS report shows them, the Send
/// buttons on the trail type them in, and the create / complete / close
/// flows open them the moment their event is added. It used to live inside
/// the report alone, which is how the report came to promise messages that
/// nothing ever sent.
///
/// [label] is the event's label as stored — translated into whatever
/// language the console was in when the event was added, so both are
/// recognised. [link] is the customer-app link (`onlineLinkProvider`); it is
/// empty while the shopfront is off, and then the line that carried it is
/// left out rather than pointing the customer at a site with nothing on it.
String smsText({
  required String label,
  required JobCard card,
  required String garage,
  required String vehicle,
  required String link,
}) {
  final total = Fmt.money(card.total);
  if (_labelIs(label, 'Work complete')) {
    return [
      'Dear Customer,',
      'Your $vehicle is ready.',
      'Apprx. Bill Amount: $total',
      if (link.isNotEmpty) link,
      'Pickup your Vehicle.',
      'Thanks.',
      garage,
    ].join('\n');
  }
  if (_labelIs(label, 'Invoice closed')) {
    return [
      'Dear Customer,',
      'Invoice ${card.number} for your $vehicle is closed. Total $total.',
      if (link.isNotEmpty) link,
      'Thanks.',
      garage,
    ].join('\n');
  }
  if (_isReminder(label)) {
    return [
      'Dear Customer,',
      link.isEmpty
          ? 'Your $vehicle is due for service. Call us to book a slot.'
          : 'Your $vehicle is due for service. Book a slot at $link',
      'Thanks.',
      garage,
    ].join('\n');
  }
  return [
    'Welcome to $garage',
    'New Jobcard is created for your Vehicle.',
    if (link.isNotEmpty) ...['You can track your Jobcard on', link],
    'Thanks.',
  ].join('\n');
}

bool _labelIs(String label, String english) =>
    label == english || label == stringsHi[english] || label == english.tr;

bool _isReminder(String label) {
  const template = 'Service reminder {0}';
  final prefixes = {
    'Service reminder',
    template.tr.split('{0}').first.trim(),
    (stringsHi[template] ?? template).split('{0}').first.trim(),
  };
  return prefixes.any((p) => p.isNotEmpty && label.startsWith(p));
}

/// Whether [e] is waiting on the counter right now: ready to send and not
/// dated in the future. A reminder for next month is scheduled too, but
/// there is nothing to do about it today.
bool smsIsDue(SmsEvent e, {DateTime? now}) =>
    e.state == SmsState.scheduled && !e.at.isAfter(now ?? DateTime.now());

/// How one event reads in a trail, so the ledger and the SMS report agree.
///
/// "Ready to send" and "Due `date`" are both `SmsState.scheduled`; they are
/// split here because one wants a tap today and the other does not, and the
/// old single blue clock made a message nobody had sent look like one in
/// flight.
({String label, GTone tone, IconData icon}) smsLook(
  SmsEvent e, {
  DateTime? now,
}) => switch (e.state) {
  SmsState.delivered => (
    label: SmsState.delivered.label,
    tone: GTone.success,
    icon: Icons.mark_chat_read_rounded,
  ),
  SmsState.scheduled when smsIsDue(e, now: now) => (
    label: SmsState.scheduled.label,
    tone: GTone.warning,
    icon: Icons.send_rounded,
  ),
  SmsState.scheduled => (
    label: 'Due {0}'.trf([Fmt.date(e.at)]),
    tone: GTone.info,
    icon: Icons.schedule_rounded,
  ),
  SmsState.failed => (
    label: SmsState.failed.label,
    tone: GTone.danger,
    icon: Icons.error_rounded,
  ),
  SmsState.skipped => (
    label: SmsState.skipped.label,
    tone: GTone.neutral,
    icon: Icons.do_not_disturb_on_rounded,
  ),
};

/// The newest event on [card] with [label] that is still waiting to go —
/// the one a create / complete / close flow has just added.
SmsEvent? newestPendingSms(JobCard card, String label) {
  SmsEvent? found;
  for (final e in card.sms) {
    if (e.state != SmsState.scheduled || !_labelIs(e.label, label)) continue;
    if (found == null || !e.at.isBefore(found.at)) found = e;
  }
  return found;
}

/// Opens the phone's SMS app on the card's customer with [sms] typed in, and
/// records it as sent once the app has opened.
///
/// "Sent" here means handed to the phone's SMS app — the most this console
/// can know. Nothing is marked when there is no number to text or no SMS
/// app to open, so a message that never left does not read as sent.
Future<void> sendCardSms(
  BuildContext context,
  WidgetRef ref,
  JobCard card,
  SmsEvent sms,
) async {
  final customer = ref.read(customerProvider(card.customerId));
  final phone = customer?.phone.trim() ?? '';
  if (phone.isEmpty) {
    GFeedback.error(context, 'This customer has no mobile number.'.tr);
    return;
  }
  final vehicle = ref.read(vehicleProvider(card.vehicleId));
  final garage = ref.read(garageProvider);
  final body = smsText(
    label: sms.label,
    card: card,
    garage: garage?.name ?? 'Workshop'.tr,
    vehicle: vehicle?.title ?? 'vehicle',
    link: ref.read(onlineLinkProvider),
  );
  // Read before the await: the notifier outlives the widget that asked.
  final ctrl = ref.read(adminProvider.notifier);
  final opened = await launchSms(context, phone, body: body);
  if (opened) ctrl.markSmsSent(card.id, sms.id);
}

/// After a create / complete / close whose SMS switch was on: finds the
/// event that action just added to the card and opens it in the SMS app, so
/// all the counter has left to do is tap Send there.
Future<void> sendNewCardSms(
  BuildContext context,
  WidgetRef ref,
  String cardId,
  String label,
) async {
  final card = ref.read(jobCardProvider(cardId));
  if (card == null) return;
  final sms = newestPendingSms(card, label);
  if (sms == null) return;
  await sendCardSms(context, ref, card, sms);
}
