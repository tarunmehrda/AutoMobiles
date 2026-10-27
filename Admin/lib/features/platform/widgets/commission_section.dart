import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/repo/garage_gateway.dart';
import '../../../data/repo/platform_gateway.dart';
import '../../../state/admin_state.dart';
import '../platform_page.dart' show toneForStatus;

/// The platform's commission screen: one partner at a time.
///
/// Pick a partner and only that partner's rate, balance and lines are on
/// screen; pick another and the first one's are gone. There is no list of
/// every partner's balance and no ledger of everybody's lines mixed together.
///
/// The database books a line by itself whenever a partner closes a job card
/// (19_commission_and_roles.sql): the rate times the bill before GST. This
/// screen reads it, sets the rate, and marks what has been paid. It records;
/// it does not charge. The customer is never charged anything.
class CommissionSection extends ConsumerStatefulWidget {
  const CommissionSection({super.key});

  @override
  ConsumerState<CommissionSection> createState() => _CommissionSectionState();
}

class _CommissionSectionState extends ConsumerState<CommissionSection> {
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  List<GarageCommission> _partners = const [];
  double _defaultPct = kDefaultCommissionPct;
  String? _selectedId;
  List<CommissionLine> _lines = const [];

  GarageCommission? get _selected =>
      _partners.where((g) => g.garageId == _selectedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gw = ref.read(platformGatewayProvider);
    final results = await Future.wait([gw.commissionSummary(), gw.settings()]);
    if (!mounted) return;
    final partners = results[0] as List<GarageCommission>?;
    setState(() {
      _failed = partners == null;
      _partners = partners ?? _partners;
      _defaultPct = (results[1] as PlatformSettings).commissionPct;
      if (_selected == null) _selectedId = _partners.firstOrNull?.garageId;
    });
    await _loadLines();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadLines() async {
    final id = _selectedId;
    if (id == null) return;
    final lines = await ref.read(platformGatewayProvider).commissions(id);
    // A slow answer for a partner no longer on screen is thrown away.
    if (!mounted || id != _selectedId) return;
    setState(() {
      _lines = lines ?? const [];
      if (lines == null) _failed = true;
    });
  }

  void _select(String? id) {
    if (id == null || id == _selectedId) return;
    setState(() {
      _selectedId = id;
      _lines = const [];
    });
    _loadLines();
  }

  /// Runs one write with the busy flag up, says what went wrong if anything
  /// did, and reloads on success.
  Future<void> _run(Future<String?> Function() write, {String? done}) async {
    setState(() => _busy = true);
    final error = await write();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      GFeedback.error(context, error);
      return;
    }
    if (done != null) GFeedback.success(context, done);
    await _load();
  }

  Future<void> _setStatus(CommissionLine line, String status) => _run(
        () => ref
            .read(platformGatewayProvider)
            .setCommissionStatus(line.id, status),
      );

