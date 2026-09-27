import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/g_art.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/vehicle_card.dart';

/// A searchable list in a sheet, used for the make and the model on the job
/// card form.
///
/// Typing something the list does not have is allowed and returned as-is —
/// a workshop sees imports and rebuilds that no catalogue will ever cover,
/// and the counter must not be stuck behind a dropdown.
///
/// ## Why the rows carry pictures
///
/// A name in a list of two hundred names is read; a picture is recognised.
/// The counter opening a card knows what is standing in the bay and is
/// looking for *that*, so the model list shows each model — and the make list
/// shows each marque's badge, which is the thing people actually scan for.
///
/// Pass [photoOf] and every row gets its picture. Pass [logoOf] and every row
/// gets its badge. Pass neither and this is the plain text list it has always
/// been, which is what the variant picker wants: a trim level has no picture
/// and a row of identical photographs would only be noise.
Future<String?> pickFromCatalog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<String> options,
  String? selected,
  String? Function(String)? photoOf,
  String? Function(String)? logoOf,
  bool Function(String)? exactOf,
}) async {
  String? chosen;

  await GFeedback.sheet<void>(
    context,
    title: title,
    subtitle: subtitle,
    child: _CatalogPicker(
      options: options,
      selected: selected,
      photoOf: photoOf,
      logoOf: logoOf,
      exactOf: exactOf,
      onPick: (value) => chosen = value,
    ),
  );

  return chosen;
}

/// A real widget rather than a `StatefulBuilder` closure, for two reasons
/// that both showed up as the sheet locking the phone up:
///
/// * **The field is built once.** It used to sit inside the subtree that
///   every keystroke rebuilt, carrying `autofocus: true` with it. Each
///   character re-ran the autofocus, which asked for the keyboard again,
///   which moved `viewInsets`, which relaid the sheet out, which rebuilt the
///   field. Only the results below it are rebuilt now, through a
///   [ValueListenableBuilder] on the controller.
///
/// * **The controller has an owner.** It used to be created beside the
///   `await` and disposed the line after it returned, while the sheet was
///   still on screen animating out — a disposed controller being read by a
///   live `TextField`. Here it lives and dies with the widget.
class _CatalogPicker extends StatefulWidget {
  const _CatalogPicker({
    required this.options,
    required this.selected,
    required this.onPick,
    this.photoOf,
    this.logoOf,
    this.exactOf,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onPick;

  /// The picture for one option, or null for none.
  final String? Function(String)? photoOf;

  /// The marque badge for one option, or null for none.
  final String? Function(String)? logoOf;

  /// Whether that option's picture is of the real thing rather than of its
  /// body style. Marked on the row, so nobody takes a stand-in for a promise.
  final bool Function(String)? exactOf;

  @override
  State<_CatalogPicker> createState() => _CatalogPickerState();
}

class _CatalogPickerState extends State<_CatalogPicker> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // `autofocus` asks on the sheet's first frame, while the route is still
    // sliding up and the page underneath still owns the focus scope. The
    // field lights up, the keyboard does not come, and the counter has to
    // tap the bar to start typing — every single time they open a picker.
    // Asking once the sheet has landed is the ask that reaches the platform.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusWhenSettled());
  }

  void _focusWhenSettled() {
    if (!mounted) return;
    final anim = ModalRoute.of(context)?.animation;
    if (anim == null || anim.isCompleted) {
      _focus.requestFocus();
      return;
    }
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      anim.removeStatusListener(onStatus);
      if (mounted) _focus.requestFocus();
    }

