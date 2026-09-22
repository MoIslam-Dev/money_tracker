import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../utils/money.dart';
import 'settings_store.dart';

/// Central application state: holds all loaded data, settings + analytics.
class AppState extends ChangeNotifier {
  final Repository repo;
  final SettingsStore settings;
  AppStrings _strings;

  bool loaded = false;
  bool initialized = false;

  List<AppCategory> categories = [];
  List<AppTransaction> transactions = [];
  List<Budget> budgets = [];
  List<SavingsGoal> goals = [];
  List<RecurringTxn> recurring = [];

  DateTime currentMonth = DateTime.now();

  AppState(this.repo, this.settings)
      : _strings = AppStrings(settings.lang);

  AppStrings get strings => _strings;

  bool get isRtl => _strings.isRtl;

  // ---------- lifecycle ----------
  Future<void> init() async {
    if (initialized) return;
    initialized = true;
    await settings.load();
    _strings = AppStrings(settings.lang);
    await reloadAll();
    if (!settings.demoAdded && !settings.demoSeen) {
      await _seedDemo(DateTime.now());
      settings.demoAdded = true;
      await settings.save();
      await reloadAll();
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> reloadAll() async {
    categories = await repo.categories();
    transactions = await repo.transactions();
    budgets = await repo.budgets();
    goals = await repo.goals();
    recurring = await repo.recurring();
  }

  Future<void> refresh() async {
    await reloadAll();
    notifyListeners();
  }

  // ---------- settings ----------
  Future<void> setLang(String lang) async {
    settings.setLang(lang);
    _strings = AppStrings(lang);
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    settings.setTheme(theme);
    notifyListeners();
  }

  Future<void> setLockEnabled(bool v) async {
    settings.setLockEnabled(v);
    notifyListeners();
  }

  void setCurrentMonth(DateTime m) {
    currentMonth = DateTime(m.year, m.month);
    notifyListeners();
  }

  Future<void> setUseBiometrics(bool v) async {
    settings.setUseBiometrics(v);
    notifyListeners();
  }

  // ---------- categories ----------
  AppCategory? categoryOf(AppTransaction t) {
    if (t.categoryId == null) return null;
    for (final c in categories) {
      if (c.id == t.categoryId) return c;
    }
    return null;
  }

  AppCategory? categoryById(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<AppCategory> categoriesFor(String type) =>
      categories.where((c) => c.type == type).toList();

  String categoryLabel(AppCategory? c) =>
      c == null ? '' : _strings.categoryName(c.name);

  Future<void> addCustomCategory(String name, String icon, String type) async {
    final c = AppCategory(
      name: slugName(name),
      type: type,
      icon: icon,
      isDefault: false,
      sortOrder: 1000 + categories.length,
    );
    await repo.addCategory(c);
    await refresh();
  }

  Future<void> renameCategory(AppCategory c, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await repo.updateCategory(AppCategory(
      id: c.id,
      name: slugName(trimmed),
      type: c.type,
      icon: c.icon,
      isDefault: c.isDefault,
      sortOrder: c.sortOrder,
    ));
    await refresh();
  }

  static String slugName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  int categoryTransactionCount(int categoryId) {
    var n = 0;
    for (final t in transactions) {
      if (t.categoryId == categoryId) n++;
    }
    return n;
  }

  /// Most recently used category ids of [type] (for the quick-add picker).
  List<int> recentCategoryIds(String type, {int limit = 6}) {
    final out = <int>[];
    final seen = <int>{};
    for (final t in transactions) {
      if (t.categoryId == null) continue;
      final c = categoryById(t.categoryId);
      if (c == null || c.type != type || !seen.add(t.categoryId!)) continue;
      out.add(t.categoryId!);
      if (out.length >= limit) break;
    }
    return out;
  }

  Future<void> removeCategory(AppCategory c) async {
    await repo.deleteCategory(c.id!);
    await refresh();
  }

  // ---------- transactions ----------
  Future<void> addTransaction({
    required String type,
    required int amount,
    required int? categoryId,
    String paymentMethod = '',
    required DateTime date,
    String? note,
  }) async {
    final now = nowIso();
    final t = AppTransaction(
      type: type,
      amount: amount,
      categoryId: categoryId,
      paymentMethod: paymentMethod,
      date: dateKey(date),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await repo.addTransaction(t);
    if (paymentMethod.isNotEmpty) settings.setLastPayment(paymentMethod);
    await refresh();
  }

  Future<void> updateTransaction(AppTransaction t, {
    required String type,
    required int amount,
    required int? categoryId,
    String paymentMethod = '',
    required DateTime date,
    String? note,
  }) async {
    final edited = AppTransaction(
      id: t.id,
      type: type,
      amount: amount,
      categoryId: categoryId,
      paymentMethod: paymentMethod,
      date: dateKey(date),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: t.createdAt,
      updatedAt: nowIso(),
    );
    await repo.updateTransaction(edited);
    await refresh();
  }

  Future<void> deleteTransaction(AppTransaction t) async {
    await repo.deleteTransaction(t.id!);
    await refresh();
  }

  Future<void> duplicateTransaction(AppTransaction t) async {
    final now = nowIso();
    final copy = AppTransaction(
      type: t.type,
      amount: t.amount,
      categoryId: t.categoryId,
      paymentMethod: t.paymentMethod,
      date: t.date,
      note: t.note,
      createdAt: now,
      updatedAt: now,
    );
    await repo.addTransaction(copy);
    await refresh();
  }

  // ---------- budgets ----------
  Future<void> saveBudget({int? id, required int categoryId, required int amount}) async {
    final month = currentMonth.month;
    final year = currentMonth.year;
    await repo.saveBudget(Budget(id: id, categoryId: categoryId, amount: amount, month: month, year: year));
    await refresh();
  }

  Future<void> deleteBudget(Budget b) async {
    await repo.deleteBudget(b.id!);
    await refresh();
  }

  // ---------- savings goals ----------
  Future<void> saveGoal({
    int? id,
    required String name,
    required int target,
    required int current,
    DateTime? targetDate,
    String? note,
  }) async {
    final now = nowIso();
    if (id == null) {
      await repo.addGoal(SavingsGoal(
        name: name,
        targetAmount: target,
        currentAmount: current,
        targetDate: targetDate == null ? null : dateKey(targetDate),
        note: note,
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      final existing = goals.firstWhere((g) => g.id == id,
          orElse: () => SavingsGoal(name: '', targetAmount: 0, currentAmount: 0, createdAt: now, updatedAt: now));
      await repo.updateGoal(SavingsGoal(
        id: id,
        name: name,
        targetAmount: target,
        currentAmount: current,
        targetDate: targetDate == null ? null : dateKey(targetDate),
        note: note,
        createdAt: existing.createdAt,
        updatedAt: now,
      ));
    }
    await refresh();
  }

  Future<void> deleteGoal(SavingsGoal g) async {
    await repo.deleteGoal(g.id!);
    await refresh();
  }

  Future<void> addToGoal(SavingsGoal g, int amount) async {
    await saveGoal(
      id: g.id,
      name: g.name,
      target: g.targetAmount,
      current: g.currentAmount + amount,
      targetDate: g.targetDate == null ? null : parseDateKey(g.targetDate!),
      note: g.note,
    );
  }

  // ---------- recurring ----------
  Future<void> saveRecurring({
    int? id,
    required String type,
    required int amount,
    required int? categoryId,
    required String frequency,
    required DateTime start,
    DateTime? end,
    String paymentMethod = '',
    String? note,
    bool isActive = true,
  }) async {
    final r = RecurringTxn(
      id: id,
      type: type,
      amount: amount,
      categoryId: categoryId,
      frequency: frequency,
      startDate: dateKey(start),
      endDate: end == null ? null : dateKey(end),
      paymentMethod: paymentMethod,
      note: note,
      isActive: isActive,
      createdAt: id == null ? nowIso() : (recurring.firstWhere((x) => x.id == id).createdAt),
    );
    if (id == null) {
      await repo.addRecurring(r);
    } else {
      await repo.updateRecurring(r);
    }
    await refresh();
  }

  Future<void> removeRecurring(RecurringTxn r) async {
    await repo.deleteRecurring(r.id!);
    await refresh();
  }

  // ---------- analytics ----------
  bool _inMonth(AppTransaction t, DateTime m) {
    final prefix = '${m.year}-${m.month.toString().padLeft(2, '0')}';
    return t.date.startsWith(prefix);
  }

  (int income, int expense) monthTotals(DateTime m) {
    var inc = 0, exp = 0;
    for (final t in transactions) {
      if (!_inMonth(t, m)) continue;
      if (t.isExpense) {
        exp += t.amount;
      } else {
        inc += t.amount;
      }
    }
    return (inc, exp);
  }

  int get balance {
    var b = 0;
    for (final t in transactions) {
      b += t.isExpense ? -t.amount : t.amount;
    }
    return b;
  }

  int expensesOn(DateTime day) {
    final k = dateKey(day);
    var s = 0;
    for (final t in transactions) {
      if (t.isExpense && t.date == k) s += t.amount;
    }
    return s;
  }

  int incomesOn(DateTime day) {
    final k = dateKey(day);
    var s = 0;
    for (final t in transactions) {
      if (!t.isExpense && t.date == k) s += t.amount;
    }
    return s;
  }

  int _sumInRange(DateTime start, DateTime end, {required bool expense}) {
    final s = dateKey(start), e = dateKey(end);
    var sum = 0;
    for (final t in transactions) {
      if (expense != t.isExpense) continue;
      if (t.date.compareTo(s) >= 0 && t.date.compareTo(e) <= 0) sum += t.amount;
    }
    return sum;
  }

  int expensesBetween(DateTime start, DateTime end) => _sumInRange(start, end, expense: true);
  int incomesBetween(DateTime start, DateTime end) => _sumInRange(start, end, expense: false);

  int get todayExpense => expensesOn(DateTime.now());

  int get weekExpense {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return expensesBetween(monday, now);
  }

  int get monthExpense => monthTotals(currentMonth).$2;

  int countInMonth(DateTime m) {
    var n = 0;
    for (final t in transactions) {
      if (_inMonth(t, m)) n++;
    }
    return n;
  }

  double savingsRate(DateTime m) {
    final (inc, exp) = monthTotals(m);
    if (inc <= 0) return 0;
    return math.max(0, (inc - exp) / inc) * 100;
  }

  // categoryId -> total spent in month
  Map<int, int> categoryTotalsInMonth(DateTime m) {
    final map = <int, int>{};
    for (final t in transactions) {
      if (!t.isExpense || !_inMonth(t, m) || t.categoryId == null) continue;
      map[t.categoryId!] = (map[t.categoryId!] ?? 0) + t.amount;
    }
    return map;
  }

  int categorySpentInMonth(int categoryId, DateTime m) {
    var s = 0;
    for (final t in transactions) {
      if (t.isExpense && _inMonth(t, m) && t.categoryId == categoryId) s += t.amount;
    }
    return s;
  }

  int categoryCountInMonth(int categoryId, DateTime m) {
    var n = 0;
    for (final t in transactions) {
      if (t.isExpense && _inMonth(t, m) && t.categoryId == categoryId) n++;
    }
    return n;
  }

  List<AppTransaction> transactionsOfMonth(DateTime m, {String? categoryId}) {
    final out = <AppTransaction>[];
    for (final t in transactions) {
      if (!_inMonth(t, m)) continue;
      if (categoryId != null && t.categoryId.toString() != categoryId) continue;
      out.add(t);
    }
    return out;
  }

  // ---- trend buckets ----
  /// Series of (dateKey, income, expense) per day between start..end inclusive.
  List<(String, int, int)> dailySeries(DateTime start, DateTime end) {
    final map = <String, ({int inc, int exp})>{};
    for (final t in transactions) {
      if (t.date.compareTo(dateKey(start)) >= 0 && t.date.compareTo(dateKey(end)) <= 0) {
        final e = map.putIfAbsent(t.date, () => (inc: 0, exp: 0));
        if (t.isExpense) {
          map[t.date] = (inc: e.inc, exp: e.exp + t.amount);
        } else {
          map[t.date] = (inc: e.inc + t.amount, exp: e.exp);
        }
      }
    }
    final out = <(String, int, int)>[];
    for (var d = startOfDay(start); !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final k = dateKey(d);
      final e = map[k];
      out.add((k, e?.inc ?? 0, e?.exp ?? 0));
    }
    return out;
  }

  // ---- committed monthly from recurring ----
  int get committedMonthly {
    var s = 0;
    for (final r in recurring) {
      if (!r.isActive || !r.isExpense) continue;
      switch (r.frequency) {
        case 'daily':
          s += r.amount * 30;
        case 'weekly':
          s += r.amount * 4;
        case 'monthly':
          s += r.amount;
        case 'yearly':
          s += (r.amount / 12).ceil();
      }
    }
    return s;
  }

  int get committedMonthlyIncome {
    var s = 0;
    for (final r in recurring) {
      if (!r.isActive || r.isExpense) continue;
      switch (r.frequency) {
        case 'daily':
          s += r.amount * 30;
        case 'weekly':
          s += r.amount * 4;
        case 'monthly':
          s += r.amount;
        case 'yearly':
          s += (r.amount / 12).ceil();
      }
    }
    return s;
  }

  // ---------- demo data ----------
  Future<void> addDemoData() async {
    await _wipeDemo();
    final now = DateTime.now();
    await _seedDemo(now);
    settings.demoAdded = true;
    await settings.save();
    await refresh();
  }

  Future<void> removeDemoData() async {
    await _wipeDemo();
    settings.demoAdded = false;
    settings.demoSeen = true;
    await settings.save();
    await refresh();
  }

  Future<void> _wipeDemo() async {
    for (final t in transactions) {
      if (_isDemo(t)) await repo.deleteTransaction(t.id!);
    }
  }

  bool _isDemo(AppTransaction t) => t.note != null && t.note!.startsWith('[demo]');

  Future<void> _seedDemo(DateTime now) async {
    final cats = categories;
    AppCategory? exp(String slug) {
      for (final c in cats) {
        if (c.type == TxType.expense && c.name == slug) return c;
      }
      return null;
    }

    AppCategory? inc(String slug) {
      for (final c in cats) {
        if (c.type == TxType.income && c.name == slug) return c;
      }
      return null;
    }

    final y = now.year, m = now.month;
    final ts = <AppTransaction>[];

    void seed(String type, int amount, AppCategory? c, DateTime d, String note) {
      final iso = d.toIso8601String();
      ts.add(AppTransaction(
        type: type,
        amount: amount,
        categoryId: c?.id,
        paymentMethod: 'cash',
        date: dateKey(d),
        note: '[demo] $note',
        createdAt: iso,
        updatedAt: iso,
      ));
    }

    final salary = inc('salary');
    final food = exp('food');
    final transport = exp('transport');
    final shopping = exp('shopping');
    final bills = exp('electricity');
    final fun = exp('entertainment');
    final coffee = exp('coffee');
    final rent = exp('rent');

    seed(TxType.income, 85000, salary, DateTime(y, m, 1), 'Salary');
    final rnd = math.Random(7);
    for (var d = 1; d <= now.day; d++) {
      final day = DateTime(y, m, d);
      if (d % 2 == 0) seed(TxType.expense, 400 + rnd.nextInt(400), food, day, 'Grocery run');
      if (d % 3 == 0) seed(TxType.expense, 150 + rnd.nextInt(250), transport, day, 'Taxi');
      if (d % 4 == 0) seed(TxType.expense, 100 + rnd.nextInt(250), coffee, day, 'Coffee');
      if (d % 5 == 0) seed(TxType.expense, 800 + rnd.nextInt(1500), shopping, day, 'Shopping');
    }
    seed(TxType.expense, 4800, bills, DateTime(y, m, 8), 'Electricity bill');
    seed(TxType.expense, 2200, fun, DateTime(y, m, 12), 'Cinema night');
    seed(TxType.expense, 12000, rent, DateTime(y, m, 3), 'Rent');
    seed(TxType.income, 12000, inc('freelance'), DateTime(y, m, 15), 'Freelance');
    seed(TxType.income, 3000, inc('refund'), DateTime(y, m, 20), 'Refund');

    for (final t in ts) {
      await repo.addTransaction(t);
    }
  }

  // ---------- delete all ----------
  Future<void> deleteAll() async {
    await repo.deleteAll();
    settings.demoAdded = false;
    settings.demoSeen = true;
    await settings.save();
    await refresh();
  }
}