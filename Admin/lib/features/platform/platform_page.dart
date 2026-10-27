import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repo/garage_gateway.dart';
import '../../data/repo/platform_gateway.dart';
import '../../state/admin_state.dart';
import 'widgets/content_section.dart';
import 'widgets/heads_section.dart';
import 'widgets/listing_review_card.dart';
import 'widgets/partner_filters.dart';
import 'widgets/register_card.dart';
import 'widgets/request_card.dart';

enum PlatformTab { register, requests, listings, content, heads }

extension on PlatformTab {
  String get label => switch (this) {
        PlatformTab.register => 'Partners',
        PlatformTab.requests => 'Requests',
        PlatformTab.listings => 'Listings',
        PlatformTab.content => 'Media',
        PlatformTab.heads => 'Heads',
      };
}

/// One page, two doors.
///
/// * Buy & Sell (`/platform`, the dashboard tile): Requests and Listings
///   only. A partner head sees every one; a garage owner sees only those
///   addressed to their workshop.
/// * Platform (`/platform/admin`, Settings → Platform): Partners, Content and
///   Heads — the platform's business, for partner heads (27_partner_heads.sql)
///   only. Anybody else who reaches it by URL is told so and sees nothing.
///
/// Commission is not here: it is shown in one place only, Settings →
/// Commission, one partner at a time.
class PlatformPage extends ConsumerStatefulWidget {
  const PlatformPage({super.key, this.admin = false, this.initialTab});

  /// True for Settings → Platform, false for Buy & Sell.
  final bool admin;

  /// Where to open, e.g. Settings → Media lands on the Media tab.
  final PlatformTab? initialTab;

  @override
  ConsumerState<PlatformPage> createState() => _PlatformPageState();
}

class _PlatformPageState extends ConsumerState<PlatformPage> {
  late PlatformTab _tab =
      widget.initialTab ??
      (widget.admin ? PlatformTab.register : PlatformTab.requests);
  bool _loading = true;

  List<RegisteredGarage> _garages = const [];
  List<PlatformRequest> _requests = const [];
  List<PlatformListing> _listings = const [];
  PlatformSettings _settings = const PlatformSettings();

  /// Active / Non-active, then State → District → PIN, on the Partners tab.
  PartnerFilter _filter = const PartnerFilter();

  /// Null until the role check answers; the page shows its skeleton until
  /// then rather than flashing the wrong set of tabs.
  bool? _platform;

  /// True when something on the page could not be read. Every list used to
  /// come back empty on a failure, so a dead connection read as "No
  /// partners yet" and "Nothing to review".
  bool _failed = false;

  List<PlatformTab> get _tabs => switch ((_platform, widget.admin)) {
        (null, _) || (false, true) => const [],
        (true, true) => const [
            PlatformTab.register,
            PlatformTab.content,
            PlatformTab.heads,
          ],
        (_, false) => const [PlatformTab.requests, PlatformTab.listings],
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final gw = ref.read(platformGatewayProvider);
    // Asked afresh on every open: another head may have switched this one
    // off (or back on) since the answer was cached. If it cannot be asked,
    // the last answer stands and the page says something failed, rather
    // than dropping a head to the owner's two tabs over a bad connection.
    final cached = ref.read(isPlatformAdminProvider).valueOrNull;
    final fresh = await gw.checkPlatformAdmin();
    if (!mounted) return;
    if (fresh != null && fresh != cached) {
      ref.invalidate(isPlatformAdminProvider);
    }
    final platform = fresh ?? cached ?? _platform ?? false;
    final checkFailed = fresh == null;

    if (!platform) {
      // A garage owner: only what is addressed to their workshop.
      final gid = ref.read(adminProvider).garage?.id ??
          ref.read(garageGatewayProvider).garageId;
      final requests = await gw.requests(garageId: gid ?? '-');
      final listings = await gw.listings(garageId: gid ?? '-');
      if (!mounted) return;
      setState(() {
        _platform = false;
        _loading = false;
        _failed = checkFailed || requests == null || listings == null;
        _requests = requests ?? _requests;
        _listings = listings ?? _listings;
        if (_tabs.isNotEmpty && !_tabs.contains(_tab)) _tab = _tabs.first;
      });
      return;
    }

    final results = await Future.wait([
      gw.garages(),
      gw.requests(),
      gw.listings(),
      gw.settings(),
    ]);
    if (!mounted) return;
    setState(() {
      _platform = true;
      _loading = false;
      _failed = checkFailed || results.any((r) => r == null);
      _garages = results[0] as List<RegisteredGarage>? ?? _garages;
      _requests = results[1] as List<PlatformRequest>? ?? _requests;
      _listings = results[2] as List<PlatformListing>? ?? _listings;
      _settings = results[3] as PlatformSettings;
    });
  }

  /// How many listings are waiting on a decision — the one number on this
  /// screen that is somebody else waiting for the platform, so it is the one
  /// worth putting on the tab.
  int get _pendingListings =>
      _listings.where((l) => l.status == 'pending').length;

