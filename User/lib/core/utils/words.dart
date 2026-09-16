/// Rupee amounts spelled out the Indian way — lakh and crore, not million.
/// Printed under every invoice total.
class Words {
  const Words._();

  static const _ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  static String _below100(int n) {
    if (n < 20) return _ones[n];
    final t = _tens[n ~/ 10];
    final o = _ones[n % 10];
    return o.isEmpty ? t : '$t $o';
  }

  static String _below1000(int n) {
    if (n < 100) return _below100(n);
    final h = '${_ones[n ~/ 100]} Hundred';
    final rest = n % 100;
    return rest == 0 ? h : '$h ${_below100(rest)}';
  }

  /// `966` -> `Nine Hundred Sixty Six`
  static String number(int value) {
    if (value == 0) return 'Zero';
    if (value < 0) return 'Minus ${number(-value)}';

    final parts = <String>[];
    var n = value;

    final crore = n ~/ 10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;

    if (crore > 0) parts.add('${number(crore)} Crore');
    if (lakh > 0) parts.add('${_below1000(lakh)} Lakh');
    if (thousand > 0) parts.add('${_below1000(thousand)} Thousand');
    if (n > 0) parts.add(_below1000(n));

    return parts.join(' ');
  }

  /// `966.50` -> `Nine Hundred Sixty Six Rupees And Fifty Paise Only`
  static String rupees(num value) {
    final whole = value.floor();
    final paise = ((value - whole) * 100).round();
    final head = '${number(whole)} Rupee${whole == 1 ? '' : 's'}';
    if (paise == 0) return '$head Only';
    return '$head And ${number(paise)} Paise Only';
  }
}
