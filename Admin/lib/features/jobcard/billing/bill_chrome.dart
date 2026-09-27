import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/enums.dart';
import '../../../data/seed/part_media.dart';

/// The head and the foot of a billing screen.
///
/// The three screens in this folder look nothing like each other in the
/// middle — a labour ledger, a parts gallery and a lubricant shelf — and that
/// is the point of them. What they must not differ on is where the running
/// total lives, where the search box is, and which button commits: those are
/// the things a counter hand finds by muscle memory while talking to a
/// customer, and a screen that moves them is a screen that gets used wrong.
///
/// So the chrome is shared and the content is not.

/// Dark head carrying the running total, the search box and one row of
/// per-screen filters.
///
/// Built on the palette's inverse surface rather than on the kind's colour,
/// with the colour used only for the figures. Three screens in three flat
/// colours is the competitor's answer; ours keeps one carbon masthead across
/// all three and lets the tint do the telling apart, which leaves the money
/// as the brightest thing on the screen instead of the background.
class BillMasthead extends StatelessWidget {
  const BillMasthead({
    super.key,
    required this.kind,
    required this.tint,
    required this.eyebrow,
    required this.title,
    required this.total,
    required this.count,
    required this.searchHint,
    required this.controller,
    required this.onQuery,
    this.filters,
  });

  final LineKind kind;
  final Color tint;
  final String eyebrow;
  final String title;
  final double total;

  /// Distinct rows on the cart, not units — "3 lines" is what the counter
  /// reads back, and 3 lines of 2 litres is still 3 lines.
  final int count;

  final String searchHint;
  final TextEditingController controller;
  final ValueChanged<String> onQuery;
  final Widget? filters;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(
        gradient: p.inverseGradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(R.xxl),
        ),
        boxShadow: Shadows.lifted(p),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Scene-setting photography, pushed almost all the way down. It is
          // there to stop the masthead reading as a flat slab; anything
          // brighter and it would compete with the total sitting on top of it.
          Positioned(
            right: -30,
            top: -20,
            child: Opacity(
              opacity: p.isDark ? 0.14 : 0.18,
              child: ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Colors.white, Colors.white.withValues(alpha: 0)],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Image.network(
                  PartMedia.mastheadFor(kind),
                  headers: AppConfig.imageHeaders,
                  height: 190,
                  width: 230,
                  fit: BoxFit.cover,
                  // Decoration only. If it never arrives the masthead is a
                  // gradient, which is exactly what it is behind the picture.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.sm,
                Gap.page,
                Gap.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GIconButton(
                        icon: Icons.arrow_back_rounded,
                        size: 40,
                        bordered: false,
                        background: p.onInverse.withValues(alpha: 0.10),
                        foreground: p.onInverse,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow.toUpperCase(),
                              style: AppType.over.c(tint),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.d3.s(24).c(p.onInverse),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // A bill can reach six figures. The total shrinks to
                      // fit rather than ellipsising, because half a number is
                      // worse than a small one.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Fmt.money(total),
                            maxLines: 1,
                            style: AppType.moneyL.s(34).c(p.volt),
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            count == 0
                                ? 'nothing picked yet'.tr
                                : Tr.plural(
                                    count,
                                    '{0} line picked',
                                    '{0} lines picked',
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.labelS.c(
                              p.onInverse.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),
                  _DarkSearch(
                    hint: searchHint,
                    controller: controller,
                    onChanged: onQuery,
                    tint: tint,
                  ),
                  if (filters != null) ...[
                    const SizedBox(height: Gap.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: filters!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's search bar, restated for a dark surface.
///
/// [GSearchBar] takes its fill from `surface`, which on the carbon masthead
/// is a pale slab in the middle of a dark head. Rather than teach that widget
/// about inverse surfaces for one caller, this is the same shape in the same
/// tokens, mixed for the surface it sits on.
class _DarkSearch extends StatelessWidget {
  const _DarkSearch({
    required this.hint,
    required this.controller,
    required this.onChanged,
    required this.tint,
  });

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: p.onInverse.withValues(alpha: 0.08),
        borderRadius: R.all(R.pill),
        border: Border.all(color: p.onInverse.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const SizedBox(width: Gap.lg),
          Icon(
            Icons.search_rounded,
            size: 19,
            color: p.onInverse.withValues(alpha: 0.6),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppType.bodyM.c(p.onInverse),
              cursorColor: tint,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppType.bodyM.c(p.onInverse.withValues(alpha: 0.42)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: Gap.lg)
                : Pressable(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    scale: 0.9,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: p.onInverse.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The commit bar. Same three things in the same three places on all three
/// screens: what is on the cart, a way to add something that is not on the
/// catalogue, and the button that ends the errand.
class BillFooter extends StatelessWidget {
  const BillFooter({
    super.key,
    required this.kind,
    required this.tint,
    required this.units,
    required this.unitNoun,
    required this.total,
    required this.onAddNew,
    required this.onSave,
  });

  final LineKind kind;
  final Color tint;

  /// Units rather than rows: this is the line a storeman checks against what
  /// is physically in their hand.
  final double units;

  /// What one unit is called here — 'job', 'part', 'litre'.
  final String unitNoun;

  final double total;
  final VoidCallback onAddNew;

  /// Null while the cart is empty, which disables the button rather than
  /// hiding it — a missing commit button reads as a broken screen.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final n = Fmt.number(units);
    return GBottomBar(
      child: Row(
        children: [
          // Expanded rather than a Spacer after it. The two buttons are
          // intrinsically sized and the total is the only thing here that can
          // give ground, so on a narrow phone it has to be the thing that
          // does — with a Spacer the row simply overflowed.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  units == 0
                      ? 'Nothing yet'.tr
                      : '$n $unitNoun${units == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelS.c(p.inkMuted),
                ),
                Text(
                  Fmt.money(total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.money.s(19).c(units == 0 ? p.inkFaint : p.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          // A bare plus rather than an outlined "New": the commit button
          // beside it needs a full label far more than this does, and two
          // labelled buttons plus a total is more than 350 points of phone.
          GIconButton(
            icon: Icons.add_rounded,
            size: 46,
            tooltip: 'Add a new {0}'.trf([kind.singular.toLowerCase()]),
            onTap: onAddNew,
          ),
          const SizedBox(width: Gap.sm),
          GButton.accent(
            label: 'Put on bill'.tr,
            size: GButtonSize.md,
            expand: false,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
