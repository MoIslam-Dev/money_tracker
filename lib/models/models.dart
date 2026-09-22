/// Core domain models for the money tracker.
///
/// All monetary values are stored as [int] (amount in DA, integer).
/// No floating point is ever used for money.
library;

class TxType {
  static const String expense = 'expense';
  static const String income = 'income';

  static bool isExpense(String t) => t == expense;
}

class AppCategory {
  final int? id;
  final String name;
  final String type; // TxType.expense | TxType.income
  final String icon;
  final bool isDefault;
  final int sortOrder;

  const AppCategory({
    this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  Map<String, Object?> toMap() => {
        'name': name,
        'type': type,
        'icon': icon,
        'is_default': isDefault ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory AppCategory.fromMap(Map<String, Object?> m) => AppCategory(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: m['type'] as String,
        icon: m['icon'] as String? ?? 'category',
        isDefault: (m['is_default'] as int? ?? 0) == 1,
        sortOrder: m['sort_order'] as int? ?? 0,
      );
}

class AppTransaction {
  final int? id;
  final String type;
  final int amount; // positive integer in DA
  final int? categoryId;
  final String paymentMethod;
  final String date; // yyyy-MM-dd
  final String? note;
  final String createdAt;
  final String updatedAt;

  const AppTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.paymentMethod = '',
    required this.date,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpense => TxType.isExpense(type);

  Map<String, Object?> toMap() => {
        'type': type,
        'amount': amount,
        'category_id': categoryId,
        'payment_method': paymentMethod,
        'date': date,
        'note': note,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory AppTransaction.fromMap(Map<String, Object?> m) => AppTransaction(
        id: m['id'] as int?,
        type: m['type'] as String,
        amount: m['amount'] as int,
        categoryId: m['category_id'] as int?,
        paymentMethod: m['payment_method'] as String? ?? '',
        date: m['date'] as String,
        note: m['note'] as String?,
        createdAt: m['created_at'] as String? ?? '',
        updatedAt: m['updated_at'] as String? ?? '',
      );
}

class Budget {
  final int? id;
  final int categoryId;
  final int amount; // monthly budget in DA
  final int month; // 1-12
  final int year;

  const Budget({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.month,
    required this.year,
  });

  Map<String, Object?> toMap() => {
        'category_id': categoryId,
        'amount': amount,
        'month': month,
        'year': year,
      };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['id'] as int?,
        categoryId: m['category_id'] as int,
        amount: m['amount'] as int,
        month: m['month'] as int,
        year: m['year'] as int,
      );
}

class SavingsGoal {
  final int? id;
  final String name;
  final int targetAmount;
  final int currentAmount;
  final String? targetDate; // yyyy-MM-dd or null
  final String? note;
  final String createdAt;
  final String updatedAt;

  const SavingsGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progressPercent =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount * 100).clamp(0, 100);

  Map<String, Object?> toMap() => {
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'target_date': targetDate,
        'note': note,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory SavingsGoal.fromMap(Map<String, Object?> m) => SavingsGoal(
        id: m['id'] as int?,
        name: m['name'] as String,
        targetAmount: m['target_amount'] as int,
        currentAmount: m['current_amount'] as int? ?? 0,
        targetDate: m['target_date'] as String?,
        note: m['note'] as String?,
        createdAt: m['created_at'] as String? ?? '',
        updatedAt: m['updated_at'] as String? ?? '',
      );
}

class RecurringTxn {
  final int? id;
  final String type;
  final int amount;
  final int? categoryId;
  final String frequency; // daily | weekly | monthly | yearly
  final String startDate; // yyyy-MM-dd
  final String? endDate; // yyyy-MM-dd or null
  final String paymentMethod;
  final String? note;
  final bool isActive;
  final String createdAt;

  bool get isExpense => TxType.isExpense(type);

  const RecurringTxn({
    this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.paymentMethod = '',
    this.note,
    this.isActive = true,
    required this.createdAt,
  });

  /// Next occurrence date strictly after [from].
  DateTime nextOccurrenceAfter(DateTime from) {
    DateTime cursor = DateTime.parse(startDate);
    if (cursor.isBefore(from)) {
      cursor = DateTime(from.year, from.month, from.day);
      switch (frequency) {
        case 'daily':
          while (!cursor.isAfter(from) || cursor.isBefore(DateTime.parse(startDate))) {
            cursor = cursor.add(const Duration(days: 1));
          }
        case 'weekly':
          while (!cursor.isAfter(from) ||
              cursor.weekday != DateTime.parse(startDate).weekday) {
            cursor = cursor.add(const Duration(days: 1));
          }
        case 'yearly':
          cursor = DateTime(from.year, DateTime.parse(startDate).month, DateTime.parse(startDate).day);
          while (!cursor.isAfter(from) || cursor.isBefore(DateTime.parse(startDate))) {
            cursor = DateTime(cursor.year + 1, cursor.month, cursor.day);
          }
        default: // monthly
          cursor = DateTime(from.year, from.month, DateTime.parse(startDate).day);
          while (!cursor.isAfter(from) || cursor.isBefore(DateTime.parse(startDate))) {
            var y = cursor.year;
            var m = cursor.month + 1;
            if (m > 12) {
              m = 1;
              y++;
            }
            cursor = DateTime(y, m, DateTime.parse(startDate).day);
          }
      }
    }
    return cursor;
  }

  Map<String, Object?> toMap() => {
        'type': type,
        'amount': amount,
        'category_id': categoryId,
        'frequency': frequency,
        'start_date': startDate,
        'end_date': endDate,
        'payment_method': paymentMethod,
        'note': note,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
      };

  factory RecurringTxn.fromMap(Map<String, Object?> m) => RecurringTxn(
        id: m['id'] as int?,
        type: m['type'] as String,
        amount: m['amount'] as int,
        categoryId: m['category_id'] as int?,
        frequency: m['frequency'] as String,
        startDate: m['start_date'] as String,
        endDate: m['end_date'] as String?,
        paymentMethod: m['payment_method'] as String? ?? '',
        note: m['note'] as String?,
        isActive: (m['is_active'] as int? ?? 1) == 1,
        createdAt: m['created_at'] as String? ?? '',
      );
}

/// A semantic payment method.
class PaymentMethods {
  static const List<String> all = [
    'cash',
    'bank',
    'card',
    'ccp',
    'baridimob',
    'other',
  ];
}