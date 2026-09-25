import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'money.dart';

String _fmtCsvField(String v) =>
    v.contains(';') || v.contains('"') || v.contains('\n')
        ? '"${v.replaceAll('"', '""')}"'
        : v;

/// Export all transactions to a CSV file and share it.
Future<String> exportCsv(AppState state) async {
  final buf = StringBuffer();
  buf.writeln('Date;Type;Amount;Currency;Category;PaymentMethod;Note');
  final sorted = [...state.transactions]
    ..sort((a, b) => b.date.compareTo(a.date));
  for (final t in sorted) {
    final cat = state.categoryLabel(state.categoryById(t.categoryId));
    buf.writeln(
      [
        _fmtCsvField(t.date),
        _fmtCsvField(t.isExpense ? 'Expense' : 'Income'),
        _fmtCsvField('${t.amount}'),
        _fmtCsvField(t.currency),
        _fmtCsvField(cat),
        _fmtCsvField(state.strings.tr(t.paymentMethod)),
        _fmtCsvField(t.note ?? ''),
      ].join(';'),
    );
  }
  return _shareText(
    'export_${dateKey(DateTime.now())}.csv',
    buf.toString(),
    mime: 'text/csv',
  );
}

/// Export a full JSON backup file and share it.
Future<String> exportJson(AppState state) async {
  final payload = jsonEncode({
    'app': 'money_tracker',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'categories':
        state.categories
            .map(
              (c) => {
                'id': c.id,
                'name': c.name,
                'nameEn': c.nameEn,
                'nameFr': c.nameFr,
                'nameAr': c.nameAr,
                'type': c.type,
                'icon': c.icon,
                'isDefault': c.isDefault,
                'sortOrder': c.sortOrder,
              },
            )
            .toList(),
    'transactions':
        state.transactions
            .map(
              (t) => {
                'id': t.id,
                'type': t.type,
                'amount': t.amount,
                'currency': t.currency,
                'originalAmount': t.originalAmount,
                'originalCurrency': t.originalCurrency,
                'categoryId': t.categoryId,
                'paymentMethod': t.paymentMethod,
                'date': t.date,
                'note': t.note,
                'createdAt': t.createdAt,
                'updatedAt': t.updatedAt,
              },
            )
            .toList(),
    'budgets':
        state.budgets
            .map(
              (b) => {
                'id': b.id,
                'categoryId': b.categoryId,
                'amount': b.amount,
                'currency': b.currency,
                'month': b.month,
                'year': b.year,
              },
            )
            .toList(),
    'savingsGoals':
        state.goals
            .map(
              (g) => {
                'id': g.id,
                'name': g.name,
                'targetAmount': g.targetAmount,
                'currentAmount': g.currentAmount,
                'currency': g.currency,
                'targetDate': g.targetDate,
                'note': g.note,
              },
            )
            .toList(),
    'recurring':
        state.recurring
            .map(
              (r) => {
                'id': r.id,
                'type': r.type,
                'amount': r.amount,
                'currency': r.currency,
                'categoryId': r.categoryId,
                'frequency': r.frequency,
                'startDate': r.startDate,
                'endDate': r.endDate,
                'paymentMethod': r.paymentMethod,
                'note': r.note,
                'isActive': r.isActive,
              },
            )
            .toList(),
  });
  return _shareText(
    'money_tracker_backup_${dateKey(DateTime.now())}.json',
    payload,
    mime: 'application/json',
  );
}

Future<String> _shareText(
  String filename,
  String content, {
  required String mime,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
  final r = await Share.shareXFiles([
    XFile(file.path, mimeType: mime),
  ], text: filename);
  if (r.status == ShareResultStatus.success) return file.path;
  return file.path;
}

/// Serialize current full backup content (string, same schema as export).
String buildBackupPayload(AppState state) {
  return jsonEncode({
    'app': 'money_tracker',
    'backup': true,
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'categories':
        state.categories.map((c) => c.toMap()..['id'] = c.id).toList(),
    'transactions':
        state.transactions.map((t) => t.toMap()..['id'] = t.id).toList(),
    'budgets': state.budgets.map((b) => b.toMap()..['id'] = b.id).toList(),
    'savingsGoals': state.goals.map((g) => g.toMap()..['id'] = g.id).toList(),
    'recurring': state.recurring.map((r) => r.toMap()..['id'] = r.id).toList(),
  });
}

class BackupFile {
  final Map<String, dynamic> json;
  BackupFile(this.json);

  factory BackupFile.parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('not an object');
    }
    if (decoded['app'] != 'money_tracker') {
      throw const FormatException('wrong app');
    }
    return BackupFile(decoded);
  }

  List<AppCategory> categories() {
    final list = (json['categories'] as List? ?? []);
    return list.map((e) {
      final m = Map<String, Object?>.from(e as Map);
      final c = AppCategory.fromMap(m);
      return AppCategory(
        id: m['id'] as int?,
        name: c.name,
        nameEn: m['nameEn'] as String? ?? c.nameEn,
        nameFr: m['nameFr'] as String? ?? c.nameFr,
        nameAr: m['nameAr'] as String? ?? c.nameAr,
        type: c.type,
        icon: c.icon,
        isDefault: c.isDefault,
        sortOrder: c.sortOrder,
      );
    }).toList();
  }

  List<AppTransaction> transactions() {
    final list = (json['transactions'] as List? ?? []);
    return list
        .map((e) => AppTransaction.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
  }

  List<Budget> budgets() {
    final list = (json['budgets'] as List? ?? []);
    return list
        .map((e) => Budget.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
  }

  List<SavingsGoal> goals() {
    final list = (json['savingsGoals'] as List? ?? []);
    return list
        .map((e) => SavingsGoal.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
  }

  List<RecurringTxn> recurring() {
    final list = (json['recurring'] as List? ?? []);
    return list
        .map((e) => RecurringTxn.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
  }
}

/// Ensure user has access to file paths (used on restore).
String? validateBackupFile(String raw) {
  try {
    final f = BackupFile.parse(raw);
    return f.json['app'] == 'money_tracker' ? null : 'invalid';
  } catch (_) {
    return 'invalid';
  }
}
