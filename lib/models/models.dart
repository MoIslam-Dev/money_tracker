class TxType {
  static const String expense = 'expense';
  static const String income = 'income';

  static bool isExpense(String t) => t == expense;
}

class AppCategory {
  final int? id;
  final String name;
  final String nameEn;
  final String nameFr;
  final String nameAr;
  final String type;
  final String icon;
  final bool isDefault;
  final int sortOrder;

  const AppCategory({
    this.id,
    required this.name,
    this.nameEn = '',
    this.nameFr = '',
    this.nameAr = '',
    required this.type,
    required this.icon,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  bool get hasLocalizedNames =>
      nameEn.trim().isNotEmpty ||
      nameFr.trim().isNotEmpty ||
      nameAr.trim().isNotEmpty;

  String localizedName(String lang, {required String fallback}) {
    final value =
        lang == 'fr'
            ? nameFr
            : lang == 'ar'
            ? nameAr
            : nameEn;
    return value.trim().isEmpty ? fallback : value.trim();
  }

  Map<String, Object?> toMap() => {
    'name': name,
    'name_en': nameEn,
    'name_fr': nameFr,
    'name_ar': nameAr,
    'type': type,
    'icon': icon,
    'is_default': isDefault ? 1 : 0,
    'sort_order': sortOrder,
  };

  factory AppCategory.fromMap(Map<String, Object?> m) {
    final name = _asString(m['name'] ?? m['key'] ?? m['slug']);
    return AppCategory(
      id: _asInt(m['id']),
      name: name,
      nameEn: _asString(m['name_en'] ?? m['nameEn']),
      nameFr: _asString(m['name_fr'] ?? m['nameFr']),
      nameAr: _asString(m['name_ar'] ?? m['nameAr']),
      type: _asString(m['type']),
      icon: _asString(m['icon'], fallback: 'category'),
      isDefault: _asBool(m['is_default'] ?? m['isDefault']),
      sortOrder: _asInt(m['sort_order'] ?? m['sortOrder']) ?? 0,
    );
  }
}

class AppTransaction {
  final int? id;
  final String type;
  final int amount;
  final String currency;
  final int? originalAmount;
  final String? originalCurrency;
  final int? categoryId;
  final String paymentMethod;
  final String date;
  final String? note;
  final String createdAt;
  final String updatedAt;

  const AppTransaction({
    this.id,
    required this.type,
    required this.amount,
    this.currency = 'DZD',
    this.originalAmount,
    this.originalCurrency,
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
    'currency': currency,
    'original_amount': originalAmount,
    'original_currency': originalCurrency,
    'category_id': categoryId,
    'payment_method': paymentMethod,
    'date': date,
    'note': note,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory AppTransaction.fromMap(Map<String, Object?> m) => AppTransaction(
    id: _asInt(m['id']),
    type: _asString(m['type']),
    amount: _asInt(m['amount']) ?? 0,
    currency: _asString(m['currency'], fallback: 'DZD'),
    originalAmount: _asInt(m['original_amount'] ?? m['originalAmount']),
    originalCurrency: _asNullableString(
      m['original_currency'] ?? m['originalCurrency'],
    ),
    categoryId: _asInt(m['category_id'] ?? m['categoryId']),
    paymentMethod: _asString(m['payment_method'] ?? m['paymentMethod']),
    date: _asString(m['date']),
    note: _asNullableString(m['note']),
    createdAt: _asString(m['created_at'] ?? m['createdAt']),
    updatedAt: _asString(m['updated_at'] ?? m['updatedAt']),
  );
}

class Budget {
  final int? id;
  final int categoryId;
  final int amount;
  final String currency;
  final int month;
  final int year;

  const Budget({
    this.id,
    required this.categoryId,
    required this.amount,
    this.currency = 'DZD',
    required this.month,
    required this.year,
  });

  Map<String, Object?> toMap() => {
    'category_id': categoryId,
    'amount': amount,
    'currency': currency,
    'month': month,
    'year': year,
  };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
    id: _asInt(m['id']),
    categoryId: _asInt(m['category_id'] ?? m['categoryId']) ?? 0,
    amount: _asInt(m['amount']) ?? 0,
    currency: _asString(m['currency'], fallback: 'DZD'),
    month: _asInt(m['month']) ?? 1,
    year: _asInt(m['year']) ?? DateTime.now().year,
  );
}

class SavingsGoal {
  final int? id;
  final String name;
  final int targetAmount;
  final int currentAmount;
  final String currency;
  final String? targetDate;
  final String? note;
  final String createdAt;
  final String updatedAt;

  const SavingsGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.currency = 'DZD',
    this.targetDate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progressPercent =>
      targetAmount <= 0
          ? 0
          : (currentAmount / targetAmount * 100).clamp(0, 100);

  Map<String, Object?> toMap() => {
    'name': name,
    'target_amount': targetAmount,
    'current_amount': currentAmount,
    'currency': currency,
    'target_date': targetDate,
    'note': note,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory SavingsGoal.fromMap(Map<String, Object?> m) => SavingsGoal(
    id: _asInt(m['id']),
    name: _asString(m['name']),
    targetAmount: _asInt(m['target_amount'] ?? m['targetAmount']) ?? 0,
    currentAmount: _asInt(m['current_amount'] ?? m['currentAmount']) ?? 0,
    currency: _asString(m['currency'], fallback: 'DZD'),
    targetDate: _asNullableString(m['target_date'] ?? m['targetDate']),
    note: _asNullableString(m['note']),
    createdAt: _asString(m['created_at'] ?? m['createdAt']),
    updatedAt: _asString(m['updated_at'] ?? m['updatedAt']),
  );
}

class RecurringTxn {
  final int? id;
  final String type;
  final int amount;
  final String currency;
  final int? categoryId;
  final String frequency;
  final String startDate;
  final String? endDate;
  final String paymentMethod;
  final String? note;
  final bool isActive;
  final String createdAt;

  bool get isExpense => TxType.isExpense(type);

  const RecurringTxn({
    this.id,
    required this.type,
    required this.amount,
    this.currency = 'DZD',
    required this.categoryId,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.paymentMethod = '',
    this.note,
    this.isActive = true,
    required this.createdAt,
  });

  DateTime nextOccurrenceAfter(DateTime from) {
    DateTime cursor = DateTime.parse(startDate);
    if (cursor.isBefore(from)) {
      cursor = DateTime(from.year, from.month, from.day);
      switch (frequency) {
        case 'daily':
          while (!cursor.isAfter(from) ||
              cursor.isBefore(DateTime.parse(startDate))) {
            cursor = cursor.add(const Duration(days: 1));
          }
        case 'weekly':
          while (!cursor.isAfter(from) ||
              cursor.weekday != DateTime.parse(startDate).weekday) {
            cursor = cursor.add(const Duration(days: 1));
          }
        case 'yearly':
          cursor = DateTime(
            from.year,
            DateTime.parse(startDate).month,
            DateTime.parse(startDate).day,
          );
          while (!cursor.isAfter(from) ||
              cursor.isBefore(DateTime.parse(startDate))) {
            cursor = DateTime(cursor.year + 1, cursor.month, cursor.day);
          }
        default:
          cursor = DateTime(
            from.year,
            from.month,
            DateTime.parse(startDate).day,
          );
          while (!cursor.isAfter(from) ||
              cursor.isBefore(DateTime.parse(startDate))) {
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
    'currency': currency,
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
    id: _asInt(m['id']),
    type: _asString(m['type']),
    amount: _asInt(m['amount']) ?? 0,
    currency: _asString(m['currency'], fallback: 'DZD'),
    categoryId: _asInt(m['category_id'] ?? m['categoryId']),
    frequency: _asString(m['frequency']),
    startDate: _asString(m['start_date'] ?? m['startDate']),
    endDate: _asNullableString(m['end_date'] ?? m['endDate']),
    paymentMethod: _asString(m['payment_method'] ?? m['paymentMethod']),
    note: _asNullableString(m['note']),
    isActive: _asBool(m['is_active'] ?? m['isActive'], fallback: true),
    createdAt: _asString(m['created_at'] ?? m['createdAt']),
  );
}

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

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String? _asNullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value == null) return fallback;
  return value.toString() == '1' || value.toString().toLowerCase() == 'true';
}
