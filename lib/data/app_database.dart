import 'dart:io' show Platform;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Default expense categories (Algeria-oriented).
const defaultExpenseCategories = [
  ('food', 'restaurant'),
  ('groceries', 'shopping_cart'),
  ('restaurant', 'local_dining'),
  ('coffee', 'coffee'),
  ('transport', 'directions_bus'),
  ('fuel', 'local_gas_station'),
  ('rent', 'home'),
  ('electricity', 'bolt'),
  ('water', 'water_drop'),
  ('gas', 'propane_tank'),
  ('internet', 'wifi'),
  ('phone', 'phone_android'),
  ('health', 'medical_services'),
  ('clothes', 'checkroom'),
  ('shopping', 'shopping_bag'),
  ('entertainment', 'movie'),
  ('education', 'school'),
  ('software', 'devices'),
  ('family', 'family_restroom'),
  ('gifts', 'card_giftcard'),
  ('debt', 'account_balance'),
  ('savings', 'savings'),
  ('other', 'more_horiz'),
];

/// Default income categories.
const defaultIncomeCategories = [
  ('salary', 'payments'),
  ('freelance', 'computer'),
  ('side_business', 'storefront'),
  ('gift', 'redeem'),
  ('refund', 'currency_exchange'),
  ('investment', 'trending_up'),
  ('other', 'more_horiz'),
];

class AppDatabase {
  static const _name = 'money_tracker.db';
  static const _version = 3;

