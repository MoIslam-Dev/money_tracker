import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'money.dart';

const _brandHex = '#0E8A62';
const _brandDarkHex = '#0A3D2C';
const _incomeHex = '#16A34A';
const _expenseHex = '#E5484D';
const _whiteHex = '#FFFFFF';
const _altRowHex = '#F4F9F6';
const _borderHex = '#D0D7DE';
const _bodyHex = '#1F2328';
const _mutedHex = '#57606A';

const _mimeXlsx =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Columns shown on the transactions sheet (backed only by real DB fields).
const _columns = [
  'date',
  'type',
  'category',
  'note',
  'amount',
  'payment_method',
];

Border _border([String hex = _borderHex]) =>
    Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString(hex));

CellStyle _headerStyle() => CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString(_whiteHex),
      backgroundColorHex: ExcelColor.fromHexString(_brandHex),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: _border(),
      rightBorder: _border(),
      topBorder: _border(),
      bottomBorder: _border(),
    );

CellStyle _bodyStyle({
  bool alt = false,
  bool bold = false,
  String color = _bodyHex,
  HorizontalAlign align = HorizontalAlign.Left,
  NumFormat? numFormat,
  TextWrapping wrap = TextWrapping.WrapText,
}) =>
    CellStyle(
      fontSize: 11,
      bold: bold,
      fontColorHex: ExcelColor.fromHexString(color),
      backgroundColorHex: ExcelColor.fromHexString(alt ? _altRowHex : _whiteHex),
      horizontalAlign: align,
      verticalAlign: VerticalAlign.Center,
      textWrapping: wrap,
      numberFormat: numFormat ?? NumFormat.standard_0,
      leftBorder: _border(),
      rightBorder: _border(),
      topBorder: _border(),
      bottomBorder: _border(),
    );

final _dateFormat = NumFormat.custom(formatCode: 'dd/mm/yyyy');
final _moneyFormat = NumFormat.custom(formatCode: '#,##0 "DA"');

/// Build an `.xlsx` report for [transactions] (defaults to every transaction
/// in [state]). The user's current filter/period can be honoured by passing the
/// already-filtered list.
///
/// The workbook contains a styled **Transactions** sheet (real date values,
/// numeric amounts, header row, borders, alternating rows, frozen header and
/// auto-filter) and a **Summary** sheet with the period totals and a per
/// category breakdown.
Uint8List buildTransactionsWorkbook(
  AppState state, {
  List<AppTransaction>? transactions,
  DateTime? exportedAt,
}) {
  final txns = [...(transactions ?? state.transactions)]
    ..sort((a, b) => b.date.compareTo(a.date));
  final sheets = state.strings;
  final when = exportedAt ?? DateTime.now();

  final excel = Excel.createExcel();
  if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

  final sheet = excel['Transactions'];
  final lastCol = _columns.length - 1;

  for (var c = 0; c < _columns.length; c++) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
    cell.value = TextCellValue(sheets.tr(_columns[c]).toUpperCase());
    cell.cellStyle = _headerStyle();
  }

  for (var i = 0; i < txns.length; i++) {
    final t = txns[i];
    final row = i + 1;
    final alt = i.isOdd;
    final cat = state.categoryById(t.categoryId);
    final category = cat == null ? sheets.tr('other') : sheets.categoryName(cat.name);
    final typeColor = t.isExpense ? _expenseHex : _incomeHex;

    void put(int col, CellValue? value, CellStyle style) {
      final c = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      c.value = value;
      c.cellStyle = style;
    }

    put(0, DateCellValue.fromDateTime(parseDateKey(t.date)),
        _bodyStyle(alt: alt, align: HorizontalAlign.Center, numFormat: _dateFormat));
    put(1, TextCellValue(sheets.tr(t.isExpense ? 'expense' : 'income')),
        _bodyStyle(alt: alt, color: typeColor, bold: true));
    put(2, TextCellValue(category), _bodyStyle(alt: alt));
    put(3, TextCellValue(t.note ?? ''), _bodyStyle(alt: alt));
    put(4, IntCellValue(t.amount),
        _bodyStyle(alt: alt, align: HorizontalAlign.Right, bold: true, numFormat: _moneyFormat));
    put(5, TextCellValue(sheets.tr(t.paymentMethod)), _bodyStyle(alt: alt, color: _mutedHex));
  }

  const widths = [13.0, 11.0, 22.0, 34.0, 16.0, 20.0];
  for (var c = 0; c < widths.length; c++) {
    sheet.setColumnWidth(c, widths[c]);
  }
  sheet.setRowHeight(0, 26);

  _buildSummary(excel, state, txns, when);

  final raw = excel.save()!;
  return _freezeAndFilter(
    Uint8List.fromList(raw),
    sheetName: 'Transactions',
    freezeRows: 1,
    lastCol: lastCol,
    lastRow: txns.length,
  );
}

