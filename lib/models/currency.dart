/// Currency settings: persistence + model.
library;

class AppCurrency {
  final String code; // e.g. 'DZD', 'USD', 'MAD'
  final String symbol; // e.g. 'DA', r'$', 'MAD'
  /// True when the symbol is a prefixed (before the amount) notation like `$`.
  final bool symbolBefore;
  final bool isCustom; // user-defined currency, symbol == code
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
}

const List<AppCurrency> kPopularCurrencies = [
  AppCurrency(
      code: 'DZD', symbol: 'DA', symbolBefore: false, nameEn: 'Algerian Dinar', nameFr: 'Dinar algérien', nameAr: 'الدينار الجزائري'),
  AppCurrency(
      code: 'USD', symbol: r'$', symbolBefore: true, nameEn: 'US Dollar', nameFr: 'Dollar américain', nameAr: 'الدولار الأمريكي'),
  AppCurrency(
      code: 'EUR', symbol: '€', symbolBefore: true, nameEn: 'Euro', nameFr: 'Euro', nameAr: 'اليورو'),
  AppCurrency(
      code: 'GBP', symbol: '£', symbolBefore: true, nameEn: 'British Pound', nameFr: 'Livre sterling', nameAr: 'الجنيه الإسترليني'),
  AppCurrency(
      code: 'CHF', symbol: 'CHF', nameEn: 'Swiss Franc', nameFr: 'Franc suisse', nameAr: 'الفرنك السويسري'),
  AppCurrency(
      code: 'CAD', symbol: r'CA$', symbolBefore: true, nameEn: 'Canadian Dollar', nameFr: 'Dollar canadien', nameAr: 'الدولار الكندي'),
];

/// Build a custom currency entry for arbitrary user-entered codes (e.g. MAD).
AppCurrency customCurrency(String code) => AppCurrency(
    code: code.trim().toUpperCase(),
    symbol: code.trim().toUpperCase(),
    isCustom: true,
    nameEn: code.trim().toUpperCase(),
    nameFr: code.trim().toUpperCase(),
    nameAr: code.trim().toUpperCase());