  final String? customPath;
  AppDatabase({this.customPath});

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    // Under `flutter test` open an in-memory database so widget and unit
    // tests never share (or pollute) the on-disk app data.
    final inTest = Platform.environment.containsKey('FLUTTER_TEST') &&
        customPath == null;
    final dir = inTest ? null : await getDatabasesPath();
    return openDatabase(
      customPath ?? (inTest ? inMemoryDatabasePath : p.join(dir!, _name)),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK(amount > 0),
        category_id INTEGER,
        payment_method TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_tx_date ON transactions(date)
    ''');
    await db.execute('''
      CREATE INDEX idx_tx_category ON transactions(category_id)
    ''');
    await db.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_budget_cat ON budgets(category_id, month, year)
    ''');
    await db.execute('''
      CREATE TABLE savings_goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount INTEGER NOT NULL,
        current_amount INTEGER NOT NULL DEFAULT 0,
        target_date TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE recurring(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK(amount > 0),
        category_id INTEGER,
        frequency TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        payment_method TEXT NOT NULL DEFAULT '',
        note TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await _seedCategories(db);
  }

  static Future<void> _seedCategories(Database db) async {
    var order = 0;
    final batch = db.batch();
    for (final (name, icon) in defaultExpenseCategories) {
      batch.insert('categories', {
        'name': name,
        'type': TxType.expense,
        'icon': icon,
        'is_default': 1,
        'sort_order': order++,
      });
    }
    for (final (name, icon) in defaultIncomeCategories) {
      batch.insert('categories', {
        'name': name,
        'type': TxType.income,
        'icon': icon,
        'is_default': 1,
        'sort_order': order++,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 3) {
      // Recreate schema defensively (personal app, data can be re-seeded).
      await db.execute('DROP TABLE IF EXISTS recurring');
      await _onCreate(db, newV);
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

/// All data-access operations.
class Repository {
  final AppDatabase appDb;
  Repository(this.appDb);

  Future<Database> get _db => appDb.database;

  // ---------- Categories ----------
  Future<List<AppCategory>> categories() async {
    final db = await _db;
    final rows = await db.query('categories', orderBy: 'sort_order ASC, id ASC');
    return rows.map(AppCategory.fromMap).toList();
  }

  Future<AppCategory?> categoryById(int id) async {
    final db = await _db;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppCategory.fromMap(rows.first);
  }

  Future<int> addCategory(AppCategory c) async =>
      (await _db).insert('categories', c.toMap());

  Future<void> updateCategory(AppCategory c) async {
    await (await _db).update(
      'categories',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<AppCategory?> upsertCategory(AppCategory c) async {
    final db = await _db;
    final rows =
        await db.query('categories', where: 'name = ? AND type = ?', whereArgs: [c.name, c.type], limit: 1);
    if (rows.isNotEmpty) return AppCategory.fromMap(rows.first);
    final id = await db.insert('categories', c.toMap());
    c = AppCategory(id: id, name: c.name, type: c.type, icon: c.icon, isDefault: c.isDefault, sortOrder: c.sortOrder);
    return c;
  }

  Future<void> deleteCategory(int id) async {
    final db = await _db;
    final other = await db.query(
      'categories',
      where: 'name = ? AND type = ?',
      whereArgs: ['other', (await _categoryById(id))?.type ?? TxType.expense],
      limit: 1,
    );
    if (other.isNotEmpty) {
      await db.update(
        'transactions',
        {'category_id': other.first['id']},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await db.update('budgets', {'category_id': other.first['id']}, where: 'category_id = ?', whereArgs: [id]);
      await db.update('recurring', {'category_id': other.first['id']}, where: 'category_id = ?', whereArgs: [id]);
    }
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<AppCategory?> _categoryById(int id) async {
    final db = await _db;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppCategory.fromMap(rows.first);
  }

  // ---------- Transactions ----------
  Future<List<AppTransaction>> transactions({String? from, String? to}) async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      where: (from != null && to != null) ? 'date >= ? AND date <= ?' : null,
      whereArgs: (from != null && to != null) ? [from, to] : null,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<AppTransaction?> transactionById(int id) async {
    final db = await _db;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppTransaction.fromMap(rows.first);
  }

  Future<int> addTransaction(AppTransaction t) async =>
      (await _db).insert('transactions', t.toMap());

  Future<void> updateTransaction(AppTransaction t) async {
    await (await _db).update('transactions', t.toMap(),
        where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> deleteTransaction(int id) async {
    await (await _db).delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countTransactions() async {
    final db = await _db;
    final res = await db.rawQuery('SELECT COUNT(*) c FROM transactions');
    return res.first['c'] as int? ?? 0;
  }

  // ---------- Budgets ----------
  Future<List<Budget>> budgets() async {
    final db = await _db;
    final rows = await db.query('budgets', orderBy: 'year DESC, month DESC, id DESC');
    return rows.map(Budget.fromMap).toList();
  }

  Future<Budget?> budgetFor(int categoryId, int month, int year) async {
    final db = await _db;
    final rows = await db.query('budgets',
        where: 'category_id = ? AND month = ? AND year = ?', whereArgs: [categoryId, month, year], limit: 1);
    return rows.isEmpty ? null : Budget.fromMap(rows.first);
  }

  Future<int> addBudget(Budget b) async => (await _db).insert('budgets', b.toMap());

  Future<int> saveBudget(Budget b) async {
    final db = await _db;
    if (b.id != null) {
      await db.update('budgets', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
      return b.id!;
    }
    return db.insert('budgets', b.toMap());
  }

  Future<void> deleteBudget(int id) async {
    await (await _db).delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Savings goals ----------
  Future<List<SavingsGoal>> goals() async {
    final db = await _db;
    final rows = await db.query('savings_goals', orderBy: 'id DESC');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  Future<int> addGoal(SavingsGoal g) async => (await _db).insert('savings_goals', g.toMap());

  Future<void> updateGoal(SavingsGoal g) async {
    await (await _db).update('savings_goals', g.toMap(),
        where: 'id = ?', whereArgs: [g.id]);
  }

  Future<void> deleteGoal(int id) async {
    await (await _db).delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Recurring ----------
  Future<List<RecurringTxn>> recurring() async {
    final db = await _db;
    final rows = await db.query('recurring', orderBy: 'id DESC');
    return rows.map(RecurringTxn.fromMap).toList();
  }

  Future<int> addRecurring(RecurringTxn r) async => (await _db).insert('recurring', r.toMap());

  Future<void> updateRecurring(RecurringTxn r) async {
    await (await _db).update('recurring', r.toMap(),
        where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteRecurring(int id) async {
    await (await _db).delete('recurring', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Bulk ----------
  Future<void> replaceAll({
    List<AppCategory> categories = const [],
    List<AppTransaction> transactions = const [],
    List<Budget> budgets = const [],
    List<SavingsGoal> goals = const [],
    List<RecurringTxn> recurring = const [],
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('budgets');
      await txn.delete('savings_goals');
      await txn.delete('recurring');
      await txn.delete('transactions');
      await txn.delete('categories');
      final bc = txn.batch();
      for (final c in categories) {
        bc.insert('categories', {...c.toMap(), if (c.id != null) 'id': c.id});
      }
      for (final t in transactions) {
        bc.insert('transactions', {...t.toMap(), if (t.id != null) 'id': t.id});
      }
      for (final b in budgets) {
        bc.insert('budgets', {...b.toMap(), if (b.id != null) 'id': b.id});
      }
      for (final g in goals) {
        bc.insert('savings_goals', {...g.toMap(), if (g.id != null) 'id': g.id});
      }
      for (final r in recurring) {
        bc.insert('recurring', {...r.toMap(), if (r.id != null) 'id': r.id});
      }
      await bc.commit(noResult: true);
    });
  }

  Future<void> deleteAll() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('budgets');
      await txn.delete('savings_goals');
      await txn.delete('recurring');
      await txn.delete('transactions');
      await txn.delete('categories');
    });
    await AppDatabase._seedCategories(db);
  }
}