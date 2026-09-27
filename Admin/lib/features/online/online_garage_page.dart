import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// The workshop's public page. Off by default; turning it on mints the share
/// link and opens the list of services the customer will see.
class OnlineGaragePage extends ConsumerStatefulWidget {
  const OnlineGaragePage({super.key});

  @override
  ConsumerState<OnlineGaragePage> createState() => _OnlineGaragePageState();
}

class _OnlineGaragePageState extends ConsumerState<OnlineGaragePage> {
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
    final garage = ref.watch(garageProvider);
    final on = ref.watch(onlineGarageOnProvider);
    final link = ref.watch(onlineLinkProvider);
    final shareText = ref.watch(onlineShareTextProvider);
    final services = ref.watch(onlineServicesProvider);

    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? services
        : services.where((s) => s.name.toLowerCase().contains(q)).toList();

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'My Online Garage'.tr,
        actions: [
          GIconButton(
            icon: Icons.help_outline_rounded,
            size: 40,
            onTap: () => GFeedback.info(
              context,
              'Customers get the app from this link, find you by name and book a slot.'
                  .tr,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- the switch --------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      (garage?.name ?? 'Workshop'.tr).toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                      style: AppType.h1.c(p.ink),
                    ),
                  ),
                ),
                Text(
                  'Disable'.tr,
                  style: AppType.labelM.c(on ? p.inkFaint : p.danger),
                ),
                const SizedBox(width: Gap.sm),
                Switch(
                  value: on,
                  activeThumbColor: Colors.white,
                  activeTrackColor: p.info,
                  onChanged: (v) {
                    HapticFeedback.mediumImpact();
                    ref.read(adminProvider.notifier).setOnlineGarage(v);
                  },
                ),
                SizedBox(width: Gap.sm),
                Text(
                  'Enable'.tr,
                  style: AppType.labelM.c(on ? p.success : p.inkFaint),
                ),
              ],
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.base,
              switchInCurve: Motion.emphasized,
              // Not the default transition builder. That one keys its
              // `FadeTransition` off the child's key, and `AnimatedSwitcher`
              // keys the entry off the transition — so the `_Live` still
              // fading out and the `_Live` coming back in arrive in the same
              // `Stack` under the same key. Flip the switch twice inside the
              // 320ms and it throws `Duplicate keys found.` in the middle of
              // a build, which leaves the subtree half torn down and puts
              // `'_dependents.isEmpty': is not true` in red over the app.
              //
              // A builder that sets no key of its own falls back to the
              // switcher's own serial number, which cannot repeat.
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: on
                  ? _Live(
                      key: const ValueKey('live'),
                      link: link,
                      shareText: shareText,
                      services: shown,
                      hasAny: services.isNotEmpty,
                      search: _search,
                      query: _query,
                      onQuery: (v) => setState(() => _query = v),
                    )
                  : _Pitch(
                      key: const ValueKey('pitch'),
                      onActivate: () => ref
                          .read(adminProvider.notifier)
                          .setOnlineGarage(true),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: on
          ? FloatingActionButton.extended(
              onPressed: () => showAddServiceSheet(context),
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              icon: const Icon(Icons.add_rounded),
              label: Text('Add service'.tr),
            )
          : null,
    );
  }
}

/// The off state — what the workshop gets if it turns this on.
class _Pitch extends StatelessWidget {
  const _Pitch({super.key, required this.onActivate});

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xxl, Gap.page, Gap.h2),
      child: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: p.inverseGradient,
              borderRadius: R.all(R.xl),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: R.all(R.xl),
                    child: CustomPaint(
                      painter: BlueprintPainter(
                        color: p.onInverse,
                        opacity: 0.08,
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.build_circle_rounded,
                  size: 78,
                  color: p.onInverse.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xxl),
          Text(
            'Your own Digital Garage!'.tr,
            textAlign: TextAlign.center,
            style: AppType.d3.c(p.ink),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Jobcard live tracking, online bookings, online payment collection and many more.'
                .tr,
            textAlign: TextAlign.center,
            style: AppType.bodyM.c(p.inkMuted),
          ),
          const SizedBox(height: Gap.xxl),
          GButton.accent(label: 'ACTIVATE NOW!'.tr, onPressed: onActivate),
        ],
      ),
    );
  }
}

/// The on state — the share link and what is listed behind it.
class _Live extends StatelessWidget {
  const _Live({
    super.key,
    required this.link,
    required this.shareText,
    required this.services,
    required this.hasAny,
    required this.search,
    required this.query,
    required this.onQuery,
  });

  final String link;

