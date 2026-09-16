import 'package:intl/intl.dart';

/// Indian-format currency, dates and other display helpers.
class Fmt {
  const Fmt._();

  static final NumberFormat _rupee = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final NumberFormat _rupeeDec = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final NumberFormat _plain = NumberFormat.decimalPattern('en_IN');

  /// `₹3,032`
  static String money(num value) => _rupee.format(value);

  /// `₹3,032.50`
  static String money2(num value) => _rupeeDec.format(value);

  /// `42,300`
  static String number(num value) => _plain.format(value);

  /// `42,300 km`
  static String km(num value) => '${_plain.format(value)} km';

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String dateShort(DateTime d) => DateFormat('d MMM').format(d);
  static String dayName(DateTime d) => DateFormat('EEE').format(d);
  static String monthName(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String time(DateTime d) => DateFormat('h:mm a').format(d);
  static String dateTime(DateTime d) => DateFormat('d MMM, h:mm a').format(d);
  static String fullDateTime(DateTime d) =>
      DateFormat('d MMM yyyy, h:mm a').format(d);

  /// `Today`, `Tomorrow`, `Yesterday` or a short date.
  static String friendlyDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('d MMM').format(d);
  }

  /// `2 hours ago`, `just now`, `in 3 days`.
  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    final future = diff.isNegative;
    final a = diff.abs();
    String unit;
    if (a.inSeconds < 60) {
      return future ? 'in a moment' : 'Just now';
    } else if (a.inMinutes < 60) {
      unit = '${a.inMinutes} min';
    } else if (a.inHours < 24) {
      unit = '${a.inHours} hr';
    } else if (a.inDays < 30) {
      unit = '${a.inDays} day${a.inDays == 1 ? '' : 's'}';
    } else {
      final m = (a.inDays / 30).floor();
      unit = '$m month${m == 1 ? '' : 's'}';
    }
    return future ? 'in $unit' : '$unit ago';
  }

  /// `6 hrs`, `45 mins`, `2 days`.
  static String duration(double hours) {
    if (hours < 1) return '${(hours * 60).round()} mins';
    if (hours < 24) {
      final whole = hours.floor();
      final mins = ((hours - whole) * 60).round();
      if (mins == 0) return '$whole hr${whole == 1 ? '' : 's'}';
      return '$whole hr $mins min';
    }
    final days = (hours / 24).ceil();
    return '$days day${days == 1 ? '' : 's'}';
  }

  /// `PB10 CX 4521` -> grouped for display, keeps input as-is otherwise.
  static String plate(String reg) => reg.toUpperCase();

  static String initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'G';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  static String maskPhone(String phone) {
    if (phone.length < 4) return phone;
    return '${'•' * (phone.length - 4)}${phone.substring(phone.length - 4)}';
  }

  static String percentOff(num mrp, num price) {
    if (mrp <= 0 || price >= mrp) return '';
    return '${(((mrp - price) / mrp) * 100).round()}% OFF';
  }
}

extension _Chars on String {
  Iterable<String> get characters => split('');
}
