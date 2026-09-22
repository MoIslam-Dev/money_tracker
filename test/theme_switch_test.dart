import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/main.dart';
import 'package:money_tracker/screens/home_shell.dart';
import 'package:money_tracker/state/app_state.dart';
import 'package:money_tracker/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regression: repeatedly toggling the theme mode must never leave stale
/// semantic colors behind. All colors are resolved from the active ThemeData
/// (via the [LuxColors] ThemeExtension) inside build(), so every switch has to
/// re-evaluate correctly.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('repeated light/dark switching keeps colors consistent',
      (tester) async {
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

    const cycle = ['dark', 'light', 'dark', 'light', 'dark', 'light'];
    for (final mode in cycle) {
      final shell = tester.element(find.byType(HomeShell));
      shell.read<AppState>().setTheme(mode);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      final rebuilt = tester.element(find.byType(HomeShell));
      final theme = Theme.of(rebuilt);
      final colors = LuxColors.of(rebuilt);

      expect(theme.brightness,
          mode == 'dark' ? Brightness.dark : Brightness.light,
          reason: 'themeMode should flip for $mode');
      expect(colors.income,
          mode == 'dark' ? AppColors.incomeDark : AppColors.income,
          reason: 'income color adapts after switch to $mode');
      expect(colors.expense,
          mode == 'dark' ? AppColors.expenseDark : AppColors.expense,
          reason: 'expense color adapts after switch to $mode');
      expect(colors.card,
          mode == 'dark' ? const Color(0xFF15181D) : Colors.white,
          reason: 'card surface adapts after switch to $mode');
      expect(theme.colorScheme.primary,
          mode == 'dark' ? AppColors.gold : AppColors.goldDeep,
          reason: 'gold primary adapts after switch to $mode');
    }
  });
}