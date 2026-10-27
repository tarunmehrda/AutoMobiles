import 'package:flutter/foundation.dart';

import '../../core/i18n/strings.dart';
import 'entities.dart' show money;
import 'enums.dart';

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

double _num(Object? v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

// ---------------------------------------------------------------------------
// Where the money sits
// ---------------------------------------------------------------------------

/// The id the drawer is always kept under, so every phone agrees on it.
const String kCashAccountId = 'cash-in-hand';

/// A place the workshop's money is kept: the drawer ("Cash in Hand") or a
/// bank account. Each starts from an opening balance on a date and moves
/// with every cash-book line that went through it.
@immutable
class BankAccount {
  const BankAccount({
    required this.id,
    required this.name,
    this.cash = false,
    this.holder = '',
    this.accountNo = '',
    this.ifsc = '',
    this.branch = '',
    this.upiId = '',
    this.opening = 0,
    this.openingAt,
    this.primary = false,
    this.printOnInvoice = false,
    this.printUpiQr = false,
  });

  /// The drawer. There is only ever one.
  factory BankAccount.cashInHand({double opening = 0, DateTime? at}) =>
      BankAccount(
        id: kCashAccountId,
        name: 'Cash in Hand',
        cash: true,
        opening: opening,
        openingAt: at,
      );

  final String id;

  /// "HDFC Bank" — or "Cash in Hand" for the drawer.
  final String name;
  final bool cash;
  final String holder;
  final String accountNo;
  final String ifsc;
  final String branch;
  final String upiId;
  final double opening;
  final DateTime? openingAt;

  /// Where non-cash money lands when nothing else is said — a UPI payment,
  /// a cheque, a transfer.
  final bool primary;

  /// Print this account's details at the foot of the invoice.
  final bool printOnInvoice;

  /// Print a UPI QR for [upiId] on the invoice.
  final bool printUpiQr;

  /// `•••• 4321` — the number as it may be read out.
  String get masked {
    final n = accountNo.replaceAll(' ', '');
    if (n.length <= 4) return n;
    return '•••• ${n.substring(n.length - 4)}';
  }

  String get title => cash ? 'Cash in Hand'.tr : name;

  BankAccount copyWith({
    String? name,
    String? holder,
    String? accountNo,
    String? ifsc,
    String? branch,
    String? upiId,
    double? opening,
    DateTime? openingAt,
    bool? primary,
    bool? printOnInvoice,
    bool? printUpiQr,
  }) => BankAccount(
    id: id,
    name: name ?? this.name,
    cash: cash,
    holder: holder ?? this.holder,
    accountNo: accountNo ?? this.accountNo,
    ifsc: ifsc ?? this.ifsc,
    branch: branch ?? this.branch,
    upiId: upiId ?? this.upiId,
    opening: opening ?? this.opening,
    openingAt: openingAt ?? this.openingAt,
    primary: primary ?? this.primary,
    printOnInvoice: printOnInvoice ?? this.printOnInvoice,
    printUpiQr: printUpiQr ?? this.printUpiQr,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cash': cash,
    'holder': holder,
    'account_no': accountNo,
    'ifsc': ifsc,
    'branch': branch,
    'upi_id': upiId,
    'opening': opening,
    'opening_at': _iso(openingAt),
    'is_primary': primary,
    'print_on_invoice': printOnInvoice,
    'print_upi_qr': printUpiQr,
  };

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    cash: (j['cash'] ?? false) as bool,
    holder: (j['holder'] ?? '') as String,
    accountNo: (j['account_no'] ?? '') as String,
    ifsc: (j['ifsc'] ?? '') as String,
    branch: (j['branch'] ?? '') as String,
    upiId: (j['upi_id'] ?? '') as String,
    opening: _num(j['opening']),
    openingAt: _date(j['opening_at']),
    primary: (j['is_primary'] ?? false) as bool,
    printOnInvoice: (j['print_on_invoice'] ?? false) as bool,
    printUpiQr: (j['print_upi_qr'] ?? false) as bool,
  );
}

// ---------------------------------------------------------------------------
// Sales and purchase documents
// ---------------------------------------------------------------------------

