/// Money + date formatting helpers.
library;

import '../models/currency.dart' as money_currency;

final RegExp _digitScan = RegExp(r'\d');

/// Format an integer amount as Algerian style: `2 500 DA`, `85 000 DA`.
String formatDA(int amount) {
  final neg = amount < 0;
  final s = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u2009');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}$buf DA';
}

/// Format [amount] in the given [currency] for the current [lang].
/// Digit order is preserved (RTL-safe), sign sticks to the digits, and the
/// currency symbol is separated by a thin space, localized under LRI/PDI
/// isolates so Arabic UIs render `-2 500 DA` not `DA 750 2 -`.
///
/// [symbolBefore] controls DA-style `85 000 DA` vs `85 000 €` ordering.
/// When [currency] is provided its registry metadata (symbol, ordering,
/// localized names) wins over the bare [currencyCode].
String formatMoney(
  int amount,
  String lang,
  String currencyCode, {
  bool symbolBefore = false,
  money_currency.AppCurrency? currency,
}) {
  final resolved = currency ?? money_currency.resolveCurrency(currencyCode);
  return _formatWithSymbol(
    _group(amount, '\u2009'),
    resolved.symbol,
    lang,
    resolved.symbolBefore || symbolBefore,
  );
}

/// Compact chart form of [formatMoney]: `85k`, `2.5M`.
String formatMoneyShort(
  int amount,
  String lang,
  String currencyCode, {
  bool symbolBefore = false,
  money_currency.AppCurrency? currency,
}) {
  final resolved = currency ?? money_currency.resolveCurrency(currencyCode);
  return _formatWithSymbol(
    formatDAShort(amount),
    resolved.symbol,
    lang,
    resolved.symbolBefore || symbolBefore,
  );
}

/// Strip LRI/PDI isolates for plain-text comparisons.
String stripIsolates(String value) => value
    .replaceAll('\u2066', '')
    .replaceAll('\u2067', '')
    .replaceAll('\u2068', '')
    .replaceAll('\u2069', '');

/// Full, localized symbol for [code] — `DA`, `CA$`, `DZD`, `د.ج`, `€`…
String currencySymbol(String code) {
  switch (code) {
    case 'DZD':
      return 'DA';
    case 'EUR':
      return '€';
    case 'USD':
      return r'$';
    case 'GBP':
      return '£';
    case 'CAD':
      return r'CA$';
    case 'CHF':
      return 'CHF';
    case 'MAD':
      return 'MAD';
    case 'SAR':
      return 'SAR';
    case 'TND':
      return 'د.ت';
    default:
      return money_currency.resolveCurrency(code).symbol;
  }
}

String _formatWithSymbol(
  String value,
  String symbol,
  String lang,
  bool symbolBefore,
) {
  final lri = '\u2066';
  final pdi = '\u2069';
  final sep = lang == 'ar' ? '\u2009' : ' ';
  if (symbolBefore) {
    return '$lri$symbol$sep$value$pdi';
  }
  return '$lri$value$sep$symbol$pdi';
}

/// Compact form used inside charts: `85k`, `2.5M`.
String formatDAShort(int amount) {
  final a = amount.abs();
  final s =
      a >= 1000000
          ? '${(a / 1000000).toStringAsFixed(1).replaceFirst('.0', '')}M'
          : a >= 1000
          ? '${(a / 1000).toStringAsFixed(1).replaceFirst('.0', '')}k'
          : '$a';
  return '${amount < 0 ? '-' : ''}$s';
}

/// Extract a positive integer from free text (strips spaces and separators).
int? parseAmount(String text) {
  final digits = _digitScan.allMatches(text).map((m) => m.group(0)!).join();
  if (digits.isEmpty) return null;
  final value = int.tryParse(digits);
  if (value == null || value <= 0) return null;
  return value;
}

/// yyyy-MM-dd, lexicographic friendly for comparisons.
String dateKey(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

DateTime parseDateKey(String key) => DateTime.parse(key);

String nowIso() => DateTime.now().toIso8601String();

/// Localized day/month name for the current language code.
String monthName(int month, String lang) {
  const en = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  const fr = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
  const ar = [
    'جانفي',
    'فيفري',
    'مارس',
    'أفريل',
    'ماي',
    'جوان',
    'جويلية',
    'أوت',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  if (lang == 'ar') return ar[month - 1];
  if (lang == 'fr') return fr[month - 1];
  return en[month - 1];
}

String weekdayName(int weekday, String lang, {bool short = false}) {
  const en = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const fr = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  const ar = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  final list =
      lang == 'ar'
          ? ar
          : lang == 'fr'
          ? fr
          : en;
  final name = list[weekday - 1];
  if (!short || lang == 'ar') return name;
  return name.substring(0, name.length >= 4 ? 3 : name.length);
}

String monthShort(int month, String lang) {
  const en = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const fr = [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Août',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];
  const ar = [
    'جان',
    'فيف',
    'مار',
    'أفر',
    'ماي',
    'جوا',
    'جويل',
    'أوت',
    'سب',
    'أكت',
    'نوف',
    'ديس',
  ];
  if (lang == 'ar') return ar[month - 1];
  if (lang == 'fr') return fr[month - 1];
  return en[month - 1];
}

String weekdayShort(int weekday, String lang) {
  const en = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  const fr = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];
  const ar = ['إث', 'ث', 'أر', 'خ', 'ج', 'س', 'ح'];
  if (lang == 'ar') return ar[weekday - 1];
  if (lang == 'fr') return fr[weekday - 1];
  return en[weekday - 1];
}

DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);

DateTime monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addMonths(DateTime d, int n) => DateTime(d.year, d.month + n, d.day);

/// Clamp number of digits so huge inputs won't overflow int parsing.
String sanitizeAmountText(String raw) {
  var digits = _digitScan.allMatches(raw).map((m) => m.group(0)!).join();
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  if (digits.isEmpty) digits = '0';
  if (digits.length > 12) digits = digits.substring(0, 12);
  return digits;
}

String intWithGrouping(int value, String lang) {
  return lang == 'ar' ? _group(value, '\u066C') : _group(value, '\u2009');
}

String _group(int value, String sep) {
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(sep);
    buf.write(s[i]);
  }
  return '${value < 0 ? '-' : ''}$buf';
}
