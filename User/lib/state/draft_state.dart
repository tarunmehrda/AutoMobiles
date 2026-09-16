import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/entities.dart';
import '../data/models/enums.dart';
import '../data/seed/catalog_seed.dart';
import 'app_state.dart';

/// The in-progress booking: cart lines, vehicle, handover mode, slot, coupon.
/// Survives app restarts so a half-finished booking is never lost.
@immutable
class BookingDraft {
  const BookingDraft({
    this.vehicleId,
    this.lines = const [],
    this.mode = ServiceMode.garage,
    this.addressId,
    this.slotDate,
    this.slotTime,
    this.couponCode,
    this.notes,
  });

  final String? vehicleId;
  final List<CartLine> lines;
  final ServiceMode mode;
  final String? addressId;
  final DateTime? slotDate;
  final String? slotTime;
  final String? couponCode;
  final String? notes;

  bool get isEmpty => lines.isEmpty;
  int get count => lines.length;

  int get subtotal => lines.fold(0, (s, l) => s + l.price);
  int get mrpTotal => lines.fold(0, (s, l) => s + l.mrp);
  int get itemSavings => mrpTotal - subtotal;
  double get hours => lines.fold<double>(0, (s, l) => s + l.durationHours);

  int get pickupFee => mode == ServiceMode.pickup ? Seed.pickupFee : 0;

  Coupon? get coupon {
    if (couponCode == null) return null;
    for (final c in Seed.coupons()) {
      if (c.code == couponCode) return c;
    }
    return null;
  }

  int get discount => coupon?.discountFor(subtotal) ?? 0;
  int get taxable => subtotal + pickupFee - discount;
  int get gst => (taxable * 0.18).round();
  int get total => taxable + gst;
  int get totalSavings => itemSavings + discount;

  bool has(String id) => lines.any((l) => l.id == id);

  /// The chosen date and time merged into one instant.
  DateTime? get slot {
    if (slotDate == null || slotTime == null) return null;
    final parts = slotTime!.split(RegExp(r'[: ]'));
    if (parts.length < 3) return slotDate;
    var hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    final meridiem = parts[2].toUpperCase();
    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return DateTime(
        slotDate!.year, slotDate!.month, slotDate!.day, hour, minute);
  }

  bool get slotReady => slot != null;
  bool get addressReady => mode == ServiceMode.garage || addressId != null;

  BookingDraft copyWith({
    String? vehicleId,
    List<CartLine>? lines,
    ServiceMode? mode,
    String? addressId,
    bool clearAddress = false,
    DateTime? slotDate,
    String? slotTime,
    bool clearSlotTime = false,
    String? couponCode,
    bool clearCoupon = false,
    String? notes,
  }) =>
      BookingDraft(
        vehicleId: vehicleId ?? this.vehicleId,
        lines: lines ?? this.lines,
        mode: mode ?? this.mode,
        addressId: clearAddress ? null : (addressId ?? this.addressId),
        slotDate: slotDate ?? this.slotDate,
        slotTime: clearSlotTime ? null : (slotTime ?? this.slotTime),
        couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'vehicle_id': vehicleId,
        'lines': lines.map((e) => e.toJson()).toList(),
        'mode': mode.name,
        'address_id': addressId,
        'slot_date': slotDate?.toIso8601String(),
        'slot_time': slotTime,
        'coupon_code': couponCode,
        'notes': notes,
      };

  factory BookingDraft.fromJson(Map<String, dynamic> j) => BookingDraft(
        vehicleId: j['vehicle_id'] as String?,
        lines: ((j['lines'] ?? const []) as List)
            .map((e) => CartLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        mode: ServiceModeX.parse(j['mode'] as String?),
        addressId: j['address_id'] as String?,
        slotDate: DateTime.tryParse((j['slot_date'] ?? '') as String),
        slotTime: j['slot_time'] as String?,
        couponCode: j['coupon_code'] as String?,
        notes: j['notes'] as String?,
      );
}

final draftProvider =
    StateNotifierProvider<DraftController, BookingDraft>((ref) {
  return DraftController();
});

class DraftController extends StateNotifier<BookingDraft> {
  DraftController()
      : super(() {
          final raw = localStore.readDraft();
          if (raw == null) return const BookingDraft();
          try {
            return BookingDraft.fromJson(raw);
          } catch (_) {
            return const BookingDraft();
          }
        }());

  void _set(BookingDraft next) {
    state = next;
    localStore.writeDraft(next.isEmpty && next.slotDate == null
        ? null
        : next.toJson());
  }

  void setVehicle(String? id) => _set(state.copyWith(vehicleId: id));

  bool togglePackage(ServicePackage p) {
    if (state.has(p.id)) {
      remove(p.id);
      return false;
    }
    _set(state.copyWith(lines: [
      ...state.lines,
      CartLine(
        id: p.id,
        name: p.name,
        price: p.price,
        mrp: p.mrp,
        isAddOn: false,
        durationHours: p.durationHours,
        categoryId: p.categoryId,
      ),
    ]));
    return true;
  }

  bool toggleAddOn(AddOn a) {
    if (state.has(a.id)) {
      remove(a.id);
      return false;
    }
    _set(state.copyWith(lines: [
      ...state.lines,
      CartLine(
        id: a.id,
        name: a.name,
        price: a.price,
        mrp: a.mrp ?? a.price,
        isAddOn: true,
        durationHours: a.durationMins / 60,
      ),
    ]));
    return true;
  }

  void remove(String id) =>
      _set(state.copyWith(lines: state.lines.where((l) => l.id != id).toList()));

  void setMode(ServiceMode mode) => _set(state.copyWith(
        mode: mode,
        clearAddress: mode == ServiceMode.garage,
      ));

  void setAddress(String? id) => _set(
      id == null ? state.copyWith(clearAddress: true) : state.copyWith(addressId: id));

  /// [clearTime] is needed when the chosen date no longer offers the time the
  /// customer had picked — otherwise a stale, unbookable slot stays selected.
  void setSlot({DateTime? date, String? time, bool clearTime = false}) =>
      _set(state.copyWith(
          slotDate: date, slotTime: time, clearSlotTime: clearTime));

  void setNotes(String? notes) => _set(state.copyWith(notes: notes));

  String? applyCoupon(String code) {
    final match = Seed.coupons().where(
        (c) => c.code.toUpperCase() == code.trim().toUpperCase());
    if (match.isEmpty) return 'That code does not exist';
    final c = match.first;
    if (!c.isLive) return 'That code has expired';
    if (state.subtotal < c.minOrder) {
      return 'Add ₹${c.minOrder - state.subtotal} more to use this code';
    }
    _set(state.copyWith(couponCode: c.code));
    return null;
  }

  void removeCoupon() => _set(state.copyWith(clearCoupon: true));

  void clear() {
    state = const BookingDraft();
    localStore.writeDraft(null);
  }
}
