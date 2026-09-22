import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/models/models.dart';

void main() {
  group('SavingsGoal.progressPercent', () {
    test('is 0 when no current savings', () {
      final g = SavingsGoal(
        name: 'Car',
        targetAmount: 100000,
        currentAmount: 0,
        createdAt: '',
        updatedAt: '',
      );
      expect(g.progressPercent, 0);
    });

    test('is ratio clamped to 100', () {
      SavingsGoal make(int target, int current) => SavingsGoal(
            name: 'Car',
            targetAmount: target,
            currentAmount: current,
            createdAt: '',
            updatedAt: '',
          );
      expect(make(20000, 5000).progressPercent, 25);
      expect(make(20000, 40000).progressPercent, 100);
    });

    test('is 0 for empty target', () {
      final g = SavingsGoal(
        name: 'Car',
        targetAmount: 0,
        currentAmount: 9999,
        createdAt: '',
        updatedAt: '',
      );
      expect(g.progressPercent, 0);
    });
  });

  group('RecurringTxn.nextOccurrenceAfter', () {
    RecurringTxn make(String frequency, String start, {String? end}) =>
        RecurringTxn(
          type: TxType.expense,
          amount: 500,
          categoryId: null,
          frequency: frequency,
          startDate: start,
          endDate: end,
          createdAt: '',
        );

    test('monthly advances one month', () {
      final r = make('monthly', '2025-01-15');
      expect(r.nextOccurrenceAfter(DateTime(2025, 2, 20)), DateTime(2025, 3, 15));
      expect(r.nextOccurrenceAfter(DateTime(2025, 3, 1)), DateTime(2025, 3, 15));
    });

    test('weekly advances seven days', () {
      final r = make('weekly', '2025-06-02');
      expect(r.nextOccurrenceAfter(DateTime(2025, 6, 8)), DateTime(2025, 6, 9));
    });

    test('daily advances one day', () {
      final r = make('daily', '2025-01-01');
      expect(r.nextOccurrenceAfter(DateTime(2025, 1, 3)), DateTime(2025, 1, 4));
    });

    test('yearly advances one year', () {
      final r = make('yearly', '2020-03-10');
      expect(r.nextOccurrenceAfter(DateTime(2025, 3, 11)), DateTime(2026, 3, 10));
    });

    test('never returns before the start date', () {
      final r = make('monthly', '2025-05-20');
      expect(r.nextOccurrenceAfter(DateTime(2025, 1, 1)).isBefore(DateTime(2025, 5, 20)),
          isFalse);
    });
  });

  group('isExpense', () {
    test('classifies by type', () {
      expect(TxType.isExpense(TxType.expense), isTrue);
      expect(TxType.isExpense(TxType.income), isFalse);
    });
  });
}