import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/utils/money.dart';

void main() {
  group('formatDA', () {
    test('formats single digit', () {
      expect(formatDA(1), '1 DA');
    });

    test('formats hundreds without separator', () {
      expect(formatDA(500), '500 DA');
      expect(formatDA(999), '999 DA');
    });

    test('formats thousands with thin separator', () {
      expect(formatDA(1000), '1\u2009000 DA');
      expect(formatDA(32500), '32\u2009500 DA');
    });

    test('formats millions', () {
      expect(formatDA(1000000), '1\u2009000\u2009000 DA');
      expect(formatDA(1500000), '1\u2009500\u2009000 DA');
    });

    test('handles negatives', () {
      expect(formatDA(-2500), '-2\u2009500 DA');
    });

    test('handles zero', () {
      expect(formatDA(0), '0 DA');
    });
  });

  group('formatDAShort', () {
    test('keeps small values as-is', () {
      expect(formatDAShort(999), '999');
      expect(formatDAShort(0), '0');
    });

    test('compacts thousands', () {
      expect(formatDAShort(85000), '85k');
      expect(formatDAShort(2500), '2.5k');
    });

    test('compacts millions', () {
      expect(formatDAShort(2500000), '2.5M');
      expect(formatDAShort(1000000), '1M');
    });
  });

  group('parseAmount', () {
    test('reads digits from free text', () {
      expect(parseAmount('12 500 DA'), 12500);
      expect(parseAmount('12,500.50'), 1250050);
      expect(parseAmount('85000'), 85000);
    });

    test('rejects empty / zero / negative', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('-5'), 5);
    });
  });

  group('sanitizeAmountText', () {
    test('strips leading zeros but keeps single zero', () {
      expect(sanitizeAmountText('04'), '4');
      expect(sanitizeAmountText('000'), '0');
      expect(sanitizeAmountText(''), '0');
    });

    test('caps at 12 digits', () {
      expect(sanitizeAmountText('123456789012345678901234'), '123456789012');
    });
  });

  group('date helpers', () {
    test('dateKey is zero-padded yyyy-MM-dd', () {
      expect(dateKey(DateTime(2025, 3, 5)), '2025-03-05');
      expect(dateKey(DateTime(2025, 12, 30)), '2025-12-30');
    });

    test('parseDateKey round-trips', () {
      expect(parseDateKey('2025-03-05'), DateTime(2025, 3, 5));
    });

    test('monthStart and monthEnd', () {
      expect(monthStart(DateTime(2025, 5, 20)), DateTime(2025, 5, 1));
      expect(monthEnd(DateTime(2025, 2, 15)), DateTime(2025, 2, 28));
    });
  });

  group('localized names', () {
    test('monthName french', () {
      expect(monthName(8, 'fr'), 'Août');
    });

    test('monthName english', () {
      expect(monthName(1, 'en'), 'January');
      expect(monthShort(2, 'en'), 'Feb');
    });

    test('weekdayName french short', () {
      expect(weekdayName(1, 'fr', short: true), 'Lun');
    });
  });
}