  /// Asks for a rate inside the band. Null when the sheet was dismissed or
  /// the number was not one; [allowDefault] adds a way back to the default,
  /// returned as a negative number.
  Future<double?> _askRate({
    required String subtitle,
    required double current,
    bool allowDefault = false,
  }) async {
    final controller = TextEditingController(text: _pct(current));
    final picked = await GFeedback.sheet<String>(
      context,
      title: 'Commission rate',
      subtitle: subtitle,
      // Disposed by the sheet after its field is gone, not by this await.
      disposing: [controller],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: _RateEditor(
          controller: controller,
          allowDefault: allowDefault,
          defaultPct: _defaultPct,
        ),
      ),
    );
    if (picked == null) return null;
    if (picked == 'default') return -1;
    final value = double.tryParse(controller.text.trim());
    if (value == null ||
        value < kMinCommissionPct ||
        value > kMaxCommissionPct) {
      if (mounted) {
        GFeedback.error(
          context,
          'The rate must be between ${_pct(kMinCommissionPct)}% and '
          '${_pct(kMaxCommissionPct)}%.',
        );
      }
      return null;
    }
    return value;
  }

  Future<void> _editDefault() async {
    final value = await _askRate(
      subtitle: 'For every partner without a rate of their own',
      current: _defaultPct,
    );
    if (value == null || value < 0) return;
    await _run(
      () => ref
          .read(platformGatewayProvider)
          .saveSettings(commissionPct: value),
      done: 'Default rate is now ${_pct(value)}%.',
    );
  }

  Future<void> _editPartnerRate(GarageCommission g) async {
    final value = await _askRate(
      subtitle: g.name,
      current: g.rate,
      allowDefault: g.customRate != null,
    );
    if (value == null) return;
    final pct = value < 0 ? null : value;
    await _run(
      () => ref.read(platformGatewayProvider).setGarageRate(g.garageId, pct),
      done: pct == null
          ? '${g.name} is back on the default rate.'
          : '${g.name} is now charged ${_pct(pct)}%.',
    );
  }

  Future<void> _settle(GarageCommission g) async {
    final go = await GFeedback.confirm(
      context,
      title: 'Mark ${g.name} settled?',
      message: 'Use this once they have paid you ${Fmt.money(g.owed)}. '
          'Every open line of theirs is marked settled.',
      confirmLabel: 'Mark settled',
    );
    if (!go) return;
    await _run(
      () => ref.read(platformGatewayProvider).settleGarage(g.garageId),
      done: '${g.name} settled.',
    );
  }

  /// Booking a line by hand against the partner on screen, for something
  /// that was not a job card — a parts sale, a settlement agreed on the
  /// phone. Job cards book their own.
  Future<void> _add(GarageCommission garage) async {
    final amount = TextEditingController();
    final note = TextEditingController();

    final saved = await GFeedback.sheet<bool>(
      context,
      title: 'Record commission',
      subtitle: garage.name,
      // The controllers die with the sheet, not with this await: the route
      // keeps its fields mounted through the exit animation, and disposing
      // them here first is the `_dependents.isEmpty` red screen.
      disposing: [amount, note],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // keyboardType only asks for a numeric keypad; it refuses
              // nothing. A paste, a swipe keyboard or a hardware keyboard
              // all put letters in the field, and the parse below then
              // reads them as zero.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount before GST',
                prefixText: '₹ ',
                helperText: 'Commission at ${_pct(garage.rate)}%',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Gap.xl),
            Builder(
              builder: (context) => FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Record'),
              ),
            ),
          ],
        ),
      ),
    );

    final value = double.tryParse(amount.text.trim()) ?? 0;
    final text = note.text;

    // A number that will not parse, or a zero, used to close the sheet and
    // book nothing at all — no row, no error, nothing to tell the person
    // why the ledger did not move. Say so instead.
    if (saved == true && value <= 0) {
      if (!mounted) return;
      GFeedback.error(context, 'Enter an amount greater than zero.');
      return;
    }

    if (saved == true) {
      await _run(
        () => ref.read(platformGatewayProvider).bookCommission(
              garageId: garage.garageId,
              amount: value,
              note: text,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (_loading) return const _Skeleton();
    final g = _selected;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          color: p.accent,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
            children: [
              if (_failed) ...[
                _Failed(onRetry: _load),
                const SizedBox(height: Gap.md),
              ],
              if (g == null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 320),
                  child: const GEmptyState(
                    icon: Icons.handshake_outlined,
                    title: 'No partners yet',
                    message: 'Once a workshop registers and closes its first '
                        'job card, what it owes shows up here.',
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(g.garageId),
                  initialValue: g.garageId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Partner',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final x in _partners)
                      DropdownMenuItem(
                        value: x.garageId,
                        child: Text(
                          x.name.isEmpty ? 'Unnamed workshop' : x.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy ? null : _select,
                ),
                const SizedBox(height: Gap.md),
                _PartnerRow(
                  partner: g,
                  busy: _busy,
                  onRate: () => _editPartnerRate(g),
                  onSettle: g.owed > 0 ? () => _settle(g) : null,
                ),
                const SizedBox(height: Gap.xl),
                Text('LATEST LINES', style: AppType.over.c(p.inkFaint)),
                const SizedBox(height: Gap.sm),
                if (_lines.isEmpty)
                  Text(
                    'Nothing booked for ${g.name} yet.',
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                for (final line in _lines) ...[
                  _LineRow(
                    line: line,
                    busy: _busy,
                    onStatus: (s) => _setStatus(line, s),
                  ),
                  const SizedBox(height: Gap.sm),
                ],
              ],
              const SizedBox(height: Gap.xl),
              _RateCard(
                pct: _defaultPct,
                busy: _busy,
                onEdit: _editDefault,
              ),
              const SizedBox(height: Gap.md),
              const _Note(
                'Every job card a partner closes books its commission here '
                'by itself: the rate times the bill before GST. The customer '
                'is never charged. Collect from the partner, then mark them '
                'settled.',
              ),
            ],
          ),
        ),
        if (g != null)
          Positioned(
            right: Gap.page,
            bottom: Gap.page,
            child: FloatingActionButton.extended(
              onPressed: _busy ? null : () => _add(g),
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record'),
            ),
          ),
      ],
    );
  }
}

