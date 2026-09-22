import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/data/app_database.dart';
import 'package:money_tracker/models/models.dart';
import 'package:money_tracker/state/app_state.dart';
import 'package:money_tracker/state/settings_store.dart';
import 'package:money_tracker/utils/excel_export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xml/xml.dart';

void main() {
  late AppState state;
  late AppDatabase appDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'settings.lang': 'en',
      'settings.demoSeen': true,
      'settings.demoAdded': true,
    });
    appDb = AppDatabase(customPath: inMemoryDatabasePath);
    state = AppState(Repository(appDb), SettingsStore());
    await state.init();
  });

  tearDown(() async {
    await appDb.close();
  });

  int? categoryId(String slug) {
    for (final c in state.categories) {
      if (c.name == slug) return c.id;
    }
    return null;
  }

  Future<void> seed() async {
    await state.addTransaction(
        type: TxType.income,
        amount: 120000,
        categoryId: categoryId('salary'),
        date: DateTime(2026, 9, 1),
        note: 'September pay');
    await state.addTransaction(
        type: TxType.expense,
        amount: 1600,
        categoryId: categoryId('food'),
        date: DateTime(2026, 9, 15),
        note: 'Lunch');
  }

  test('workbook contains transactions and summary sheets', () async {
    await seed();
    final bytes = buildTransactionsWorkbook(state);
    final excel = Excel.decodeBytes(bytes);

    expect(excel.tables.keys, containsAll(['Transactions', 'Summary']));
    final sheet = excel.tables['Transactions']!;
    expect(sheet.maxRows, 3); // header + 2 rows

    final headers = [
      for (var c = 0; c < 6; c++)
        (sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value
                as TextCellValue)
            .value
            .text,
    ];
    expect(headers, ['DATE', 'TYPE', 'CATEGORY', 'NOTE', 'AMOUNT', 'PAYMENT METHOD']);
  });

  test('amounts are numeric and dates are real dates', () async {
    await seed();
    final excel = Excel.decodeBytes(buildTransactionsWorkbook(state));
    final sheet = excel.tables['Transactions']!;

    final amount = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value;
    expect(amount, isA<IntCellValue>());
    expect((amount as IntCellValue).value, 1600);

    final date = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value;
    expect(date, anyOf(isA<DateCellValue>(), isA<DateTimeCellValue>()));
    final dt = date is DateCellValue ? date.asDateTimeLocal() : (date as DateTimeCellValue).asDateTimeLocal();
    expect(dt.year, 2026);
    expect(dt.month, 9);
  });

  test('summary totals respect the exported (filtered) set', () async {
    await seed();
    final onlyIncome = state.transactions.where((t) => !t.isExpense).toList();
    final excel = Excel.decodeBytes(
        buildTransactionsWorkbook(state, transactions: onlyIncome));
    final summary = excel.tables['Summary']!;

    expect(_numberAt(summary, 4), 120000); // total income
    expect(_numberAt(summary, 5), 0); // total expenses
    expect(_numberAt(summary, 6), 120000); // net
    expect(_numberAt(summary, 7), 1); // count
  });

  test('header is frozen and auto-filter is applied', () async {
    await seed();
    final bytes = buildTransactionsWorkbook(state);
    final archive = ZipDecoder().decodeBytes(bytes);

    final wb = XmlDocument.parse(
        utf8.decode(_file(archive, 'xl/workbook.xml').content as List<int>));
    final sheets = wb.rootElement.getElement('sheets')!;
    final txn = sheets.childElements
        .firstWhere((e) => e.getAttribute('name') == 'Transactions');
    final rid = txn.getAttribute('r:id') ?? txn.getAttribute('id');
    final rels = XmlDocument.parse(utf8.decode(
        _file(archive, 'xl/_rels/workbook.xml.rels').content as List<int>));
    final target = rels.rootElement.childElements
        .firstWhere((e) => e.getAttribute('Id') == rid)
        .getAttribute('Target')!;
    final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';

    final xml = XmlDocument.parse(
        utf8.decode(_file(archive, path).content as List<int>));
    final pane = xml.findAllElements('pane').first;
    expect(pane.getAttribute('state'), 'frozen');
    expect(pane.getAttribute('topLeftCell'), 'A2');

    final filter = xml.findAllElements('autoFilter').first;
    expect(filter.getAttribute('ref'), 'A1:F3');
  });

  test('empty export still produces a valid single-header workbook', () {
    final bytes = buildTransactionsWorkbook(state);
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables['Transactions']!;
    expect(sheet.maxRows, 1);
    expect(_numberAt(excel.tables['Summary']!, 7), 0);
  });
}

int _numberAt(Sheet sheet, int row) {
  final value = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value;
  return switch (value) {
    IntCellValue v => v.value,
    DoubleCellValue v => v.value.toInt(),
    _ => 0,
  };
}

ArchiveFile _file(Archive archive, String name) =>
    archive.files.firstWhere((f) => f.name == name);
