import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/money.dart';
import '../widgets/icons.dart';
import '../widgets/widgets.dart';
import 'budgets_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _range = '30d';
  int? _excludedCategory;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final month = state.currentMonth;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.tr('statistics'),
          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => state.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _monthBar(context, month),
              const SizedBox(height: 16),
              _summaryCard(context, month),
              const SizedBox(height: 20),
              _budgetCard(context, month),
              const SizedBox(height: 20),
              _donut(context, month),
              const SizedBox(height: 12),
              _categoryList(context, month),
              const SizedBox(height: 24),
              _excludeCard(context, month),
              const SizedBox(height: 24),
              _trendChart(context),
              const SizedBox(height: 24),
              _compareCard(context),
              const SizedBox(height: 24),
              _cashflowCard(context),
              const SizedBox(height: 24),
              _weekdayCard(context),
              const SizedBox(height: 24),
              _paceCard(context, month),
              const SizedBox(height: 24),
              _biggestMoves(context, month),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthBar(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    return MonthSelector(
      month: month,
      label: '${monthName(month.month, strings.lang)} ${month.year}',
      onPrev:
          () => state.setCurrentMonth(DateTime(month.year, month.month - 1)),
      onNext:
          () => state.setCurrentMonth(DateTime(month.year, month.month + 1)),
    );
  }

  Widget _summaryCard(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final (inc, exp) = state.monthTotals(month);
    final rate = state.savingsRate(month);
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            context,
            strings.tr('monthly_summary'),
            'stats_monthly_summary',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  context,
                  strings.tr('income'),
                  state.money(inc),
                  AppColors.incomeOn(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  context,
                  strings.tr('expenses'),
                  state.money(exp),
                  AppColors.expenseOn(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  context,
                  strings.tr('saved'),
                  state.money(inc - exp),
                  t.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (rate / 100).clamp(0, 1),
                    minHeight: 10,
                    backgroundColor: t.colorScheme.surfaceContainerHighest,
                    color: AppColors.incomeOn(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${strings.tr('savings_rate')} · ${state.countInMonth(month)} ${strings.tr('transactions')}',
              style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: t.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetCard(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final list =
        state.budgets
            .where(
              (b) =>
                  b.month == month.month &&
                  b.year == month.year &&
                  b.currency == state.currency,
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    if (list.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, strings.tr('budgets'), 'stats_budgets'),
          const SizedBox(height: 12),
          for (final b in list) ...[
            _budgetRow(context, b, month),
            if (b != list.last) const SizedBox(height: 12),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BudgetsScreen(),
                    ),
                  ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(strings.tr('budgets')),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetRow(BuildContext context, Budget budget, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cat = state.categoryById(budget.categoryId);
    final spent = state.categorySpentInMonth(budget.categoryId, month);
    final pct = budget.amount == 0 ? 0.0 : spent / budget.amount * 100;
    final color =
        pct >= 100
            ? AppColors.expenseOn(context)
            : pct >= 80
            ? AppColors.amberOn(context)
            : t.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                cat == null ? strings.tr('other') : state.categoryLabel(cat),
                style: t.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: t.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LevelBar(value: (pct / 100).clamp(0.0, 1.0), color: color),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '${strings.tr('spent')}: ${state.money(spent)}',
                style: t.textTheme.labelSmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '${strings.tr('budget')}: ${state.money(budget.amount)}',
              style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cardTitle(BuildContext context, String title, String helpKey) {
    final t = Theme.of(context);
    final strings = context.watch<AppState>().strings;
    return Row(
      children: [
        _infoIcon(context, strings.tr(helpKey)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: t.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoIcon(BuildContext context, String help) {
    final t = Theme.of(context);
    final strings = context.watch<AppState>().strings;
    return Tooltip(
      message: strings.tr('more_info'),
      child: InkWell(
        onTap: () => _showHelp(context, help),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.priority_high_rounded,
            size: 14,
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context, String help) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final t = Theme.of(dialogContext);
        final strings = context.watch<AppState>().strings;
        return AlertDialog(
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.priority_high_rounded,
                  size: 16,
                  color: t.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.tr('more_info'),
                  style: t.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            help,
            style: t.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.tr('ok')),
            ),
          ],
        );
      },
    );
  }

  Widget _donut(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final totals = state.categoryTotalsInMonth(month);
    final used =
        totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final slices = <(String, int, Color)>[];
    var colorIdx = 0;
    for (final e in used) {
      final cat = state.categoryById(e.key);
      slices.add((
        cat == null ? strings.tr('other') : state.categoryLabel(cat),
        e.value,
        chartColors[colorIdx++ % chartColors.length],
      ));
    }
    if (slices.isEmpty) {
      return SectionCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(
            strings.tr('no_data_chart'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            context,
            strings.tr('spending_by_category'),
            'stats_spending_by_category',
          ),
          const SizedBox(height: 12),
          DonutChart(slices: slices),
        ],
      ),
    );
  }

  Widget _categoryList(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final totals =
        state.categoryTotalsInMonth(month).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final total = totals.fold<int>(0, (a, e) => a + e.value);

    if (totals.isEmpty) {
      return Text(
        strings.tr('no_data_chart'),
        style: t.textTheme.bodyMedium?.copyWith(
          color: t.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: _cardTitle(
              context,
              strings.tr('where_money_go'),
              'stats_where_money_go',
            ),
          ),
          for (var i = 0; i < totals.length; i++)
            InkWell(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => _CategoryTxScreen(
                            categoryId: totals[i].key,
                            month: month,
                          ),
                    ),
                  ),
              child: _categoryRow(context, i, totals[i], total),
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              iconFor(cat?.icon ?? 'more_horiz'),
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${cat == null ? strings.tr('other') : state.categoryLabel(cat)}',
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            state.money(e.value),
            style: t.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: t.colorScheme.outline),
        ],
      ),
    );
  }

  Widget _excludeCard(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final totals =
        state.categoryTotalsInMonth(month).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    if (totals.isEmpty) {
      return Text(
        strings.tr('no_data_chart'),
        style: t.textTheme.bodyMedium?.copyWith(
          color: t.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final exId = _excludedCategory != null &&
            totals.any((e) => e.key == _excludedCategory)
        ? _excludedCategory
        : null;

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            context,
            strings.tr('exclude_card_title'),
            'stats_exclude',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in totals)
                Builder(
                  builder: (context) {
                    final cat = state.categoryById(e.key);
                    return ChoiceChip(
                      label: Text(
                        cat == null
                            ? strings.tr('other')
                            : state.categoryLabel(cat),
                      ),
                      selected: e.key == exId,
                      onSelected: (sel) => setState(
                        () => _excludedCategory = sel ? e.key : null,
                      ),
                    );
                  },
                ),
            ],
          ),
          if (exId != null) ...[
            const SizedBox(height: 16),
            _excludeResult(context, month, exId, totals),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              strings.tr('exclude_hint'),
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _excludeResult(
    BuildContext context,
    DateTime month,
    int exId,
    List<MapEntry<int, int>> totals,
  ) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cat = state.categoryById(exId);
    final name = cat == null ? strings.tr('other') : state.categoryLabel(cat);
    final added = totals.firstWhere((e) => e.key == exId).value;
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final n = state.transactions
        .where(
          (x) =>
              x.isExpense &&
              x.currency == state.currency &&
              x.categoryId == exId &&
              x.date.startsWith(prefix),
        )
        .length;
    final (inc, exp) = state.monthTotals(month);
    final oldSav = inc - exp;
    final newSav = oldSav + added;
    final oldRate = inc > 0 ? (oldSav < 0 ? 0.0 : oldSav / inc * 100) : null;
    final newRate = inc > 0 ? (newSav < 0 ? 0.0 : newSav / inc * 100) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.incomeOn(context).withValues(alpha: 0.16),
                t.colorScheme.primary.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.incomeOn(context).withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.tr('exclude_saved'),
                style: t.textTheme.labelSmall?.copyWith(
                  color: AppColors.incomeOn(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                state.money(added),
                style: t.textTheme.headlineMedium?.copyWith(
                  color: AppColors.incomeOn(context),
                  fontWeight: FontWeight.w800,
                  fontFamily: 'PlayfairDisplay',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _resultRow(
          context,
          strings.tr('expenses'),
          '${state.money(exp)} → ${state.money(exp - added)}',
        ),
        const SizedBox(height: 8),
        _resultRow(
          context,
          strings.tr('whatif_savings'),
          '${state.money(oldSav)} → ${state.money(newSav)}',
        ),
        if (newRate != null) ...[
          const SizedBox(height: 8),
          _resultRow(
            context,
            strings.tr('whatif_rate'),
            oldRate == null
                ? '— → ${newRate.toStringAsFixed(1)}%'
                : '${oldRate.toStringAsFixed(1)}% → ${newRate.toStringAsFixed(1)}%',
          ),
        ],
        const SizedBox(height: 10),
        Text(
          strings
              .tr('exclude_note')
              .replaceAll('{c}', name)
              .replaceAll('{n}', '$n'),
          style: t.textTheme.labelSmall?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _resultRow(BuildContext context, String label, String value) {
    final t = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _rangePill(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final options = {
      '7d': strings.tr('days7'),
      '30d': strings.tr('days30'),
      '3m': strings.tr('months3'),
      '6m': strings.tr('months6'),
      '1y': strings.tr('year1'),
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: _range == e.key,
            onSelected: (_) => setState(() => _range = e.key),
          ),
      ],
    );
  }

  Widget _trendChart(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final now = DateTime.now();

    final Widget chart;
    if (_range.contains('m') || _range == '1y') {
      final months =
          _range == '3m'
              ? 3
              : _range == '6m'
              ? 6
              : 12;
      final series = <(String, int, int)>[];
      for (var i = months - 1; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i);
        final (inc, exp) = state.monthTotals(m);
        series.add((
          '${m.year}-${m.month.toString().padLeft(2, '0')}',
          inc,
          exp,
        ));
      }
      chart = TrendBars(
        series: series,
        incomeColor: AppColors.incomeOn(context),
        expenseColor: AppColors.expenseOn(context),
      );
    } else {
      final days = _range == '7d' ? 7 : 30;
      chart = TrendBars(
        series: state.dailySeries(now.subtract(Duration(days: days - 1)), now),
        incomeColor: AppColors.incomeOn(context),
        expenseColor: AppColors.expenseOn(context),
      );
    }

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, strings.tr('trends'), 'stats_trends'),
          const SizedBox(height: 12),
          _rangePill(context),
          const SizedBox(height: 12),
          _legendDot(
            context,
            AppColors.incomeOn(context),
            strings.tr('income'),
          ),
          const SizedBox(height: 6),
          _legendDot(
            context,
            AppColors.expenseOn(context),
            strings.tr('expenses'),
          ),
          const SizedBox(height: 14),
          SizedBox(height: 200, child: chart),
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    final t = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: t.textTheme.labelMedium),
      ],
    );
  }

  Widget _compareCard(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final month = state.currentMonth;
    final prev = DateTime(month.year, month.month - 1);

    final active = (
      m: month,
      inc: state.monthTotals(month).$1,
      exp: state.monthTotals(month).$2,
    );
    final prevRow = (
      m: prev,
      inc: state.monthTotals(prev).$1,
      exp: state.monthTotals(prev).$2,
    );

    final trendRows = <({DateTime m, int inc, int exp})>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(DateTime.now().year, DateTime.now().month - i);
      final (inc, exp) = state.monthTotals(m);
      trendRows.add((m: m, inc: inc, exp: exp));
    }

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            context,
            strings.tr('compare_months'),
            'stats_compare_months',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _monthMini(context, active, isActive: true)),
              const SizedBox(width: 12),
              Expanded(child: _monthMini(context, prevRow)),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: t.dividerColor),
          const SizedBox(height: 12),
          _diffRow(context, active, prevRow),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: TrendLine(
              income: [for (final r in trendRows) (_monthKey(r.m), r.inc)],
              expense: [for (final r in trendRows) (_monthKey(r.m), r.exp)],
            ),
          ),
        ],
      ),
    );
  }

  String _monthKey(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  Widget _monthMini(
    BuildContext context,
    ({DateTime m, int inc, int exp}) r, {
    bool isActive = false,
  }) {
    final state = context.watch<AppState>();
    final strings2 = state.strings;
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isActive
                ? t.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : t.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${monthName(r.m.month, strings2.lang)} ${r.m.year}',
            style: t.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '↑ ${state.money(r.inc)}',
                  style: TextStyle(
                    color: AppColors.incomeOn(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '↓ ${state.money(r.exp)}',
                  style: TextStyle(
                    color: AppColors.expenseOn(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _diffRow(
    BuildContext context,
    ({DateTime m, int inc, int exp}) cur,
    ({DateTime m, int inc, int exp}) prev,
  ) {
    final strings = context.watch<AppState>().strings;
    final dInc = cur.inc - prev.inc;
    final dExp = cur.exp - prev.exp;
    return Column(
      children: [
        _diffLine(
          context,
          Icons.north_east_rounded,
          strings.tr('income'),
          dInc,
          AppColors.incomeOn(context),
        ),
        const SizedBox(height: 6),
        _diffLine(
          context,
          Icons.south_west_rounded,
          strings.tr('expenses'),
          dExp,
          AppColors.expenseOn(context),
        ),
      ],
    );
  }

  Widget _diffLine(
    BuildContext context,
    IconData icon,
    String label,
    int diff,
    Color color,
  ) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${strings.tr('difference')} — $label',
            style: t.textTheme.bodySmall,
          ),
        ),
        Text(
          '${diff >= 0 ? '+' : ''}${state.money(diff)}',
          style: TextStyle(
            color: diff == 0 ? t.colorScheme.outline : color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _cashflowCard(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final series = state.monthlyBalanceSeries(6);
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            context,
            strings.tr('net_cashflow'),
            'stats_net_cashflow',
          ),
          if (series.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              state.money(series.last.$2),
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.tr('net_cashflow_hint'),
              style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: 190,
            child: BalanceTrend(series: series, lang: strings.lang),
          ),
        ],
      ),
    );
  }

  Widget _weekdayCard(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final avg = state.weekdayAverages(state.settings.spendingHabitsWeeks);
    final hasData = avg.any((v) => v > 0);
    final maxV = avg.fold<int>(1, (m, v) => v > m ? v : m);
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child:
          hasData
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardTitle(
                    context,
                    strings.tr('spending_habits'),
                    'stats_spending_habits',
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < 7; i++)
                    _weekdayRow(context, i, avg[i], maxV),
                ],
              )
              : Text(
                strings.tr('no_data_chart'),
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
    );
  }

  Widget _weekdayRow(BuildContext context, int i, int value, int maxV) {
    final state = context.watch<AppState>();
    final t = Theme.of(context);
    final strings = state.strings;
    final isPeak = value > 0 && value == maxV;
    final color = isPeak ? t.colorScheme.primary : AppColors.expenseOn(context);
    final fraction = maxV == 0 ? 0.0 : (value / maxV).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              weekdayShort(i + 1, strings.lang),
              style: t.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isPeak ? color : t.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 9,
                color: t.colorScheme.surfaceContainerHighest,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(color: color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              state.money(value),
              textAlign: TextAlign.end,
              style: t.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paceCard(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final exp = state.monthTotals(month).$2;
    final dailyAvg = state.dailyAverageExpense(month);
    final projected = state.projectedExpense(month);
    final now = DateTime.now();
    final isCurrent = _isSameMonth(month, now);
    final daysTotal = DateTime(month.year, month.month + 1, 0).day;
    final elapsed = isCurrent ? now.day : daysTotal;
    final onTrack = projected <= 0 || exp <= projected;
    final statusColor =
        onTrack ? AppColors.incomeOn(context) : AppColors.expenseOn(context);

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            context,
            strings.tr('monthly_pace'),
            'stats_monthly_pace',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  context,
                  strings.tr('daily_avg'),
                  state.money(dailyAvg),
                  t.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  context,
                  strings.tr('projected'),
                  state.money(projected),
                  AppColors.expenseOn(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value:
                        projected <= 0 ? 0 : (exp / projected).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: t.colorScheme.surfaceContainerHighest,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                onTrack
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: statusColor,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${strings.tr('pace_caption').replaceAll('{d}', '$elapsed').replaceAll('{D}', '$daysTotal')} · ${onTrack ? strings.tr('on_track') : strings.tr('over_pace')}',
              style: t.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _biggestMoves(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final topExp = state.largestTransactions(month, isExpense: true);
    final topInc = state.largestTransactions(month, isExpense: false, n: 1);
    final hasExp = topExp.isNotEmpty;
    final hasInc = topInc.isNotEmpty;
    if (!hasExp && !hasInc) {
      return Text(
        strings.tr('no_data_chart'),
        style: t.textTheme.bodyMedium?.copyWith(
          color: t.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            context,
            strings.tr('biggest_moves'),
            'stats_biggest_moves',
          ),
          const SizedBox(height: 12),
          if (hasExp) ...[
            Text(
              strings.tr('biggest_expense'),
              style: t.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.expenseOn(context),
              ),
            ),
            const SizedBox(height: 8),
            for (final tx in topExp) _moveRow(context, tx),
          ],
          if (hasExp && hasInc) const SizedBox(height: 14),
          if (hasInc) ...[
            Text(
              strings.tr('biggest_income'),
              style: t.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.incomeOn(context),
              ),
            ),
            const SizedBox(height: 8),
            for (final tx in topInc) _moveRow(context, tx),
          ],
        ],
      ),
    );
  }

  Widget _moveRow(BuildContext context, AppTransaction tx) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cat =
        tx.categoryId == null ? null : state.categoryById(tx.categoryId);
    final label = cat == null ? strings.tr('other') : state.categoryLabel(cat);
    final color =
        tx.isExpense
            ? AppColors.expenseOn(context)
            : AppColors.incomeOn(context);
    final parts = tx.date.split('-');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              iconFor(cat?.icon ?? 'more_horiz'),
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${int.parse(parts[2])} ${monthShort(int.parse(parts[1]), strings.lang)}',
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${tx.isExpense ? '- ' : '+'}${state.moneyFor(tx.amount, tx.currency)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Transactions of a single category for a month.
class _CategoryTxScreen extends StatelessWidget {
  final int categoryId;
  final DateTime month;
  const _CategoryTxScreen({required this.categoryId, required this.month});

  Future<void> _showWhatIf(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WhatIfSheet(categoryId: categoryId, month: month),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cat = state.categoryById(categoryId);
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final txs =
        state.transactions
            .where(
              (x) =>
                  x.isExpense &&
                  x.currency == state.currency &&
                  x.categoryId == categoryId &&
                  x.date.startsWith(prefix),
            )
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          cat == null ? strings.tr('other') : state.categoryLabel(cat),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_rounded),
            tooltip: strings.tr('simulate_price'),
            onPressed: () => _showWhatIf(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child:
            txs.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _categoryMonthSummary(context, txs),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          itemCount: txs.length,
                          itemBuilder: (context, i) {
                            final x = txs[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SectionCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      x.date,
                                      style: t.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        x.note ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                        style: t.textTheme.bodySmall,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '- ${state.moneyFor(x.amount, x.currency)}',
                                      style: TextStyle(
                                        color: AppColors.expenseOn(context),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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

  Widget _categoryMonthSummary(
    BuildContext context,
    List<AppTransaction> txs,
  ) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    var total = 0;
    for (final x in txs) {
      total += x.amount;
    }
    final avg = txs.isEmpty ? 0 : total ~/ txs.length;
    final prev = DateTime(month.year, month.month - 1);
    final prevTotal =
        state.categoryTotalsInMonth(prev)[categoryId] ?? 0;
    final diff = total - prevTotal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: SectionCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.expenseOn(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: AppColors.expenseOn(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.tr('spent_this_month'),
                    style: t.textTheme.labelSmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.money(total),
                    style: t.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.expenseOn(context),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${txs.length} ${strings.tr('expenses')}',
                  style: t.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.colorScheme.onSurface,
                  ),
                ),
                Text(
                  strings
                      .tr('avg_expense_tx')
                      .replaceAll('{n}', '${txs.length}')
                      .replaceAll('{a}', state.money(avg)),
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (prevTotal > 0)
                  Text(
                    diff >= 0
                        ? '+${state.money(diff)} ${strings.tr('vs_last')}'
                        : '${state.money(diff)} ${strings.tr('vs_last')}',
                    style: t.textTheme.labelSmall?.copyWith(
                      color:
                          diff >= 0
                              ? AppColors.expenseOn(context)
                              : AppColors.incomeOn(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "What if this category cost less AND I earned more?" scenario planner.
class _WhatIfSheet extends StatefulWidget {
  final int categoryId;
  final DateTime month;
  const _WhatIfSheet({required this.categoryId, required this.month});

  @override
  State<_WhatIfSheet> createState() => _WhatIfSheetState();
}

class _WhatIfSheetState extends State<_WhatIfSheet> {
  late final TextEditingController _target;
  late final FocusNode _targetFocus;

  @override
  void initState() {
    super.initState();
    _target = TextEditingController(text: '');
    _targetFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      final txs = _categoryTxs(state);
      if (txs.isNotEmpty) {
        final total = txs.fold<int>(0, (s, x) => s + x.amount);
        _target.text = '${total ~/ txs.length}';
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _target.dispose();
    _targetFocus.dispose();
    super.dispose();
  }

  List<AppTransaction> _categoryTxs(AppState state) {
    final prefix =
        '${widget.month.year}-${widget.month.month.toString().padLeft(2, '0')}';
    return state.transactions
        .where(
          (x) =>
              x.isExpense &&
              x.currency == state.currency &&
              x.categoryId == widget.categoryId &&
              x.date.startsWith(prefix),
        )
        .toList();
  }

  void _onChanged(TextEditingController c, String raw) {
    final cleaned = sanitizeAmountText(raw);
    if (cleaned != raw) {
      c.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cat = state.categoryById(widget.categoryId);
    final label = cat == null ? strings.tr('other') : state.categoryLabel(cat);
    final monthLabel =
        '${monthName(widget.month.month, strings.lang)} ${widget.month.year}';

    final txs = _categoryTxs(state);
    final count = txs.length;
    final oldTotal = txs.fold<int>(0, (s, x) => s + x.amount);
    final target = parseAmount(_target.text) ?? 0;
    final kept =
        target > 0
            ? txs.fold<int>(
                0,
                (s, x) => s + (x.amount > target ? x.amount - target : 0),
              )
            : 0;
    final newTotal = oldTotal - kept;

    final (inc, exp) = state.monthTotals(widget.month);
    final oldSavings = inc - exp;
    final newSavings = oldSavings + kept;

    final oldShare = exp > 0 ? oldTotal / exp * 100 : null;
    final newShareDenom = exp - kept;
    final newShare =
        newShareDenom > 0 ? newTotal / newShareDenom * 100 : null;
    final rateBefore =
        inc > 0 ? (oldSavings < 0 ? 0.0 : oldSavings / inc * 100) : null;
    final rateAfter =
        inc > 0 ? (newSavings < 0 ? 0.0 : newSavings / inc * 100) : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calculate_rounded,
                      size: 22,
                      color: t.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings
                              .tr('whatif_scenario_title')
                              .toUpperCase(),
                          style: t.textTheme.labelSmall?.copyWith(
                            color: t.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.tr('whatif_title').replaceAll('{c}', label),
                          style: t.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$monthLabel · ${state.currency}',
                          style: t.textTheme.labelSmall?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                strings.tr('whatif_desc').replaceAll('{c}', label),
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              _sectionHeader(
                context,
                Icons.shopping_bag_rounded,
                AppColors.expenseOn(context),
                '${strings.tr('whatif_exp_section')} · $label',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _target,
                focusNode: _targetFocus,
                keyboardType: TextInputType.number,
                enabled: count > 0,
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  labelText: strings.tr('target_price'),
                  suffixText: state.currencyLabel,
                  filled: true,
                  fillColor: t.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.payments_rounded, size: 20),
                ),
                onChanged: (raw) => _onChanged(_target, raw),
              ),
              if (count > 0) ...[
                const SizedBox(height: 6),
                Text(
                  strings
                      .tr('whatif_exp_summary')
                      .replaceAll('{n}', '$count')
                      .replaceAll('{a}', state.money(oldTotal))
                      .replaceAll('{b}', state.money(newTotal)),
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  strings.tr('whatif_none'),
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.incomeOn(context).withValues(alpha: 0.16),
                      t.colorScheme.primary.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.incomeOn(context).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings
                          .tr('whatif_kept')
                          .replaceAll('{a}', state.money(kept)),
                      style: t.textTheme.labelSmall?.copyWith(
                        color: AppColors.incomeOn(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.money(kept),
                      style: t.textTheme.headlineMedium?.copyWith(
                        color: AppColors.incomeOn(context),
                        fontWeight: FontWeight.w800,
                        fontFamily: 'PlayfairDisplay',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _whatIfRow(
                context,
                strings.tr('whatif_new_total'),
                '${state.money(oldTotal)} → ${state.money(newTotal)}',
              ),
              const SizedBox(height: 8),
              _whatIfRow(
                context,
                strings.tr('whatif_share'),
                oldShare == null || newShare == null
                    ? '—'
                    : '${oldShare.toStringAsFixed(1)}% → ${newShare.toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 8),
              _whatIfRow(
                context,
                strings.tr('whatif_savings'),
                '${state.money(oldSavings)} → ${state.money(newSavings)}',
              ),
              if (rateAfter != null) ...[
                const SizedBox(height: 8),
                _whatIfRow(
                  context,
                  strings.tr('whatif_rate'),
                  rateBefore == null
                      ? '— → ${rateAfter.toStringAsFixed(1)}%'
                      : '${rateBefore.toStringAsFixed(1)}% → ${rateAfter.toStringAsFixed(1)}%',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
  ) {
    final t = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _whatIfRow(BuildContext context, String label, String value) {
    final t = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
