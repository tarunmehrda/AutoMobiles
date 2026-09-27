import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../state/providers.dart';

/// Every customer the workshop has ever billed, with their vehicles and what
/// they have spent.
class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);
    final q = _query.trim().toLowerCase().replaceAll(' ', '');

    final customers =
        data.customers.where((c) {
          if (q.isEmpty) return true;
          final regs = data
              .vehiclesOf(c.id)
              .map((v) => v.regNo.toLowerCase().replaceAll(' ', ''))
              .join(' ');
          return c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              regs.contains(q);
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Customers'.tr,
        subtitle: '{0} on record'.trf([data.customers.length]),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.sm,
              Gap.page,
              Gap.lg,
            ),
            child: GSearchBar(
              hint: 'Name, phone or registration'.tr,
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              onClear: _query.isEmpty
                  ? null
                  : () {
                      _search.clear();
                      setState(() => _query = '');
                    },
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? GEmptyState(
                    icon: Icons.people_alt_rounded,
                    title: 'No customers yet'.tr,
                    art: Art.customers,
                    message:
                        'Open a job card and the customer is saved with it.'.tr,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      0,
                      Gap.page,
                      Gap.h2,
                    ),
                    itemCount: customers.length,
                    itemBuilder: (context, i) {
                      final c = customers[i];
                      final vehicles = data.vehiclesOf(c.id);
                      final cards = data.jobCards
                          .where((j) => j.customerId == c.id)
                          .toList();
                      final spend = cards.fold<double>(
                        0,
                        (s, j) => s + j.total,
                      );
                      final due = cards.fold<double>(
                        0,
                        (s, j) => s + j.balance,
                      );

                      return Entrance(
                        index: i.clamp(0, 8),
                        child: Pressable(
                          onTap: () => context.push('/customer/${c.id}'),
                          scale: 0.985,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: Gap.sm),
                            padding: const EdgeInsets.all(Gap.lg),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: R.all(R.md),
                              border: Border.all(color: p.line),
                              boxShadow: Shadows.soft(p),
                            ),
                            child: Row(
                              children: [
                                GAvatar(
                                  initials: Fmt.initials(c.name),
                                  size: 42,
                                  tone: GTone.neutral,
                                ),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppType.h2.c(p.ink),
                                      ),
                                      Text(
                                        c.phone,
                                        style: AppType.bodyS.c(p.inkMuted),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 5,
                                        runSpacing: 4,
                                        children: [
                                          GTag(
                                            label: Tr.plural(
                                              cards.length,
                                              '{0} visit',
                                              '{0} visits',
                                            ),
                                            outlined: true,
                                          ),
                                          for (final v in vehicles.take(2))
                                            GTag(
                                              label: Fmt.plate(v.regNo),
                                              icon:
                                                  Icons.directions_car_rounded,
                                              outlined: true,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Gap.sm),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Fmt.money(spend),
                                      style: AppType.money.s(15).c(p.ink),
                                    ),
                                    if (due > 0)
                                      Text(
                                        'Due {0}'.trf([Fmt.money(due)]),
                                        style: AppType.labelS
                                            .s(10.5)
                                            .c(p.danger),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
