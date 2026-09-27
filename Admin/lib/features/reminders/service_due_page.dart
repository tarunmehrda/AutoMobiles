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
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/repo/garage_gateway.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../shared/support_sheet.dart';

/// How far ahead the reminder list looks.
enum DueWindow { today, week, month, overdue }

extension on DueWindow {
  String get label => switch (this) {
    DueWindow.today => 'Today'.tr,
    DueWindow.week => 'This week'.tr,
    DueWindow.month => 'This month'.tr,
    DueWindow.overdue => 'Overdue'.tr,
  };

  /// Inclusive range for the chosen window, anchored on today.
  ({DateTime from, DateTime to}) range() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final endOfDay = start.add(const Duration(days: 1, microseconds: -1));
    return switch (this) {
      DueWindow.today => (from: start, to: endOfDay),
      DueWindow.week => (
        from: start,
        to: start.add(const Duration(days: 7, microseconds: -1)),
      ),
      DueWindow.month => (
        from: start,
        to: DateTime(
          now.year,
          now.month + 1,
          now.day,
        ).subtract(const Duration(microseconds: 1)),
      ),
      DueWindow.overdue => (
        from: DateTime(2000),
        to: start.subtract(const Duration(microseconds: 1)),
      ),
    };
  }
}

/// Service and insurance reminders, the two lists the counter works through
/// before opening the shutter.
class ServiceDuePage extends ConsumerStatefulWidget {
  const ServiceDuePage({super.key});

  @override
  ConsumerState<ServiceDuePage> createState() => _ServiceDuePageState();
}

class _ServiceDuePageState extends ConsumerState<ServiceDuePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));
  DueWindow _window = DueWindow.today;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickWindow() async {
    final picked = await showModalBottomSheet<DueWindow>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _WindowSheet(selected: _window),
    );
    if (picked != null) setState(() => _window = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final r = _window.range();
    final service = ref.watch(
      serviceDueRangeProvider((from: r.from, to: r.to)),
    );
    final insurance = ref.watch(
      insuranceDueRangeProvider((from: r.from, to: r.to)),
    );
    final count = _tabs.index == 0 ? service.length : insurance.length;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Service Due'.tr,
        subtitle: '$count in ${_window.label.toLowerCase()}',
        actions: [
          Pressable(
            onTap: _pickWindow,
            scale: 0.94,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: R.all(R.pill),
                border: Border.all(color: p.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_window.label, style: AppType.labelM.c(p.accentInk)),
                  Icon(Icons.expand_more_rounded, size: 17, color: p.accentInk),
                ],
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: p.ink,
          unselectedLabelColor: p.inkMuted,
          indicatorColor: p.accent,
          indicatorWeight: 2.5,
          labelStyle: AppType.labelL,
          unselectedLabelStyle: AppType.labelL,
          tabs: [
            Tab(text: 'Service Due (${service.length})'),
            Tab(text: 'Insurance Due (${insurance.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DueList(
            cards: service,
            empty: 'No Service Due',
            emptyBlurb:
                "Looks like you haven't carded any job card\nto your list yet.",
            dateOf: (j) => j.nextServiceAt,
            reason: 'service',
          ),
          _DueList(
            cards: insurance,
            empty: 'No Insurance Due',
            emptyBlurb: 'No policy is coming up for renewal in this window.',
            dateOf: (j) => j.createdAt.add(const Duration(days: 365)),
            reason: 'insurance renewal',
          ),
        ],
      ),
    );
  }
}

class _DueList extends ConsumerWidget {
  const _DueList({
    required this.cards,
    required this.empty,
    required this.emptyBlurb,
    required this.dateOf,
    required this.reason,
  });

