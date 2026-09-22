import 'package:flutter/material.dart';

/// Semantic accent palette shared by the whole app.
///
/// Every color in here is theme-resolved inside `build()` via
/// [AppColors.*On] helpers or through [LuxColors] so that flipping the
/// [ThemeMode] always re-evaluates against the active ThemeData. Never keep
/// one of these values cached in a `State` field across theme switches —
/// resolve them from `context` at paint time.
class AppColors {
  /// Signature gold used as the brand color (and ColorScheme seed).
  static const gold = Color(0xFFD4AF37);

  /// Deeper gold — primary in the light theme (AA on light cards).
  static const goldDeep = Color(0xFF8A6919);

  /// Bright champagne gold — highlights on dark surfaces.
  static const goldBright = Color(0xFFE6CE6A);

  /// Near-black used as foreground over gold fills.
  static const onGold = Color(0xFF211A05);

  static const seed = gold;

  static const income = Color(0xFF1E7A4F);
  static const expense = Color(0xFFBF4747);

  // Brighter variants keep income/expense amounts legible on dark cards.
  static const incomeDark = Color(0xFF53D98A);
  static const expenseDark = Color(0xFFFF8A80);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color incomeOn(BuildContext context) =>
      Theme.of(context).extension<LuxColors>()?.income ??
      (isDark(context) ? incomeDark : income);

  static Color expenseOn(BuildContext context) =>
      Theme.of(context).extension<LuxColors>()?.expense ??
      (isDark(context) ? expenseDark : expense);

  static const amber = Color(0xFF9A6208);
  static const amberDark = Color(0xFFF2C14E);
  static const amberIcon = Color(0xFF9A6208);
  static const violet = Color(0xFF6B46C1);
  static const violetDark = Color(0xFFB9A1F0);
  static const sky = Color(0xFF1B6FA8);
  static const skyDark = Color(0xFF63C5F5);

  static Color amberOn(BuildContext context) =>
      isDark(context) ? amberDark : amber;
  static Color amberIconOn(BuildContext context) =>
      isDark(context) ? amberDark : amberIcon;
  static Color violetOn(BuildContext context) =>
      isDark(context) ? violetDark : violet;
  static Color skyOn(BuildContext context) => isDark(context) ? skyDark : sky;

  /// Deep luxury gradient used behind the balance card. Kept dark in both
  /// themes so the white foreground always has enough contrast.
  static List<Color> balanceGradient(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
          ? const [Color(0xFF463807), Color(0xFF141006)]
          : const [Color(0xFF8A6919), Color(0xFFC9A227)];

  /// WCAG relative-luminance contrast ratio between two opaque colors.
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  // Demo-data banner palette; gold-tinted so it blends with the luxury look.
  static const bannerBgLight = Color(0xFFFFF6DA);
  static const bannerBorderLight = Color(0xFFE4CD8C);
  static const bannerFgLight = Color(0xFF7A5C00);
  static const bannerIconLight = Color(0xFFB8860B);
  static const bannerBgDark = Color(0xFF2C2610);
  static const bannerBorderDark = Color(0xFF544A1E);
  static const bannerFgDark = Color(0xFFF2D77C);
  static const bannerIconDark = Color(0xFFFFD75E);

  static Color bannerBg(BuildContext c) => isDark(c) ? bannerBgDark : bannerBgLight;
  static Color bannerBorder(BuildContext c) =>
      isDark(c) ? bannerBorderDark : bannerBorderLight;
  static Color bannerFg(BuildContext c) => isDark(c) ? bannerFgDark : bannerFgLight;
  static Color bannerIcon(BuildContext c) =>
      isDark(c) ? bannerIconDark : bannerIconLight;
}

/// App-wide semantic colors resolved from the active [ThemeData].
///
/// Registering these as a [ThemeExtension] makes the widget tree recompute
/// every accent on theme change automatically, which is the architectural
/// guarantee that repeated Light/Dark switching never leaves stale colors
/// behind. Screens read through `Theme.of(context).extension<LuxColors>()`
/// (or the [AppColors] helpers that delegate to it).
class LuxColors extends ThemeExtension<LuxColors> {
  /// Amount color for income on this theme (dark-safe variant).
  final Color income;

  /// Amount color for expenses on this theme (dark-safe variant).
  final Color expense;

  /// Signature gold for the active brightness (bright in dark, deep in light).
  final Color gold;

  /// Dark foreground used on gold fills.
  final Color onGold;

  /// Raised surface used for cards / dialogs / menus.
  final Color card;

  /// Scaffold background.
  final Color scaffold;

  /// Slightly raised surface (inputs, progress tracks).
  final Color surfaceAlt;

  /// Neutral chip background.
  final Color chip;

  /// Hairline separators.
  final Color separator;

  const LuxColors({
    required this.income,
    required this.expense,
    required this.gold,
    required this.onGold,
    required this.card,
    required this.scaffold,
    required this.surfaceAlt,
    required this.chip,
    required this.separator,
  });

  static LuxColors of(BuildContext context) =>
      Theme.of(context).extension<LuxColors>() ?? _fallback(context);

  static LuxColors _fallback(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) return _dark;
    return _light;
  }

  static const _light = LuxColors(
    income: AppColors.income,
    expense: AppColors.expense,
    gold: AppColors.goldDeep,
    onGold: Colors.white,
    card: Colors.white,
    scaffold: Color(0xFFF6F1E7),
    surfaceAlt: Color(0xFFECE8DD),
    chip: Color(0xFFEDE7D8),
    separator: Color(0x0F000000),
  );

