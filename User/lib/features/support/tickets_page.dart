import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class TicketsPage extends ConsumerWidget {
  const TicketsPage({super.key});

  static const categories = [
    'Billing or invoice',
    'Service quality',
    'Delay in delivery',
    'Staff behaviour',
    'Pickup & drop',
    'App issue',
    'Something else',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final tickets = ref.watch(ticketsProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Complaints & tickets',
        subtitle: tickets.isEmpty
            ? 'Nothing raised yet'
            : '${tickets.length} raised',
      ),
      body: tickets.isEmpty
          ? GEmptyState(
              icon: Icons.support_agent_rounded,
              title: 'No tickets yet',
              message:
                  'If something did not go right — a bill, a delay, the work '
                  'itself — raise it here and a manager will respond within '
                  '24 hours.',
              actionLabel: 'Raise a ticket',
              onAction: () => _raise(context, ref),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.sm, Gap.page, Gap.h2),
              itemCount: tickets.length,
              separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
              itemBuilder: (context, i) {
                final t = tickets[i];
                return Entrance(
                  index: i,
                  child: GCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GPill(
                              label: t.status.toUpperCase(),
                              tone: t.status == 'Open'
                                  ? GTone.warning
                                  : GTone.success,
                              compact: true,
                            ),
                            const Spacer(),
                            Text(t.id,
                                style: AppType.labelS.c(p.inkFaint)),
                          ],
                        ),
                        const SizedBox(height: Gap.md),
                        Text(t.subject, style: AppType.h3.c(p.ink)),
                        const SizedBox(height: 3),
                        Text(t.category,
                            style: AppType.labelS.c(p.accentInk)),
                        const SizedBox(height: Gap.sm),
                        Text(t.body,
                            style: AppType.bodyM.c(p.inkMuted),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: Gap.md),
                        Divider(height: 1, color: p.lineSoft),
                        const SizedBox(height: Gap.sm),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 13, color: p.inkFaint),
                            const SizedBox(width: 5),
                            Text(Fmt.relative(t.createdAt),
                                style: AppType.labelS.c(p.inkMuted)),
                            const Spacer(),
                            Text('Response within 24 hrs',
                                style: AppType.labelS.c(p.inkFaint)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: tickets.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _raise(context, ref),
              backgroundColor: p.ink,
              foregroundColor: p.isDark ? p.canvas : Colors.white,
              elevation: 0,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('New ticket', style: AppType.labelM),
            ),
    );
  }

  static void _raise(BuildContext context, WidgetRef ref) {
    GFeedback.sheet<void>(
      context,
      title: 'Raise a ticket',
      subtitle: 'A workshop manager reads every one of these',
      child: const _TicketForm(),
    );
  }
}

class _TicketForm extends ConsumerStatefulWidget {
  const _TicketForm();

  @override
  ConsumerState<_TicketForm> createState() => _TicketFormState();
}

class _TicketFormState extends ConsumerState<_TicketForm> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _category = TicketsPage.categories.first;
  String? _bookingCode;

  bool get _valid =>
      _subject.text.trim().length >= 4 && _body.text.trim().length >= 10;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_valid) return;
    final t = ref.read(appControllerProvider.notifier).raiseTicket(
          subject: _subject.text.trim(),
          category: _category,
          body: _body.text.trim(),
          bookingCode: _bookingCode,
        );
    Navigator.of(context).pop();
    GFeedback.success(context, 'Ticket ${t.id} raised');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final bookings = ref.watch(bookingsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page,
          Gap.xxl + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CATEGORY', style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final c in TicketsPage.categories)
                ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  showCheckmark: false,
                  backgroundColor: p.surface,
                  selectedColor: p.ink,
                  side: BorderSide(color: _category == c ? p.ink : p.line),
                  labelStyle: AppType.labelM.c(_category == c
                      ? (p.isDark ? p.canvas : Colors.white)
                      : p.inkSoft),
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          GField(
            label: 'Subject',
            hint: 'One line about the problem',
            controller: _subject,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'What happened?',
            hint: 'Dates, amounts, who you spoke to — the more detail the faster '
                'we can fix it.',
            controller: _body,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
          ),
          if (bookings.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            GPickerField(
              label: 'Related booking (optional)',
              value: _bookingCode,
              placeholder: 'Not related to a booking',
              leadingIcon: Icons.receipt_long_rounded,
              onTap: () async {
                final code = await GFeedback.sheet<String>(
                  context,
                  title: 'Pick a booking',
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.page, Gap.lg, Gap.page, Gap.h1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final b in bookings.take(10))
                          GOptionRow(
                            label: b.code,
                            subtitle:
                                '${Fmt.date(b.slot)} • ${b.lines.isEmpty ? 'Service' : b.lines.first.name}',
                            selected: _bookingCode == b.code,
                            onTap: () => Navigator.of(context).pop(b.code),
                          ),
                      ],
                    ),
                  ),
                );
                if (code != null) setState(() => _bookingCode = code);
              },
            ),
          ],
          const SizedBox(height: Gap.xxl),
          GButton.accent(
            label: 'Submit ticket',
            onPressed: _valid ? _submit : null,
          ),
        ],
      ),
    );
  }
}
