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
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../data/models/entities.dart';
import '../../state/providers.dart';
import '../jobcard/widgets/job_card_tile.dart';
import '../jobcard/widgets/ledger_tabs.dart';
import '../shared/support_sheet.dart';

/// The two follow-up lists a workshop lives or dies by: money still owed,
/// and customers due back for a service.
class PendingPage extends ConsumerStatefulWidget {
  const PendingPage({super.key});

  @override
  ConsumerState<PendingPage> createState() => _PendingPageState();
}

enum _Tab { balance, due }

class _PendingPageState extends ConsumerState<PendingPage> {
  _Tab _tab = _Tab.balance;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final pending = ref.watch(pendingBalanceProvider);
    final total = ref.watch(pendingTotalProvider);
    final due = ref.watch(serviceDueProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: const GHeader(title: 'Follow up'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Gap.page, Gap.sm, Gap.page, Gap.md),
            child: GSegmented<_Tab>(
              options: _Tab.values,
              selected: _tab,
              onSelect: (t) => setState(() => _tab = t),
              labelOf: (t) => t == _Tab.balance
                  ? 'Balance (${pending.length})'
                  : 'Service due (${due.length})',
            ),
          ),
          if (_tab == _Tab.balance && pending.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg, vertical: Gap.md),
                decoration: BoxDecoration(
                  gradient: p.inverseGradient,
                  borderRadius: R.all(R.lg),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OUTSTANDING',
                            style: AppType.over
                                .s(9.5)
                                .c(p.onInverse.withValues(alpha: 0.55))),
                        const SizedBox(height: 2),
                        Text(Fmt.money(total),
                            style: AppType.moneyL.c(p.volt)),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Across\n${pending.length} job card'
                      '${pending.length == 1 ? '' : 's'}',
                      textAlign: TextAlign.right,
                      style: AppType.bodyS
                          .c(p.onInverse.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _tab == _Tab.balance
                ? _BalanceList(cards: pending)
                : _DueList(cards: due),
          ),
        ],
      ),
    );
  }
}

class _BalanceList extends ConsumerWidget {
  const _BalanceList({required this.cards});

  final List<JobCard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cards.isEmpty) {
      return const GEmptyState(
        icon: Icons.verified_rounded,
        title: 'Everything is collected',
        message: 'No job card is carrying a balance right now.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final card = cards[i];
        return Entrance(
          index: i.clamp(0, 8),
          child: Column(
            children: [
              JobCardTile(card: card),
              Padding(
                padding: const EdgeInsets.only(left: 74, bottom: Gap.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: GButton(
                        label: 'Collect ${Fmt.money(card.balance)}',
                        kind: GButtonKind.ghost,
                        size: GButtonSize.sm,
                        icon: Icons.payments_rounded,
                        onPressed: () =>
                            showCollectSheet(context, ref, card),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    _RemindButton(card: card),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DueList extends ConsumerWidget {
  const _DueList({required this.cards});

  final List<JobCard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    if (cards.isEmpty) {
      return const GEmptyState(
        icon: Icons.event_available_rounded,
        title: 'Nobody is due today',
        message: 'Service reminders appear here on the day they fall due.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final card = cards[i];
        final customer = ref.watch(customerProvider(card.customerId));
        final vehicle = ref.watch(vehicleProvider(card.vehicleId));
        return Entrance(
          index: i.clamp(0, 8),
          child: Container(
            margin: const EdgeInsets.only(bottom: Gap.md),
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: R.all(R.lg),
              border: Border.all(color: p.line),
              boxShadow: Shadows.soft(p),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer?.name ?? 'Unknown',
                              style: AppType.h2.c(p.ink)),
                          Text(
                            '${vehicle?.title ?? ''} • '
                            '${Fmt.plate(vehicle?.regNo ?? '')}',
                            style: AppType.bodyS.c(p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    GPill(
                      label: 'Due ${Fmt.friendlyDay(card.nextServiceAt!)}',
                      tone: GTone.warning,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Expanded(
                      child: GButton(
                        label: 'Call',
                        kind: GButtonKind.ghost,
                        size: GButtonSize.sm,
                        icon: Icons.call_rounded,
                        onPressed: customer == null
                            ? null
                            : () => launchDial(context, customer.phone),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: GButton(
                        label: 'WhatsApp',
                        kind: GButtonKind.ghost,
                        size: GButtonSize.sm,
                        icon: Icons.chat_rounded,
                        onPressed: customer == null
                            ? null
                            : () => launchWhatsApp(
                                  context,
                                  customer.phone,
                                  text: 'Hello ${customer.name}, your '
                                      '${vehicle?.title ?? 'vehicle'} is due '
                                      'for service. Shall we book a slot?',
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RemindButton extends ConsumerWidget {
  const _RemindButton({required this.card});

  final JobCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerProvider(card.customerId));
    return Expanded(
      child: GButton(
        label: 'Remind',
        kind: GButtonKind.ghost,
        size: GButtonSize.sm,
        icon: Icons.chat_rounded,
        onPressed: customer == null
            ? null
            : () => launchWhatsApp(
                  context,
                  customer.phone,
                  text: 'Hello ${customer.name}, a balance of '
                      '${Fmt.money(card.balance)} is pending against job card '
                      '${card.number}. Thank you.',
                ),
      ),
    );
  }
}
