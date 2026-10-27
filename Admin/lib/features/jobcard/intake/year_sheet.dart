import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/pressable.dart';

/// The oldest make year the sheet offers. Anything older on an Indian road is
/// a restoration, and the counter can still save the card without a year by
/// picking the oldest one and noting it — a grid that runs back to 1950 is a
/// grid nobody can find this year's car in.
const kOldestMakeYear = 1980;

/// A grid of years, newest first, for the make year on the RC.
///
/// A grid rather than a wheel or a text field: the year is read off a paper
/// in the customer's hand, and a tap on "2015" in a block of four-per-row is
/// faster than scrolling a drum or raising a keyboard for four digits.
Future<int?> pickMakeYear(BuildContext context, {int? selected}) {
  final p = context.c;
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: p.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
    ),
    builder: (_) => _YearSheet(selected: selected),
  );
}

class _YearSheet extends StatelessWidget {
  const _YearSheet({required this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final now = DateTime.now().year;
    final years = [for (var y = now; y >= kOldestMakeYear; y--) y];

    return ConstrainedBox(
      // Capped, so the sheet never covers the form it is filling in.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.62,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Make Year'.tr, style: AppType.h2.c(p.ink)),
                const SizedBox(height: 2),
                Text(
                  'As printed on the RC'.tr,
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ],
            ),
          ),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                0,
                Gap.page,
                Gap.xxl,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: Gap.sm,
                crossAxisSpacing: Gap.sm,
                childAspectRatio: 1.9,
              ),
              itemCount: years.length,
              itemBuilder: (context, i) {
                final y = years[i];
                final on = y == selected;
                return Pressable(
                  onTap: () => Navigator.of(context).pop(y),
                  scale: 0.94,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? p.accent : p.surfaceAlt,
                      borderRadius: R.all(R.sm),
                      border: Border.all(color: on ? p.accent : p.line),
                    ),
                    child: Text(
                      '$y',
                      style: AppType.money
                          .s(14)
                          .c(on ? p.onAccent : p.ink)
                          .w(on ? FontWeight.w800 : FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
