import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import 'widgets/job_card_tile.dart';

/// The three buckets behind one segmented control, so the counter can flick
/// between them without losing the search term.
class JobCardListPage extends ConsumerStatefulWidget {
  const JobCardListPage({super.key, this.initial = JobStatus.open});

  final JobStatus initial;

  @override
  ConsumerState<JobCardListPage> createState() => _JobCardListPageState();
}

class _JobCardListPageState extends ConsumerState<JobCardListPage> {
  late JobStatus _status = widget.initial;
  final _search = TextEditingController();
  String _query = '';

  @override
  void didUpdateWidget(covariant JobCardListPage old) {
    super.didUpdateWidget(old);
    // A tap on a dashboard counter re-enters this route with a new status.
    if (old.initial != widget.initial) _status = widget.initial;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<JobCard> _filter(List<JobCard> cards) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return cards;
    final data = ref.read(adminProvider);
    return cards.where((c) {
      final customer = data.customerById(c.customerId);
      final vehicle = data.vehicleById(c.vehicleId);
      return [
        c.number,
        customer?.name ?? '',
        customer?.phone ?? '',
        vehicle?.regNo ?? '',
        vehicle?.title ?? '',
      ].any((f) => f.toLowerCase().replaceAll(' ', '').contains(
            q.replaceAll(' ', ''),
          ));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final all = ref.watch(bucketProvider(_status));
    final cards = _filter(all);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.sm, Gap.page, Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Job cards', style: AppType.d2.c(p.ink)),
                        Text(_status.blurb,
                            style: AppType.bodyS.c(p.inkMuted)),
                      ],
                    ),
                  ),
                  GPill(
                    label: '${all.length}',
                    tone: GTone.neutral,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: GSegmented<JobStatus>(
                options: JobStatus.values,
                selected: _status,
                onSelect: (s) => setState(() => _status = s),
                labelOf: (s) => s.label,
                iconOf: (s) => s.icon,
              ),
            ),
            const SizedBox(height: Gap.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: GSearchBar(
                hint: 'Number, name, phone or registration',
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
            const SizedBox(height: Gap.lg),
            Expanded(
              child: cards.isEmpty
                  ? GEmptyState(
                      icon: _status.icon,
                      title: _query.isEmpty
                          ? 'No ${_status.label.toLowerCase()} job cards'
                          : 'Nothing matches that',
                      message: _query.isEmpty
                          ? _status.blurb
                          : 'Try the job card number, the customer name or '
                              'the registration.',
                      actionLabel: _query.isEmpty ? 'Create job card' : null,
                      onAction: () => context.push('/job/new'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, 0, Gap.page, 110),
                      itemCount: cards.length + 1,
                      itemBuilder: (context, i) {
                        if (i == cards.length) return _Footer(cards: cards);
                        return Entrance(
                          index: i.clamp(0, 8),
                          child: JobCardTile(
                            card: cards[i],
                            stampStatus: _status,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Totals for whatever is currently on screen — useful when the list is
/// filtered down to one customer or one day.
class _Footer extends StatelessWidget {
  const _Footer({required this.cards});

  final List<JobCard> cards;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final billed = cards.fold<double>(0, (s, c) => s + c.total);
    final due = cards.fold<double>(0, (s, c) => s + c.balance);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Row(
        children: [
          Text('${cards.length} shown',
              style: AppType.labelS.c(p.inkFaint)),
          const Spacer(),
          Text('Billed ${Fmt.money(billed)}',
              style: AppType.labelS.c(p.inkMuted)),
          if (due > 0) ...[
            const SizedBox(width: Gap.md),
            Text('Due ${Fmt.money(due)}',
                style: AppType.labelS.c(p.danger)),
          ],
        ],
      ),
    );
  }
}
