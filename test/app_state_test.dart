import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/data/app_database.dart';
import 'package:money_tracker/models/models.dart';
import 'package:money_tracker/state/app_state.dart';
import 'package:money_tracker/state/settings_store.dart';
import 'package:money_tracker/utils/money.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppState state;
  late AppDatabase appDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'settings.demoSeen': true,
      'settings.demoAdded': true,
    });
    final settings = SettingsStore();
    appDb = AppDatabase(customPath: inMemoryDatabasePath);
    final state2 = AppState(Repository(appDb), settings);
    await state2.init();
    state = state2;
  });

  tearDown(() async {
    // The in-memory DB is cached per-isolate; closing it guarantees a fresh
    // database on the next setUp so tests stay isolated.
    await appDb.close();
  });

  int? categoryId(String slug) {
    for (final c in state.categories) {
      if (c.name == slug) return c.id;
    }
    return null;
  }

  test('no demo data when settings say seen', () {
    expect(state.transactions, isEmpty);
  });

  test('balance, month totals and savings rate', () async {
    final month = state.currentMonth;
    final incomeCat = categoryId('salary');
    final expenseCat = categoryId('food');
    final day = DateTime(month.year, month.month, 10);

    await state.addTransaction(
        type: TxType.income, amount: 100000, categoryId: incomeCat, date: day);
    await state.addTransaction(
        type: TxType.expense, amount: 20000, categoryId: expenseCat, date: day);
    await state.addTransaction(
        type: TxType.expense, amount: 30000, categoryId: expenseCat, date: day);

    expect(state.balance, 50000);
    final (inc, exp) = state.monthTotals(month);
    expect(inc, 100000);
    expect(exp, 50000);
    expect(state.savingsRate(month), 50);
    expect(state.expensesOn(day), 50000);
    expect(state.incomesOn(day), 100000);
    expect(state.countInMonth(month), 3);
  });

  test('category aggregates in month', () async {
    final month = state.currentMonth;
    final incomeCat = categoryId('salary');
    final expenseCat = categoryId('food');
    final day = DateTime(month.year, month.month, 5);

    await state.addTransaction(
        type: TxType.income, amount: 100000, categoryId: incomeCat, date: day);
    await state.addTransaction(
        type: TxType.expense, amount: 15000, categoryId: expenseCat, date: day);
    await state.addTransaction(
        type: TxType.expense, amount: 25000, categoryId: expenseCat, date: day);

    final totals = state.categoryTotalsInMonth(month);
    expect(totals[expenseCat], 40000);
    expect(totals[incomeCat], isNull);
    expect(state.categorySpentInMonth(expenseCat!, month), 40000);
    expect(state.categoryCountInMonth(expenseCat, month), 2);
    expect(state.categorySpentInMonth(incomeCat!, month), 0);
  });

  test('dailySeries buckets by day across months', () async {
    final incomeCat = categoryId('salary');
    final expenseCat = categoryId('food');
    await state.addTransaction(
        type: TxType.income,
        amount: 1000,
        categoryId: incomeCat,
        date: DateTime(2025, 6, 1));
    await state.addTransaction(
        type: TxType.expense,
        amount: 300,
        categoryId: expenseCat,
        date: DateTime(2025, 6, 2));
    await state.addTransaction(
        type: TxType.expense,
        amount: 200,
        categoryId: expenseCat,
        date: DateTime(2025, 6, 2));

    final series =
        state.dailySeries(DateTime(2025, 6, 1), DateTime(2025, 6, 3));
    expect(series.length, 3);
    expect(series[0], ('2025-06-01', 1000, 0));
    expect(series[1], ('2025-06-02', 0, 500));
    expect(series[2], ('2025-06-03', 0, 0));
  });

  test('budgets save and delete', () async {
    final food = categoryId('food')!;
    await state.saveBudget(categoryId: food, amount: 20000);
    expect(state.budgets.single.amount, 20000);

    await state.deleteBudget(state.budgets.single);
    expect(state.budgets, isEmpty);
  });

  test('savings goals and addToGoal', () async {
    await state.saveGoal(name: 'Car', target: 100000, current: 0);
    final g = state.goals.single;
    await state.addToGoal(g, 25000);
    expect(state.goals.single.currentAmount, 25000);
    expect(state.goals.single.progressPercent, 25);
  });

  test('recurring committed monthly totals', () async {
    final food = categoryId('food')!;
    await state.saveRecurring(
        type: TxType.expense,
        amount: 5000,
        categoryId: food,
        frequency: 'monthly',
        start: DateTime(2025, 1, 1));
    await state.saveRecurring(
        type: TxType.expense,
        amount: 2500,
        categoryId: food,
        frequency: 'weekly',
        start: DateTime(2025, 1, 1));
    await state.saveRecurring(
        type: TxType.income,
        amount: 60000,
        categoryId: categoryId('salary'),
        frequency: 'monthly',
        start: DateTime(2025, 1, 1));
    expect(state.committedMonthly, 15000);
    expect(state.committedMonthlyIncome, 60000);
  });

  test('renameCategory updates the category and keeps history', () async {
    final food = categoryId('food')!;
    await state.addTransaction(
        type: TxType.expense,
        amount: 5000,
        categoryId: food,
        date: DateTime(state.currentMonth.year, state.currentMonth.month, 5));
    await state.renameCategory(state.categoryById(food)!, ' Eating  Out ');
    final renamed = state.categoryById(food)!;
    expect(renamed.name, 'eating_out');
    expect(renamed.id, food);
    expect(state.transactions.single.categoryId, food);
    expect(state.strings.categoryName(renamed.name), 'Eating Out');
  });

  test('removeCategory deletes the category', () async {
    await state.addCustomCategory('gym', 'fitness_center', TxType.expense);
    final gym = state.categories.firstWhere((c) => c.name == 'gym');
    await state.removeCategory(gym);
    expect(state.categoryById(gym.id), isNull);
  });

  test('recentCategoryIds favours most recent transactions per type',
      () async {
    final food = categoryId('food')!;
    final transport = categoryId('transport')!;
    final salary = categoryId('salary')!;
    await state.addTransaction(
        type: TxType.expense,
        amount: 100,
        categoryId: food,
        date: DateTime(2025, 1, 1));
    await state.addTransaction(
        type: TxType.expense,
        amount: 200,
        categoryId: transport,
        date: DateTime(2025, 2, 1));
    await state.addTransaction(
        type: TxType.income,
        amount: 1000,
        categoryId: salary,
        date: DateTime(2025, 2, 5));

    expect(state.recentCategoryIds(TxType.expense), [transport, food]);
    expect(state.recentCategoryIds(TxType.income, limit: 1), [salary]);
    expect(state.recentCategoryIds(TxType.income), [salary]);
  });

  test('addTransaction remembers the last payment method', () async {
    await state.addTransaction(
        type: TxType.expense,
        amount: 500,
        categoryId: categoryId('food'),
        date: DateTime(state.currentMonth.year, state.currentMonth.month, 6),
        paymentMethod: 'card');
    expect(state.settings.lastPayment, 'card');
  });

  test('language switch rebuilds strings', () async {
    expect(state.strings.lang, 'fr');
    await state.setLang('en');
    expect(state.strings.lang, 'en');
    expect(state.strings.tr('save'), isNotEmpty);
  });

  test('formatDA and dateKey are consistent with stored data', () async {
    final food = categoryId('food')!;
    await state.addTransaction(
        type: TxType.expense,
        amount: 150000,
        categoryId: food,
        date: DateTime(2025, 7, 8));
    final t = state.transactions.single;
    expect(formatDA(t.amount), '150\u2009000 DA');
    expect(t.date, '2025-07-08');
  });
}