/// The paper a sale or a purchase leaves behind. Job-card invoices, counter
/// sales and purchase orders keep their own older records; these are the
/// rest of the ledger.
enum TradeKind { estimate, saleReturn, saleOrder, purchaseBill, purchaseReturn }

extension TradeKindX on TradeKind {
  String get label => switch (this) {
    TradeKind.estimate => 'Estimate'.tr,
    TradeKind.saleReturn => 'Sale Return'.tr,
    TradeKind.saleOrder => 'Sale Order'.tr,
    TradeKind.purchaseBill => 'Purchase Bill'.tr,
    TradeKind.purchaseReturn => 'Purchase Return'.tr,
  };

  /// The number's prefix — `SR-0004`.
  String get prefix => switch (this) {
    TradeKind.estimate => 'EST',
    TradeKind.saleReturn => 'SR',
    TradeKind.saleOrder => 'SO',
    TradeKind.purchaseBill => 'PB',
    TradeKind.purchaseReturn => 'PR',
  };

  bool get isSale =>
      this == TradeKind.estimate ||
      this == TradeKind.saleReturn ||
      this == TradeKind.saleOrder;

  /// A quotation moves neither stock nor money.
  bool get isQuote => this == TradeKind.estimate;

  /// What it does to the shelf: +1 brings stock in, -1 takes it out, 0 is an
  /// order, which moves nothing.
  int get stockSign => switch (this) {
    TradeKind.saleReturn => 1,
    TradeKind.purchaseBill => 1,
    TradeKind.purchaseReturn => -1,
    TradeKind.saleOrder || TradeKind.estimate => 0,
  };

  /// Whether money settled on it comes in (true) or goes out (false).
  bool get moneyIn => switch (this) {
    TradeKind.estimate ||
    TradeKind.saleOrder ||
    TradeKind.purchaseReturn => true,
    TradeKind.saleReturn || TradeKind.purchaseBill => false,
  };

  static TradeKind parse(String? v) => TradeKind.values.firstWhere(
    (e) => e.name == v,
    orElse: () => TradeKind.purchaseBill,
  );
}

/// How the tax on a line is split. Inside one state it is CGST + SGST, half
/// each; across states it is IGST, all of it.
enum TaxSplit { intra, inter }

/// One row on a sale or purchase document.
@immutable
class TradeLine {
  const TradeLine({
    required this.name,
    this.kind = LineKind.spare,
    this.masterId,
    this.qty = 1,
    this.unit = 'nos',
    this.rate = 0,
    this.gstRate = 0,
    this.taxIncluded = false,
    this.hsn = '',
  });

  final String name;

  /// Job, spare or lube — how an estimate groups its lines.
  final LineKind kind;

  /// Set when the row is a stocked item, so the document moves its stock.
  final String? masterId;
  final double qty;
  final String unit;

  /// The rate as typed — with or without tax, as [taxIncluded] says.
  final double rate;

  /// The GST slab as a fraction (0.18).
  final double gstRate;
  final bool taxIncluded;
  final String hsn;

  /// The value before tax.
  double get taxable {
    final gross = qty * rate;
    return money(taxIncluded ? gross / (1 + gstRate) : gross);
  }

  double get tax => money(taxable * gstRate);

  double get total => money(taxable + tax);

  /// Half the tax each way inside the state; all of it as IGST across.
  double cgst(TaxSplit s) => s == TaxSplit.intra ? money(tax / 2) : 0;
  double sgst(TaxSplit s) => s == TaxSplit.intra ? money(tax - tax / 2) : 0;
  double igst(TaxSplit s) => s == TaxSplit.inter ? tax : 0;

  TradeLine copyWith({
    String? name,
    double? qty,
    String? unit,
    double? rate,
    double? gstRate,
    bool? taxIncluded,
    String? hsn,
  }) => TradeLine(
    name: name ?? this.name,
    kind: kind,
    masterId: masterId,
    qty: qty ?? this.qty,
    unit: unit ?? this.unit,
    rate: rate ?? this.rate,
    gstRate: gstRate ?? this.gstRate,
    taxIncluded: taxIncluded ?? this.taxIncluded,
    hsn: hsn ?? this.hsn,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind.name,
    'master_id': masterId,
    'qty': qty,
    'unit': unit,
    'rate': rate,
    'gst_rate': gstRate,
    'tax_included': taxIncluded,
    'hsn': hsn,
  };

