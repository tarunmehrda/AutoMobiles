import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/books.dart';
import '../../data/models/enums.dart';
import '../../data/repo/admin_data.dart';
import '../../state/admin_state.dart';

// ---------------------------------------------------------------------------
// The pieces Sales, Purchase, Estimates and Bank & Cash all share, so a
// payment taken on any of them reads the same way and lands in the same
// account the same way.
// ---------------------------------------------------------------------------

/// The four ways money changes hands at a workshop counter. Card is left
/// off on purpose: a swipe settles into the bank exactly like net banking,
/// and the client's own list never had it.
const List<PayMode> kTradeModes = [
  PayMode.cash,
  PayMode.upi,
  PayMode.cheque,
  PayMode.netbanking,
];

/// Where money paid by [mode] lands when nobody says otherwise: cash in the
/// drawer, everything else in the primary bank — the same rule
/// [AdminData.accountOf] applies to a line that names no account, so what
/// the sheet shows is what the books will do.
String defaultAccountFor(AdminData d, PayMode mode) => mode == PayMode.cash
    ? kCashAccountId
    : (d.primaryBank?.id ?? kCashAccountId);

/// `1,500` or `1,500.50` — how an amount goes back into a field.
String plainAmount(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Upper-case caption over a group of controls, as on the expense sheet.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.sm),
    child: Text(text.toUpperCase(), style: AppType.over.c(context.c.inkFaint)),
  );
}