void _buildSummary(
  Excel excel,
  AppState state,
  List<AppTransaction> txns,
  DateTime when,
) {
  final sheets = state.strings;
  final sheet = excel['Summary'];
  sheet.setColumnWidth(0, 34);
  sheet.setColumnWidth(1, 20);

  var income = 0;
  var expense = 0;
  final byCategory = <String, int>{};
  DateTime? minDate;
  DateTime? maxDate;
  for (final t in txns) {
    if (t.isExpense) {
      expense += t.amount;
    } else {
      income += t.amount;
    }
    final d = parseDateKey(t.date);
    if (minDate == null || d.isBefore(minDate)) minDate = d;
    if (maxDate == null || d.isAfter(maxDate)) maxDate = d;
    final cat = state.categoryById(t.categoryId);
    final label = cat == null ? sheets.tr('other') : sheets.categoryName(cat.name);
    final key = t.isExpense ? '-$label' : label;
    byCategory[key] = (byCategory[key] ?? 0) + t.amount;
  }

  void title(int col, int row, String text) {
    final c = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    c.value = TextCellValue(text);
    c.cellStyle = CellStyle(
      bold: true,
      fontSize: row == 0 ? 16 : 13,
      fontColorHex: ExcelColor.fromHexString(row == 0 ? _brandDarkHex : _brandHex),
    );
  }

  void pair(int row, String label, CellValue value, {bool bold = false, String? color}) {
    final l = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    l.value = TextCellValue(label);
    l.cellStyle = _bodyStyle(bold: bold, color: color ?? _mutedHex);
    final v = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    v.value = value;
    v.cellStyle = _bodyStyle(bold: true, color: color ?? _bodyHex, align: HorizontalAlign.Right);
  }

  title(0, 0, sheets.tr('app_name'));
  pair(1, sheets.tr('date'), TextCellValue(_formatDate(when)));
  final period = minDate == null
      ? '—'
      : '${_formatDate(minDate)} - ${_formatDate(maxDate!)}';
  pair(2, sheets.tr('transactions'), TextCellValue(period));

  pair(4, sheets.tr('income'), IntCellValue(income), bold: true, color: _incomeHex);
  pair(5, sheets.tr('expenses'), IntCellValue(expense), bold: true, color: _expenseHex);
  pair(6, sheets.tr('balance'), IntCellValue(income - expense), bold: true);
  pair(7, sheets.tr('transactions'), IntCellValue(txns.length));

  final keys = byCategory.keys.toList()..sort();
  if (keys.isNotEmpty) {
    title(0, 9, sheets.tr('category'));
    title(1, 9, sheets.tr('amount'));
    for (var i = 0; i < keys.length; i++) {
      final k = keys[i];
      final isExpense = k.startsWith('-');
      final name = isExpense ? k.substring(1) : k;
      pair(10 + i, name, IntCellValue(byCategory[k]!),
          color: isExpense ? _expenseHex : _incomeHex);
    }
  }
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Insert a frozen header [pane] and an [autoFilter] into the sheet named
/// [sheetName]. The `excel` package does not emit these elements itself, so the
/// generated zip is post-processed. Any failure degrades gracefully to the
/// untouched workbook.
Uint8List _freezeAndFilter(
  Uint8List bytes, {
  required String sheetName,
  required int freezeRows,
  required int lastCol,
  required int lastRow,
}) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final path = _sheetXmlPath(archive, sheetName);
    if (path == null) return bytes;
    final file = archive.files.firstWhere((f) => f.name == path);
    final doc = XmlDocument.parse(utf8.decode(file.content as List<int>));
    final worksheet = doc.rootElement;

    final sheetViews = worksheet.getElement('sheetViews') ??
        XmlElement(XmlName('sheetViews'));
    if (worksheet.getElement('sheetViews') == null) {
      worksheet.children.insert(0, sheetViews);
    }
    var sheetView = sheetViews.getElement('sheetView');
    if (sheetView == null) {
      sheetView = XmlElement(XmlName('sheetView'), [
        XmlAttribute(XmlName('workbookViewId'), '0'),
      ]);
      sheetViews.children.add(sheetView);
    }
    sheetView.children.insert(
      0,
      XmlElement(XmlName('pane'), [
        XmlAttribute(XmlName('ySplit'), '$freezeRows'),
        XmlAttribute(XmlName('topLeftCell'), 'A${freezeRows + 1}'),
        XmlAttribute(XmlName('activePane'), 'bottomLeft'),
        XmlAttribute(XmlName('state'), 'frozen'),
      ]),
    );

    final sheetData = worksheet.getElement('sheetData');
    if (sheetData != null) {
      final ref = 'A1:${_colName(lastCol)}${lastRow + 1}';
      final filter = XmlElement(XmlName('autoFilter'), [
        XmlAttribute(XmlName('ref'), ref),
      ]);
      final siblings = sheetData.parent!.children;
      siblings.insert(siblings.indexOf(sheetData) + 1, filter);
    }

    final updated = Uint8List.fromList(utf8.encode(doc.toXmlString()));
    final out = Archive();
    for (final f in archive.files) {
      if (f.name == path) {
        out.addFile(ArchiveFile(f.name, updated.length, updated));
      } else {
        out.addFile(ArchiveFile(f.name, f.size, f.content));
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(out)!);
  } catch (_) {
    return bytes;
  }
}

