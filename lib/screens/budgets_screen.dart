import 'package:flutter/material.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/money.dart';
import '../widgets/icons.dart';
import '../widgets/widgets.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final month = state.currentMonth;

    return Scaffold(
      appBar: AppBar(title: Text(strings.tr('budgets'))),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => state.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              MonthSelector(
                month: month,
                label: '${monthName(month.month, strings.lang)} ${month.year}',
                onPrev:
                    () => state.setCurrentMonth(
                      DateTime(month.year, month.month - 1),
                    ),
                onNext:
                    () => state.setCurrentMonth(
                      DateTime(month.year, month.month + 1),
                    ),
              ),
              const SizedBox(height: 16),
              _budgetSummary(context),
              const SizedBox(height: 16),
              _budgetList(context),
              const SizedBox(height: 20),
              BigButton(
                label: strings.tr('add_budget'),
                icon: Icons.add_rounded,
                onPressed: () => _openEditor(context),
              ),
              const SizedBox(height: 30),
              if (state.committedMonthly > 0)
                Text(
                  '${strings.tr('committed_monthly')}: ${state.money(state.committedMonthly)} / ${strings.tr('per_month')}',
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _budgetSummary(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final month = state.currentMonth;
    final valid =
        state.budgets
            .where((b) => b.month == month.month && b.year == month.year)
            .toList();
    var totalBudget = 0;
    var totalSpent = 0;
    for (final b in valid) {
      if (b.currency != state.currency) continue;
      totalBudget += b.amount;
      totalSpent += state.categorySpentInMonth(b.categoryId, month);
    }
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.tr('budget_total'),
            style: t.textTheme.labelMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.money(totalBudget),
            style: t.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value:
                        totalBudget == 0
                            ? 0
                            : (totalSpent / totalBudget).clamp(0, 1),
                    minHeight: 10,
                    backgroundColor: t.colorScheme.surfaceContainerHighest,
                    color:
                        totalBudget > 0 && totalSpent >= totalBudget
                            ? AppColors.expenseOn(context)
                            : t.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${totalBudget == 0 ? 0 : (totalSpent / totalBudget * 100).toStringAsFixed(0)}%',
                style: t.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${strings.tr('spent')}: ${state.money(totalSpent)}',
            style: t.textTheme.labelSmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetList(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final month = state.currentMonth;
    final list =
        state.budgets
            .where((b) => b.month == month.month && b.year == month.year)
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.track_changes_outlined,
        title: strings.tr('month_budget'),
        subtitle: strings.tr('empty_transactions_sub'),
      );
    }

    return Column(
      children: [
        for (final b in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _budgetCard(context, b),
          ),
      ],
    );
  }

  Widget _budgetCard(BuildContext context, Budget b) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cat = state.categoryById(b.categoryId);
    final spent = state.categorySpentInMonth(
      b.categoryId,
      state.currentMonth,
      currency: b.currency,
    );
    final pct = b.amount == 0 ? 0.0 : spent / b.amount * 100;
    final remaining = b.amount - spent;
    final color =
        pct >= 100
            ? AppColors.expenseOn(context)
            : pct >= 80
            ? AppColors.amberOn(context)
            : t.colorScheme.primary;

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconFor(cat?.icon ?? 'more_horiz'),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat == null
                          ? strings.tr('other')
                          : state.categoryLabel(cat),
                      style: t.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${strings.tr('budget')}: ${state.moneyFor(b.amount, b.currency)}',
                      style: t.textTheme.labelSmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected:
                    (v) =>
                        v == 'edit'
                            ? _openEditor(context, b)
                            : _delete(context, b),
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(strings.tr('edit')),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(strings.tr('delete')),
                      ),
                    ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: LevelBar(value: pct / 100, color: color)),
              const SizedBox(width: 12),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${strings.tr('spent')}: ${state.moneyFor(spent, b.currency)}',
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                pct >= 100
                    ? '${strings.tr('over_budget')} ${state.moneyFor(-remaining, b.currency)}'
                    : '${strings.tr('remaining')}: ${state.moneyFor(remaining, b.currency)}',
                style: TextStyle(
                  color:
                      pct >= 100
                          ? AppColors.expenseOn(context)
                          : AppColors.incomeOn(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, [Budget? editing]) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final amountCtrl = TextEditingController(
      text: editing == null ? '' : '${editing.amount}',
    );
    var categoryId = editing?.categoryId;
    await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setState) {
              final t = Theme.of(ctx);
              final cats = state.categoriesFor(TxType.expense);
              return AlertDialog(
                title: Text(
                  editing == null
                      ? strings.tr('add_budget')
                      : strings.tr('edit_budget'),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.tr('budget_amount'),
                        style: t.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText:
                              '${state.currencyDefinition(editing?.currency ?? state.currency).symbol} ',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (cats.isEmpty)
                        Text(
                          strings.tr('no_income'),
                          style: t.textTheme.bodySmall,
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in cats)
                              ChoiceChip(
                                label: Text(state.categoryLabel(c)),
                                selected: categoryId == c.id,
                                onSelected:
                                    (_) => setState(() => categoryId = c.id),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(strings.tr('cancel')),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final amount = parseAmount(amountCtrl.text);
                      if (amount == null || categoryId == null) return;
                      await state.saveBudget(
                        id: editing?.id,
                        categoryId: categoryId!,
                        amount: amount,
                        currency: editing?.currency,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
                    child: Text(strings.tr('saveexp')),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _delete(BuildContext context, Budget b) async {
    final strings = context.watch<AppState>().strings;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(strings.tr('confirm')),
            content: Text(strings.tr('confirm_delete')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(strings.tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(strings.tr('delete')),
              ),
            ],
          ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().deleteBudget(b);
    }
  }
}