  int get _openRequests =>
      _requests.where((r) => r.status == 'pending').length;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: widget.admin ? 'Platform' : 'Buy & Sell',
        subtitle: widget.admin
            ? (_platform == true ? '${_garages.length} partners' : null)
            : _platform == false
                ? 'Parts requested from and offered to your workshop'
                : 'Every part request and listing',
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              itemCount: _tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
              itemBuilder: (context, i) {
                final t = _tabs[i];
                final badge = switch (t) {
                  PlatformTab.listings => _pendingListings,
                  PlatformTab.requests => _openRequests,
                  _ => 0,
                };
                return _TabChip(
                  label: t.label,
                  badge: badge,
                  on: _tab == t,
                  onTap: () => setState(() => _tab = t),
                );
              },
            ),
          ),
          if (_tab == PlatformTab.register && _platform == true && !_loading)
            PartnerFilterBar(
              garages: _garages,
              filter: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          if (_failed && !_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.md, Gap.page, 0),
              child: Pressable(
                onTap: _load,
                child: Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: p.dangerSoft,
                    borderRadius: R.rMd,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 16, color: p.danger),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          'Some of this could not be loaded. Tap to try '
                          'again.',
                          style: AppType.bodyS.c(p.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? ListView.separated(
                    padding: const EdgeInsets.all(Gap.page),
                    itemCount: 5,
                    separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                    itemBuilder: (_, _) => const GSkeleton(height: 92),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: p.accent,
                    child: _body(p),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _body(AppPalette p) => _tabs.isEmpty
      ? _list(
          empty: const GEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Partner heads only',
            message: 'Partners, media and heads are run by the platform.',
          ),
          count: 0,
          builder: (_) => const SizedBox.shrink(),
        )
      : _tabBody();

  Widget _tabBody() => switch (_tab) {
        PlatformTab.register => _partners(),
        PlatformTab.requests => _list(
            empty: const GEmptyState(
              icon: Icons.build_circle_outlined,
              title: 'No part requests',
              message: 'When a customer asks for a part you cannot find in '
                  'stock, it lands here with a code.',
            ),
            count: _requests.length,
            builder: (i) => RequestCard(
              request: _requests[i],
              garages: _garages,
              onChanged: _load,
            ),
          ),
        PlatformTab.listings => _list(
            empty: const GEmptyState(
              icon: Icons.sell_outlined,
              title: 'Nothing to review',
              message: 'Parts people list for sale wait here until you '
                  'approve them.',
            ),
            count: _listings.length,
            builder: (i) => ListingReviewCard(
              listing: _listings[i],
              onChanged: _load,
            ),
          ),
        PlatformTab.content => ContentSection(
            settings: _settings,
            onChanged: _load,
          ),
        PlatformTab.heads => const HeadsSection(),
      };

  Widget _partners() {
    final shown = _filter.apply(_garages);
    return _list(
      empty: _garages.isEmpty
          ? const GEmptyState(
              icon: Icons.handshake_outlined,
              title: 'No partners yet',
              message: 'Workshops that register from the customer app appear '
                  'here for you to verify and list.',
            )
          : _filter.narrowed
              ? const GEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No partners here',
                  message: 'Nobody on this side matches that State, '
                      'District and PIN code. Clear the filters to see all.',
                )
              : _filter.active
                  ? const GEmptyState(
                      icon: Icons.block_rounded,
                      title: 'Every partner is blocked',
                      message: 'Unblock one from Non-active to bring it back.',
                    )
                  : const GEmptyState(
                      icon: Icons.verified_user_outlined,
                      title: 'Nobody is blocked',
                      message: 'Partners you block appear here, ready to '
                          'unblock.',
                    ),
      count: shown.length,
      builder: (i) => RegisterCard(
        key: ValueKey(shown[i].id),
        garage: shown[i],
        onChanged: _load,
      ),
    );
  }

  Widget _list({
    required Widget empty,
    required int count,
    required Widget Function(int) builder,
  }) {
    if (count == 0) {
      // Still scrollable, so pull-to-refresh works on an empty list — which
      // is exactly when somebody wants to refresh.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // A floor, not a ceiling: at a large font the empty state is taller
        // than 320 and grows instead of overflowing.
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: empty,
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
      itemBuilder: (context, i) =>
          Entrance(index: i.clamp(0, 8), child: builder(i)),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.on,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? p.accent : p.surface,
          borderRadius: R.all(R.pill),
          border: Border.all(color: on ? p.accent : p.line),
        ),
        child: Row(
          children: [
            Text(label,
                style: AppType.labelM.c(on ? p.onAccent : p.inkMuted)),
            if (badge > 0) ...[
              const SizedBox(width: Gap.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm, vertical: 1),
                decoration: BoxDecoration(
                  color: on ? p.onAccent.withValues(alpha: 0.22) : p.dangerSoft,
                  borderRadius: R.all(R.pill),
                ),
                child: Text(
                  '$badge',
                  style: AppType.labelS.c(on ? p.onAccent : p.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared by the sections below — the money column every list has.
String platformMoney(num v) => Fmt.money(v);

/// Shared tone mapping, so a status reads the same colour on every screen.
GTone toneForStatus(String status) => switch (status) {
      'approved' || 'completed' || 'settled' => GTone.success,
      'rejected' || 'cancelled' => GTone.danger,
      'processing' || 'invoiced' || 'sold' => GTone.info,
      'pending' || 'accrued' => GTone.warning,
      _ => GTone.neutral,
    };

/// A labelled text field used across the platform sheets.
Widget platformField({
  required String label,
  String? hint,
  TextEditingController? controller,
  TextInputType? keyboardType,
  int maxLines = 1,
}) =>
    GField(
      label: label,
      hint: hint,
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
