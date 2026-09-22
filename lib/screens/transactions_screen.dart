import 'package:flutter/material.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/excel_export.dart';
import '../utils/money.dart';
import '../widgets/icons.dart';
import '../widgets/widgets.dart';
import 'add_edit_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('transactions'),
            style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchScreen())),
            tooltip: strings.tr('search'),
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(top: false, child: const _TxList()),
    );
  }
}

class _TxList extends StatelessWidget {
  const _TxList();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    if (state.transactions.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: strings.tr('empty_transactions'),
        subtitle: strings.tr('empty_transactions_sub'),
        buttonLabel: strings.tr('add_first'),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddEditScreen(type: TxType.expense))),
      );
    }

    final groups = <String, List<AppTransaction>>{};
    for (final t in state.transactions) {
      groups.putIfAbsent(t.date, () => []).add(t);
    }
    final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: dates.length,
      itemBuilder: (context, i) {
        final date = dates[i];
        final items = groups[date]!;
        final dayTotals = items.fold<({int exp, int inc})>(
          (exp: 0, inc: 0),
          (acc, t) => t.isExpense
              ? (exp: acc.exp + t.amount, inc: acc.inc)
              : (exp: acc.exp, inc: acc.inc + t.amount),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dayHeader(context, date, dayTotals),
            for (final t in items) _txRow(context, t),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }

  Widget _dayHeader(BuildContext context, String date, ({int exp, int inc}) totals) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    final d = parseDateKey(date);
    final label = _dayLabel(context, d);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: t.colorScheme.primaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${d.day}',
                    style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800, color: t.colorScheme.onPrimaryContainer)),
                Text(monthShort(d.month, strings.lang),
                    style: t.textTheme.labelSmall?.copyWith(
                        color: t.colorScheme.onPrimaryContainer, fontSize: 9)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label.toUpperCase(),
                style: t.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700, color: t.colorScheme.onSurface)),
          ),
          if (totals.inc > 0)
            Text('+${formatDA(totals.inc)} ',
                style: TextStyle(
                    color: AppColors.incomeOn(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          if (totals.exp > 0)
            Text('-${formatDA(totals.exp)}',
                style: TextStyle(
                    color: AppColors.expenseOn(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _dayLabel(BuildContext context, DateTime d) {
    final strings = context.watch<AppState>().strings;
    final now = DateTime.now();
    if (dateKey(d) == dateKey(now)) {
      return strings.lang == 'ar' ? 'اليوم' : strings.lang == 'fr' ? "Aujourd'hui" : 'Today';
    }
    return '${weekdayName(d.weekday, strings.lang)} ${d.day} ${monthName(d.month, strings.lang)}';
  }

  Widget _txRow(BuildContext context, AppTransaction t) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final cat = state.categoryById(t.categoryId);
    final color = t.isExpense ? AppColors.expenseOn(context) : AppColors.incomeOn(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconFor(cat?.icon ?? 'more_horiz'), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      cat == null ? strings.tr('other') : strings.categoryName(cat.name),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (t.note != null && t.note!.isNotEmpty)
                    Text(t.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  if (t.paymentMethod.isNotEmpty && t.paymentMethod != 'cash')
                    Text(strings.tr(t.paymentMethod),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.8))),
                ],
              ),
            ),
            Text('${t.isExpense ? '- ' : '+ '}${formatDA(t.amount)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
            PopupMenuButton<String>(
              onSelected: (v) => _action(context, t, v),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(strings.tr('edit'))),
                PopupMenuItem(value: 'duplicate', child: Text(strings.tr('duplicate'))),
                PopupMenuItem(value: 'delete', child: Text(strings.tr('delete'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _action(BuildContext context, AppTransaction t, String v) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    switch (v) {
      case 'edit':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => AddEditScreen(type: t.type, editing: t)));
      case 'duplicate':
        await state.duplicateTransaction(t);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(strings.tr('confirm')),
            content: Text(strings.tr('confirm_delete')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.tr('cancel'))),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true), child: Text(strings.tr('delete'))),
            ],
          ),
        );
        if (ok == true) await state.deleteTransaction(t);
    }
  }
}

