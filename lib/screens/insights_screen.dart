import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
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

  var expCount = 0, expSum = 0, maxExp = -1;
  AppTransaction? maxTx;
  for (final t in state.transactions) {
    if (t.currency != state.currency) continue;
    final d = parseDateKey(t.date);
    if (d.year != month.year || d.month != month.month) continue;
    if (!t.isExpense) continue;
    expCount++;
    expSum += t.amount;
    if (t.amount > maxExp) {
      maxExp = t.amount;
      maxTx = t;
    }
  }

  final catTotals = state.categoryTotalsInMonth(month);
  if (catTotals.isNotEmpty) {
    final top = catTotals.entries.reduce((a, b) => b.value > a.value ? b : a);
    final topCat = state.categoryById(top.key);
    final topLabel =
        topCat == null ? strings.tr('other') : state.categoryLabel(topCat);
    out.add(
      strings.tr('largest_category').replaceAll('{c}', topLabel),
    );
    if (expSum > 0 && top.value / expSum >= 0.3) {
      out.add(
        strings
            .tr('top_category_share')
            .replaceAll('{c}', topLabel)
            .replaceAll('{p}', (top.value / expSum * 100).toStringAsFixed(0)),
      );
    }
  }

  _spendSpike(state, strings, month, catTotals, out);

  final monday = now.subtract(Duration(days: now.weekday - 1));
  final weekTotals = <int, int>{};
  for (final t in state.transactions) {
    if (!t.isExpense || t.categoryId == null) continue;
    if (t.currency != state.currency) continue;
    if (t.date.compareTo(dateKey(monday)) >= 0 &&
        t.date.compareTo(dateKey(now)) <= 0) {
      weekTotals[t.categoryId!] = (weekTotals[t.categoryId!] ?? 0) + t.amount;
    }
  }
  if (weekTotals.isNotEmpty) {
    final top = weekTotals.entries.reduce((a, b) => b.value > a.value ? b : a);
    final topCat = state.categoryById(top.key);
    if (topCat != null) {
      out.add(
        strings
            .tr('spent_x_week')
            .replaceAll('{a}', state.money(top.value))
            .replaceAll('{c}', state.categoryLabel(topCat)),
      );
    }
  }

  if (catTotals.isNotEmpty) {
    final first = catTotals.keys.first;
    final cat = state.categoryById(first);
    final n = state.categoryCountInMonth(first, month);
    if (cat != null && n > 0) {
      out.add(
        strings
            .tr('tx_x_month')
            .replaceAll('{n}', '$n')
            .replaceAll('{c}', state.categoryLabel(cat)),
      );
    }
  }

  final prev = DateTime(month.year, month.month - 1);
  final (prevInc, prevExp) = state.monthTotals(prev);
  if (prevInc > 0) {
    final dInc = inc - prevInc;
    out.add(
      strings
          .tr('income_vs_last')
          .replaceAll('{a}', state.money(dInc.abs()))
          .replaceAll(
            '{dir}',
            dInc >= 0 ? strings.tr('higher') : strings.tr('lower'),
          ),
    );
    final (_, exp) = state.monthTotals(month);
    final dExp = exp - prevExp;
    out.add(
      strings
          .tr('expense_vs_last')
          .replaceAll('{a}', state.money(dExp.abs()))
          .replaceAll(
            '{dir}',
            dExp >= 0 ? strings.tr('higher') : strings.tr('lower'),
          ),
    );
    if (inc > 0) {
      final curRate = state.savingsRate(month);
      final prevRate = state.savingsRate(prev);
      out.add(
        strings
            .tr('savings_rate_vs_last')
            .replaceAll('{r}', curRate.toStringAsFixed(1))
            .replaceAll('{p}', prevRate.toStringAsFixed(1))
            .replaceAll(
              '{dir}',
              curRate >= prevRate
                  ? strings.tr('higher')
                  : strings.tr('lower'),
            ),
      );
    }
  }

  if (expCount > 0) {
    out.add(
      strings
          .tr('avg_expense_tx')
          .replaceAll('{a}', state.money(expSum ~/ expCount))
          .replaceAll('{n}', '$expCount'),
    );
    if (maxTx != null) {
      final cat =
          maxTx.categoryId == null ? null : state.categoryById(maxTx.categoryId);
      out.add(
        strings
            .tr('largest_expense_month')
            .replaceAll('{a}', state.money(maxTx.amount))
            .replaceAll(
              '{c}',
              cat == null ? strings.tr('other') : state.categoryLabel(cat),
            ),
      );
    }
  }

  if (state.committedMonthly > 0) {
    out.add(
      strings
          .tr('committed_note')
          .replaceAll('{a}', state.money(state.committedMonthly)),
    );
  }

  return out;
}

/// Flags a category whose spending this month is well above its average of
/// the previous three months (a "spend spike" worth reviewing).
void _spendSpike(
  AppState state,
  AppStrings strings,
  DateTime month,
  Map<int, int> catTotals,
  List<String> out,
) {
  for (final entry in catTotals.entries) {
    final cur = entry.value;
    if (cur <= 0) continue;
    var prevSum = 0;
    var prevMonths = 0;
    for (var k = 1; k <= 3; k++) {
      final d = DateTime(month.year, month.month - k);
      final m = state.categoryTotalsInMonth(d)[entry.key] ?? 0;
      if (m > 0) {
        prevSum += m;
        prevMonths++;
      }
    }
    if (prevMonths < 2 || prevSum <= 0) continue;
    final prevAvg = prevSum / prevMonths;
    if (cur < prevAvg * 1.5) continue;
    final cat = state.categoryById(entry.key);
    final label =
        cat == null ? strings.tr('other') : state.categoryLabel(cat);
    out.add(
      strings
          .tr('spike_category')
          .replaceAll('{c}', label)
          .replaceAll(
            '{p}',
            ((cur / prevAvg - 1) * 100).toStringAsFixed(0),
          ),
    );
  }
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
    final colors =
        AppColors.isDark(context)
            ? const [
              AppColors.amberDark,
              AppColors.skyDark,
              AppColors.violetDark,
            ]
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
            child: Text(
              text,
              style: t.textTheme.bodyMedium?.copyWith(
                color:
                    t.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
