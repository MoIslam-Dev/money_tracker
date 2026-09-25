library;

enum CurrencyChangeMode { keep, convert }

class AppCurrency {
  final String code;
  final String symbol;
  final bool symbolBefore;
  final bool isCustom;
  final String nameEn;
  final String nameFr;
  final String nameAr;

  const AppCurrency({
    this.code = 'DZD',
    this.symbol = 'DA',
    this.symbolBefore = false,
    this.isCustom = false,
    this.nameEn = 'Algerian Dinar',
    this.nameFr = 'Dinar algérien',
    this.nameAr = 'الدينار الجزائري',
  });

  String localizedName(String lang) {
    final value =
        lang == 'fr'
            ? nameFr
            : lang == 'ar'
            ? nameAr
            : nameEn;
    return value.trim().isEmpty ? code : value.trim();
  }

  Map<String, Object?> toJson() => {
    'code': code,
    'symbol': symbol,
    'symbolBefore': symbolBefore,
    'isCustom': isCustom,
    'nameEn': nameEn,
    'nameFr': nameFr,
    'nameAr': nameAr,
  };

  factory AppCurrency.fromJson(Map<String, dynamic> json) => AppCurrency(
    code: (json['code'] as String? ?? 'DZD').trim().toUpperCase(),
    symbol: (json['symbol'] as String? ?? '').trim(),
    symbolBefore: json['symbolBefore'] as bool? ?? false,
    isCustom: json['isCustom'] as bool? ?? true,
    nameEn: (json['nameEn'] as String? ?? '').trim(),
    nameFr: (json['nameFr'] as String? ?? '').trim(),
    nameAr: (json['nameAr'] as String? ?? '').trim(),
  );
}

const List<AppCurrency> kPopularCurrencies = [
  AppCurrency(
    code: 'DZD',
    symbol: 'DA',
    symbolBefore: false,
    nameEn: 'Algerian Dinar',
    nameFr: 'Dinar algérien',
    nameAr: 'الدينار الجزائري',
  ),
  AppCurrency(
    code: 'USD',
    symbol: r'$',
    symbolBefore: true,
    nameEn: 'US Dollar',
    nameFr: 'Dollar américain',
    nameAr: 'الدولار الأمريكي',
  ),
  AppCurrency(
    code: 'EUR',
    symbol: '€',
    symbolBefore: true,
    nameEn: 'Euro',
    nameFr: 'Euro',
    nameAr: 'اليورو',
  ),
  AppCurrency(
    code: 'GBP',
    symbol: '£',
    symbolBefore: true,
    nameEn: 'British Pound',
    nameFr: 'Livre sterling',
    nameAr: 'الجنيه الإسترليني',
  ),
  AppCurrency(
    code: 'CHF',
    symbol: 'CHF',
    nameEn: 'Swiss Franc',
    nameFr: 'Franc suisse',
    nameAr: 'الفرنك السويسري',
  ),
  AppCurrency(
    code: 'CAD',
    symbol: r'CA$',
    symbolBefore: true,
    nameEn: 'Canadian Dollar',
    nameFr: 'Dollar canadien',
    nameAr: 'الدولار الكندي',
  ),
];

AppCurrency customCurrency(
  String code, {
  String? symbol,
  bool symbolBefore = false,
  String? nameEn,
  String? nameFr,
  String? nameAr,
}) {
  final normalized = code.trim().toUpperCase();
  final fallbackSymbol =
      symbol?.trim().isNotEmpty == true ? symbol!.trim() : normalized;
  final fallbackName = normalized;
  return AppCurrency(
    code: normalized,
    symbol: fallbackSymbol,
    symbolBefore: symbolBefore,
    isCustom: true,
    nameEn: nameEn?.trim().isNotEmpty == true ? nameEn!.trim() : fallbackName,
    nameFr: nameFr?.trim().isNotEmpty == true ? nameFr!.trim() : fallbackName,
    nameAr: nameAr?.trim().isNotEmpty == true ? nameAr!.trim() : fallbackName,
  );
}

AppCurrency popularCurrency(String code) {
  final normalized = code.trim().toUpperCase();
  for (final currency in kPopularCurrencies) {
    if (currency.code == normalized) return currency;
  }
  return customCurrency(normalized);
}

AppCurrency resolveCurrency(
  String code, {
  Iterable<AppCurrency> custom = const [],
}) {
  final normalized = code.trim().toUpperCase();
  for (final currency in custom) {
    if (currency.code == normalized) return currency;
  }
  return popularCurrency(normalized);
}
