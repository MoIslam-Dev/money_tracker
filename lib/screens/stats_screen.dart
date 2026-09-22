import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/money.dart';
import '../widgets/icons.dart';
import '../widgets/widgets.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _range = '30d';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final month = state.currentMonth;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('statistics'),
            style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
              SectionHeader(strings.tr('spending_by_category')),
              const SizedBox(height: 12),
              _donut(context, month),
              const SizedBox(height: 20),
              SectionHeader(strings.tr('where_money_go')),
              const SizedBox(height: 12),
              _categoryList(context, month),
              const SizedBox(height: 24),
              SectionHeader(strings.tr('trends')),
              const SizedBox(height: 12),
              _rangePill(context),
              const SizedBox(height: 14),
              _trendChart(context),
              const SizedBox(height: 24),
              SectionHeader(strings.tr('compare_months')),
              const SizedBox(height: 12),
              _compareCard(context),
              const SizedBox(height: 24),
              SectionHeader(strings.tr('net_cashflow')),
              const SizedBox(height: 12),
              _cashflowCard(context),
              const SizedBox(height: 24),
              SectionHeader(strings.tr('spending_habits')),
              const SizedBox(height: 12),
              _weekdayCard(context),
              const SizedBox(height: 24),
              SectionHeader(strings.tr('monthly_pace')),
              const SizedBox(height: 12),
              _paceCard(context, month),
              const SizedBox(height: 24),
              SectionHeader(strings.tr('biggest_moves')),
              const SizedBox(height: 12),
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
      onPrev: () => state.setCurrentMonth(DateTime(month.year, month.month - 1)),
      onNext: () => state.setCurrentMonth(DateTime(month.year, month.month + 1)),
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
        children: [
          Row(
            children: [
              Expanded(
                  child: _statBox(context, strings.tr('income'), formatDA(inc), AppColors.incomeOn(context))),
              const SizedBox(width: 10),
              Expanded(
                  child: _statBox(context, strings.tr('expenses'), formatDA(exp), AppColors.expenseOn(context))),
              const SizedBox(width: 10),
              Expanded(
                  child: _statBox(context, strings.tr('saved'), formatDA(inc - exp), t.colorScheme.primary)),
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
              Text('${rate.toStringAsFixed(1)}%',
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
                '${strings.tr('savings_rate')} · ${state.countInMonth(month)} ${strings.tr('transactions')}',
                style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _statBox(BuildContext context, String label, String value, Color color) {
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
          Text(label,
              style: t.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _donut(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final totals = state.categoryTotalsInMonth(month);
    final used = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final slices = <(String, int, Color)>[];
    var colorIdx = 0;
    for (final e in used) {
      final cat = state.categoryById(e.key);
      slices.add((
        cat == null ? strings.tr('other') : strings.categoryName(cat.name),
        e.value,
        chartColors[colorIdx++ % chartColors.length],
      ));
    }
    if (slices.isEmpty) {
      return SectionCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(strings.tr('no_data_chart'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
    }
    return SectionCard(padding: const EdgeInsets.all(16), child: DonutChart(slices: slices));
  }

  Widget _categoryList(BuildContext context, DateTime month) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final totals = state.categoryTotalsInMonth(month).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = totals.fold<int>(0, (a, e) => a + e.value);

    if (totals.isEmpty) {
      return Text(strings.tr('no_data_chart'),
          style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant));
    }

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < totals.length; i++)
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _CategoryTxScreen(categoryId: totals[i].key, month: month),
                ),
              ),
              child: _categoryRow(context, i, totals[i], total),
            ),
        ],
      ),
    );
  }

  Widget _categoryRow(BuildContext context, int i, MapEntry<int, int> e, int total) {
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
            child: Icon(iconFor(cat?.icon ?? 'more_horiz'), size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}. ${cat == null ? strings.tr('other') : strings.categoryName(cat.name)}',
                    style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text('${pct.toStringAsFixed(1)}%',
                    style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(formatDA(e.value),
              style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: t.colorScheme.outline),
        ],
      ),
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
      final months = _range == '3m' ? 3 : _range == '6m' ? 6 : 12;
      final series = <(String, int, int)>[];
      for (var i = months - 1; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i);
        final (inc, exp) = state.monthTotals(m);
        series.add(('${m.year}-${m.month.toString().padLeft(2, '0')}', inc, exp));
      }
      chart = TrendBars(
          series: series,
          incomeColor: AppColors.incomeOn(context),
          expenseColor: AppColors.expenseOn(context));
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
          _legendDot(context, AppColors.incomeOn(context), strings.tr('income')),
          const SizedBox(height: 6),
          _legendDot(context, AppColors.expenseOn(context), strings.tr('expenses')),
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: t.textTheme.labelMedium),
      ],
    );
  }

  Widget _compareCard(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final rows = <({DateTime m, int inc, int exp})>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(DateTime.now().year, DateTime.now().month - i);
      final (inc, exp) = state.monthTotals(m);
      rows.add((m: m, inc: inc, exp: exp));
    }

    final activeIdx = rows.indexWhere((r) => _isSameMonth(r.m, state.currentMonth));
    final prevIdx = activeIdx > 0 ? activeIdx - 1 : -1;

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _monthMini(context, rows[activeIdx], isActive: true)),
              const SizedBox(width: 12),
              if (prevIdx >= 0)
                Expanded(child: _monthMini(context, rows[prevIdx]))
              else
                Expanded(
                  child: Center(
                    child: Text(strings.tr('no_prev_month'),
                        style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
          if (prevIdx >= 0) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: t.dividerColor),
            const SizedBox(height: 12),
            _diffRow(context, rows[activeIdx], rows[prevIdx]),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: TrendLine(
              income: [for (final r in rows) (_monthKey(r.m), r.inc)],
              expense: [for (final r in rows) (_monthKey(r.m), r.exp)],
            ),
          ),
        ],
      ),
    );
  }

  String _monthKey(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

  bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  Widget _monthMini(BuildContext context, ({DateTime m, int inc, int exp}) r,
      {bool isActive = false}) {
    final strings2 = context.watch<AppState>().strings;
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? t.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : t.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${monthName(r.m.month, strings2.lang)} ${r.m.year}',
              style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('↑ ${formatDA(r.inc)}',
                    style: TextStyle(
                        color: AppColors.incomeOn(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: Text('↓ ${formatDA(r.exp)}',
                    style: TextStyle(
                        color: AppColors.expenseOn(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _diffRow(BuildContext context, ({DateTime m, int inc, int exp}) cur, ({DateTime m, int inc, int exp}) prev) {
    final strings = context.watch<AppState>().strings;
    final dInc = cur.inc - prev.inc;
    final dExp = cur.exp - prev.exp;
    return Column(
      children: [
        _diffLine(context, Icons.north_east_rounded, strings.tr('income'), dInc, AppColors.incomeOn(context)),
        const SizedBox(height: 6),
        _diffLine(context, Icons.south_west_rounded, strings.tr('expenses'), dExp, AppColors.expenseOn(context)),
      ],
    );
  }

  Widget _diffLine(BuildContext context, IconData icon, String label, int diff, Color color) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
            child: Text('${strings.tr('difference')} — $label', style: t.textTheme.bodySmall)),
        Text('${diff >= 0 ? '+' : ''}${formatDA(diff)}',
            style: TextStyle(color: diff == 0 ? t.colorScheme.outline : color, fontWeight: FontWeight.w800)),
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
          if (series.isNotEmpty) ...[
            Text(formatDA(series.last.$2),
                style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(strings.tr('net_cashflow_hint'),
                style: t.textTheme.labelSmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
          ],
          SizedBox(height: 190, child: BalanceTrend(series: series, lang: strings.lang)),
        ],
      ),
    );
  }

  Widget _weekdayCard(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final avg = state.weekdayAverages(8);
    final hasData = avg.any((v) => v > 0);
    final maxV = avg.fold<int>(1, (m, v) => v > m ? v : m);
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: hasData
          ? Column(
              children: [
                for (var i = 0; i < 7; i++) _weekdayRow(context, i, avg[i], maxV),
              ],
            )
          : Text(strings.tr('no_data_chart'),
              style: t.textTheme.bodyMedium
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
    );
  }

  Widget _weekdayRow(BuildContext context, int i, int value, int maxV) {
    final t = Theme.of(context);
    final strings = context.watch<AppState>().strings;
    final isPeak = value > 0 && value == maxV;
    final color = isPeak ? t.colorScheme.primary : AppColors.expenseOn(context);
    final fraction = maxV == 0 ? 0.0 : (value / maxV).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(weekdayShort(i + 1, strings.lang),
                style: t.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isPeak ? color : t.colorScheme.onSurfaceVariant)),
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
            child: Text(formatDA(value),
                textAlign: TextAlign.end,
                style: t.textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
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
    final statusColor = onTrack ? AppColors.incomeOn(context) : AppColors.expenseOn(context);

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _statBox(context, strings.tr('daily_avg'), formatDA(dailyAvg), t.colorScheme.primary)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statBox(context, strings.tr('projected'), formatDA(projected), AppColors.expenseOn(context))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: projected <= 0 ? 0 : (exp / projected).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: t.colorScheme.surfaceContainerHighest,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(onTrack ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: statusColor, size: 22),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${strings.tr('pace_caption').replaceAll('{d}', '$elapsed').replaceAll('{D}', '$daysTotal')} · ${onTrack ? strings.tr('on_track') : strings.tr('over_pace')}',
              style: t.textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
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
      return Text(strings.tr('no_data_chart'),
          style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant));
    }
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasExp) ...[
            Text(strings.tr('biggest_expense'),
                style: t.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.expenseOn(context))),
            const SizedBox(height: 8),
            for (final tx in topExp) _moveRow(context, tx),
          ],
          if (hasExp && hasInc) const SizedBox(height: 14),
          if (hasInc) ...[
            Text(strings.tr('biggest_income'),
                style: t.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.incomeOn(context))),
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
    final cat = tx.categoryId == null ? null : state.categoryById(tx.categoryId);
    final label = cat == null ? strings.tr('other') : strings.categoryName(cat.name);
    final color = tx.isExpense ? AppColors.expenseOn(context) : AppColors.incomeOn(context);
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
            child: Icon(iconFor(cat?.icon ?? 'more_horiz'), size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text('${int.parse(parts[2])} ${monthShort(int.parse(parts[1]), strings.lang)}',
                    style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text('${tx.isExpense ? '- ' : '+'}${formatDA(tx.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cat = state.categoryById(categoryId);
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final txs = state.transactions
        .where((x) => x.isExpense && x.categoryId == categoryId && x.date.startsWith(prefix))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(cat == null ? strings.tr('other') : strings.categoryName(cat.name)),
      ),
      body: SafeArea(
        top: false,
        child: txs.isEmpty
            ? const SizedBox.shrink()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                itemCount: txs.length,
                itemBuilder: (context, i) {
                  final x = txs[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SectionCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Text(x.date,
                              style: t.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Expanded(
                            child: Text(x.note ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: t.textTheme.bodySmall),
                          ),
                          const SizedBox(width: 8),
                          Text('- ${formatDA(x.amount)}',
                              style: TextStyle(
                                  color: AppColors.expenseOn(context),
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}