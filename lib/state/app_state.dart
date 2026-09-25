import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../l10n/strings.dart';
import '../models/currency.dart';
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

  AppState(this.repo, this.settings) : _strings = AppStrings(settings.lang);

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

  String get currency => settings.currency;

  AppCurrency get activeCurrency =>
      resolveCurrency(settings.currency, custom: settings.customCurrencies);

  List<AppCurrency> get currencies => [
    ...kPopularCurrencies,
    for (final c in settings.customCurrencies)
      if (!kPopularCurrencies.any((p) => p.code == c.code)) c,
  ];

  AppCurrency currencyDefinition(String code) =>
      resolveCurrency(code, custom: settings.customCurrencies);

  /// Currency-aware, RTL-safe money rendering for the current lang + currency.
  String money(int amount, {String? currency}) => formatMoney(
    amount,
    settings.lang,
    currency ?? settings.currency,
    currency: currency == null ? activeCurrency : currencyDefinition(currency),
  );

  /// Currency-aware, RTL-safe money rendering for a specific currency.
  String moneyFor(int amount, String? currency) => formatMoney(
    amount,
    settings.lang,
    currency ?? settings.currency,
    currency: currency == null ? activeCurrency : currencyDefinition(currency),
  );

  /// Compact (chart) form of the current-currency money.
  String moneyShort(int amount, {String? currency}) => formatMoneyShort(
    amount,
    settings.lang,
    currency ?? settings.currency,
    currency: currency == null ? activeCurrency : currencyDefinition(currency),
  );

  String moneyForShort(int amount, String? currency) => formatMoneyShort(
    amount,
    settings.lang,
    currency ?? settings.currency,
    currency: currency == null ? activeCurrency : currencyDefinition(currency),
  );

  String get currencyLabel =>
      '${activeCurrency.localizedName(settings.lang)} · ${activeCurrency.symbol}';

  String currencyLabelFor(String code) {
    final c = currencyDefinition(code);
    return '${c.localizedName(settings.lang)} · ${c.symbol}';
  }

  Future<bool> setCurrency(
    String v, {
    CurrencyChangeMode mode = CurrencyChangeMode.keep,
    double? rate,
  }) async {
    final to = v.trim().toUpperCase();
    final from = settings.currency;
    if (to.isEmpty || from == to) return true;
    if (mode == CurrencyChangeMode.convert) {
      if (rate == null || rate <= 0) return false;
      await repo.convertTransactionCurrency(from: from, to: to, rate: rate);
      await refresh();
    }
    settings.setCurrency(to);
    await settings.save();
    notifyListeners();
    return true;
  }

  Future<void> addCustomCurrency(AppCurrency c) async {
    await settings.addCustomCurrency(c);
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

  String categoryLabel(AppCategory? c) {
    if (c == null) return '';
    if (c.hasLocalizedNames) {
      return c.localizedName(settings.lang, fallback: c.name);
    }
    return _strings.categoryName(c.name);
  }

  Future<void> addCustomCategory(
    String name,
    String icon,
    String type, {
    String? nameFr,
    String? nameAr,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final c = AppCategory(
      name: slugName(trimmed),
      nameEn: trimmed,
      nameFr: nameFr?.trim().isNotEmpty == true ? nameFr!.trim() : trimmed,
      nameAr: nameAr?.trim().isNotEmpty == true ? nameAr!.trim() : trimmed,
      type: type,
      icon: icon,
      isDefault: false,
      sortOrder: 1000 + categories.length,
    );
    await repo.addCategory(c);
    await refresh();
  }

  Future<void> renameCategory(
    AppCategory c,
    String name, {
    String? nameEn,
    String? nameFr,
    String? nameAr,
  }) async {
    final trimmed = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.isEmpty) return;
    String? norm(String? v) =>
        v == null ? null : (v.replaceAll(RegExp(r'\s+'), ' ').trim());
    final en = norm(nameEn)?.isNotEmpty == true ? norm(nameEn)! : trimmed;
    final fr = norm(nameFr)?.isNotEmpty == true ? norm(nameFr)! : en;
    final ar = norm(nameAr)?.isNotEmpty == true ? norm(nameAr)! : en;
    await repo.updateCategory(
      AppCategory(
        id: c.id,
        name: c.name,
        nameEn: en,
        nameFr: fr,
        nameAr: ar,
        type: c.type,
        icon: c.icon,
        isDefault: c.isDefault,
        sortOrder: c.sortOrder,
      ),
    );
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
    String? currency,
  }) async {
    final now = nowIso();
    final t = AppTransaction(
      type: type,
      amount: amount,
      currency: currency ?? settings.currency,
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

  Future<void> updateTransaction(
    AppTransaction t, {
    required String type,
    required int amount,
    required int? categoryId,
    String paymentMethod = '',
    required DateTime date,
    String? note,
    String? currency,
  }) async {
    final edited = AppTransaction(
      id: t.id,
      type: type,
      amount: amount,
      currency: currency ?? t.currency,
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
      currency: t.currency,
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
  Future<void> saveBudget({
    int? id,
    required int categoryId,
    required int amount,
    String? currency,
  }) async {
    final month = currentMonth.month;
    final year = currentMonth.year;
    final eff =
        currency ??
        (id == null
            ? settings.currency
            : _budgetCurrency(id) ?? settings.currency);
    await repo.saveBudget(
      Budget(
        id: id,
        categoryId: categoryId,
        amount: amount,
        currency: eff,
        month: month,
        year: year,
      ),
    );
    await refresh();
  }

  Future<void> deleteBudget(Budget b) async {
    await repo.deleteBudget(b.id!);
    await refresh();
  }

  String? _budgetCurrency(int id) {
    for (final b in budgets) {
      if (b.id == id) return b.currency;
    }
    return null;
  }

  // ---------- savings goals ----------
  Future<void> saveGoal({
    int? id,
    required String name,
    required int target,
    required int current,
    DateTime? targetDate,
    String? note,
    String? currency,
  }) async {
    final now = nowIso();
    final effCurrency =
        currency ??
        (id == null
            ? settings.currency
            : _goalCurrency(id) ?? settings.currency);
    if (id == null) {
      await repo.addGoal(
        SavingsGoal(
          name: name,
          targetAmount: target,
          currentAmount: current,
          currency: effCurrency,
          targetDate: targetDate == null ? null : dateKey(targetDate),
          note: note,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      final existing = goals.firstWhere(
        (g) => g.id == id,
        orElse:
            () => SavingsGoal(
              name: '',
              targetAmount: 0,
              currentAmount: 0,
              createdAt: now,
              updatedAt: now,
            ),
      );
      await repo.updateGoal(
        SavingsGoal(
          id: id,
          name: name,
          targetAmount: target,
          currentAmount: current,
          currency: effCurrency,
          targetDate: targetDate == null ? null : dateKey(targetDate),
          note: note,
          createdAt: existing.createdAt,
          updatedAt: now,
        ),
      );
    }
    await refresh();
  }

  String? _goalCurrency(int id) {
    for (final g in goals) {
      if (g.id == id) return g.currency;
    }
    return null;
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
      currency: g.currency,
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
    String? currency,
  }) async {
    final existing =
        id == null
            ? null
            : recurring.where((x) => x.id == id).toList().isEmpty
            ? null
            : recurring.firstWhere((x) => x.id == id);
    final effCurrency = currency ?? existing?.currency ?? settings.currency;
    final r = RecurringTxn(
      id: id,
      type: type,
      amount: amount,
      currency: effCurrency,
      categoryId: categoryId,
      frequency: frequency,
      startDate: dateKey(start),
      endDate: end == null ? null : dateKey(end),
      paymentMethod: paymentMethod,
      note: note,
      isActive: isActive,
      createdAt: existing?.createdAt ?? nowIso(),
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

  bool _matchesCurrency(AppTransaction t, String? currency) =>
      t.currency == (currency ?? settings.currency);

  (int income, int expense) monthTotals(DateTime m, {String? currency}) {
    var inc = 0, exp = 0;
    for (final t in transactions) {
      if (!_inMonth(t, m) || !_matchesCurrency(t, currency)) continue;
      if (t.isExpense) {
        exp += t.amount;
      } else {
        inc += t.amount;
      }
    }
    return (inc, exp);
  }

  int get balance => balanceFor();

  int balanceFor([String? currency]) {
    final eff = currency ?? settings.currency;
    var b = 0;
    for (final t in transactions) {
      if (!_matchesCurrency(t, eff)) continue;
      b += t.isExpense ? -t.amount : t.amount;
    }
    return b;
  }

  int expensesOn(DateTime day, {String? currency}) {
    final k = dateKey(day);
    var s = 0;
    for (final t in transactions) {
      if (t.isExpense && t.date == k && _matchesCurrency(t, currency)) {
        s += t.amount;
      }
    }
    return s;
  }

  int incomesOn(DateTime day, {String? currency}) {
    final k = dateKey(day);
    var s = 0;
    for (final t in transactions) {
      if (!t.isExpense && t.date == k && _matchesCurrency(t, currency)) {
        s += t.amount;
      }
    }
    return s;
  }

  int _sumInRange(
    DateTime start,
    DateTime end, {
    required bool expense,
    String? currency,
  }) {
    final s = dateKey(start), e = dateKey(end);
    var sum = 0;
    for (final t in transactions) {
      if (expense != t.isExpense) continue;
      if (!_matchesCurrency(t, currency)) continue;
      if (t.date.compareTo(s) >= 0 && t.date.compareTo(e) <= 0) sum += t.amount;
    }
    return sum;
  }

  int expensesBetween(DateTime start, DateTime end, {String? currency}) =>
      _sumInRange(start, end, expense: true, currency: currency);
  int incomesBetween(DateTime start, DateTime end, {String? currency}) =>
      _sumInRange(start, end, expense: false, currency: currency);

  int get todayExpense => expensesOn(DateTime.now());

  int get weekExpense {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return expensesBetween(monday, now);
  }

  int get monthExpense => monthTotals(currentMonth).$2;

  int countInMonth(DateTime m, {String? currency}) {
    var n = 0;
    for (final t in transactions) {
      if (_inMonth(t, m) && _matchesCurrency(t, currency)) n++;
    }
    return n;
  }

  double savingsRate(DateTime m, {String? currency}) {
    final (inc, exp) = monthTotals(m, currency: currency);
    if (inc <= 0) return 0;
    return math.max(0, (inc - exp) / inc) * 100;
  }

  // categoryId -> total spent in month
  Map<int, int> categoryTotalsInMonth(DateTime m, {String? currency}) {
    final map = <int, int>{};
    for (final t in transactions) {
      if (!t.isExpense || !_inMonth(t, m) || t.categoryId == null) continue;
      if (!_matchesCurrency(t, currency)) continue;
      map[t.categoryId!] = (map[t.categoryId!] ?? 0) + t.amount;
    }
    return map;
  }

  int categorySpentInMonth(int categoryId, DateTime m, {String? currency}) {
    var s = 0;
    for (final t in transactions) {
      if (t.isExpense &&
          _inMonth(t, m) &&
          t.categoryId == categoryId &&
          _matchesCurrency(t, currency)) {
        s += t.amount;
      }
    }
    return s;
  }

  int categoryCountInMonth(int categoryId, DateTime m, {String? currency}) {
    var n = 0;
    for (final t in transactions) {
      if (t.isExpense &&
          _inMonth(t, m) &&
          t.categoryId == categoryId &&
          _matchesCurrency(t, currency)) {
        n++;
      }
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
  List<(String, int, int)> dailySeries(
    DateTime start,
    DateTime end, {
    String? currency,
  }) {
    final map = <String, ({int inc, int exp})>{};
    for (final t in transactions) {
      if (!_matchesCurrency(t, currency)) continue;
      if (t.date.compareTo(dateKey(start)) >= 0 &&
          t.date.compareTo(dateKey(end)) <= 0) {
        final e = map.putIfAbsent(t.date, () => (inc: 0, exp: 0));
        if (t.isExpense) {
          map[t.date] = (inc: e.inc, exp: e.exp + t.amount);
        } else {
          map[t.date] = (inc: e.inc + t.amount, exp: e.exp);
        }
      }
    }
    final out = <(String, int, int)>[];
    for (
      var d = startOfDay(start);
      !d.isAfter(end);
      d = d.add(const Duration(days: 1))
    ) {
      final k = dateKey(d);
      final e = map[k];
      out.add((k, e?.inc ?? 0, e?.exp ?? 0));
    }
    return out;
  }

  // ---- committed monthly from recurring ----
  int get committedMonthly => committedMonthlyFor();

  int committedMonthlyFor([String? currency]) {
    final eff = currency ?? settings.currency;
    var s = 0;
    for (final r in recurring) {
      if (!r.isActive || !r.isExpense || r.currency != eff) continue;
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

  int get committedMonthlyIncome => committedMonthlyIncomeFor();

  int committedMonthlyIncomeFor([String? currency]) {
    final eff = currency ?? settings.currency;
    var s = 0;
    for (final r in recurring) {
      if (!r.isActive || r.isExpense || r.currency != eff) continue;
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

  // ---- professional analytics ----

  /// Cumulative net balance (income minus expenses) across the last [n]
  /// months ending with the current one. Series of (yyyy-MM, balance).
  List<(String, int)> monthlyBalanceSeries(int n, {String? currency}) {
    final eff = currency ?? settings.currency;
    final now = DateTime.now();
    final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
    final out = <(String, int)>[];
    var bal = 0;
    var idx = 0;
    for (var i = n - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      final prefix = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      while (idx < sorted.length && sorted[idx].date.startsWith(prefix)) {
        final t = sorted[idx++];
        if (t.currency != eff) continue;
        bal += t.isExpense ? -t.amount : t.amount;
      }
      out.add((prefix, bal));
    }
    return out;
  }

  /// Average amount spent per weekday over the last [weeks] weeks
  /// (Monday..Sunday). Index 0 = Monday.
  List<int> weekdayAverages(int weeks, {String? currency}) {
    final eff = currency ?? settings.currency;
    final now = DateTime.now();
    final start = startOfDay(now.subtract(Duration(days: weeks * 7 - 1)));
    final sums = List<int>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    for (var d = start; !d.isAfter(now); d = d.add(const Duration(days: 1))) {
      counts[d.weekday - 1]++;
    }
    for (final t in transactions) {
      if (!t.isExpense) continue;
      if (t.currency != eff) continue;
      final d = parseDateKey(t.date);
      if (d.isBefore(start) || d.isAfter(now)) continue;
      sums[d.weekday - 1] += t.amount;
    }
    return [
      for (var i = 0; i < 7; i++) counts[i] == 0 ? 0 : sums[i] ~/ counts[i],
    ];
  }

  /// Average expense per elapsed day in [m] (current month) or full-month
  /// average otherwise.
  int dailyAverageExpense(DateTime m, {String? currency}) {
    final (_, exp) = monthTotals(m, currency: currency);
    final now = DateTime.now();
    final days =
        (m.year == now.year && m.month == now.month)
            ? now.day
            : DateTime(m.year, m.month + 1, 0).day;
    return days == 0 ? 0 : exp ~/ days;
  }

  /// Projected total spend for [m]: for the current month the current pacing
  /// extrapolated to month-end; otherwise the month's actual spend.
  int projectedExpense(DateTime m, {String? currency}) {
    if (m.year == DateTime.now().year && m.month == DateTime.now().month) {
      return dailyAverageExpense(m, currency: currency) *
          DateTime(m.year, m.month + 1, 0).day;
    }
    return monthTotals(m, currency: currency).$2;
  }

  /// The [n] largest transactions of the given kind within [m].
  List<AppTransaction> largestTransactions(
    DateTime m, {
    required bool isExpense,
    int n = 3,
    String? currency,
  }) {
    final prefix = '${m.year}-${m.month.toString().padLeft(2, '0')}';
    final eff = currency ?? settings.currency;
    final list =
        transactions
            .where(
              (t) =>
                  t.isExpense == isExpense &&
                  t.date.startsWith(prefix) &&
                  _matchesCurrency(t, eff),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    return list.take(n).toList();
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

  bool _isDemo(AppTransaction t) =>
      t.note != null && t.note!.startsWith('[demo]');

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

    void seed(
      String type,
      int amount,
      AppCategory? c,
      DateTime d,
      String note,
    ) {
      final iso = d.toIso8601String();
      ts.add(
        AppTransaction(
          type: type,
          amount: amount,
          categoryId: c?.id,
          paymentMethod: 'cash',
          date: dateKey(d),
          note: '[demo] $note',
          createdAt: iso,
          updatedAt: iso,
        ),
      );
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
      if (d % 2 == 0) {
        seed(TxType.expense, 400 + rnd.nextInt(400), food, day, 'Grocery run');
      }
      if (d % 3 == 0) {
        seed(TxType.expense, 150 + rnd.nextInt(250), transport, day, 'Taxi');
      }
      if (d % 4 == 0) {
        seed(TxType.expense, 100 + rnd.nextInt(250), coffee, day, 'Coffee');
      }
      if (d % 5 == 0) {
        seed(
          TxType.expense,
          800 + rnd.nextInt(1500),
          shopping,
          day,
          'Shopping',
        );
      }
    }
    seed(TxType.expense, 4800, bills, DateTime(y, m, 8), 'Electricity bill');
    seed(TxType.expense, 2200, fun, DateTime(y, m, 12), 'Cinema night');
    seed(TxType.expense, 12000, rent, DateTime(y, m, 3), 'Rent');
    seed(
      TxType.income,
      12000,
      inc('freelance'),
      DateTime(y, m, 15),
      'Freelance',
    );
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
