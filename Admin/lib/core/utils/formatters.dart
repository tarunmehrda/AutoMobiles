import 'package:intl/intl.dart';

import '../i18n/strings.dart';

/// Indian-format currency, dates and other display helpers.
class Fmt {
  const Fmt._();

  // Money keeps the Indian grouping and Latin digits in every language.
  // CLDR would happily give Hindi its own numbering, but a workshop's
  // invoice, its ledger and the printed bill all have to read the same to
  // whoever is checking them, so the numerals stay put and only the words
  // around them change.
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
  static String km(num value) => '${_plain.format(value)} ${'km'.tr}';

  // Dates do follow the language — month and day names are words, and a
  // Hindi console reading "15 सित 2026" is the whole point. The formats are
  // cached per pattern and rebuilt when the language changes, because
  // building a DateFormat on every list row showed up in a scroll profile.
  static String _cachedFor = '';
  static final Map<String, DateFormat> _dates = {};

  static DateFormat _fmt(String pattern) {
    final code = Tr.language.code;
    if (code != _cachedFor) {
      _dates.clear();
      _cachedFor = code;
    }
    // English keeps intl's default locale — it needs no symbol data loaded,
    // which matters for widget tests and for the first frame. Anything else
    // names its locale, and `initializeDateFormatting` in main() has already
    // put the symbols in place.
    return _dates[pattern] ??= code == 'en'
        ? DateFormat(pattern)
        : DateFormat(pattern, code);
  }

  static String date(DateTime d) => _fmt('d MMM yyyy').format(d);
  static String dateShort(DateTime d) => _fmt('d MMM').format(d);
  static String dayName(DateTime d) => _fmt('EEE').format(d);
  static String monthName(DateTime d) => _fmt('MMMM yyyy').format(d);
  static String time(DateTime d) => _fmt('h:mm a').format(d);
  static String dateTime(DateTime d) => _fmt('d MMM, h:mm a').format(d);
  static String fullDateTime(DateTime d) =>
      _fmt('d MMM yyyy, h:mm a').format(d);

  /// `Today`, `Tomorrow`, `Yesterday` or a short date.
  static String friendlyDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today'.tr;
    if (diff == 1) return 'Tomorrow'.tr;
    if (diff == -1) return 'Yesterday'.tr;
    return dateShort(d);
  }

  /// `2 hours ago`, `just now`, `in 3 days`.
  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    final future = diff.isNegative;
    final a = diff.abs();
    String unit;
    if (a.inSeconds < 60) {
      return future ? 'in a moment'.tr : 'Just now'.tr;
    } else if (a.inMinutes < 60) {
      unit = '{0} min'.trf([a.inMinutes]);
    } else if (a.inHours < 24) {
      unit = '{0} hr'.trf([a.inHours]);
    } else if (a.inDays < 30) {
      unit = Tr.plural(a.inDays, '{0} day', '{0} days');
    } else {
      final m = (a.inDays / 30).floor();
      unit = Tr.plural(m, '{0} month', '{0} months');
    }
    return future ? 'in {0}'.trf([unit]) : '{0} ago'.trf([unit]);
  }

  /// `6 hrs`, `45 mins`, `2 days`.
  static String duration(double hours) {
    if (hours < 1) return '{0} mins'.trf([(hours * 60).round()]);
    if (hours < 24) {
      final whole = hours.floor();
      final mins = ((hours - whole) * 60).round();
      if (mins == 0) return Tr.plural(whole, '{0} hr', '{0} hrs');
      return '{0} hr {1} min'.trf([whole, mins]);
    }
    final days = (hours / 24).ceil();
    return Tr.plural(days, '{0} day', '{0} days');
  }

  /// `PB10 CX 4521` -> grouped for display, keeps input as-is otherwise.
  static String plate(String reg) => reg.toUpperCase();

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'G';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  static String maskPhone(String phone) {
    if (phone.length < 4) return phone;
    return '${'•' * (phone.length - 4)}${phone.substring(phone.length - 4)}';
  }

  /// An Indian PIN code: six digits, never starting with 0. The customer app
  /// prints it beside the workshop's name, so a registration cannot go
  /// through without one. `26_require_garage_pin.sql` holds the same rule.
  static bool isPin(String pin) => RegExp(r'^[1-9]\d{5}$').hasMatch(pin.trim());

  static String percentOff(num mrp, num price) {
    if (mrp <= 0 || price >= mrp) return '';
    return '{0}% OFF'.trf([(((mrp - price) / mrp) * 100).round()]);
  }
}

extension _Chars on String {
  Iterable<String> get characters => split('');
}
