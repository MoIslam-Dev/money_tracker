import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/main.dart';
import 'package:money_tracker/screens/home_shell.dart';
import 'package:money_tracker/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Minimum WCAG contrast ratios used by the accessibility checks below.
const _body = 4.5;
const _large = 3.0;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('dark color scheme contrast', () {
    final scheme = buildDarkTheme().colorScheme;
    final card = buildDarkTheme().cardTheme.color!;

    test('LuxColors resolves the dark semantic set', () {
      final lux = buildDarkTheme().extension<LuxColors>()!;
      expect(lux.income, AppColors.incomeDark);
      expect(lux.expense, AppColors.expenseDark);
      expect(lux.gold, AppColors.gold);
      expect(lux.card, const Color(0xFF15181D));
    });

    test('onSurface reads on cards and scaffold', () {
      expect(AppColors.contrastRatio(scheme.onSurface, card), greaterThan(_body));
      expect(AppColors.contrastRatio(scheme.onSurface, const Color(0xFF0F1216)),
          greaterThan(_body));
    });

    test('secondary text stays readable', () {
      expect(AppColors.contrastRatio(scheme.onSurfaceVariant, card), greaterThan(_body));
    });

    test('income and expense amounts stay readable', () {
      expect(AppColors.contrastRatio(AppColors.incomeDark, card), greaterThan(_body));
      expect(AppColors.contrastRatio(AppColors.expenseDark, card), greaterThan(_body));
    });

    test('accent text (amber, violet, sky) stays readable on dark cards', () {
      for (final c in [AppColors.amberDark, AppColors.violetDark, AppColors.skyDark]) {
        expect(AppColors.contrastRatio(c, card), greaterThan(_body));
      }
    });

    test('selected chips use onPrimary over primary', () {
      expect(AppColors.contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThan(_body));
    });

    test('date badge text reads on its container', () {
      expect(
        AppColors.contrastRatio(scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThan(_body),
      );
    });

    test('balance card keeps white text on its gradient', () {
      for (final c in AppColors.balanceGradient(scheme)) {
        expect(AppColors.contrastRatio(Colors.white, c), greaterThan(_large));
      }
    });

    test('demo banner is legible in dark mode', () {
      expect(AppColors.contrastRatio(AppColors.bannerFgDark, AppColors.bannerBgDark),
          greaterThan(_body));
      expect(AppColors.contrastRatio(AppColors.bannerFgLight, AppColors.bannerBgLight),
          greaterThan(_body));
    });
  });

  group('light color scheme contrast', () {
    final lightCard = buildLightTheme().cardTheme.color!;

    test('accent text stays readable on light cards', () {
      for (final c in [AppColors.amber, AppColors.violet, AppColors.sky]) {
        expect(AppColors.contrastRatio(c, lightCard), greaterThan(_body));
      }
    });
  });

  testWidgets('dark dashboard text keeps enough contrast', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.lang': 'en',
      'settings.theme': 'dark',
      'settings.demoSeen': true,
      'settings.demoAdded': true,
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(const MoneyApp());
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(HomeShell), findsOneWidget);
    final card = Theme.of(tester.element(find.byType(HomeShell))).cardTheme.color!;

    final today = tester.widget<Text>(find.text('TODAY'));
    expect(AppColors.contrastRatio(today.style!.color!, card), greaterThan(_large));

    final banner = tester.widget<Text>(find.text('You are viewing sample data.'));
    final bannerBg = _bannerBackground(tester, banner);
    expect(AppColors.contrastRatio(banner.style!.color!, bannerBg), greaterThan(_body));
  });
}

Color _bannerBackground(WidgetTester tester, Text text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.byWidget(text), matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration).color!;
}
