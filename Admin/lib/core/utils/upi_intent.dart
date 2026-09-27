/// The scan-to-pay string behind every payment QR in the console.
///
/// One builder, because the QR on the ledger tab and the QR printed on the
/// bill have to resolve to the same collection — a customer who scans the
/// paper and a customer who scans the screen must reach the same account for
/// the same amount.
library;

/// A standard UPI intent. Any UPI app reads it and pre-fills the amount.
///
/// Returns an empty string when there is no payee to collect into, which is
/// the caller's signal to leave the QR off rather than print one that
/// resolves nowhere.
String upiIntent({
  required String upiId,
  required String payee,
  required double amount,
  String note = '',
}) {
  final pa = upiId.trim();
  if (pa.isEmpty) return '';
  return Uri(
    scheme: 'upi',
    host: 'pay',
    queryParameters: {
      'pa': pa,
      'pn': payee,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      if (note.isNotEmpty) 'tn': note,
    },
  ).toString();
}
