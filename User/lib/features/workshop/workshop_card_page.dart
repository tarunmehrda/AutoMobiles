import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/workshop.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

/// The garage's job card, as the customer sees it.
///
/// Read-only on purpose: this is the workshop's document, mirrored here so
/// there is one version of the truth rather than two. Everything on it
/// updates live — a line ticked off at the counter lands here in under a
/// second, with no pull to refresh.
class WorkshopCardPage extends ConsumerWidget {
  const WorkshopCardPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final card = ref.watch(workshopCardProvider(id));

    if (card == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Job card'),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(Gap.page),
            child: GEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Not available',
              message:
                  'This job card is no longer shared with you. Ask the '
                  'workshop if you need a copy.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: card.number,
        subtitle: card.garageName.isEmpty ? null : card.garageName,
        actions: [
          if (card.garagePhone.trim().isNotEmpty)
            IconButton(
              tooltip: 'Call the workshop',
              icon: const Icon(Icons.call_rounded),
              onPressed: () => launchUrl(Uri.parse('tel:${card.garagePhone}')),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface,
        onRefresh: () =>
            ref.read(appControllerProvider.notifier).refreshWorkshop(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h3),
          children: [
            Entrance(child: _StatusCard(card: card)),
            const SizedBox(height: Gap.lg),
            if (card.items.isNotEmpty) ...[
              Entrance(index: 1, child: _WorkList(card: card)),
              const SizedBox(height: Gap.lg),
              Entrance(index: 2, child: _BillCard(card: card)),
              const SizedBox(height: Gap.lg),
            ],
            if (card.voices.isNotEmpty)
              Entrance(
                index: 3,
                child: _ListCard(
                  title: 'What you reported',
                  icon: Icons.record_voice_over_rounded,
                  lines: card.voices,
                ),
              ),
            if (card.accessories.isNotEmpty) ...[
              const SizedBox(height: Gap.lg),
              Entrance(
                index: 4,
                child: _ListCard(
                  title: 'Handed over with the car',
                  icon: Icons.inventory_2_rounded,
                  lines: card.accessories,
                ),
              ),
            ],
            if (card.workNote.trim().isNotEmpty) ...[
              const SizedBox(height: Gap.lg),
              Entrance(
                index: 5,
                child: _ListCard(
                  title: "The workshop's note",
                  icon: Icons.sticky_note_2_rounded,
                  lines: [card.workNote.trim()],
                ),
              ),
            ],
            const SizedBox(height: Gap.lg),
            Entrance(index: 6, child: _IntakeCard(card: card)),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.card});

  final WorkshopCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final ready = card.isComplete;
    final closed = card.isClosed;

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GPill(
                label: card.statusLabel.toUpperCase(),
                tone: closed
                    ? GTone.neutral
                    : (ready ? GTone.success : GTone.volt),
                dot: true,
                pulse: card.isOpen,
                compact: true,
              ),
              const Spacer(),
              Text('Opened ${Fmt.dateShort(card.openedAt)}',
                  style: AppType.labelS.copyWith(color: p.inkMuted)),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text(
            card.vehicleTitle.isEmpty ? card.regNo : card.vehicleTitle,
            style: AppType.h2.copyWith(color: p.ink),
          ),
          if (card.regNo.isNotEmpty && card.vehicleTitle.isNotEmpty)
            Text(card.regNo, style: AppType.labelM.copyWith(color: p.inkSoft)),
          if (card.mechanic.trim().isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Icon(Icons.engineering_rounded, size: 16, color: p.inkMuted),
                const SizedBox(width: Gap.xs),
                Expanded(
                  child: Text('On the car: ${card.mechanic}',
                      style: AppType.bodyS.copyWith(color: p.inkSoft)),
                ),
              ],
            ),
          ],
          if (card.promisedAt != null && !closed) ...[
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: p.inkMuted),
                const SizedBox(width: Gap.xs),
                Text('Promised ${Fmt.relative(card.promisedAt!)}',
                    style: AppType.bodyS.copyWith(color: p.inkSoft)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkList extends StatelessWidget {
  const _WorkList({required this.card});

  final WorkshopCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The work', style: AppType.h3.copyWith(color: p.ink)),
          const SizedBox(height: Gap.md),
          for (final line in card.items) _WorkRow(line: line),
        ],
      ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  const _WorkRow({required this.line});

  final WorkshopLine line;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final (icon, colour) = switch (line.state) {
      'done' => (Icons.check_circle_rounded, p.success),
      'running' => (Icons.autorenew_rounded, p.accent),
      'skipped' => (Icons.remove_circle_outline_rounded, p.inkFaint),
      _ => (Icons.radio_button_unchecked_rounded, p.inkFaint),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colour),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: AppType.bodyM.copyWith(
                    color: line.state == 'skipped' ? p.inkMuted : p.ink,
                    decoration: line.state == 'skipped'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (line.remark.trim().isNotEmpty)
                  Text(line.remark,
                      style: AppType.labelS.copyWith(color: p.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Text(Fmt.money(line.amount),
              style: AppType.moneyS.copyWith(color: p.inkSoft)),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.card});

  final WorkshopCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    Widget row(String label, double value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: (strong ? AppType.labelL : AppType.bodyS)
                        .copyWith(color: strong ? p.ink : p.inkSoft)),
              ),
              Text(
                Fmt.money2(value),
                style: (strong ? AppType.money : AppType.moneyS)
                    .copyWith(color: strong ? p.ink : p.inkSoft),
              ),
            ],
          ),
        );

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The bill', style: AppType.h3.copyWith(color: p.ink)),
          const SizedBox(height: Gap.sm),
          row('Subtotal', card.subTotal),
          if (card.discount > 0) row('Discount', -card.discount),
          if (card.tax > 0) row('Tax', card.tax),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Gap.sm),
            child: GDashedLine(),
          ),
          row('Total', card.total, strong: true),
          if (card.paid > 0) row('Paid', card.paid),
          if (card.balance > 0) ...[
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Expanded(
                  child: Text('Balance due',
                      style: AppType.labelL.copyWith(color: p.ink)),
                ),
                Text(Fmt.money2(card.balance),
                    style: AppType.money.copyWith(color: p.warning)),
              ],
            ),
          ] else if (card.items.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            GPill(label: 'SETTLED', tone: GTone.success, compact: true),
          ],
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.icon,
    required this.lines,
  });

  final String title;
  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: p.inkMuted),
              const SizedBox(width: Gap.sm),
              Text(title, style: AppType.labelL.copyWith(color: p.ink)),
            ],
          ),
          const SizedBox(height: Gap.md),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: Text('· $line',
                  style: AppType.bodyS.copyWith(color: p.inkSoft)),
            ),
        ],
      ),
    );
  }
}

class _IntakeCard extends StatelessWidget {
  const _IntakeCard({required this.card});

  final WorkshopCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    Widget fact(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppType.labelS.copyWith(color: p.inkMuted)),
            const SizedBox(height: Gap.xxs),
            Text(value, style: AppType.labelL.copyWith(color: p.ink)),
          ],
        );

    return GCard(
      child: Row(
        children: [
          Expanded(child: fact('Odometer', '${card.odometerKm} km')),
          Expanded(child: fact('Fuel', '${card.fuelPercent}%')),
          Expanded(
            child: fact(
              'Next service',
              card.nextServiceAt == null
                  ? '—'
                  : Fmt.dateShort(card.nextServiceAt!),
            ),
          ),
        ],
      ),
    );
  }
}