    anim.addStatusListener(onStatus);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(String value) {
    widget.onPick(value);
    Navigator.of(context).pop();
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
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              // The bar itself is the `child`: the builder hands the same
              // instance back every time, so the TextField is never rebuilt
              // and never asks for the keyboard twice.
              builder: (context, value, child) => child!,
              child: GSearchBar(
                hint: 'Search or type a new one'.tr,
                controller: _controller,
                focusNode: _focus,
                onClear: _controller.clear,
              ),
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

  /// What kind of art this picker's rows carry, decided once for the whole
  /// list so every row is the same height and `itemExtent` still holds.
  _RowArt get _art => widget.photoOf != null
      ? _RowArt.photo
      : widget.logoOf != null
      ? _RowArt.logo
      : _RowArt.none;

  Widget _results(String raw) {
    final p = context.c;
    final q = raw.toLowerCase();
    final matches = q.isEmpty
        ? widget.options
        : widget.options.where((o) => o.toLowerCase().contains(q)).toList();
    final exact = widget.options.any((o) => o.toLowerCase() == q);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (raw.isNotEmpty && !exact)
          Padding(
            padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
            child: _Row(
              label: 'Use "{0}"'.trf([raw]),
              subtitle: 'Not in the list — added to this card only'.tr,
              icon: Icons.edit_rounded,
              selected: false,
              art: _art,
              onTap: () => _pick(raw),
            ),
          ),
        Flexible(
          child: matches.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: Gap.h1),
                  child: GEmptyState(
                    compact: true,
                    icon: Icons.search_off_rounded,
                    title: 'No match'.tr,
                    art: Art.vehicleSale,
                    message: 'Type it in and carry on.'.tr,
                  ),
                )
              // No `shrinkWrap`. It forced every row in the catalogue to be
              // built and measured on each keystroke; the list is bounded by
              // the Flexible above it, so it can stay lazy and build only
              // what is on screen.
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    0,
                    Gap.page,
                    Gap.h1,
                  ),
                  itemCount: matches.length,
                  itemExtent: _Row.extentFor(_art),
                  itemBuilder: (context, i) => _Row(
                    label: matches[i],
                    selected: matches[i] == widget.selected,
                    art: _art,
                    photo: widget.photoOf?.call(matches[i]),
                    logo: widget.logoOf?.call(matches[i]),
                    exact: widget.exactOf?.call(matches[i]) ?? false,
                    onTap: () => _pick(matches[i]),
                  ),
                ),
        ),
        if (matches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Text(
              '${matches.length} of ${widget.options.length}',
              style: AppType.labelS.c(p.inkFaint),
            ),
          ),
      ],
    );
  }
}

/// What the left of a row shows.
enum _RowArt { none, logo, photo }

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.selected,
    required this.onTap,
    this.art = _RowArt.none,
    this.photo,
    this.logo,
    this.exact = false,
    this.subtitle,
    this.icon,
  });

  /// Fixed per kind of row, so the list can use `itemExtent` and skip
  /// measuring two hundred rows on every keystroke.
  static const double height = 60;

  static double extentFor(_RowArt art) => switch (art) {
    _RowArt.none => height,
    _RowArt.logo => 64,
    _RowArt.photo => 78,
  };

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final _RowArt art;
  final String? photo;
  final String? logo;
  final bool exact;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        height: subtitle == null ? extentFor(art) - Gap.sm : null,
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: EdgeInsets.fromLTRB(
          art == _RowArt.photo ? Gap.sm : Gap.lg,
          art == _RowArt.photo ? Gap.sm : Gap.md,
          Gap.lg,
          art == _RowArt.photo ? Gap.sm : Gap.md,
        ),
        decoration: BoxDecoration(
          color: selected ? p.surfaceSunken : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: selected ? p.ink : p.line),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: p.accentInk),
              const SizedBox(width: Gap.md),
            ] else if (art == _RowArt.photo) ...[
              _Thumb(asset: photo),
              const SizedBox(width: Gap.md),
            ] else if (art == _RowArt.logo) ...[
              SizedBox(
                width: 30,
                child: logo == null
                    ? Icon(
                        Icons.local_offer_rounded,
                        size: 15,
                        color: p.inkFaint,
                      )
                    : GMarqueLogo(asset: logo!, size: 24),
              ),
              const SizedBox(width: Gap.md),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted),
                    )
                  // Only where the picture is of this exact model. A body
                  // shot is an honest stand-in, not a photograph of the car,
                  // and the row should not imply otherwise.
                  else if (exact)
                    Text(
                      'Photo'.tr,
                      style: AppType.labelS.s(9.5).c(p.inkFaint),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 19, color: p.accent),
          ],
        ),
      ),
    );
  }
}

/// One picture on a picker row.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.asset});

  final String? asset;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return ClipRRect(
      borderRadius: R.all(R.xs),
      child: Container(
        width: 78,
        height: 54,
        color: p.surfaceSunken,
        child: asset == null
            ? Icon(Icons.directions_car_rounded, size: 18, color: p.inkFaint)
            : Image.asset(
                asset!,
                fit: BoxFit.cover,
                // Two hundred rows of a 480px JPEG is how an image cache
                // starts evicting the ones still on screen.
                cacheHeight: (54 * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
      ),
    );
  }
}
