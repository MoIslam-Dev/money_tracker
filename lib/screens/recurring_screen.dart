import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/money.dart';
import '../widgets/category_picker.dart';
import '../widgets/icons.dart';
import '../widgets/widgets.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.tr('recurring'))),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => state.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _committedCard(context),
              const SizedBox(height: 18),
              if (state.recurring.isEmpty)
                EmptyState(
                  icon: Icons.repeat_rounded,
                  title: strings.tr('recurring_transactions'),
                  subtitle: strings.tr('empty_transactions_sub'),
                )
              else
                for (final r in state.recurring)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _recurringCard(context, r),
                  ),
              const SizedBox(height: 12),
              BigButton(
                label: strings.tr('add_recurring'),
                icon: Icons.add_rounded,
                onPressed: () => _openEditor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _committedCard(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.tr('committed_monthly'),
              style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text('${formatDA(state.committedMonthly)} / ${strings.tr('per_month')}',
              style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.skyOn(context))),
        ],
      ),
    );
  }

  Widget _recurringCard(BuildContext context, RecurringTxn r) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cat = state.categoryById(r.categoryId);
    final color = r.isExpense ? AppColors.expenseOn(context) : AppColors.incomeOn(context);
    final next = r.isActive ? r.nextOccurrenceAfter(DateTime.now()) : null;

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        cat == null
                            ? strings.tr('other')
                            : '${strings.categoryName(cat.name)} · ${strings.tr(r.frequency)}',
                        style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      '${strings.tr(r.frequency)} · ${strings.tr('next_occurrence')}: ${next == null ? '—' : dateKey(next)}',
                      style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text('${r.isExpense ? '- ' : '+ '}${formatDA(r.amount)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              PopupMenuButton<String>(
                onSelected: (v) => _action(context, r, v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'log', child: Text(strings.tr('record_today'))),
                  PopupMenuItem(value: 'edit', child: Text(strings.tr('edit'))),
                  PopupMenuItem(value: 'delete', child: Text(strings.tr('delete'))),
                ],
              ),
            ],
          ),
          if (r.note != null && r.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.note!, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  void _action(BuildContext context, RecurringTxn r, String v) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    switch (v) {
      case 'log':
        await state.addTransaction(
          type: r.type,
          amount: r.amount,
          categoryId: r.categoryId,
          paymentMethod: r.paymentMethod,
          date: DateTime.now(),
          note: r.note,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.tr('transaction_saved'))),
          );
        }
      case 'edit':
        _openEditor(context, r);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(strings.tr('confirm')),
            content: Text(strings.tr('confirm_delete')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.tr('cancel'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.tr('delete'))),
            ],
          ),
        );
        if (ok == true) await state.removeRecurring(r);
    }
  }

  Future<void> _openEditor(BuildContext context, [RecurringTxn? editing]) async {
    final state = context.read<AppState>();
    final strings = state.strings;

    final amountCtrl = TextEditingController(text: editing == null ? '' : '${editing.amount}');
    final noteCtrl = TextEditingController(text: editing?.note ?? '');
    var type = editing?.type ?? TxType.expense;
    String frequency = editing?.frequency ?? 'monthly';
    var categoryId = editing?.categoryId;
    DateTime start = editing == null ? DateTime.now() : parseDateKey(editing.startDate);
    DateTime? end = editing?.endDate == null ? null : parseDateKey(editing!.endDate!);
    String payment = editing?.paymentMethod ?? 'cash';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final t = Theme.of(ctx);
          return AlertDialog(
            title: Text(editing == null ? strings.tr('add_recurring') : strings.tr('edit_recurring')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: TxType.expense, label: Text(strings.tr('expense'))),
                      ButtonSegment(value: TxType.income, label: Text(strings.tr('income'))),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) {
                      setState(() {
                        type = s.first;
                        final okCat = categoryId != null && state.categoryById(categoryId)?.type == type;
                        if (!okCat) categoryId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: strings.tr('amount'), prefixText: 'DA ')),
                  const SizedBox(height: 12),
                  Text(strings.tr('category'), style: t.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: CategoryPicker(
                      type: type,
                      selectedId: categoryId,
                      onSelected: (id) => setState(() => categoryId = id),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(strings.tr('frequency'), style: t.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in ['daily', 'weekly', 'monthly', 'yearly'])
                        ChoiceChip(
                          label: Text(strings.tr(f)),
                          selected: frequency == f,
                          onSelected: (_) => setState(() => frequency = f),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: start,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        locale: Locale(state.strings.lang),
                      );
                      if (p != null) setState(() => start = p);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: strings.tr('start_date'),
                        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                      child: Text(dateKey(start)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: end ?? DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        locale: Locale(state.strings.lang),
                      );
                      if (p != null) setState(() => end = p);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: strings.tr('end_date'),
                        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                      child: Text(end == null ? strings.tr('never') : dateKey(end!)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PaymentChips(selected: payment, onChanged: (m) => setState(() => payment = m)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(labelText: strings.tr('note'))),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(strings.tr('cancel'))),
              FilledButton(
                onPressed: () async {
                  final amount = parseAmount(amountCtrl.text);
                  final cid = categoryId ?? state.categoriesFor(type).firstOrNull?.id;
                  if (amount == null || cid == null) return;
                  await state.saveRecurring(
                    id: editing?.id,
                    type: type,
                    amount: amount,
                    categoryId: cid,
                    frequency: frequency,
                    start: start,
                    end: end,
                    paymentMethod: payment,
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    isActive: editing?.isActive ?? true,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(strings.tr('saveexp')),
              ),
            ],
          );
        },
      ),
    );
  }
}