  final List<JobCard> cards;
  final String empty;
  final String emptyBlurb;
  final DateTime? Function(JobCard) dateOf;
  final String reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cards.isEmpty) {
      return GEmptyState(
        icon: Icons.event_repeat_rounded,
        title: empty,
        art: Art.maintenance,
        message: emptyBlurb,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h2),
      itemCount: cards.length,
      itemBuilder: (context, i) => Entrance(
        index: i.clamp(0, 8),
        child: _DueRow(card: cards[i], due: dateOf(cards[i]), reason: reason),
      ),
    );
  }
}

class _DueRow extends ConsumerWidget {
  const _DueRow({required this.card, required this.due, required this.reason});

  final JobCard card;
  final DateTime? due;
  final String reason;

  /// Opens WhatsApp — or the SMS app, while WhatsApp is switched off in
  /// Settings — with the reminder already typed, for the counter to send.
  /// Through the shared launchers, which say so when there is no app to
  /// open; `canLaunchUrl` used to answer false and the tap did nothing.
  ///
  /// The link is what makes this worth more than a plain text message: the
  /// customer taps it and sees the car's job card — what was done and what
  /// it cost — without installing anything or signing in.
  ///
  /// Looking the link up costs one round trip, so the message is composed
  /// after it comes back, and goes without it if it does not. A reminder
  /// with no link still does its job; one that never went because the
  /// database was a migration behind does not.
  Future<void> _remind(
    BuildContext context,
    WidgetRef ref,
    String phone,
    String name,
    String vehicle, {
    required bool whatsapp,
  }) async {
    final link = await ref.read(garageGatewayProvider).shareLink(card.id);
    final text = StringBuffer(
      'Hi $name, your $vehicle is due for $reason. Shall we book a slot?',
    );
    if (link != null) text.write('\n\nYour last service: $link');
    if (!context.mounted) return;
    if (whatsapp) {
      await launchWhatsApp(context, phone, text: text.toString());
    } else {
      await launchSms(context, phone, body: text.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final customer = ref.watch(customerProvider(card.customerId));
    final vehicle = ref.watch(vehicleProvider(card.vehicleId));
    final whatsapp = ref.watch(
      adminProvider.select((s) => s.whatsappEnabled),
    );
    final late = due != null && due!.isBefore(DateTime.now());

    return Pressable(
      onTap: () => context.push('/job/${card.id}'),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?.name ?? 'Customer'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (vehicle != null) Fmt.plate(vehicle.regNo),
                      if (vehicle != null) vehicle.title,
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                  const SizedBox(height: Gap.sm),
                  GPill(
                    label: due == null
                        ? 'No date'.tr
                        : (late
                              ? 'Overdue · {0}'.trf([Fmt.date(due!)])
                              : 'Due {0}'.trf([Fmt.date(due!)])),
                    tone: late ? GTone.danger : GTone.warning,
                    compact: true,
                  ),
                ],
              ),
            ),
            if (customer != null && customer.phone.isNotEmpty)
              Pressable(
                onTap: () => _remind(
                  context,
                  ref,
                  customer.phone,
                  customer.name,
                  vehicle?.title ?? 'vehicle',
                  whatsapp: whatsapp,
                ),
                scale: 0.9,
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: p.successSoft,
                    borderRadius: R.all(R.sm),
                  ),
                  child: Icon(
                    whatsapp ? Icons.chat_rounded : Icons.sms_rounded,
                    size: 19,
                    color: p.success,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WindowSheet extends StatelessWidget {
  const _WindowSheet({required this.selected});

  final DueWindow selected;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xxl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.md),
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: p.line,
                borderRadius: R.all(R.pill),
              ),
            ),
            const SizedBox(height: Gap.lg),
            for (final w in DueWindow.values)
              ListTile(
                title: Text(w.label, style: AppType.labelL.c(p.ink)),
                trailing: w == selected
                    ? Icon(Icons.check_rounded, color: p.accent)
                    : null,
                onTap: () => Navigator.of(context).pop(w),
              ),
            const SizedBox(height: Gap.lg),
          ],
        ),
      ),
    );
  }
}