  static const _dark = LuxColors(
    income: AppColors.incomeDark,
    expense: AppColors.expenseDark,
    gold: AppColors.gold,
    onGold: AppColors.onGold,
    card: Color(0xFF15181D),
    scaffold: Color(0xFF0B0D10),
    surfaceAlt: Color(0xFF252B33),
    chip: Color(0xFF232830),
    separator: Color(0x14FFFFFF),
  );

  @override
  LuxColors copyWith({
    Color? income,
    Color? expense,
    Color? gold,
    Color? onGold,
    Color? card,
    Color? scaffold,
    Color? surfaceAlt,
    Color? chip,
    Color? separator,
  }) {
    return LuxColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      gold: gold ?? this.gold,
      onGold: onGold ?? this.onGold,
      card: card ?? this.card,
      scaffold: scaffold ?? this.scaffold,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      chip: chip ?? this.chip,
      separator: separator ?? this.separator,
    );
  }

  @override
  LuxColors lerp(ThemeExtension<LuxColors>? other, double t) {
    if (other is! LuxColors) return this;
    return LuxColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      onGold: Color.lerp(onGold, other.onGold, t)!,
      card: Color.lerp(card, other.card, t)!,
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      chip: Color.lerp(chip, other.chip, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
    );
  }
}

TextTheme _textTheme(ThemeData base, ColorScheme scheme) => base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

ThemeData _base({
  required ColorScheme scheme,
  required LuxColors lux,
  required Color scaffold,
  required Color card,
  required Color divider,
  required Color navigation,
  required Color snack,
  Color? chip,
}) {
  final t = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = _textTheme(t, scheme);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [lux],
    textTheme: text,
    primaryTextTheme: text,
    scaffoldBackgroundColor: scaffold,
    iconTheme: IconThemeData(color: scheme.onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      titleTextStyle: text.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: card,
      showDragHandle: true,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      textStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lux.surfaceAlt.withValues(alpha: 0.55),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      prefixIconColor: scheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide.none,
      backgroundColor: chip ?? lux.chip,
      selectedColor: scheme.secondaryContainer,
      labelStyle: TextStyle(color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(color: scheme.onSecondaryContainer),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: scheme.onPrimary,
        backgroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurface,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? scheme.primary.withValues(alpha: 0.45)
            : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.transparent
            : scheme.outline,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: snack,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      backgroundColor: navigation,
      surfaceTintColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: lux.surfaceAlt,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      valueIndicatorColor: scheme.inverseSurface,
      valueIndicatorTextStyle:
          text.labelMedium?.copyWith(color: scheme.onInverseSurface),
    ),
    dividerColor: divider,
  );
}

/// Hand-built "Dark + Gold" luxury color scheme.
ColorScheme _darkScheme() => const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFD4AF37),
      onPrimary: Color(0xFF211A05),
      primaryContainer: Color(0xFF3A3012),
      onPrimaryContainer: Color(0xFFEFDFA0),
      secondary: Color(0xFF3A3B2F),
      onSecondary: Color(0xFFECE7D8),
      secondaryContainer: Color(0xFF2A2C22),
      onSecondaryContainer: Color(0xFFE6E0CA),
      tertiary: Color(0xFF7FA98C),
      onTertiary: Color(0xFF0C1A12),
      tertiaryContainer: Color(0xFF24362B),
      onTertiaryContainer: Color(0xFFC8E8D4),
      error: Color(0xFFFF8A80),
      onError: Color(0xFF3B0808),
      errorContainer: Color(0xFF4A1D1D),
      onErrorContainer: Color(0xFFFFC8BA),
      surface: Color(0xFF0B0D10),
      onSurface: Color(0xFFECE7D8),
      surfaceContainerHighest: Color(0xFF252B33),
      onSurfaceVariant: Color(0xFFB5AE9E),
      outline: Color(0xFF4E4A3F),
      outlineVariant: Color(0xFF2E2C25),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE6E1D3),
      onInverseSurface: Color(0xFF221F17),
      inversePrimary: Color(0xFFD4AF37),
      surfaceTint: Color(0xFFD4AF37),
    );

/// Warm-paper light scheme with a deep gold primary.
ColorScheme _lightScheme() => const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF8A6919),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFF0E3B6),
      onPrimaryContainer: Color(0xFF3A2E06),
      secondary: Color(0xFF6E6A4F),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE3E8CD),
      onSecondaryContainer: Color(0xFF24290F),
      tertiary: Color(0xFF4B6E58),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFCDE8D4),
      onTertiaryContainer: Color(0xFF0E2B19),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFDFBF5),
      onSurface: Color(0xFF272419),
      surfaceContainerHighest: Color(0xFFECE8DD),
      onSurfaceVariant: Color(0xFF645E50),
      outline: Color(0xFF7C7360),
      outlineVariant: Color(0xFFD8D0C0),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF464441),
      onInverseSurface: Color(0xFFF6F0E6),
      inversePrimary: Color(0xFFD4AF37),
      surfaceTint: Color(0xFF8A6919),
    );

ThemeData buildLightTheme() => _base(
      scheme: _lightScheme(),
      lux: LuxColors._light,
      scaffold: const Color(0xFFF6F1E7),
      card: Colors.white,
      divider: Colors.black.withValues(alpha: 0.07),
      navigation: const Color(0xFFFDFBF5),
      snack: const Color(0xFF2E2A22),
    );

ThemeData buildDarkTheme() => _base(
      scheme: _darkScheme(),
      lux: LuxColors._dark,
      scaffold: const Color(0xFF0B0D10),
      card: const Color(0xFF15181D),
      divider: Colors.white.withValues(alpha: 0.08),
      navigation: const Color(0xFF101318),
      snack: const Color(0xFF2A2722),
      chip: const Color(0xFF232830),
    );

ThemeMode themeModeFrom(String v) => switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };