import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/data/app_database.dart';
import 'package:money_tracker/models/currency.dart';
import 'package:money_tracker/models/models.dart';
import 'package:money_tracker/state/app_state.dart';
import 'package:money_tracker/state/settings_store.dart';
import 'package:money_tracker/utils/money.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppState state;
  late AppDatabase db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'settings.lang': 'en',
      'settings.demoSeen': true,
      'settings.demoAdded': true,
    });
    db = AppDatabase(customPath: inMemoryDatabasePath);
    state = AppState(Repository(db), SettingsStore());
    await state.init();
  });

  tearDown(() async {
    await db.close();
  });

  int? cat(String slug) =>
      state.categories.firstWhere((c) => c.name == slug).id;

  test('formatMoney renders localized symbol and grouping', () {
    expect(stripIsolates(state.moneyFor(85000, 'DZD')), '85\u2009000 DA');
    expect(
      stripIsolates(state.moneyFor(1200, 'USD')),
      r'$ 1'
      '\u2009'
      r'200',
    );
    expect(
      stripIsolates(state.moneyFor(1200, 'EUR')),
      '€ 1'
      '\u2009'
      '200',
    );
  });

  test('new transactions use the active currency', () async {
    await state.addTransaction(
      type: TxType.expense,
      amount: 1000,
      categoryId: cat('food'),
      date: DateTime(2026, 1, 3),
    );
    expect(state.transactions.single.currency, 'DZD');
    expect(state.monthTotals(DateTime(2026, 1, 1)).$2, 1000);
  });

  test('switching currency keeps history and original amounts', () async {
    await state.addTransaction(
      type: TxType.expense,
      amount: 2000,
      categoryId: cat('food'),
      date: DateTime(2026, 1, 3),
    );
    final id = state.transactions.single.id;

    expect(await state.setCurrency('USD'), isTrue);
    expect(state.currency, 'USD');

    final t = state.transactions.single;
    expect(t.id, id);
    expect(t.currency, 'DZD');
    expect(t.amount, 2000);
    expect(state.monthTotals(DateTime(2026, 1, 1)).$2, 0);
  });

  test('convert mode scales amounts and records conversion audit', () async {
    await state.addTransaction(
      type: TxType.expense,
      amount: 2000,
      categoryId: cat('food'),
      date: DateTime(2026, 1, 3),
    );
    final id = state.transactions.single.id;

    final ok = await state.setCurrency(
      'USD',
      mode: CurrencyChangeMode.convert,
      rate: 0.0067,
    );
    expect(ok, isTrue);

    final t = state.transactions.single;
    expect(t.id, id);
    expect(t.currency, 'USD');
    expect(t.amount, 13);
    expect(t.originalAmount, 2000);
    expect(t.originalCurrency, 'DZD');
    expect(state.monthTotals(DateTime(2026, 1, 1)).$2, 13);
  });

  test('conversion requires a positive rate', () async {
    expect(
      await state.setCurrency('USD', mode: CurrencyChangeMode.convert, rate: 0),
      isFalse,
    );
    expect(
      await state.setCurrency(
        'USD',
        mode: CurrencyChangeMode.convert,
        rate: -1,
      ),
      isFalse,
    );
    expect(state.currency, 'DZD');
  });

  test(
    'trilingual rename keeps stable id and populates localized names',
    () async {
      final food = cat('food');
      final before = state.categoryById(food)!;
      await state.renameCategory(
        before,
        'Nourriture',
        nameEn: 'Food',
        nameFr: 'Nourriture',
        nameAr: 'غذاء',
      );
      final renamed = state.categoryById(food)!;
      expect(renamed.name, 'food');
      expect(renamed.id, food);
      expect(renamed.nameEn, 'Food');
      expect(renamed.nameFr, 'Nourriture');
      expect(renamed.nameAr, 'غذاء');
    },
  );
}