  /// The whole message, from `onlineShareTextProvider` — the same words the
  /// Settings share uses. This used to put "https://" in front of a link
  /// that already carried it and promise job card tracking the link does
  /// not give.
  final String shareText;
  final List<OnlineService> services;
  final bool hasAny;
  final TextEditingController search;
  final String query;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      children: [
        Entrance(
          child: Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: R.all(R.lg),
              border: Border.all(color: p.line),
              boxShadow: Shadows.soft(p),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share Link on Whatsapp'.tr, style: AppType.h2.c(p.ink)),
                const SizedBox(height: 4),
                Text(
                  'Your customers get the app from this link, find you by name and book a slot.'
                      .tr,
                  style: AppType.bodyS.c(p.inkMuted),
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: Pressable(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: link));
                          GFeedback.success(context, 'Link copied'.tr);
                        },
                        scale: 0.98,
                        child: Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelL
                              .c(p.info)
                              .copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    GButton(
                      label: 'Share'.tr,
                      kind: GButtonKind.volt,
                      size: GButtonSize.sm,
                      icon: Icons.share_rounded,
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: shareText.isEmpty ? link : shareText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        GSearchBar(
          hint: 'Search services and show online'.tr,
          controller: search,
          onChanged: onQuery,
          onClear: query.isEmpty
              ? null
              : () {
                  search.clear();
                  onQuery('');
                },
        ),
        const SizedBox(height: Gap.lg),
        if (!hasAny)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xxl),
            child: Column(
              children: [
                Text(
                  'No Services added in Online Garage'.tr,
                  textAlign: TextAlign.center,
                  style: AppType.h2.c(p.ink),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Add services to your online garage — this is what the customer sees on your page.'
                      .tr,
                  textAlign: TextAlign.center,
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < services.length; i++)
            Entrance(
              index: i.clamp(0, 8),
              child: _ServiceRow(service: services[i]),
            ),
      ],
    );
  }
}

class _ServiceRow extends ConsumerWidget {
  const _ServiceRow({required this.service});

  final OnlineService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    return Dismissible(
      key: ValueKey(service.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.only(right: Gap.lg),
        decoration: BoxDecoration(
          color: p.dangerSoft,
          borderRadius: R.all(R.md),
        ),
        child: Icon(Icons.delete_outline_rounded, color: p.danger),
      ),
      onDismissed: (_) {
        ref.read(adminProvider.notifier).removeOnlineService(service.id);
        GFeedback.info(context, 'Removed from your online garage'.tr);
      },
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
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  if (service.blurb.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      service.blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                  ],
                  const SizedBox(height: Gap.sm),
                  GPill(
                    label: '{0} min'.trf([service.durationMins]),
                    tone: GTone.info,
                    compact: true,
                  ),
                ],
              ),
            ),
            Text(Fmt.money(service.price), style: AppType.money.c(p.ink)),
          ],
        ),
      ),
    );
  }
}

/// Publish one service. Picking from the labour master is the fast path,
/// because that list is already priced.
Future<void> showAddServiceSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _AddServiceSheet(),
    );

class _AddServiceSheet extends ConsumerStatefulWidget {
  const _AddServiceSheet();

  @override
  ConsumerState<_AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends ConsumerState<_AddServiceSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _blurb = TextEditingController();
  int _mins = 60;

  @override
  void dispose() {
    for (final c in [_name, _price, _blurb]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (double.tryParse(_price.text.trim()) ?? 0) > 0;

  void _save() {
    if (!_valid) return;
    ref
        .read(adminProvider.notifier)
        .addOnlineService(
          name: _name.text,
          price: double.parse(_price.text.trim()),
          blurb: _blurb.text,
          durationMins: _mins,
        );
    Navigator.of(context).pop();
    GFeedback.success(context, 'Published to your online garage'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final labour = ref.watch(mastersProvider(LineKind.job));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                Text('Add a service'.tr, style: AppType.h1.c(p.ink)),
                const SizedBox(height: Gap.lg),
                if (labour.isNotEmpty) ...[
                  Text(
                    'FROM YOUR LABOUR LIST'.tr,
                    style: AppType.over.c(p.inkFaint),
                  ),
                  const SizedBox(height: Gap.sm),
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      for (final m in labour.take(10))
                        Pressable(
                          onTap: () => setState(() {
                            _name.text = m.name;
                            _price.text = m.rate.toStringAsFixed(0);
                          }),
                          scale: 0.95,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Gap.md,
                              vertical: Gap.sm,
                            ),
                            decoration: BoxDecoration(
                              color: p.surfaceAlt,
                              borderRadius: R.all(R.pill),
                              border: Border.all(color: p.line),
                            ),
                            child: Text(
                              m.name,
                              style: AppType.labelM.c(p.inkSoft),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),
                ],
                GField(
                  label: 'Service name'.tr,
                  hint: 'General Service'.tr,
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: GField(
                        label: 'Price'.tr,
                        hint: '1500',
                        controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GPickerField(
                        label: 'Takes about'.tr,
                        value: '$_mins min',
                        placeholder: '60 min'.tr,
                        onTap: () async {
                          final picked = await showModalBottomSheet<int>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) => Container(
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(R.xxl),
                                ),
                              ),
                              child: SafeArea(
                                top: false,
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: Gap.lg,
                                  ),
                                  children: [
                                    for (final m in const [
                                      15,
                                      30,
                                      45,
                                      60,
                                      90,
                                      120,
                                      180,
                                      240,
                                    ])
                                      ListTile(
                                        title: Text(
                                          '{0} min'.trf([m]),
                                          style: AppType.labelL.c(p.ink),
                                        ),
                                        onTap: () =>
                                            Navigator.of(context).pop(m),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          if (picked != null) setState(() => _mins = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'What it covers'.tr,
                  hint: 'Optional'.tr,
                  controller: _blurb,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: Gap.xl),
                GButton.accent(
                  label: 'Publish'.tr,
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
