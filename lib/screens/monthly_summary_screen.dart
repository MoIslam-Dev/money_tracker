import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/money.dart';
import '../widgets/icons.dart';
import '../widgets/widgets.dart';

/// Real month-by-month summary: totals, savings rate, comparison with the
/// previous month and the month's top expense categories.
class MonthlySummaryScreen extends StatelessWidget {
  const MonthlySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final month = state.currentMonth;
    final (income, expense) = state.monthTotals(month);
    final remaining = income - expense;
    final rate = state.savingsRate(month);
    final count = state.countInMonth(month);
    final prev = DateTime(month.year, month.month - 1);
    final (prevInc, prevExp) = state.monthTotals(prev);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.tr('monthly_summary'),
          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => state.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _monthNav(context),
              const SizedBox(height: 16),
              _summaryCard(
                context,
                month,
                income,
                expense,
                remaining,
                rate,
                count,
              ),
              const SizedBox(height: 16),
              if (count > 0) ...[
                _vsLastCard(context, income, expense, remaining, prevInc,
                    prevExp),
                const SizedBox(height: 16),
                _categoriesCard(context, month),
              ] else
                _emptyCard(context, month),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthNav(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final month = state.currentMonth;
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    return Column(
      children: [
        MonthSelector(
          month: month,
          label: '${monthName(month.month, strings.lang)} ${month.year}',
          onPrev: () =>
              state.setCurrentMonth(DateTime(month.year, month.month - 1)),
          onNext: () =>
              state.setCurrentMonth(DateTime(month.year, month.month + 1)),
        ),
        if (!isCurrent)
          TextButton.icon(
            onPressed: () => state.setCurrentMonth(DateTime.now()),
            icon: const Icon(Icons.today_rounded, size: 18),
            label: Text(strings.tr('today')),
          ),
      ],
    );
  }

  Widget _summaryCard(
    BuildContext context,
    DateTime month,
    int income,
    int expense,
    int remaining,
    double rate,
    int count,
  ) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.balanceGradient(cs),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: isDark ? 0.35 : 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.tr('remaining').toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${remaining < 0 ? '-' : remaining > 0 ? '+' : ''}${state.money(remaining.abs())}',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: AppColors.gold.withValues(alpha: 0.3)),
          const SizedBox(height: 14),
          Row(
            children: [
              _whiteStat(
                context,
                strings.tr('money_in'),
                '${income > 0 ? '+' : ''}${state.money(income)}',
                const Color(0xFF8CE99A),
              ),
              _whiteStat(
                context,
                strings.tr('money_out'),
                '${expense > 0 ? '-' : ''}${state.money(expense)}',
                const Color(0xFFFFA8A8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _whiteStat(
                context,
                strings.tr('savings_rate'),
                '${rate.toStringAsFixed(1)}%',
                const Color(0xFF85DAFF),
              ),
              _whiteStat(
                context,
                strings.tr('transactions'),
                '$count',
                AppColors.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _whiteStat(BuildContext context, String label, String value, Color c) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: c,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vsLastCard(
    BuildContext context,
    int income,
    int expense,
    int remaining,
    int prevInc,
    int prevExp,
  ) {
    final strings = context.watch<AppState>().strings;
    if (prevInc == 0 && prevExp == 0) {
      return SectionCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          strings.tr('no_prev_month'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final prevRemaining = prevInc - prevExp;
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.tr('vs_last').toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          _vsRow(context, strings.tr('money_in'), income, prevInc,
              goodWhenPositive: true),
          const SizedBox(height: 10),
          _vsRow(context, strings.tr('money_out'), expense, prevExp,
              goodWhenPositive: false),
          const SizedBox(height: 10),
          _vsRow(context, strings.tr('remaining'), remaining, prevRemaining,
              goodWhenPositive: true),
        ],
      ),
    );
  }

  Widget _vsRow(
    BuildContext context,
    String label,
    int current,
    int prev,
    {required bool goodWhenPositive,
  }) {
    final state = context.watch<AppState>();
    final t = Theme.of(context);
    final delta = current - prev;
    final good = goodWhenPositive
        ? delta >= 0
        : delta <= 0;
    final color = delta == 0
        ? t.colorScheme.onSurfaceVariant
        : good
        ? AppColors.incomeOn(context)
        : AppColors.expenseOn(context);
    final deltaText = delta == 0
        ? '0'
        : '${delta > 0 ? '+' : '-'}${state.money(delta.abs())}';
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: t.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          state.money(current),
          style: t.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          state.money(prev),
          style: t.textTheme.bodySmall?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            deltaText,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoriesCard(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final totals =
        state.categoryTotalsInMonth(month).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    if (totals.isEmpty) {
      return SectionCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          strings.tr('no_data_for_month'),
          style: t.textTheme.bodyMedium?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final total = totals.fold<int>(0, (a, e) => a + e.value);
    final top = totals.take(5).toList();
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.tr('top_categories'),
            style: t.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _categoryRow(context, i, top[i], total),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(
    BuildContext context,
    int i,
    MapEntry<int, int> e,
    int total,
  ) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cat = state.categoryById(e.key);
    final color = chartColors[i % chartColors.length];
    final pct = total == 0 ? 0.0 : e.value / total * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                iconFor(cat?.icon ?? 'more_horiz'),
                size: 17,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${i + 1}. ${cat == null ? strings.tr('other') : state.categoryLabel(cat)}',
                style: t.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              state.money(e.value),
              style: t.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LevelBar(value: pct / 100, color: color),
      ],
    );
  }

  Widget _emptyCard(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 30,
            color: t.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            strings.tr('no_data_for_month'),
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${strings.tr('add_income')} · ${strings.tr('add_expense')}',
            textAlign: TextAlign.center,
            style: t.textTheme.labelSmall?.copyWith(
              color: t.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}