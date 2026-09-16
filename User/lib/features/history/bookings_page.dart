import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_state.dart';
import '../../data/models/enums.dart';
import '../../state/providers.dart';
import 'widgets/booking_card.dart';

class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 4, vsync: this, initialIndex: widget.initialTab);

  static const _statuses = [
    BookingStatus.upcoming,
    BookingStatus.active,
    BookingStatus.completed,
    BookingStatus.cancelled,
  ];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final all = ref.watch(bookingsProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'My bookings',
        subtitle: '${all.length} in total',
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          tabs: [
            for (final s in _statuses)
              Tab(
                height: 46,
                text:
                    '${s.label} (${all.where((b) => b.status == s).length})',
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final s in _statuses)
            _list(all.where((b) => b.status == s).toList()..sort((a, b) =>
                s == BookingStatus.upcoming
                    ? a.slot.compareTo(b.slot)
                    : b.slot.compareTo(a.slot)), s),
        ],
      ),
    );
  }

  Widget _list(List bookings, BookingStatus status) {
    if (bookings.isEmpty) {
      return GEmptyState(
        icon: switch (status) {
          BookingStatus.upcoming => Icons.event_available_rounded,
          BookingStatus.active => Icons.build_circle_rounded,
          BookingStatus.completed => Icons.task_alt_rounded,
          BookingStatus.cancelled => Icons.event_busy_rounded,
        },
        title: 'No ${status.label.toLowerCase()} bookings',
        message: switch (status) {
          BookingStatus.upcoming =>
            'Book a service and it will show up here with its slot and status.',
          BookingStatus.active =>
            'When your car is with us you can follow every step live from here.',
          BookingStatus.completed =>
            'Finished jobs, invoices and warranties will be collected here.',
          BookingStatus.cancelled =>
            'Cancelled bookings are kept for your records. Nothing here yet.',
        },
        actionLabel: status == BookingStatus.upcoming ? 'Book a service' : null,
        onAction: () => context.go('/book'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h2),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
      itemBuilder: (context, i) =>
          BookingCard(booking: bookings[i], index: i),
    );
  }
}
