import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../shared/support_sheet.dart';
import '../trade/payment_sheets.dart';

/// Who the workshop buys parts from, and what is still owed to each of them.
class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
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
    final all = ref.watch(suppliersProvider);
    final owed = all.fold<double>(0, (s, e) => s + e.outstanding);
    final q = _query.trim().toLowerCase();
    final rows = q.isEmpty
        ? all
        : all
              .where(
                (s) => s.name.toLowerCase().contains(q) || s.phone.contains(q),
              )
              .toList();

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Suppliers'.tr,
        subtitle: owed > 0
            ? '{0} on record  ·  {1} owed'.trf([all.length, Fmt.money(owed)])
            : '{0} on record'.trf([all.length]),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
            child: GSearchBar(
              hint: 'Search suppliers'.tr,
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
            child: rows.isEmpty
                ? GEmptyState(
                    icon: Icons.local_shipping_rounded,
                    title: 'No suppliers yet'.tr,
                    art: Art.delivery,
                    message:
                        'Add the shops you buy parts from and purchase orders can be raised against them.'
                            .tr,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      0,
                      Gap.page,
                      Gap.h2,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => Entrance(
                      index: i.clamp(0, 8),
                      child: _Row(supplier: rows[i]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: 'Add Supplier'.tr,
          icon: Icons.add_rounded,
          onPressed: () => showSupplierSheet(context),
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final owes = supplier.outstanding > 0.009;
    return Pressable(
      // Tapping edits: a supplier's number or GSTIN changes, and the only way
      // to fix one used to be deleting it.
      onTap: () => showSupplierSheet(context, existing: supplier),
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
        child: Column(
          children: [
            Row(
              children: [
                GAvatar(
                  initials: Fmt.initials(supplier.name),
                  size: 42,
                  tone: GTone.info,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelL.c(p.ink),
                      ),
                      if (supplier.phone.isNotEmpty)
                        Text(
                          supplier.phone,
                          style: AppType.bodyS.c(p.inkMuted),
                        ),
                      if (supplier.gstin.isNotEmpty)
                        Text(
                          'GSTIN {0}'.trf([supplier.gstin]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelS.c(p.inkFaint),
                        ),
                    ],
                  ),
                ),
                if (supplier.phone.isNotEmpty)
                  Pressable(
                    // The shared dialler says so when there is nothing to dial
                    // with; `canLaunchUrl` used to answer no and the tap did
                    // nothing at all.
                    onTap: () => launchDial(context, supplier.phone),
                    scale: 0.9,
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: p.successSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.call_rounded,
                        size: 17,
                        color: p.success,
                      ),
                    ),
                  ),
                const SizedBox(width: Gap.sm),
                Pressable(
                  onTap: () async {
                    final ok = await GFeedback.confirm(
                      context,
                      title: 'Remove {0}?'.trf([supplier.name]),
                      message:
                          'Purchase orders already raised keep their name.'.tr,
                      confirmLabel: 'Remove'.tr,
                      destructive: true,
                      icon: Icons.delete_outline_rounded,
                    );
                    if (!ok) return;
                    ref
                        .read(adminProvider.notifier)
                        .removeSupplier(supplier.id);
                  },
                  scale: 0.9,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: p.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    owes
                        ? 'Outstanding {0}'.trf([
                            Fmt.money(supplier.outstanding),
                          ])
                        : 'Nothing outstanding'.tr,
                    style: AppType.labelM.c(owes ? p.danger : p.success),
                  ),
                ),
                if (owes)
                  GLink(
                    label: 'Pay'.tr,
                    icon: Icons.north_east_rounded,
                    onTap: () =>
                        showPayOutSheet(context, supplierId: supplier.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add a supplier — or, with [existing], correct one. Resolves to the
/// supplier saved, so a purchase bill can add one and carry straight on
/// with it selected.
Future<Supplier?> showSupplierSheet(
  BuildContext context, {
  Supplier? existing,
}) => showModalBottomSheet<Supplier>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (_) => _SupplierSheet(existing: existing),
);

class _SupplierSheet extends ConsumerStatefulWidget {
  const _SupplierSheet({this.existing});

  final Supplier? existing;

  @override
  ConsumerState<_SupplierSheet> createState() => _SupplierSheetState();
}

class _SupplierSheetState extends ConsumerState<_SupplierSheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _address = TextEditingController(text: widget.existing?.address);
  late final _gstin = TextEditingController(text: widget.existing?.gstin);

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _gstin]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Name and a full ten-digit number: a supplier nobody can call is one
  /// the counter cannot chase for a short delivery.
  bool get _valid =>
      _name.text.trim().isNotEmpty && _phone.text.trim().length == 10;

  void _save() {
    final ctrl = ref.read(adminProvider.notifier);
    final old = widget.existing;
    final Supplier saved;
    if (old == null) {
      saved = ctrl.addSupplier(
        name: _name.text,
        phone: _phone.text,
        address: _address.text,
        gstin: _gstin.text,
      );
    } else {
      saved = old.copyWith(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        gstin: _gstin.text.trim().toUpperCase(),
      );
      ctrl.updateSupplier(saved);
    }
    Navigator.of(context).pop(saved);
    GFeedback.success(
      context,
      old == null ? 'Supplier added'.tr : 'Supplier updated'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(R.xxl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.md,
              Gap.page,
              Gap.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 44,
                    decoration: BoxDecoration(
                      color: p.line,
                      borderRadius: R.all(R.pill),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                Text(
                  widget.existing == null
                      ? 'Add Supplier'.tr
                      : 'Edit Supplier'.tr,
                  style: AppType.h1.c(p.ink),
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Party Name / Firm Name *'.tr,
                  hint: 'Bharat Auto Parts'.tr,
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Contact No. *'.tr,
                  hint: '9876543210',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Address (optional)'.tr,
                  hint: '12, MG Road, Bengaluru'.tr,
                  controller: _address,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'GSTIN (optional)'.tr,
                  hint: '29ABCDE1234F1Z5',
                  controller: _gstin,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: Gap.xl),
                GButton.accent(
                  label: 'Save supplier'.tr,
                  onPressed: _valid ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