  factory TradeLine.fromJson(Map<String, dynamic> j) => TradeLine(
    name: (j['name'] ?? '') as String,
    kind: LineKindX.parse(j['kind'] as String?),
    masterId: j['master_id'] as String?,
    qty: _num(j['qty']),
    unit: (j['unit'] ?? 'nos') as String,
    rate: _num(j['rate']),
    gstRate: _num(j['gst_rate']),
    taxIncluded: (j['tax_included'] ?? false) as bool,
    hsn: (j['hsn'] ?? '') as String,
  );
}

/// An estimate, sale return, sale order, purchase bill or purchase return.
@immutable
class TradeDoc {
  const TradeDoc({
    required this.id,
    required this.kind,
    required this.number,
    required this.at,
    this.party = '',
    this.phone = '',
    this.gstin = '',
    this.address = '',
    this.supplierId,
    this.customerId,
    this.lines = const [],
    this.split = TaxSplit.intra,
    this.discount = 0,
    this.paid = 0,
    this.mode = PayMode.cash,
    this.accountId,
    this.note = '',
    this.refNo = '',
    this.dueAt,
    this.fulfilled = false,
  });

  final String id;
  final TradeKind kind;
  final String number;
  final DateTime at;
  final String party;
  final String phone;
  final String gstin;
  final String address;
  final String? supplierId;
  final String? customerId;
  final List<TradeLine> lines;
  final TaxSplit split;
  final double discount;

  /// Settled on the document itself, at the time it was made.
  final double paid;
  final PayMode mode;
  final String? accountId;
  final String note;

  /// The other side's own number — the supplier's bill no, or the invoice a
  /// return is against.
  final String refNo;

  /// When an order is due.
  final DateTime? dueAt;

  /// An order that has been delivered, or an estimate turned into a job
  /// card.
  final bool fulfilled;

  double get taxable => money(lines.fold<double>(0, (s, e) => s + e.taxable));
  double get tax => money(lines.fold<double>(0, (s, e) => s + e.tax));
  double get cgst => money(lines.fold<double>(0, (s, e) => s + e.cgst(split)));
  double get sgst => money(lines.fold<double>(0, (s, e) => s + e.sgst(split)));
  double get igst => money(lines.fold<double>(0, (s, e) => s + e.igst(split)));
  double get total =>
      money((taxable + tax - discount).clamp(0, double.infinity));
  double get balance => money((total - paid).clamp(0, double.infinity));
  bool get settled => balance <= 0.009;

  TradeDoc copyWith({
    String? party,
    String? phone,
    String? gstin,
    String? address,
    List<TradeLine>? lines,
    TaxSplit? split,
    double? discount,
    double? paid,
    PayMode? mode,
    String? accountId,
    String? note,
    String? refNo,
    DateTime? at,
    DateTime? dueAt,
    bool? fulfilled,
  }) => TradeDoc(
    id: id,
    kind: kind,
    number: number,
    at: at ?? this.at,
    party: party ?? this.party,
    phone: phone ?? this.phone,
    gstin: gstin ?? this.gstin,
    address: address ?? this.address,
    supplierId: supplierId,
    customerId: customerId,
    lines: lines ?? this.lines,
    split: split ?? this.split,
    discount: discount ?? this.discount,
    paid: paid ?? this.paid,
    mode: mode ?? this.mode,
    accountId: accountId ?? this.accountId,
    note: note ?? this.note,
    refNo: refNo ?? this.refNo,
    dueAt: dueAt ?? this.dueAt,
    fulfilled: fulfilled ?? this.fulfilled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'number': number,
    'at': _iso(at)!,
    'party': party,
    'phone': phone,
    'gstin': gstin,
    'address': address,
    'supplier_id': supplierId,
    'customer_id': customerId,
    'lines': lines.map((e) => e.toJson()).toList(),
    'split': split.name,
    'discount': discount,
    'paid': paid,
    'mode': mode.name,
    'account_id': accountId,
    'note': note,
    'ref_no': refNo,
    'due_at': _iso(dueAt),
    'fulfilled': fulfilled,
  };

