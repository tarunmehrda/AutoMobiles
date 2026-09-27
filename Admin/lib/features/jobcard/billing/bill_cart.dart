import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/admin_state.dart';

/// What has been picked off the catalogue but not yet put on the bill.
///
/// A plain object rather than a notifier: each of the three billing screens
/// owns exactly one of these for the life of the screen, edits it inside
/// `setState`, and hands [linesOver] back on pop. Nothing else in the app can
/// see a cart, so there is nothing to notify.
///
/// Quantities are keyed by master id and held as doubles, because a lube is
/// counted in litres — half a litre of fork oil is a real line, and an `int`
/// here would round it into a whole can on the customer's bill.
class BillCart {
  final Map<String, double> _qty = <String, double>{};

  double qtyOf(String id) => _qty[id] ?? 0;

  bool has(String id) => (_qty[id] ?? 0) > 0;

  /// How many distinct catalogue rows are on the cart.
  int get rows => _qty.length;

  /// How many units in total, which is what the counter says out loud.
  double get units => _qty.values.fold<double>(0, (s, v) => s + v);

  bool get isEmpty => _qty.isEmpty;

  void bump(String id, [double step = 1]) => setQty(id, qtyOf(id) + step);

  void drop(String id, [double step = 1]) => setQty(id, qtyOf(id) - step);

  /// Clamped at zero and cleared there, so a row at zero is absent rather
  /// than present-and-empty — [rows] would otherwise count rows the customer
  /// is not being charged for.
  void setQty(String id, double q) {
    final v = (q * 100).roundToDouble() / 100;
    if (v <= 0) {
      _qty.remove(id);
    } else {
      _qty[id] = v;
    }
  }

  void clear() => _qty.clear();

  double totalOver(List<MasterItem> masters) {
    var t = 0.0;
    for (final m in masters) {
      final q = _qty[m.id];
      if (q != null) t += m.rate * q;
    }
    return money(t);
  }

  /// The cart as bill lines, in catalogue order.
  ///
  /// [masterId] is carried through deliberately: it is what lets the job card
  /// take the part out of stock when the card is opened and put it back if
  /// the line is deleted. A line built without it bills correctly and moves
  /// no stock at all.
  List<LineItem> linesOver(List<MasterItem> masters, LineKind kind) => [
    for (final m in masters)
      if ((_qty[m.id] ?? 0) > 0)
        LineItem(
          id: newId('li'),
          kind: kind,
          name: m.name,
          partNo: m.partNo,
          qty: _qty[m.id]!,
          rate: m.rate,
          masterId: m.id,
        ),
  ];
}

/// The colour each billing screen is built around.
///
/// The competitor's three screens are one layout in three colours. Ours are
/// three layouts, and the colour is the least of what tells them apart — but
/// it still has to come from the palette rather than from a screen, so a
/// change to the brand reaches all three.
Color billAccent(AppPalette p, LineKind kind) => switch (kind) {
  LineKind.job => p.accent,
  LineKind.spare => p.info,
  LineKind.lube => p.success,
};

/// Plus / minus around a figure, sized for a thumb on a busy counter.
///
/// [step] is what one tap is worth. Spares step in ones; lubes step in half
/// litres, because that is how oil actually leaves the shelf.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
    required this.tint,
    this.step = 1,
    this.unit = '',
    this.compact = false,
  });

  final double qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final Color tint;
  final double step;
  final String unit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final h = compact ? 32.0 : 38.0;
    final on = qty > 0;

    // Before anything is picked the control is a single add button. The
    // minus only appears once there is something to take away, which keeps
    // an untouched catalogue from reading as a screenful of disabled
    // controls.
    if (!on) {
      return Pressable(
        onTap: onAdd,
        scale: 0.88,
        child: Container(
          height: h,
          width: h,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: R.all(R.pill),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.add_rounded,
            size: h * 0.5,
            color: p.isDark ? p.canvas : Colors.white,
          ),
        ),
      );
    }

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.pill),
        border: Border.all(color: tint, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Step(
            icon: Icons.remove_rounded,
            size: h,
            tint: tint,
            onTap: onRemove,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: compact ? 30 : 42),
            child: Text(
              unit.isEmpty
                  ? Fmt.number(qty)
                  : '${Fmt.number(qty)} ${unit.toUpperCase()}',
              textAlign: TextAlign.center,
              style: AppType.money.s(compact ? 13 : 15).c(p.ink),
            ),
          ),
          _Step(icon: Icons.add_rounded, size: h, tint: tint, onTap: onAdd),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.size,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.85,
    child: SizedBox(
      height: size,
      width: size,
      child: Icon(icon, size: size * 0.44, color: tint),
    ),
  );
}
