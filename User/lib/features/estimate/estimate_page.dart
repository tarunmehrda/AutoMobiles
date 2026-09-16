import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../data/seed/media.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class EstimatePage extends ConsumerStatefulWidget {
  const EstimatePage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<EstimatePage> createState() => _EstimatePageState();
}

class _EstimatePageState extends ConsumerState<EstimatePage> {
  Set<String>? _selected;
  bool _submitting = false;

  Set<String> _initialSelection(Estimate estimate) => {
        for (final i in estimate.items)
          if (i.approved || (i.condition == Condition.replace && !i.approved))
            i.id
      };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final booking = ref.watch(bookingProvider(widget.bookingId));
    final estimate = ref.watch(latestEstimateProvider(widget.bookingId));
    final versions = ref.watch(estimatesProvider(widget.bookingId));

    if (booking == null || estimate == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Estimate'),
        body: GEmptyState(
          icon: Icons.request_quote_rounded,
          title: 'No estimate yet',
          message:
              'Once the inspection is done, any recommended work is quoted here '
              'before a spanner is touched.',
          actionLabel: 'Back to booking',
          onAction: () => context.pop(),
        ),
      );
    }

    _selected ??= _initialSelection(estimate);
    final locked = estimate.status != EstimateStatus.pending;
    final selected = _selected!;
    final selectedTotal = estimate.items
        .where((i) => selected.contains(i.id))
        .fold(0, (s, i) => s + i.total);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Estimate v${estimate.version}',
        subtitle: locked
            ? estimate.status.label
            : '${estimate.items.length} recommended items',
        actions: [
          if (versions.length > 1)
            GIconButton(
              icon: Icons.history_rounded,
              size: 40,
              tooltip: 'Version history',
              onTap: () => _showVersions(versions),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          // --- revision banner -----------------------------------------
          if (estimate.isRevision)
            Entrance(child: _RevisionBanner(estimate: estimate)),
          if (estimate.isRevision) const SizedBox(height: Gap.lg),

          // --- gate explanation ----------------------------------------
          Entrance(
            index: 1,
            child: Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                color: locked ? p.successSoft : p.accentSoft,
                borderRadius: R.all(R.lg),
                border: Border.all(
                    color: (locked ? p.success : p.accent)
                        .withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    locked
                        ? Icons.verified_rounded
                        : Icons.pan_tool_alt_rounded,
                    size: 20,
                    color: locked ? p.success : p.accentInk,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locked
                              ? 'Approved ${estimate.approvedAt == null ? '' : Fmt.relative(estimate.approvedAt!).toLowerCase()}'
                              : 'Work is on hold until you decide',
                          style: AppType.labelL
                              .c(locked ? p.success : p.accentInk),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          locked
                              ? 'Recorded against ${estimate.approvedBy ?? 'your account'} on '
                                  '${estimate.approvedAt == null ? '—' : Fmt.fullDateTime(estimate.approvedAt!)}'
                              : 'Tick only the items you want done. Everything you leave '
                                  'unticked will not be touched or charged.',
                          style: AppType.bodyS.c(
                              (locked ? p.success : p.accentInk)
                                  .withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- bulk actions --------------------------------------------
          if (!locked) ...[
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                Expanded(
                  child: GButton(
                    label: 'Select all',
                    kind: GButtonKind.ghost,
                    size: GButtonSize.sm,
                    onPressed: () => setState(() =>
                        _selected = estimate.items.map((e) => e.id).toSet()),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: GButton(
                    label: 'Only urgent',
                    kind: GButtonKind.ghost,
                    size: GButtonSize.sm,
                    onPressed: () => setState(() => _selected = {
                          for (final i in estimate.items)
                            if (i.condition == Condition.replace) i.id
                        }),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: GButton(
                    label: 'Clear',
                    kind: GButtonKind.ghost,
                    size: GButtonSize.sm,
                    onPressed: () => setState(() => _selected = {}),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: Gap.xl),

          // --- items -----------------------------------------------------
          for (var i = 0; i < estimate.items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: _EstimateItemCard(
                item: estimate.items[i],
                index: i,
                locked: locked,
                selected: locked
                    ? estimate.items[i].approved
                    : selected.contains(estimate.items[i].id),
                onToggle: locked
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          final s = {...selected};
                          if (!s.remove(estimate.items[i].id)) {
                            s.add(estimate.items[i].id);
                          }
                          _selected = s;
                        });
                      },
              ),
            ),

          // --- totals -----------------------------------------------------
          const SizedBox(height: Gap.md),
          GCard(
            child: Column(
              children: [
                GKeyValue(
                  label: 'All recommended items',
                  value: Fmt.money(estimate.total),
                ),
                GKeyValue(
                  label: locked ? 'Approved' : 'Selected now',
                  value: Fmt.money(locked ? estimate.approvedTotal : selectedTotal),
                  valueColor: p.accentInk,
                ),
                GKeyValue(
                  label: 'Declined',
                  value: Fmt.money(estimate.total -
                      (locked ? estimate.approvedTotal : selectedTotal)),
                  valueColor: p.inkMuted,
                ),
                const SizedBox(height: Gap.sm),
                const GDashedLine(),
                const SizedBox(height: Gap.sm),
                GKeyValue(
                  label: 'Booked package',
                  value: Fmt.money(booking.subtotal),
                ),
                GKeyValue(
                  label: 'New job total (before tax)',
                  value: Fmt.money(booking.subtotal +
                      (locked ? estimate.approvedTotal : selectedTotal)),
                  emphasize: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Icon(Icons.gavel_rounded, size: 15, color: p.inkFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your approval is timestamped and stored with this job card. '
                  'Any later change needs a fresh estimate and a fresh approval.',
                  style: AppType.bodyS.c(p.inkFaint),
                ),
              ),
            ],
          ),

          if (!locked) ...[
            const SizedBox(height: Gap.xl),
            GButton(
              label: 'Talk to the advisor first',
              kind: GButtonKind.outline,
              expand: true,
              icon: Icons.call_rounded,
              onPressed: () async {
                final uri = Uri.parse('tel:${Seed.garage.phone}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ],
        ],
      ),
      bottomNavigationBar: locked
          ? (booking.stage == JobStage.repairInProgress
              ? GBottomBar(
                  child: GButton(
                    label: 'Back to live tracking',
                    icon: Icons.timeline_rounded,
                    onPressed: () => context.pop(),
                  ),
                )
              : null)
          : GBottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('${selected.length} of ${estimate.items.length} selected',
                          style: AppType.labelM.c(p.inkMuted)),
                      const Spacer(),
                      Text(Fmt.money(selectedTotal),
                          style: AppType.money.c(p.ink)),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Expanded(
                        child: GButton(
                          label: 'Decline',
                          kind: GButtonKind.danger,
                          onPressed: _submitting ? null : () => _submit(const {}),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        flex: 2,
                        child: GButton.accent(
                          label: selected.isEmpty
                              ? 'Select items to approve'
                              : 'Approve ${selected.length} item${selected.length == 1 ? '' : 's'}',
                          loading: _submitting,
                          onPressed: selected.isEmpty
                              ? null
                              : () => _submit(selected),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _submit(Set<String> ids) async {
    final estimate = ref.read(latestEstimateProvider(widget.bookingId));
    if (estimate == null) return;

    final declining = ids.isEmpty;
    final total = estimate.items
        .where((i) => ids.contains(i.id))
        .fold(0, (s, i) => s + i.total);

    final ok = await GFeedback.confirm(
      context,
      title: declining ? 'Decline all extra work?' : 'Confirm approval',
      message: declining
          ? 'We will only complete the package you originally booked. You can '
              'still approve items later while the car is with us.'
          : 'You are approving ${ids.length} item${ids.length == 1 ? '' : 's'} '
              'worth ${Fmt.money(total)} plus taxes. Work starts immediately.',
      confirmLabel: declining ? 'Decline all' : 'Yes, approve',
      cancelLabel: 'Go back',
      destructive: declining,
      icon: declining ? Icons.block_rounded : Icons.how_to_reg_rounded,
    );
    if (!ok || !mounted) return;

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    ref
        .read(appControllerProvider.notifier)
        .approveEstimate(widget.bookingId, ids);
    HapticFeedback.mediumImpact();
    setState(() => _submitting = false);

    GFeedback.success(
      context,
      declining ? 'Extra work declined' : 'Approved — work has started',
    );
  }

  void _showVersions(List<Estimate> versions) {
    GFeedback.sheet<void>(
      context,
      title: 'Estimate history',
      subtitle: 'Every revision is kept, nothing is overwritten',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in versions.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: GCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Version ${v.version}',
                              style: AppType.labelL.c(context.c.ink)),
                          const SizedBox(width: Gap.sm),
                          GPill(
                            label: v.status.label,
                            tone: v.status == EstimateStatus.pending
                                ? GTone.warning
                                : GTone.success,
                            compact: true,
                          ),
                          const Spacer(),
                          Text(Fmt.money(v.total),
                              style: AppType.money.c(context.c.ink)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${v.items.length} items • ${Fmt.fullDateTime(v.createdAt)}',
                        style: AppType.bodyS.c(context.c.inkMuted),
                      ),
                      if (v.reason != null) ...[
                        const SizedBox(height: 4),
                        Text('Reason: ${v.reason}',
                            style: AppType.bodyS.c(context.c.warning)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RevisionBanner extends StatelessWidget {
  const _RevisionBanner({required this.estimate});

  final Estimate estimate;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final previous = estimate.previousTotal ?? 0;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.warningSoft,
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.update_rounded, size: 19, color: p.warning),
              const SizedBox(width: Gap.sm),
              Text('Estimate updated to v${estimate.version}',
                  style: AppType.labelL.c(p.warning)),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PREVIOUS', style: AppType.over.s(9).c(p.warning)),
                  Text(
                    Fmt.money(previous),
                    style: AppType.money.c(p.warning).copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: p.warning,
                        ),
                  ),
                ],
              ),
              const SizedBox(width: Gap.lg),
              Icon(Icons.arrow_forward_rounded, size: 18, color: p.warning),
              const SizedBox(width: Gap.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEW', style: AppType.over.s(9).c(p.warning)),
                  Text(Fmt.money(estimate.total),
                      style: AppType.money.c(p.warning)),
                ],
              ),
            ],
          ),
          if (estimate.reason != null) ...[
            const SizedBox(height: Gap.md),
            Text(estimate.reason!, style: AppType.bodyM.c(p.warning)),
          ],
          const SizedBox(height: Gap.sm),
          Text(
            'Only the newly added items need your approval. Previously approved '
            'work continues.',
            style: AppType.bodyS.c(p.warning.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _EstimateItemCard extends StatelessWidget {
  const _EstimateItemCard({
    required this.item,
    required this.index,
    required this.selected,
    required this.locked,
    this.onToggle,
  });

  final EstimateItem item;
  final int index;
  final bool selected;
  final bool locked;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final urgent = item.condition == Condition.replace;
    final tone = urgent ? GTone.danger : GTone.warning;
    final t = toneOf(context, tone);

    return Entrance(
      index: index,
      stagger: const Duration(milliseconds: 45),
      child: GCard(
        padding: EdgeInsets.zero,
        onTap: onToggle,
        borderColor: selected ? p.accent : null,
        child: Column(
          children: [
            if (item.isNew)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg, vertical: 5),
                color: p.warning.withValues(alpha: 0.14),
                child: Row(
                  children: [
                    Icon(Icons.fiber_new_rounded, size: 14, color: p.warning),
                    const SizedBox(width: 5),
                    Text('ADDED IN THIS REVISION',
                        style: AppType.over.s(9).c(p.warning)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: Motion.fast,
                        height: 24,
                        width: 24,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: selected ? p.accent : Colors.transparent,
                          borderRadius: R.all(7),
                          border: Border.all(
                            color: selected
                                ? p.accent
                                : (locked ? p.line : p.inkFaint),
                            width: 1.8,
                          ),
                        ),
                        child: selected
                            ? Icon(Icons.check_rounded,
                                size: 15, color: p.onAccent)
                            : null,
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: AppType.h3.c(p.ink)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                GPill(
                                  label: urgent ? 'Needs doing' : 'Can wait',
                                  tone: tone,
                                  compact: true,
                                  icon: urgent
                                      ? Icons.priority_high_rounded
                                      : Icons.schedule_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(Fmt.money(item.total),
                          style: AppType.money.c(p.ink)),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.md, vertical: Gap.sm),
                    decoration: BoxDecoration(
                      color: p.surfaceSunken,
                      borderRadius: R.all(R.sm),
                    ),
                    child: Row(
                      children: [
                        _split(context, 'Parts', item.parts),
                        Container(
                            height: 22,
                            width: 1,
                            color: p.line,
                            margin: const EdgeInsets.symmetric(
                                horizontal: Gap.md)),
                        _split(context, 'Labour', item.labour),
                        const Spacer(),
                        Flexible(
                          child: Text('incl. in final bill',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: AppType.labelS.s(10).c(p.inkFaint)),
                        ),
                      ],
                    ),
                  ),
                  if (item.note != null) ...[
                    const SizedBox(height: Gap.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.engineering_rounded,
                            size: 15, color: t.fg),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(item.note!,
                              style: AppType.bodyS.c(p.inkMuted)),
                        ),
                      ],
                    ),
                  ],
                  if (urgent) ...[
                    const SizedBox(height: Gap.md),
                    ClipRRect(
                      borderRadius: R.all(R.sm),
                      child: Image.asset(
                        Media.workshop,
                        height: 108,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _split(BuildContext context, String label, int amount) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppType.over.s(8.5).c(p.inkFaint)),
        Text(Fmt.money(amount), style: AppType.moneyS.c(p.inkSoft)),
      ],
    );
  }
}