/// A workshop owner's own commission, and nothing of any other workshop's.
///
/// The database decides whose it is (`my_commission()`,
/// 21_private_commission.sql): the owner of this workshop gets its figures,
/// a staff login gets nothing. Read-only — the rate is the platform's.
class OwnCommissionView extends ConsumerStatefulWidget {
  const OwnCommissionView({super.key});

  @override
  ConsumerState<OwnCommissionView> createState() => _OwnCommissionViewState();
}

class _OwnCommissionViewState extends ConsumerState<OwnCommissionView> {
  bool _loading = true;
  bool _ok = false;
  GarageCommission? _mine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // The server's id first: a workshop registered on this phone and not
    // yet synced carries a phone-minted id the database cannot even parse.
    final gid = ref.read(garageGatewayProvider).garageId ??
        ref.read(adminProvider).garage?.id;
    final res = gid == null
        ? (ok: false, mine: null)
        : await ref.read(platformGatewayProvider).myCommission(gid);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _ok = res.ok;
      _mine = res.mine;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (_loading) return const _Skeleton();
    final mine = _mine;

    return RefreshIndicator(
      onRefresh: _load,
      color: p.accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
        children: [
          if (!_ok)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 320),
              child: GEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load the commission'.tr,
                message: 'Pull down to try again.'.tr,
              ),
            )
          else if (mine == null)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 320),
              child: GEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Only the owner can see this'.tr,
                message:
                    'Commission is private to the workshop owner.'.tr,
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'To pay'.tr,
                    value: Fmt.money(mine.owed),
                    tone: p.warning,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: _Stat(
                    label: 'Paid'.tr,
                    value: Fmt.money(mine.settled),
                    tone: p.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            _Note(
              '{0}% of each closed bill before GST. Set by the platform; your customers never pay or see it.'.trf([_pct(mine.rate)]),
            ),
            const SizedBox(height: Gap.xl),
            Text('Recent'.tr, style: AppType.over.c(p.inkFaint)),
            const SizedBox(height: Gap.sm),
            if (mine.recent.isEmpty)
              Text(
                'Nothing yet. Commission is booked when a job card is closed.'.tr,
                style: AppType.bodyS.c(p.inkMuted),
              ),
            for (final line in mine.recent) ...[
              _LineRow(line: line),
              const SizedBox(height: Gap.sm),
            ],
          ],
        ],
      ),
    );
  }
}