/// A row of pill chips — one choice out of a few, wrapping on a narrow
/// phone instead of scrolling out of sight.
class ChipChoice<T> extends StatelessWidget {
  const ChipChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.labelOf,
    this.iconOf,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelect;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final onInk = p.isDark ? p.canvas : Colors.white;
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final o in options)
          Pressable(
            onTap: () => onSelect(o),
            scale: 0.95,
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              decoration: BoxDecoration(
                color: o == selected ? p.ink : p.surfaceAlt,
                borderRadius: R.all(R.pill),
                border: Border.all(color: o == selected ? p.ink : p.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconOf?.call(o) case final icon?) ...[
                    Icon(
                      icon,
                      size: 15,
                      color: o == selected ? onInk : p.inkMuted,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    labelOf(o),
                    style: AppType.labelM.c(o == selected ? onInk : p.inkSoft),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Mode chips plus the account the money goes through. Changing the mode
/// moves the account to that mode's default, because a UPI receipt sitting
/// in the drawer is the mistake this exists to stop.
class PayControls extends ConsumerWidget {
  const PayControls({
    super.key,
    required this.mode,
    required this.accountId,
    required this.onChanged,
    this.showAccount = true,
  });

  final PayMode mode;
  final String? accountId;
  final void Function(PayMode mode, String accountId) onChanged;

  /// Off where the books pick the account themselves — a job card payment
  /// follows its mode.
  final bool showAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(adminProvider);
    final account = data.accountById(
      accountId ?? defaultAccountFor(data, mode),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Payment mode'.tr),
        ChipChoice<PayMode>(
          options: kTradeModes,
          selected: mode,
          labelOf: (m) => m.label,
          iconOf: (m) => m.icon,
          onSelect: (m) => onChanged(m, defaultAccountFor(data, m)),
        ),
        if (showAccount) ...[
          const SizedBox(height: Gap.lg),
          GPickerField(
            label: mode == PayMode.cash ? 'Account'.tr : 'Bank account'.tr,
            value: account == null
                ? null
                : '${account.title}  ·  ${Fmt.money(data.balanceOf(account))}',
            placeholder: 'Cash in Hand'.tr,
            leadingIcon: account?.cash ?? true
                ? Icons.payments_rounded
                : Icons.account_balance_rounded,
            onTap: () async {
              final picked = await pickAccount(context, selected: account?.id);
              if (picked != null) onChanged(mode, picked);
            },
          ),
        ],
      ],
    );
  }
}

/// Opens the list of accounts — the drawer first, then every bank with its
/// balance — and returns the id chosen.
Future<String?> pickAccount(
  BuildContext context, {
  String? selected,
  String? exclude,
}) {
  return GFeedback.sheet<String>(
    context,
    title: 'Choose account'.tr,
    subtitle: 'Where the money moves through'.tr,
    child: Consumer(
      builder: (context, ref, _) {
        final data = ref.watch(adminProvider);
        final all = [
          data.cashAccount,
          ...data.banks,
        ].where((a) => a.id != exclude).toList();
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.lg,
            Gap.page,
            Gap.h1,
          ),
          children: [
            for (final a in all)
              GOptionRow(
                label: a.title,
                subtitle: [
                  if (a.masked.isNotEmpty) a.masked,
                  Fmt.money(data.balanceOf(a)),
                  if (a.primary) 'Primary'.tr,
                ].join('  ·  '),
                icon: a.cash
                    ? Icons.payments_rounded
                    : Icons.account_balance_rounded,
                selected: a.id == selected,
                onTap: () => Navigator.of(context).pop(a.id),
              ),
            if (data.banks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: Text(
                  'Add a bank account under Bank & Cash to take UPI and cheques into it.'
                      .tr,
                  style: AppType.bodyS.c(context.c.inkMuted),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// A date shown as a field, opening the calendar on tap.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.first,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? placeholder;
  final DateTime? first;

  @override
  Widget build(BuildContext context) => GPickerField(
    label: label,
    value: value == null ? null : Fmt.date(value!),
    placeholder: placeholder ?? 'Select date'.tr,
    leadingIcon: Icons.event_rounded,
    icon: Icons.calendar_month_rounded,
    onTap: () async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? now,
        firstDate: first ?? DateTime(now.year - 5),
        lastDate: DateTime(now.year + 5),
      );
      if (picked == null) return;
      // Keep the time of day it was opened at, so two entries made the same
      // day still sort in the order they were made.
      final base = value ?? now;
      onChanged(
        DateTime(
          picked.year,
          picked.month,
          picked.day,
          base.hour,
          base.minute,
          base.second,
        ),
      );
    },
  );
}

/// Count, total and what is left unpaid — the strip at the top of every
/// Sales, Purchase and Estimates tab.
class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.cells});

  final List<({String label, String value, Color? tint})> cells;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) Container(height: 34, width: 1, color: p.line),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cells[i].value,
                        maxLines: 1,
                        style: AppType.money.s(17).c(cells[i].tint ?? p.ink),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cells[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppType.bodyS.s(11.5).c(p.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One document, payment or invoice in a list.
class DocRow extends StatelessWidget {
  const DocRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.icon,
    this.tint,
    this.pill,
    this.pillTone = GTone.neutral,
    this.amountTint,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String amount;
  final IconData? icon;
  final Color? tint;
  final String? pill;
  final GTone pillTone;
  final Color? amountTint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = tint ?? p.accent;
    return Pressable(
      onTap: onTap,
      enabled: onTap != null,
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
            if (icon != null) ...[
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: t.withValues(alpha: 0.12),
                  borderRadius: R.all(R.sm),
                ),
                child: Icon(icon, size: 18, color: t),
              ),
              const SizedBox(width: Gap.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: AppType.money.c(amountTint ?? p.ink)),
                if (pill != null) ...[
                  const SizedBox(height: 3),
                  GPill(label: pill!, tone: pillTone, compact: true),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A tab body: the strip, then the list, or the empty state when there is
/// nothing yet.
class TabList extends StatelessWidget {
  const TabList({
    super.key,
    required this.summary,
    required this.children,
    required this.emptyTitle,
    required this.emptyMessage,
    this.emptyArt = Art.invoice,
    this.emptyIcon = Icons.receipt_long_rounded,
  });

  final Widget summary;
  final List<Widget> children;
  final String emptyTitle;
  final String emptyMessage;
  final String emptyArt;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
      children: [
        Entrance(child: summary),
        const SizedBox(height: Gap.lg),
        if (children.isEmpty)
          GEmptyState(
            compact: true,
            icon: emptyIcon,
            art: emptyArt,
            title: emptyTitle,
            message: emptyMessage,
          )
        else
          for (var i = 0; i < children.length; i++)
            Entrance(index: (i + 1).clamp(0, 8), child: children[i]),
      ],
    );
  }
}

/// The chip row under a hub's header.
class HubTabs<T> extends StatelessWidget {
  const HubTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.labelOf,
    this.iconOf,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelect;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: GChoiceChips<T>(
      options: options,
      selected: selected,
      onSelect: onSelect,
      labelOf: labelOf,
      iconOf: iconOf,
    ),
  );
}

/// A searchable list in a sheet. Returns the item tapped, or — when
/// [freeText] is given — whatever was typed, wrapped by it.
Future<T?> pickFromList<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<T> items,
  required String Function(T) labelOf,
  String Function(T)? subtitleOf,
  String Function(T)? trailingOf,
  IconData icon = Icons.search_rounded,
  T Function(String typed)? freeText,
  String? emptyMessage,
}) {
  return GFeedback.sheet<T>(
    context,
    title: title,
    subtitle: subtitle,
    child: _SearchList<T>(
      items: items,
      labelOf: labelOf,
      subtitleOf: subtitleOf,
      trailingOf: trailingOf,
      icon: icon,
      freeText: freeText,
      emptyMessage: emptyMessage,
    ),
  );
}

class _SearchList<T> extends StatefulWidget {
  const _SearchList({
    required this.items,
    required this.labelOf,
    required this.icon,
    this.subtitleOf,
    this.trailingOf,
    this.freeText,
    this.emptyMessage,
  });

  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;
  final String Function(T)? trailingOf;
  final IconData icon;
  final T Function(String typed)? freeText;
  final String? emptyMessage;

  @override
  State<_SearchList<T>> createState() => _SearchListState<T>();
}

class _SearchListState<T> extends State<_SearchList<T>> {
  // Owned here, not by the caller: the sheet keeps rebuilding through its
  // exit transition, and a controller disposed beside the `await` would be
  // read after it died.
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              Gap.md,
            ),
            child: GSearchBar(
              hint: widget.freeText == null
                  ? 'Search'.tr
                  : 'Search or type a new one'.tr,
              controller: _controller,
              onClear: _controller.clear,
            ),
          ),
          Flexible(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => _results(value.text.trim()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(String raw) {
    final p = context.c;
    final q = raw.toLowerCase();
    bool hit(T e) =>
        widget.labelOf(e).toLowerCase().contains(q) ||
        (widget.subtitleOf?.call(e).toLowerCase().contains(q) ?? false);
    final matches = q.isEmpty ? widget.items : widget.items.where(hit).toList();
    final exact = widget.items.any((e) => widget.labelOf(e).toLowerCase() == q);
    final free = widget.freeText;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h1),
      children: [
        if (free != null && raw.isNotEmpty && !exact)
          _PickRow(
            label: 'Use "{0}"'.trf([raw]),
            subtitle: 'Not in the list — typed as is'.tr,
            icon: Icons.edit_rounded,
            onTap: () => Navigator.of(context).pop(free(raw)),
          ),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xl),
            child: Text(
              widget.emptyMessage ?? 'No match'.tr,
              textAlign: TextAlign.center,
              style: AppType.bodyM.c(p.inkMuted),
            ),
          )
        else
          for (final e in matches)
            _PickRow(
              label: widget.labelOf(e),
              subtitle: widget.subtitleOf?.call(e),
              trailing: widget.trailingOf?.call(e),
              icon: widget.icon,
              onTap: () => Navigator.of(context).pop(e),
            ),
      ],
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String label;
  final String? subtitle;
  final String? trailing;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: p.inkMuted),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                ],
              ),
            ),
            if (trailing != null && trailing!.isNotEmpty) ...[
              const SizedBox(width: Gap.sm),
              Text(trailing!, style: AppType.moneyS.c(p.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The padded, scrolling body every form sheet here sits in.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      Gap.page,
      Gap.lg,
      Gap.page,
      MediaQuery.of(context).padding.bottom + Gap.xl,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// "Cash · Cash in Hand" — how a cash-book line says where it went.
String accountLabel(AdminData d, String accountId) =>
    d.accountById(accountId)?.title ?? 'Cash in Hand'.tr;
