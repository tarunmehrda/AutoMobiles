import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'pressable.dart';

/// Labelled text field. The label sits inside the box and floats onto the
/// border once the field is focused or filled, which is the shape the rest of
/// the app's inputs use.
class GField extends StatelessWidget {
  const GField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.validator,
    this.obscure = false,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.sentences,
    this.helper,
    this.autofocus = false,
    this.onTap,
    this.readOnly = false,
    this.textInputAction,
    this.onSubmitted,
    this.initialValue,
    this.maxLength,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool obscure;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final String? helper;
  final bool autofocus;
  final VoidCallback? onTap;
  final bool readOnly;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? initialValue;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: obscure ? 1 : maxLines,
      minLines: 1,
      maxLength: maxLength,
      obscureText: obscure,
      enabled: enabled,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: AppType.bodyL.c(p.ink),
      cursorRadius: const Radius.circular(2),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        // On a multi-line box the label belongs on the first line of text,
        // not halfway down the field.
        alignLabelWithHint: maxLines > 1,
        hintText: hint,
        counterText: '',
        fillColor: enabled ? p.surface : p.surfaceSunken,
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: Gap.lg, right: Gap.sm),
                child: prefix,
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: Gap.lg, left: Gap.sm),
                child: suffix,
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        helperText: helper,
        helperStyle: AppType.labelS.c(p.inkFaint),
      ),
    );
  }
}

/// Read-only field that opens a picker when tapped.
class GPickerField extends StatelessWidget {
  const GPickerField({
    super.key,
    required this.label,
    required this.value,
    this.placeholder = 'Select',
    this.onTap,
    this.icon = Icons.expand_more_rounded,
    this.leadingIcon,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final IconData icon;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final has = value != null && value!.isNotEmpty;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      // InputDecorator gives the picker the same box, border and in-box label
      // as GField. The label stays floated because the placeholder underneath
      // ('Not set', 'Choose a supplier') has to stay readable while empty.
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          fillColor: p.surface,
          prefixIcon: leadingIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: Gap.lg, right: Gap.sm),
                  child: Icon(leadingIcon, size: 19, color: p.inkMuted),
                ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: Gap.lg, left: Gap.sm),
            child: Icon(icon, size: 20, color: p.inkMuted),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
        child: Text(
          has ? value! : placeholder,
          style: AppType.bodyL.c(has ? p.ink : p.inkFaint),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Search bar used on Home, catalogue and brand pickers.
class GSearchBar extends StatelessWidget {
  const GSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.trailing,
    this.onClear,
  });

  final String hint;
  final TextEditingController? controller;

  /// Supply one where the keyboard has to be raised by hand — `autofocus`
  /// only fires on the first frame, which is too early inside a sheet that
  /// is still sliding up.
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;
  final Widget? trailing;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.pill),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Row(
        children: [
          const SizedBox(width: Gap.lg),
          Icon(Icons.search_rounded, size: 20, color: p.inkMuted),
          const SizedBox(width: Gap.md),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onTap: onTap,
              readOnly: readOnly,
              autofocus: autofocus,
              style: AppType.bodyM.c(p.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppType.bodyM.c(p.inkFaint),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (onClear != null)
            Pressable(
              onTap: onClear,
              scale: 0.9,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                child: Icon(Icons.close_rounded, size: 18, color: p.inkMuted),
              ),
            ),
          if (trailing != null) trailing!,
          const SizedBox(width: Gap.md),
        ],
      ),
    );
  }
}

/// Segmented control (Garage visit / Pickup & drop, tab-like switches).
class GSegmented<T> extends StatelessWidget {
  const GSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.labelOf,
    this.iconOf,
    this.height = 46,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelect;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final index = options.indexOf(selected).clamp(0, options.length - 1);
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: R.all(R.pill),
        border: Border.all(color: p.line),
      ),
      // Measured inside the track rather than outside it. Working the pill
      // width out from the incoming constraint meant subtracting the padding
      // and the border by hand, and being a pixel out either way overflowed
      // the row. The customer app shipped that sum two pixels short and wore
      // a "RIGHT OVERFLOWED BY 2.0 PIXELS" badge on its Parts tabs for it.
      // Here maxWidth is already the space the pills actually have, so there
      // is no sum to keep in step with the padding.
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.base,
                curve: Motion.spring,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: R.all(R.pill),
                    boxShadow: [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final o in options)
                    SizedBox(
                      width: w,
                      child: Pressable(
                        onTap: () => onSelect(o),
                        scale: 0.96,
                        // Segment labels shrink to fit rather than being cut
                        // to "Mechanic Cop…" — the whole word is the point of
                        // a tab, and a long one must not push the row wider
                        // than its share of the track either.
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (iconOf?.call(o) != null) ...[
                                  Icon(
                                    iconOf!.call(o),
                                    size: 16,
                                    color: o == selected
                                        ? p.onAccent
                                        : p.inkMuted,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  labelOf(o),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: AppType.labelM
                                      .c(
                                        o == selected ? p.onAccent : p.inkMuted,
                                      )
                                      .w(
                                        o == selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Keeps [disposables] alive for as long as the subtree it wraps is on
/// screen, and disposes them the moment it leaves.
///
/// Sheets and dialogs in this app are opened from a plain function that
/// builds a few [TextEditingController]s, awaits the sheet, and disposes them
/// on the line after. That line runs too early. A sheet's future completes
/// when the route *starts* closing, not when it has closed: the route goes on
/// rebuilding — and its fields go on reading their controllers — for the
/// whole exit transition, a few hundred milliseconds during which the
/// controller is already dead.
///
/// The failure is loud and looks like it came from somewhere else entirely.
/// A `TextField` merges its controller and focus node into a fresh
/// `Listenable.merge` on every build, and `AnimatedWidget` treats a listenable
/// it has not seen before as its cue to subscribe — so the first rebuild after
/// the dispose calls `addListener` on a disposed `ChangeNotifier` and throws
/// in the middle of a build. That leaves the subtree half torn down, and the
/// complaint that actually reaches the screen is the framework's next one:
/// `'_dependents.isEmpty': is not true`, in red, over the whole app.
///
/// Wrapping the sheet's own content ties the controllers to it, so they die
/// with the sheet instead of with the `await` that opened it. The caller keeps
/// its references and can still read them once the sheet has closed — the
/// subtree is gone by then, so nothing is left to read a dead controller.
class DisposeWithSubtree extends StatefulWidget {
  const DisposeWithSubtree({
    super.key,
    required this.disposables,
    required this.child,
  });

  final List<ChangeNotifier> disposables;
  final Widget child;

  @override
  State<DisposeWithSubtree> createState() => _DisposeWithSubtreeState();
}

class _DisposeWithSubtreeState extends State<DisposeWithSubtree> {
  @override
  void dispose() {
    for (final d in widget.disposables) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