/// `3` for 3.00 and `2.5` for 2.50: a rate reads as the number it is.
String _pct(double v) =>
    v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(Gap.page),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
        itemBuilder: (_, _) => const GSkeleton(height: 92),
      );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onRetry,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(color: p.dangerSoft, borderRadius: R.rMd),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 16, color: p.danger),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                'Some of this could not be loaded. Tap to try again.',
                style: AppType.bodyS.c(p.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(color: p.infoSoft, borderRadius: R.rMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: p.info),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(text, style: AppType.bodyS.c(p.ink))),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.rLg,
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.labelS.c(p.inkMuted)),
          const SizedBox(height: Gap.xs),
          Text(value, style: AppType.moneyL.c(tone)),
        ],
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.pct,
    required this.busy,
    required this.onEdit,
  });

  final double pct;
  final bool busy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: busy ? null : onEdit,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.rLg,
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Default rate', style: AppType.labelM.c(p.ink)),
                  Text(
                    'Allowed ${_pct(kMinCommissionPct)}% to '
                    '${_pct(kMaxCommissionPct)}%. Only you can change it.',
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                ],
              ),
            ),
            Text('${_pct(pct)}%', style: AppType.h2.c(p.ink)),
            const SizedBox(width: Gap.xs),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _PartnerRow extends StatelessWidget {
  const _PartnerRow({
    required this.partner,
    required this.busy,
    required this.onRate,
    required this.onSettle,
  });

  final GarageCommission partner;
  final bool busy;
  final VoidCallback onRate;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final g = partner;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.rMd,
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Owes you', style: AppType.labelM.c(p.ink)),
              ),
              Text(
                Fmt.money(g.owed),
                style: AppType.money.c(g.owed > 0 ? p.warning : p.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            [
              '${g.lines} ${g.lines == 1 ? 'bill' : 'bills'}',
              '${Fmt.money(g.billed)} billed',
              if (g.settled > 0) '${Fmt.money(g.settled)} settled',
            ].join('  •  '),
            style: AppType.labelS.c(p.inkMuted),
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              _Chip(
                label: g.customRate == null
                    ? '${_pct(g.rate)}% (default)'
                    : '${_pct(g.rate)}% (own rate)',
                icon: Icons.percent_rounded,
                enabled: !busy,
                onTap: onRate,
              ),
              if (onSettle != null)
                _Chip(
                  label: 'Mark settled',
                  icon: Icons.check_rounded,
                  enabled: !busy,
                  onTap: onSettle!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      enabled: enabled,
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
        decoration: BoxDecoration(
          color: p.surfaceSunken,
          borderRadius: R.all(R.pill),
          border: Border.all(color: p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: p.inkMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.labelS.c(p.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One ledger line. [onStatus] is the platform's; without it the line is
/// read-only, which is how a workshop owner sees their own.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, this.busy = false, this.onStatus});

  final CommissionLine line;
  final bool busy;
  final ValueChanged<String>? onStatus;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final onStatus = this.onStatus;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.rMd,
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.note.isEmpty ? 'Commission' : line.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelM.c(p.ink),
                ),
              ),
              Text(Fmt.money(line.fee), style: AppType.money.c(p.ink)),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    '${Fmt.money(line.amount)} @ ${_pct(line.pct)}%',
                    if (line.at != null) Fmt.date(line.at!.toLocal()),
                  ].join('  •  '),
                  style: AppType.labelS.c(p.inkMuted),
                ),
              ),
              GPill(
                label: line.status,
                tone: toneForStatus(line.status),
                compact: true,
              ),
            ],
          ),
          if (onStatus != null &&
              line.status != 'settled' &&
              line.status != 'waived') ...[
            const SizedBox(height: Gap.md),
            Wrap(
              runSpacing: Gap.xs,
              children: [
                for (final next in const ['invoiced', 'settled', 'waived'])
                  if (next != line.status)
                    Padding(
                      padding: const EdgeInsets.only(right: Gap.xs),
                      child: Pressable(
                        enabled: !busy,
                        onTap: () => onStatus(next),
                        scale: 0.96,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Gap.md, vertical: Gap.xs),
                          decoration: BoxDecoration(
                            color: p.surfaceSunken,
                            borderRadius: R.all(R.pill),
                            border: Border.all(color: p.line),
                          ),
                          child: Text(next,
                              style: AppType.labelS.c(p.inkMuted)),
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The number, big, with the band under it. Pops `'save'`, or `'default'`
/// when [allowDefault] offers the way back to the platform default.
class _RateEditor extends StatelessWidget {
  const _RateEditor({
    required this.controller,
    required this.allowDefault,
    required this.defaultPct,
  });

  final TextEditingController controller;
  final bool allowDefault;
  final double defaultPct;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: AppType.d3.c(p.ink),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            suffixText: '%',
            suffixStyle: AppType.h2.c(p.inkMuted),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: Gap.lg),
        Text(
          'Between ${_pct(kMinCommissionPct)}% and ${_pct(kMaxCommissionPct)}% '
          'of the bill before GST. Applies to job cards closed from now on; '
          'bills already booked keep the rate they were booked at.',
          textAlign: TextAlign.center,
          style: AppType.bodyS.c(p.inkMuted),
        ),
        const SizedBox(height: Gap.xxl),
        FilledButton(
          onPressed: () => Navigator.of(context).pop('save'),
          child: const Text('Save rate'),
        ),
        if (allowDefault) ...[
          const SizedBox(height: Gap.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop('default'),
            child: Text('Use the default (${_pct(defaultPct)}%)'),
          ),
        ],
      ],
    );
  }
}
