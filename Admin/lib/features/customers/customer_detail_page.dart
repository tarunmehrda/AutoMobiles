import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../state/providers.dart';
import '../jobcard/widgets/job_card_tile.dart';
import '../shared/support_sheet.dart';
import 'widgets/link_code_sheet.dart';

/// One customer: how to reach them, what they drive, and every visit.
class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);
    final customer = data.customerById(id);

    if (customer == null) {
      return const Scaffold(
        appBar: GHeader(title: 'Customer'),
        body: GEmptyState(
          icon: Icons.person_off_rounded,
          title: 'Customer not found',
          message: 'They may have been removed.',
        ),
      );
    }

    final vehicles = data.vehiclesOf(id);
    final cards = data.jobCards.where((j) => j.customerId == id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final spend = cards.fold<double>(0, (s, j) => s + j.total);
    final due = cards.fold<double>(0, (s, j) => s + j.balance);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(title: customer.name, subtitle: customer.phone),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          // --- reach them ------------------------------------------------
          Row(
            children: [
              Expanded(
                child: GButton(
                  label: 'Call',
                  kind: GButtonKind.ghost,
                  size: GButtonSize.md,
                  icon: Icons.call_rounded,
                  onPressed: () => launchDial(context, customer.phone),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: GButton(
                  label: 'WhatsApp',
                  kind: GButtonKind.ghost,
                  size: GButtonSize.md,
                  icon: Icons.chat_rounded,
                  onPressed: () =>
                      launchWhatsApp(context, customer.phone),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: GButton(
                  label: 'Link app',
                  kind: GButtonKind.ghost,
                  size: GButtonSize.md,
                  icon: Icons.link_rounded,
                  onPressed: () => LinkCodeSheet.open(
                    context,
                    customerId: customer.id,
                    name: customer.name,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),

          // --- lifetime --------------------------------------------------
          GCard(
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                      label: 'Visits', value: '${cards.length}'),
                ),
                Expanded(
                  child:
                      _Stat(label: 'Billed', value: Fmt.money(spend)),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Due',
                    value: Fmt.money(due),
                    color: due > 0 ? p.danger : p.success,
                  ),
                ),
              ],
            ),
          ),

          // --- vehicles --------------------------------------------------
          const GSectionHeader(
            title: 'Vehicles',
            padding: EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
          ),
          if (vehicles.isEmpty)
            Text('No vehicle on record.',
                style: AppType.bodyS.c(p.inkFaint))
          else
            for (final v in vehicles)
              Pressable(
                onTap: () => context.push('/job/new?vehicle=${v.id}'),
                scale: 0.985,
                child: Container(
                  margin: const EdgeInsets.only(bottom: Gap.sm),
                  padding: const EdgeInsets.all(Gap.lg),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: R.all(R.md),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car_rounded,
                          size: 22, color: p.inkMuted),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.title, style: AppType.labelL.c(p.ink)),
                            Text(
                              '${Fmt.plate(v.regNo)} • ${v.fuel.label}'
                              '${v.year == null ? '' : ' • ${v.year}'}',
                              style: AppType.bodyS.c(p.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      GTag(
                        label: 'New card',
                        icon: Icons.add_rounded,
                        tone: GTone.accent,
                      ),
                    ],
                  ),
                ),
              ),

          // --- history ---------------------------------------------------
          GSectionHeader(
            title: 'Visit history',
            subtitle: cards.isEmpty ? null : '${cards.length} job cards',
            padding: const EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
          ),
          if (cards.isEmpty)
            Text('Nothing billed yet.', style: AppType.bodyS.c(p.inkFaint))
          else
            for (final card in cards) JobCardTile(card: card),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppType.over.s(9.5).c(p.inkFaint)),
        const SizedBox(height: 3),
        Text(value, style: AppType.money.s(16).c(color ?? p.ink)),
      ],
    );
  }
}