/// Search screen with filters + sort.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  String? _type;
  int? _categoryId;
  String? _payment;
  DateTime? _from;
  DateTime? _to;
  String _sort = 'newest';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<AppTransaction> _filtered(BuildContext context) {
    final state = context.read<AppState>();
    final q = _queryCtrl.text.trim().toLowerCase();
    final qAmount = parseAmount(_queryCtrl.text);
    final list = state.transactions.where((t) {
      if (_type != null && t.type != _type) return false;
      if (_categoryId != null && t.categoryId != _categoryId) return false;
      if (_payment != null && t.paymentMethod != _payment) return false;
      if (_from != null && t.date.compareTo(dateKey(_from!)) < 0) return false;
      if (_to != null && t.date.compareTo(dateKey(_to!)) > 0) return false;
      if (q.isNotEmpty) {
        final cat = state.categoryById(t.categoryId);
        final catName = cat == null ? '' : state.strings.categoryName(cat.name).toLowerCase();
        final inCat = catName.contains(q);
        final inNote = (t.note ?? '').toLowerCase().contains(q);
        final inAmount = qAmount != null && t.amount == qAmount;
        if (!inCat && !inNote && !inAmount) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case 'oldest':
        list.sort((a, b) => a.date.compareTo(b.date));
      case 'high':
        list.sort((a, b) => b.amount.compareTo(a.amount));
      case 'low':
        list.sort((a, b) => a.amount.compareTo(b.amount));
      default:
        list.sort((a, b) => b.date.compareTo(a.date));
    }
    return list;
  }

  Future<void> _pickDate({required bool from}) async {
    final state = context.read<AppState>();
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? (_from ?? DateTime(DateTime.now().year - 1)) : (_to ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: Locale(state.strings.lang),
    );
    if (picked != null) {
      setState(() => from ? _from = picked : _to = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final results = _filtered(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('search')),
        actions: [
          IconButton(
            tooltip: strings.tr('export_excel'),
            icon: const Icon(Icons.table_view_rounded),
            onPressed: results.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final path =
                          await exportExcel(state, transactions: results);
                      messenger.showSnackBar(SnackBar(
                          content: Text('${strings.tr('exported_to')} $path')));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _queryCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: strings.tr('search_hint'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _queryCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _queryCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: Text(strings.tr('all')),
                    selected: _type == null,
                    onSelected: (_) => setState(() => _type = null),
                  ),
                  FilterChip(
                    label: Text(strings.tr('income')),
                    selected: _type == TxType.income,
                    onSelected: (_) => setState(() => _type = _type == TxType.income ? null : TxType.income),
                  ),
                  FilterChip(
                    label: Text(strings.tr('expense')),
                    selected: _type == TxType.expense,
                    onSelected: (_) => setState(() => _type = _type == TxType.expense ? null : TxType.expense),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _dropdown<int?>(
                      context,
                      value: _categoryId,
                      hint: strings.tr('category'),
                      items: [
                        DropdownMenuItem(value: null, child: Text(strings.tr('all'))),
                        for (final c in state.categories)
                          DropdownMenuItem(value: c.id, child: Text(strings.categoryName(c.name))),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dropdown<String?>(
                      context,
                      value: _payment,
                      hint: strings.tr('payment_method'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        for (final m in PaymentMethods.all)
                          DropdownMenuItem(value: m, child: Text(strings.tr(m))),
                      ],
                      onChanged: (v) => setState(() => _payment = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(from: true),
                      icon: const Icon(Icons.start_rounded, size: 16),
                      label: Text(_from == null ? '${strings.tr('from')} ?' : dateKey(_from!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(from: false),
                      icon: const Icon(Icons.stop_rounded, size: 16),
                      label: Text(_to == null ? '${strings.tr('to')} ?' : dateKey(_to!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: strings.tr('sort'),
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'newest', child: Text(strings.tr('sort_newest'))),
                      PopupMenuItem(value: 'oldest', child: Text(strings.tr('sort_oldest'))),
                      PopupMenuItem(value: 'high', child: Text(strings.tr('sort_high'))),
                      PopupMenuItem(value: 'low', child: Text(strings.tr('sort_low'))),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.sort_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down_rounded, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${results.length} ${strings.tr('transactions_count').replaceAll('{n}', '')}',
                    style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: results.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: strings.tr('search'),
                      subtitle: strings.tr('filters'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final tx = results[i];
                        final cat = state.categoryById(tx.categoryId);
                        final color = tx.isExpense ? AppColors.expenseOn(context) : AppColors.incomeOn(context);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SectionCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(iconFor(cat?.icon ?? 'more_horiz'), color: color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          cat == null ? strings.tr('other') : strings.categoryName(cat.name),
                                          style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                      Text(
                                        [tx.date, if (tx.note?.isNotEmpty ?? false) tx.note]
                                            .whereType<String>()
                                            .join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.textTheme.labelSmall
                                            ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Text('${tx.isExpense ? '- ' : '+ '}${formatDA(tx.amount)}',
                                    style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>(BuildContext context,
      {required T value, required String hint, required List<DropdownMenuItem<T>> items, required ValueChanged<T> onChanged}) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}