import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/data/models/books.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/repo/admin_data.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// The books the client asked for: per-line GST, the advance, cash in hand
/// against the bank, and the purchase and sale documents with what each one
/// does to stock and to what a supplier is owed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  AdminController c() => container.read(adminProvider.notifier);
  AdminData d() => container.read(adminProvider);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    localStore = await LocalStore.open();
    container = ProviderContainer();
    c().markSignedIn();
    c().completeOnboarding();
  });
  tearDown(() => container.dispose());

  MasterItem battery() => c().addMaster(
    kind: LineKind.spare,
    name: 'Battery',
    rate: 5000,
    stock: 10,
  );

  JobCard card() {
    final cu = c().upsertCustomer(name: 'Ramesh', phone: '9876543210');
    final v = c().upsertVehicle(
      customerId: cu.id,
      regNo: 'KA01AB1234',
      brand: 'Hyundai',
      model: 'Santro',
      year: 2015,
    );
    return c().createJobCard(
      customerId: cu.id,
      vehicleId: v.id,
      odometerKm: 0,
      fuelPercent: 30,
    );
  }

  group('job card GST and advance', () {
    test('each line is taxed at its own rate, the rest at the card rate', () {
      final j = card();
      c().addItem(j.id, kind: LineKind.spare, name: 'Battery', rate: 1000,
          gstRate: 0.28);
      c().addItem(j.id, kind: LineKind.job, name: 'Labour', rate: 1000);
      c().setTaxRate(j.id, 0.18);
      final now = d().jobById(j.id)!;
      expect(now.taxAmount, 280 + 180);
      expect(now.total, 2460);
    });

    test('a discount takes its share off every line\'s tax', () {
      final j = card();
      c().addItem(j.id, kind: LineKind.spare, name: 'A', rate: 1000,
          gstRate: 0.28);
      c().addItem(j.id, kind: LineKind.job, name: 'B', rate: 1000,
          gstRate: 0.18);
      c().setDiscount(j.id, 1000);
      // Half the value is gone, so half of each line's tax goes with it.
      expect(d().jobById(j.id)!.taxAmount, 140 + 90);
    });

    test('the advance is told apart from what was paid at delivery', () {
      final j = card();
      c().addPayment(j.id, amount: 500, mode: PayMode.upi, advance: true);
      c().addItem(j.id, kind: LineKind.job, name: 'Service', rate: 2000);
      c().addPayment(j.id, amount: 1000, mode: PayMode.cash);
      final now = d().jobById(j.id)!;
      expect(now.advancePaid, 500);
      expect(now.paid, 1500);
      expect(now.balance, 500);
    });
  });

  test('deleting a card takes its money out of the drawer too', () {
    final j = card();
    c().addPayment(j.id, amount: 500, mode: PayMode.cash, advance: true);
    expect(d().balanceOf(d().cashAccount), 500);
    c().deleteJobCard(j.id);
    expect(d().balanceOf(d().cashAccount), 0);
  });

  group('bank and cash in hand', () {
    test('cash lands in the drawer, UPI in the primary bank', () {
      final j = card();
      c().setCashOpening(2000, DateTime(2020));
      c().addBank(name: 'HDFC', opening: 10000, openingAt: DateTime(2020));
      c().addItem(j.id, kind: LineKind.job, name: 'Service', rate: 3000);
      c().addPayment(j.id, amount: 1000, mode: PayMode.cash);
      c().addPayment(j.id, amount: 2000, mode: PayMode.upi);
      expect(d().balanceOf(d().cashAccount), 3000);
      expect(d().balanceOf(d().primaryBank!), 12000);
      expect(d().totalFunds, 15000);
    });

    test('the first bank is primary, and marking another moves it', () {
      final a = c().addBank(name: 'HDFC');
      expect(d().primaryBank!.id, a.id);
      final b = c().addBank(name: 'SBI', primary: true);
      expect(d().primaryBank!.id, b.id);
      expect(d().banks.where((x) => x.primary).length, 1);
    });

    test('an online expense comes out of the bank, not the drawer', () {
      c().addBank(name: 'HDFC', opening: 5000, openingAt: DateTime(2020));
      c().addExpense(
        title: 'Rent',
        amount: 3000,
        paid: 3000,
        category: 'Rent',
        mode: PayMode.upi,
      );
      expect(d().balanceOf(d().primaryBank!), 2000);
      expect(d().balanceOf(d().cashAccount), 0);
    });

    test('banking cash moves it, and changes nothing in total', () {
      c().setCashOpening(5000, DateTime(2020));
      final bank = c().addBank(name: 'HDFC', openingAt: DateTime(2020));
      c().transferFunds(fromId: kCashAccountId, toId: bank.id, amount: 4000);
      expect(d().balanceOf(d().cashAccount), 1000);
      expect(d().balanceOf(d().accountById(bank.id)!), 4000);
      expect(d().totalFunds, 5000);
    });
  });

  group('sales and purchase documents', () {
    test('a purchase bill stocks up and owes the supplier the balance', () {
      final m = battery();
      final s = c().addSupplier(name: 'Exide Distributor');
      final bill = c().addTradeDoc(
        kind: TradeKind.purchaseBill,
        supplierId: s.id,
        lines: [
          TradeLine(name: 'Battery', masterId: m.id, qty: 2, rate: 4000,
              gstRate: 0.28),
        ],
        paid: 4000,
      );
      expect(bill.number, 'PB-0001');
      expect(bill.total, 10240);
      expect(bill.cgst, 1120);
      expect(bill.sgst, 1120);
      expect(d().masterById(m.id)!.stock, 12);
      expect(d().supplierById(s.id)!.outstanding, 6240);
      expect(d().balanceOf(d().cashAccount), -4000);

      c().recordPayOut(party: s.name, supplierId: s.id, amount: 6240);
      expect(d().supplierById(s.id)!.outstanding, 0);
    });

    test('deleting a bill undoes stock, money and the supplier', () {
      final m = battery();
      final s = c().addSupplier(name: 'Exide Distributor');
      final bill = c().addTradeDoc(
        kind: TradeKind.purchaseBill,
        supplierId: s.id,
        lines: [TradeLine(name: 'Battery', masterId: m.id, qty: 2, rate: 100)],
        paid: 50,
      );
      c().settleTradeDoc(bill.id, amount: 100, mode: PayMode.cash);
      c().removeTradeDoc(bill.id);
      expect(d().masterById(m.id)!.stock, 10);
      expect(d().supplierById(s.id)!.outstanding, 0);
      expect(d().cashBook, isEmpty);
    });

    test('a rate typed with tax is split back out of it', () {
      const l = TradeLine(name: 'Oil', qty: 1, rate: 118, gstRate: 0.18,
          taxIncluded: true);
      expect(l.taxable, 100);
      expect(l.tax, 18);
      expect(l.igst(TaxSplit.inter), 18);
      expect(l.cgst(TaxSplit.inter), 0);
    });

    test('a sale return puts stock back and pays the customer', () {
      final m = battery();
      c().addTradeDoc(
        kind: TradeKind.saleReturn,
        party: 'Walk-in',
        lines: [TradeLine(name: 'Battery', masterId: m.id, rate: 5000)],
        paid: 5000,
      );
      expect(d().masterById(m.id)!.stock, 11);
      expect(d().balanceOf(d().cashAccount), -5000);
    });

    test('an order moves nothing until it is handed over', () {
      final m = battery();
      final o = c().addTradeDoc(
        kind: TradeKind.saleOrder,
        party: 'Fleet Co',
        lines: [TradeLine(name: 'Battery', masterId: m.id, qty: 3, rate: 5000)],
      );
      expect(d().masterById(m.id)!.stock, 10);
      c().fulfilSaleOrder(o.id, collect: 15000, mode: PayMode.upi);
      expect(d().masterById(m.id)!.stock, 7);
      expect(d().tradeDocs.single.settled, isTrue);
    });

    test('an estimate moves neither stock nor money', () {
      final m = battery();
      final e = c().addTradeDoc(
        kind: TradeKind.estimate,
        party: 'Ramesh',
        lines: [TradeLine(name: 'Battery', masterId: m.id, rate: 5000)],
      );
      expect(e.number, 'EST-0001');
      expect(d().masterById(m.id)!.stock, 10);
      expect(d().cashBook, isEmpty);
      c().markEstimateConverted(e.id);
      expect(d().tradeDocs.single.fulfilled, isTrue);
    });
  });

  test('the books survive a restart', () {
    c().addBank(name: 'HDFC', accountNo: '123456789', printOnInvoice: true);
    c().addTradeDoc(
      kind: TradeKind.purchaseBill,
      lines: const [TradeLine(name: 'Oil', unit: 'ltr', qty: 5, rate: 300)],
    );
    c().setSocial(const SocialLinks(instagram: 'insta/balaji'));
    final back = AdminData.fromJson(d().toJson());
    expect(back.banks.single.printOnInvoice, isTrue);
    expect(back.tradeDocs.single.lines.single.unit, 'ltr');
    expect(back.social.instagram, 'insta/balaji');
  });

  test('switching company keeps the list of companies', () {
    c().rememberCompany('A@x.in', 'Balaji Automobiles');
    c().rememberCompany('b@x.in', 'Balaji Motors');
    expect(d().signedOut().knownCompanies.map((k) => k.email), [
      'b@x.in',
      'a@x.in',
    ]);
  });
}
