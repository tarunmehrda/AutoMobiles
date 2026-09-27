import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repo/device_contacts.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// One row of the list: somebody from the phone, somebody from the customer
/// book, or somebody who is both.
typedef _Row = ({String name, String phone, String email, String? customerId});

/// The phone's address book, as the counter sees it.
///
/// The console could already pull a contact into a new job card, but only
/// from inside the create screen and only as a one-shot picker. This is the
/// book itself: searchable, marked up with who is already a customer, and
/// with the two things anybody at a counter actually wants to do with a
/// number — ring it, or open a card against it — one tap away.
class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  final _search = TextEditingController();

  /// Null while the first read is still running. [ContactsAccess] afterwards,
  /// which is what decides between the list and one of four dead ends.
  ContactsAccess? _access;
  List<ContactPick> _book = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Straight in. The permission dialog is the first thing somebody
    // arriving at this screen expects, and making them tap a button to
    // raise it is a step that explains nothing they did not already know
    // by opening a screen called Contacts.
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _access = null);
    final book = await DeviceContacts.read();
    if (!mounted) return;
    setState(() {
      _access = book.access;
      _book = book.people;
    });
  }

  /// The phone's book and the shop's book, merged on the number.
  ///
  /// The customer record wins where both have the same number: a shop that
  /// has served somebody knows their name better than whatever nickname
  /// the phone has them under.
  List<_Row> get _rows {
    final data = ref.read(adminDataProvider);
    final rows = <String, _Row>{};
    for (final c in data.customers) {
      final phone = c.phone.trim();
      if (phone.isEmpty) continue;
      rows[phone] = (
        name: c.name,
        phone: phone,
        email: c.email,
        customerId: c.id,
      );
    }
    for (final p in _book) {
      rows.putIfAbsent(
        p.phone,
        () => (name: p.name, phone: p.phone, email: p.email, customerId: null),
      );
    }

    final q = _query.trim().toLowerCase();
    final list =
        rows.values.where((r) {
          if (q.isEmpty) return true;
          return r.name.toLowerCase().contains(q) || r.phone.contains(q);
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    // Watched, not read: adding somebody as a customer from the sheet has to
    // repaint their row with its new pill.
    ref.watch(customersProvider);
    final rows = _rows;
    final fromPhone = _book.length;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Contacts'.tr,
        subtitle: _access == null
            ? 'Reading your phone…'.tr
            : '{0} shown · {1} in your phone'.trf([rows.length, fromPhone]),
        actions: [
          GIconButton(
            icon: Icons.refresh_rounded,
            size: 40,
            tooltip: 'Read again'.tr,
            onTap: _load,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.md,
                Gap.page,
                Gap.sm,
              ),
              child: GField(
                hint: 'Search by name or number'.tr,
                controller: _search,
                textCapitalization: TextCapitalization.none,
                prefix: Icon(Icons.search_rounded, size: 19, color: p.inkFaint),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(child: _body(rows)),
          ],
        ),
      ),
    );
  }

  Widget _body(List<_Row> rows) {
    if (_access == null) return const _Loading();

    // A refusal is not an empty book, and the difference is the whole of
    // what somebody can do next.
    switch (_access!) {
      case ContactsAccess.denied:
        return _Gate(
          icon: Icons.contacts_rounded,
          title: 'Contacts are not shared yet'.tr,
          message:
              'Allow contacts and the phone book appears here, with everyone you have already served marked as a customer.'
                  .tr,
          actionLabel: 'Allow contacts'.tr,
          onAction: _load,
        );
      case ContactsAccess.blocked:
        return _Gate(
          icon: Icons.lock_rounded,
          title: 'Contacts are blocked for this app'.tr,
          message:
              'They were refused for good, so the app can no longer ask. Open Settings, allow Contacts, then come back.'
                  .tr,
          actionLabel: 'Open Settings'.tr,
          onAction: () async {
            await DeviceContacts.openSettings();
            if (mounted) await _load();
          },
        );
      case ContactsAccess.failed:
        return _Gate(
          icon: Icons.error_outline_rounded,
          title: 'Could not read your contacts'.tr,
          message:
              'The phone refused the request. Try again, and if it keeps happening the customer book below still works.'
                  .tr,
          actionLabel: 'Try again'.tr,
          onAction: _load,
        );
      case ContactsAccess.unsupported:
      case ContactsAccess.ok:
        break;
    }

    if (rows.isEmpty) {
      return GEmptyState(
        icon: Icons.contacts_rounded,
        art: Art.customers,
        title: _query.isEmpty ? 'Nothing to show'.tr : 'No match'.tr,
        message: _query.isEmpty
            ? (_access == ContactsAccess.unsupported
                  ? 'This device has no address book. The customer book fills this screen once you open your first job card.'
                        .tr
                  : 'Your phone book is empty and no customers are on record yet.'
                        .tr)
            : 'Nobody here matches "{0}".'.trf([_query]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
      itemCount: rows.length,
      itemBuilder: (context, i) =>
          _ContactRow(row: rows[i], onTap: () => _actions(rows[i])),
    );
  }

  /// What the counter can do with a number, in the order it usually wants
  /// to do it.
  Future<void> _actions(_Row row) async {
    await GFeedback.sheet<void>(
      context,
      title: row.name,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GTileGroup(
              children: [
                GTile(
                  title: 'Call {0}'.trf([row.phone]),
                  icon: Icons.call_rounded,
                  iconColor: context.c.success,
                  onTap: () => _open(Uri.parse('tel:${row.phone}')),
                ),
                // Only while WhatsApp is switched on under Settings, the
                // same as on every other customer row.
                if (ref.read(adminProvider).whatsappEnabled)
                  GTile(
                    title: 'WhatsApp'.tr,
                    subtitle: 'Opens a chat with this number'.tr,
                    icon: Icons.chat_rounded,
                    iconColor: context.c.success,
                    onTap: () =>
                        _open(Uri.parse('https://wa.me/91${row.phone}')),
                  ),
                if (row.customerId != null)
                  GTile(
                    title: 'Open their customer record'.tr,
                    subtitle: 'History, vehicles and balance'.tr,
                    icon: Icons.person_rounded,
                    iconColor: context.c.accent,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/customer/${row.customerId}');
                    },
                  ),
                if (row.customerId == null)
                  GTile(
                    title: 'Save as a customer'.tr,
                    subtitle: 'Puts them on the book, ready for a job card'.tr,
                    icon: Icons.person_add_rounded,
                    iconColor: context.c.info,
                    onTap: () => _saveCustomer(row),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('No app on this phone can open that'.tr)),
    );
  }

  /// Puts somebody on the book and goes straight to their record, which is
  /// where a job card is opened from. Saving and then leaving them looking
  /// at the same list, one pill richer, would be a step that went nowhere.
  void _saveCustomer(_Row row) {
    final saved = ref
        .read(adminProvider.notifier)
        .upsertCustomer(name: row.name, phone: row.phone, email: row.email);
    Navigator.of(context).pop();
    GFeedback.success(context, '{0} is on the customer book'.trf([row.name]));
    context.push('/customer/${saved.id}');
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.row, required this.onTap});

  final _Row row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        margin: EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Row(
          children: [
            GAvatar(
              initials: Fmt.initials(row.name),
              size: 40,
              tone: row.customerId == null ? GTone.neutral : GTone.accent,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.h2.c(p.ink),
                  ),
                  Text(row.phone, style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
            if (row.customerId != null)
              GPill(label: 'Customer'.tr, tone: GTone.accent, compact: true),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => GSkeletonGroup(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
      children: [
        for (var i = 0; i < 8; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: Gap.sm),
            child: GSkeleton(height: 64, radius: R.md),
          ),
      ],
    ),
  );
}

/// A dead end with the way out attached.
class _Gate extends StatelessWidget {
  const _Gate({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Gap.page),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GEmptyState(
            icon: icon,
            art: Art.customers,
            title: title,
            message: message,
            compact: true,
          ),
          const SizedBox(height: Gap.lg),
          GButton.accent(
            label: actionLabel,
            size: GButtonSize.md,
            expand: false,
            onPressed: onAction,
          ),
        ],
      ),
    ),
  );
}
