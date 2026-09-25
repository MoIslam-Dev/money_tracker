import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/data/app_database.dart';
import 'package:money_tracker/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDb;
  late Repository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    appDb = AppDatabase(customPath: inMemoryDatabasePath);
    repo = Repository(appDb);
    await repo.categories(); // trigger schema creation
  });

  tearDown(() async {
    await appDb.close();
  });

  test('seeds default categories on first open', () async {
    final cats = await repo.categories();
    expect(cats.length, greaterThan(20));
    expect(cats.where((c) => c.type == TxType.expense).length, 23);
    expect(cats.any((c) => c.name == 'food'), isTrue);
    expect(cats.any((c) => c.name == 'salary'), isTrue);
  });

  test('category add / upsert / delete', () async {
    final added = await repo.addCategory(AppCategory(
      name: 'custom_x',
      type: TxType.expense,
      icon: 'more_horiz',
      isDefault: false,
      sortOrder: 999,
    ));
    expect(added, greaterThan(0));

    final byId = await repo.categoryById(added);
    expect(byId!.name, 'custom_x');

    final upserted = await repo.upsertCategory(AppCategory(
      name: 'custom_x',
      type: TxType.expense,
      icon: 'more_horiz',
    ));
    expect(upserted!.id, added);

    await repo.deleteCategory(added);
    expect(await repo.categoryById(added), isNull);
  });

  test('updateCategory renames in place keeping id and type', () async {
    final id = await repo.addCategory(AppCategory(
      name: 'gym',
      type: TxType.expense,
      icon: 'fitness_center',
      isDefault: false,
      sortOrder: 900,
    ));
    await repo.updateCategory(AppCategory(
      id: id,
      name: 'sport',
      type: TxType.expense,
      icon: 'fitness_center',
      isDefault: false,
      sortOrder: 900,
    ));
    final got = await repo.categoryById(id);
    expect(got!.name, 'sport');
    expect(got.id, id);
    expect(got.type, TxType.expense);
  });

  test('deleteCategory reassigns transactions, budgets and recurring to Other',
      () async {
    final custom = await repo.addCategory(AppCategory(
      name: 'gym',
      type: TxType.expense,
      icon: 'fitness_center',
      isDefault: false,
      sortOrder: 901,
    ));
    final all = await repo.categories();
    final other = all.firstWhere(
        (c) => c.type == TxType.expense && c.name == 'other');

    await repo.addTransaction(AppTransaction(
      type: TxType.expense,
      amount: 2400,
      categoryId: custom,
      date: '2025-02-10',
      createdAt: 't',
      updatedAt: 't',
    ));
    await repo.addBudget(
        Budget(categoryId: custom, amount: 10000, month: 2, year: 2025));
    await repo.addRecurring(RecurringTxn(
      type: TxType.expense,
      amount: 5000,
      categoryId: custom,
      frequency: 'monthly',
      startDate: '2025-01-01',
      createdAt: 't',
    ));

    await repo.deleteCategory(custom);

    expect(await repo.categoryById(custom), isNull);
    expect((await repo.transactions()).single.categoryId, other.id);
    expect((await repo.budgetFor(other.id!, 2, 2025))!.amount, 10000);
    expect((await repo.recurring()).single.categoryId, other.id);
  });

  test('existing data survives a reopen at the same schema version', () async {
    final dir = await Directory.systemTemp.createTemp('money_tracker_test');
    final path = '${dir.path}${Platform.pathSeparator}mt.db';
    try {
      final db1 = AppDatabase(customPath: path);
      final repo1 = Repository(db1);
      await repo1.categories();
      final id = await repo1.addCategory(AppCategory(
        name: 'gym',
        type: TxType.expense,
        icon: 'fitness_center',
        isDefault: false,
        sortOrder: 902,
      ));
      await repo1.addTransaction(AppTransaction(
        type: TxType.expense,
        amount: 9999,
        categoryId: id,
        date: '2025-05-05',
        createdAt: 't',
        updatedAt: 't',
      ));
      await db1.close();

      final db2 = AppDatabase(customPath: path);
      final repo2 = Repository(db2);
      final txns = await repo2.transactions();
      expect(txns.single.amount, 9999);
      expect((await repo2.categoryById(id))!.name, 'gym');
      expect((await repo2.categories()).length, greaterThan(20));
      final db = await db2.database;
      expect(await db.getVersion(), 4);
      await db2.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('transaction CRUD round-trip', () async {
    final t = AppTransaction(
      type: TxType.expense,
      amount: 2500,
      categoryId: null,
      paymentMethod: 'cash',
      date: '2025-03-15',
      note: 'lunch',
      createdAt: '2025-03-15T12:00:00Z',
      updatedAt: '2025-03-15T12:00:00Z',
    );
    final id = await repo.addTransaction(t);
    final got = await repo.transactionById(id);
    expect(got!.amount, 2500);
    expect(got.type, TxType.expense);
    expect(got.note, 'lunch');

    await repo.updateTransaction(AppTransaction(
      id: id,
      type: TxType.expense,
      amount: 3000,
      categoryId: null,
      paymentMethod: 'card',
      date: '2025-03-16',
      createdAt: got.createdAt,
      updatedAt: '2025-03-16T12:00:00Z',
    ));
    final edited = await repo.transactionById(id);
    expect(edited!.amount, 3000);
    expect(edited.date, '2025-03-16');

    final filtered = await repo.transactions(from: '2025-03-01', to: '2025-03-31');
    expect(filtered.length, 1);

    await repo.deleteTransaction(id);
    expect(await repo.transactionById(id), isNull);
    expect(await repo.countTransactions(), 0);
  });

  test('budgets save, update and delete', () async {
    final id = await repo.addBudget(
        Budget(categoryId: 1, amount: 15000, month: 3, year: 2025));
    final b = await repo.budgetFor(1, 3, 2025);
    expect(b!.amount, 15000);
    expect(b.month, 3);

    // update through saveBudget using the existing id
    await repo.saveBudget(
        Budget(id: id, categoryId: 1, amount: 12000, month: 3, year: 2025));
    final updated = await repo.budgetFor(1, 3, 2025);
    expect(updated!.amount, 12000);

    final list = await repo.budgets();
    expect(list.where((x) => x.month == 3 && x.year == 2025).length, 1);

    await repo.deleteBudget(id);
    expect(await repo.budgetFor(1, 3, 2025), isNull);
  });

  test('savings goal CRUD', () async {
    final id = await repo.addGoal(SavingsGoal(
      name: 'Laptop',
      targetAmount: 200000,
      currentAmount: 50000,
      createdAt: 't',
      updatedAt: 't',
    ));
    await repo.updateGoal(SavingsGoal(
      id: id,
      name: 'Laptop',
      targetAmount: 200000,
      currentAmount: 70000,
      createdAt: 't',
      updatedAt: 't2',
    ));
    final goals = await repo.goals();
    expect(goals.single.currentAmount, 70000);

    await repo.deleteGoal(id);
    expect(await repo.goals(), isEmpty);
  });

  test('recurring CRUD', () async {
    final id = await repo.addRecurring(RecurringTxn(
      type: TxType.expense,
      amount: 5000,
      categoryId: null,
      frequency: 'monthly',
      startDate: '2025-01-01',
      createdAt: 't',
    ));
    final list = await repo.recurring();
    expect(list.single.isActive, isTrue);

    await repo.deleteRecurring(id);
    expect(await repo.recurring(), isEmpty);
  });

  test('replaceAll swaps whole dataset and keeps ids', () async {
    final id = await repo.addTransaction(AppTransaction(
      type: TxType.income,
      amount: 1000,
      categoryId: null,
      date: '2025-01-01',
      createdAt: 't',
      updatedAt: 't',
    ));
    await repo.replaceAll(
      transactions: [
        AppTransaction(
          id: id,
          type: TxType.income,
          amount: 999999,
          categoryId: null,
          date: '2024-12-31',
          createdAt: 'b',
          updatedAt: 'b',
        ),
      ],
    );
    final txs = await repo.transactions();
    expect(txs.single.amount, 999999);
    expect(txs.single.id, id);
  });

  test('deleteAll removes data and reseeds defaults', () async {
    await repo.addTransaction(AppTransaction(
      type: TxType.expense,
      amount: 500,
      categoryId: null,
      date: '2025-01-01',
      createdAt: 't',
      updatedAt: 't',
    ));
    await repo.deleteAll();
    expect(await repo.countTransactions(), 0);
    final cats = await repo.categories();
    expect(cats.length, greaterThan(20));
  });
}