  factory TradeDoc.fromJson(Map<String, dynamic> j) => TradeDoc(
    id: j['id'] as String,
    kind: TradeKindX.parse(j['kind'] as String?),
    number: (j['number'] ?? '') as String,
    at: _date(j['at']) ?? DateTime.now(),
    party: (j['party'] ?? '') as String,
    phone: (j['phone'] ?? '') as String,
    gstin: (j['gstin'] ?? '') as String,
    address: (j['address'] ?? '') as String,
    supplierId: j['supplier_id'] as String?,
    customerId: j['customer_id'] as String?,
    lines: ((j['lines'] as List?) ?? const [])
        .map((e) => TradeLine.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    split: j['split'] == 'inter' ? TaxSplit.inter : TaxSplit.intra,
    discount: _num(j['discount']),
    paid: _num(j['paid']),
    mode: PayModeX.parse(j['mode'] as String?),
    accountId: j['account_id'] as String?,
    note: (j['note'] ?? '') as String,
    refNo: (j['ref_no'] ?? '') as String,
    dueAt: _date(j['due_at']),
    fulfilled: (j['fulfilled'] ?? false) as bool,
  );
}

// ---------------------------------------------------------------------------
// Growing the business
// ---------------------------------------------------------------------------

/// Business links the workshop shares from "Grow your business".
@immutable
class SocialLinks {
  const SocialLinks({
    this.whatsapp = '',
    this.instagram = '',
    this.facebook = '',
    this.youtube = '',
    this.google = '',
    this.website = '',
  });

  final String whatsapp;
  final String instagram;
  final String facebook;
  final String youtube;

  /// The Google Business Profile / Maps review link.
  final String google;
  final String website;

  bool get isEmpty => [
    whatsapp,
    instagram,
    facebook,
    youtube,
    google,
    website,
  ].every((e) => e.trim().isEmpty);

  SocialLinks copyWith({
    String? whatsapp,
    String? instagram,
    String? facebook,
    String? youtube,
    String? google,
    String? website,
  }) => SocialLinks(
    whatsapp: whatsapp ?? this.whatsapp,
    instagram: instagram ?? this.instagram,
    facebook: facebook ?? this.facebook,
    youtube: youtube ?? this.youtube,
    google: google ?? this.google,
    website: website ?? this.website,
  );

  Map<String, dynamic> toJson() => {
    'whatsapp': whatsapp,
    'instagram': instagram,
    'facebook': facebook,
    'youtube': youtube,
    'google': google,
    'website': website,
  };

  factory SocialLinks.fromJson(Map<String, dynamic>? j) => j == null
      ? const SocialLinks()
      : SocialLinks(
          whatsapp: (j['whatsapp'] ?? '') as String,
          instagram: (j['instagram'] ?? '') as String,
          facebook: (j['facebook'] ?? '') as String,
          youtube: (j['youtube'] ?? '') as String,
          google: (j['google'] ?? '') as String,
          website: (j['website'] ?? '') as String,
        );
}

/// A workshop account this phone has signed in to, kept so the owner can
/// switch between their companies without retyping the email.
@immutable
class KnownCompany {
  const KnownCompany({required this.email, required this.name, this.lastUsed});

  final String email;
  final String name;
  final DateTime? lastUsed;

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'last_used': _iso(lastUsed),
  };

  factory KnownCompany.fromJson(Map<String, dynamic> j) => KnownCompany(
    email: (j['email'] ?? '') as String,
    name: (j['name'] ?? '') as String,
    lastUsed: _date(j['last_used']),
  );
}

/// The cash-book reasons Payment In and Pay Out are filed under, so their
/// lists can be read back out of the day book.
const String kPaymentIn = 'Payment In';
const String kPayOut = 'Pay Out';