String _colName(int index) {
  var i = index + 1;
  final sb = StringBuffer();
  while (i > 0) {
    final rem = (i - 1) % 26;
    sb.writeCharCode(65 + rem);
    i = (i - rem) ~/ 26;
  }
  return String.fromCharCodes(sb.toString().codeUnits.reversed);
}

String? _sheetXmlPath(Archive archive, String sheetName) {
  ArchiveFile? find(String name) {
    for (final f in archive.files) {
      if (f.name == name) return f;
    }
    return null;
  }

  final wbFile = find('xl/workbook.xml');
  final relFile = find('xl/_rels/workbook.xml.rels');
  if (wbFile == null || relFile == null) return null;
  final wb = XmlDocument.parse(utf8.decode(wbFile.content as List<int>));
  final sheets = wb.rootElement.getElement('sheets');
  if (sheets == null) return null;
  for (final s in sheets.childElements) {
    if (s.getAttribute('name') != sheetName) continue;
    final rid = s.getAttribute('r:id') ?? s.getAttribute('id');
    final rels = XmlDocument.parse(utf8.decode(relFile.content as List<int>));
    for (final r in rels.rootElement.childElements) {
      if (r.getAttribute('Id') != rid) continue;
      var target = r.getAttribute('Target') ?? '';
      if (target.startsWith('/')) {
        target = target.substring(1);
      } else if (!target.startsWith('xl/')) {
        target = 'xl/$target';
      }
      return target.replaceAll('//', '/');
    }
  }
  return null;
}

/// Export every transaction to a formatted `.xlsx` file and share it.
Future<String> exportExcel(AppState state, {List<AppTransaction>? transactions}) async {
  final bytes = buildTransactionsWorkbook(state, transactions: transactions);
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/money_tracker_${dateKey(DateTime.now())}.xlsx');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: _mimeXlsx)],
    text: file.uri.pathSegments.last,
  );
  return file.path;
}
