import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/money.dart';
import '../widgets/widgets.dart';

/// Build data-driven insights (factual, non-judgmental).
List<String> buildInsights(BuildContext context) {
  final state = context.read<AppState>();
  final strings = state.strings;
  final now = DateTime.now();
  final month = state.currentMonth;
  final out = <String>[];

  final (inc, _) = state.monthTotals(month);

  final catTotals = state.categoryTotalsInMonth(month);
  if (catTotals.isNotEmpty) {
    final top = catTotals.entries.reduce((a, b) => b.value > a.value ? b : a);
    final topCat = state.categoryById(top.key);
    out.add(strings.tr('largest_category').replaceAll(
        '{c}', topCat == null ? strings.tr('other') : strings.categoryName(topCat.name)));
  }

  final monday = now.subtract(Duration(days: now.weekday - 1));
  final weekTotals = <int, int>{};
  for (final t in state.transactions) {
    if (!t.isExpense || t.categoryId == null) continue;
    if (t.date.compareTo(dateKey(monday)) >= 0 && t.date.compareTo(dateKey(now)) <= 0) {
      weekTotals[t.categoryId!] = (weekTotals[t.categoryId!] ?? 0) + t.amount;
    }
  }
  if (weekTotals.isNotEmpty) {
    final top = weekTotals.entries.reduce((a, b) => b.value > a.value ? b : a);
    final topCat = state.categoryById(top.key);
    if (topCat != null) {
      out.add(strings.tr('spent_x_week')
          .replaceAll('{a}', formatDA(top.value))
          .replaceAll('{c}', strings.categoryName(topCat.name)));
    }
  }

  if (catTotals.isNotEmpty) {
    final first = catTotals.keys.first;
    final cat = state.categoryById(first);
    final n = state.categoryCountInMonth(first, month);
    if (cat != null && n > 0) {
      out.add(strings.tr('tx_x_month')
          .replaceAll('{n}', '$n')
          .replaceAll('{c}', strings.categoryName(cat.name)));
    }
  }

  final prev = DateTime(month.year, month.month - 1);
  final (prevInc, prevExp) = state.monthTotals(prev);
  if (prevInc > 0) {
    final dInc = inc - prevInc;
    out.add(strings.tr('income_vs_last')
        .replaceAll('{a}', formatDA(dInc.abs()))
        .replaceAll('{dir}', dInc >= 0 ? strings.tr('higher') : strings.tr('lower')));
    final (_, exp) = state.monthTotals(month);
    final dExp = exp - prevExp;
    out.add(strings.tr('expense_vs_last')
        .replaceAll('{a}', formatDA(dExp.abs()))
        .replaceAll('{dir}', dExp >= 0 ? strings.tr('higher') : strings.tr('lower')));
  }

  if (state.committedMonthly > 0) {
    out.add(strings.tr('committed_note').replaceAll('{a}', formatDA(state.committedMonthly)));
  }

  return out;
}

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final insights = buildInsights(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.tr('insights'))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            if (insights.isEmpty)
              EmptyState(
                icon: Icons.lightbulb_outline_rounded,
                title: strings.tr('no_income'),
                subtitle: strings.tr('empty_transactions_sub'),
              )
            else
              for (final (i, text) in insights.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _insightCard(context, i, text),
                ),
          ],
        ),
      ),
    );
  }

  Widget _insightCard(BuildContext context, int i, String text) {
    final t = Theme.of(context);
    final colors = AppColors.isDark(context)
        ? const [AppColors.amberDark, AppColors.skyDark, AppColors.violetDark]
        : const [AppColors.amber, AppColors.sky, AppColors.violet];
    final color = colors[i % colors.length];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_rounded, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: t.textTheme.bodyMedium?.copyWith(
                    color: t.brightness == Brightness.dark ? Colors.white : Colors.black87)),
          ),
        ],
      ),
    );
  }
}