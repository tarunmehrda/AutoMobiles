import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../data/models/marketplace.dart';
import '../../data/repo/marketplace_gateway.dart';
import 'widgets/listing_card.dart';
import 'widgets/listing_sheet.dart';

enum _Tab { browse, wanted, selling }

/// Parts — what is for sale, what this customer asked for, and what they
/// are selling.
///
/// Three lists rather than three screens, because all three are short and a
/// customer flips between "did my listing go live" and "did they price my
/// request" in the same thirty seconds.
class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  final _search = TextEditingController();
  Timer? _debounce;

  _Tab _tab = _Tab.browse;
  bool _loading = true;

  // Null is "could not load", which is not the same as an empty list: it
  // gets a Retry instead of "Nothing listed yet".
  List<PartListing>? _browse = const [];
  List<PartRequest>? _requests = const [];
  List<PartListing>? _mine = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final gw = ref.read(marketplaceGatewayProvider);
    // All three at once: the tabs are cheap, and a customer who taps straight
    // to "Selling" should not then wait for a list that could have been
    // fetched while they read the first one.
    final results = await Future.wait([
      gw.browse(query: _search.text),
      gw.myRequests(),
      gw.myListings(),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _browse = results[0] as List<PartListing>?;
      _requests = results[1] as List<PartRequest>?;
      _mine = results[2] as List<PartListing>?;
    });
  }

  /// "Mark sold" or "Withdraw" on one of the customer's own listings.
  ///
  /// The gateway has always allowed both and nothing called it, so a part
  /// sold at the counter stayed "Live" on everybody's browse screen. Asked
  /// first, because neither can be undone from the app.
  Future<void> _setStatus(PartListing l, ListingStatus to) async {
    final sold = to == ListingStatus.sold;
    final go = await GFeedback.confirm(
      context,
      title: sold ? 'Mark this part sold?' : 'Withdraw this listing?',
      message: sold
          ? 'It comes off the browse list and stays on yours as Sold.'
          : 'It comes off the browse list and stops being reviewed. '
              'You can list it again any time.',
      confirmLabel: sold ? 'Mark sold' : 'Withdraw',
      cancelLabel: 'Keep it',
      destructive: !sold,
    );
    if (!go || !mounted) return;
    final ok =
        await ref.read(marketplaceGatewayProvider).setListingStatus(l.id, to);
    if (!mounted) return;
    if (!ok) {
      GFeedback.error(
          context, 'Could not update that. Check your connection and try again.');
      return;
    }
    GFeedback.success(context, sold ? 'Marked as sold' : 'Listing withdrawn');
    unawaited(_load());
  }

  /// A failed load, with the way back. Shared by all three tabs.
  Widget _failed(VoidCallback retry) => GEmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load this",
        message: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: retry,
      );

  Future<void> _refreshBrowse() async {
    final rows =
        await ref.read(marketplaceGatewayProvider).browse(query: _search.text);
    if (!mounted) return;
    setState(() => _browse = rows);
  }

  void _onTyped(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _refreshBrowse);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: const GHeader(title: 'Parts'),
      floatingActionButton: _tab == _Tab.selling
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/parts/sell');
                if (mounted) unawaited(_load());
              },
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Sell a part'),
            )
          : _tab == _Tab.wanted
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await context.push('/parts/need');
                    if (mounted) unawaited(_load());
                  },
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('I need a part'),
                )
              : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
            child: GSegmented<_Tab>(
              options: _Tab.values,
              selected: _tab,
              onSelect: (t) => setState(() => _tab = t),
              labelOf: (t) => switch (t) {
                _Tab.browse => 'Browse',
                _Tab.wanted => 'Wanted',
                _Tab.selling => 'Selling',
              },
            ),
          ),
          if (_tab == _Tab.browse) ...[
            const SizedBox(height: Gap.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: GSearchBar(
                hint: 'Part name, number or vehicle',
                controller: _search,
                onChanged: _onTyped,
                onClear: _search.text.isEmpty
                    ? null
                    : () {
                        _search.clear();
                        _refreshBrowse();
                      },
              ),
            ),
          ],
          Expanded(child: _body(p)),
        ],
      ),
    );
  }

  Widget _body(AppPalette p) {
    if (_loading) {
      return ListView.separated(
        padding: const EdgeInsets.all(Gap.page),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
        itemBuilder: (_, _) => const GSkeleton(height: 96),
      );
    }
    return switch (_tab) {
      _Tab.browse => _browseList(p),
      _Tab.wanted => _wantedList(p),
      _Tab.selling => _sellingList(p),
    };
  }

  Widget _browseList(AppPalette p) {
    final browse = _browse;
    if (browse == null) return _failed(_load);
    if (browse.isEmpty) {
      return GEmptyState(
        icon: Icons.storefront_outlined,
        title: _search.text.trim().isEmpty
            ? 'Nothing listed yet'
            : 'No parts matched',
        message: _search.text.trim().isEmpty
            ? 'When people list parts for sale they will show up here.'
            : 'Try a different part name, or the part number.',
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshBrowse,
      color: p.accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
        itemCount: browse.length,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
        itemBuilder: (context, i) => Entrance(
          index: i.clamp(0, 8),
          child: ListingCard(
            listing: browse[i],
            onTap: () async {
              final asked = await showListingSheet(context, ref, browse[i]);
              if (asked && mounted) unawaited(_load());
            },
          ),
        ),
      ),
    );
  }

  Widget _wantedList(AppPalette p) {
    final requests = _requests;
    if (requests == null) return _failed(_load);
    if (requests.isEmpty) {
      return const GEmptyState(
        icon: Icons.build_circle_outlined,
        title: 'No requests yet',
        message: 'Looking for a part you cannot find? Tell us what you need '
            'and we will source it and quote you.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: p.accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
        itemCount: requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
        itemBuilder: (context, i) => Entrance(
          index: i.clamp(0, 8),
          child: _RequestCard(request: requests[i]),
        ),
      ),
    );
  }

  Widget _sellingList(AppPalette p) {
    final mine = _mine;
    if (mine == null) return _failed(_load);
    if (mine.isEmpty) {
      return const GEmptyState(
        icon: Icons.sell_outlined,
        title: 'Nothing for sale',
        message: 'Got a part sitting in the garage? List it and we will put '
            'it in front of people looking for one.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: p.accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
        itemCount: mine.length,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
        itemBuilder: (context, i) {
          final l = mine[i];
          // Only while it is still in play: a rejected, sold or withdrawn
          // listing has nothing left to take back.
          final open = l.status == ListingStatus.pending ||
              l.status == ListingStatus.approved;
          return Entrance(
            index: i.clamp(0, 8),
            child: ListingCard(
              listing: l,
              showStatus: true,
              footer: !open
                  ? null
                  : Row(
                      children: [
                        Expanded(
                          child: GButton(
                            label: 'Mark sold',
                            icon: Icons.sell_rounded,
                            kind: GButtonKind.outline,
                            size: GButtonSize.sm,
                            onPressed: () =>
                                _setStatus(l, ListingStatus.sold),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: GButton(
                            label: 'Withdraw',
                            icon: Icons.undo_rounded,
                            kind: GButtonKind.ghost,
                            size: GButtonSize.sm,
                            onPressed: () =>
                                _setStatus(l, ListingStatus.withdrawn),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// One "I need this part" request, with its code and where it has got to.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final PartRequest request;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tone = switch (request.status) {
      RequestStatus.completed => GTone.success,
      RequestStatus.cancelled => GTone.neutral,
      RequestStatus.processing => GTone.info,
      RequestStatus.pending => GTone.warning,
    };

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
          Row(
            children: [
              Expanded(
                child: Text(
                  request.partName.isEmpty ? 'Part request' : request.partName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.h3.c(p.ink),
                ),
              ),
              const SizedBox(width: Gap.sm),
              GPill(label: request.status.label, tone: tone, compact: true),
            ],
          ),
          if (request.vehicleText.isNotEmpty) ...[
            const SizedBox(height: Gap.xxs),
            Text(request.vehicleText, style: AppType.bodyS.c(p.inkMuted)),
          ],
          const SizedBox(height: Gap.md),
          Row(
            children: [
              // The code, which is the thing the customer is here to read.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md, vertical: Gap.xs),
                decoration: BoxDecoration(
                  color: p.surfaceSunken,
                  borderRadius: R.rSm,
                  border: Border.all(color: p.line),
                ),
                child: Text(request.code, style: AppType.labelM.c(p.ink)),
              ),
              const Spacer(),
              if (request.quote != null)
                Text(Fmt.money(request.quote!),
                    style: AppType.money.c(p.success)),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            request.note.isNotEmpty ? request.note : request.status.blurb,
            style: AppType.bodyS.c(p.inkMuted),
          ),
        ],
      ),
    );
  }
}
