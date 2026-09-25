import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/main.dart';
import 'package:money_tracker/screens/categories_screen.dart';
import 'package:money_tracker/screens/home_shell.dart';
import 'package:money_tracker/screens/notification_settings_screen.dart';
import 'package:money_tracker/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'settings.lang': 'en',
      'settings.theme': 'light',
      'settings.demoSeen': true,
      'settings.demoAdded': true,
    });
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // Real DB + plugin I/O does not complete in the fake-async zone, so the
    // initial load must run inside runAsync.
    await tester.runAsync(() async {
      await tester.pumpWidget(const MoneyApp());
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('app boots to the home shell', (tester) async {
    await pumpApp(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.textContaining('0 DA'), findsWidgets);
  });

  testWidgets('quick add sheet opens from the center quick-add button',
      (tester) async {
    await pumpApp(tester);

    final addBtn = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(Icons.add_rounded),
    );
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pump(const Duration(milliseconds: 400));

    // The quick-add bottom sheet is active once the amount field is shown.
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('dark theme renders the home shell and today card',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.lang': 'en',
      'settings.theme': 'dark',
      'settings.demoSeen': true,
      'settings.demoAdded': true,
    });
    await pumpApp(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(Theme.of(tester.element(find.byType(HomeShell))).brightness,
        Brightness.dark);
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('settings opens the categories and reminders screens',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    final settingsScroll = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('Categories'), 300,
        scrollable: settingsScroll);
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);
    expect(find.text('EXPENSE CATEGORIES'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Daily reminders'), 300,
        scrollable: settingsScroll);
    await tester.tap(find.text('Daily reminders'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    expect(find.text('08:00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}