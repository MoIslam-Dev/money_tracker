import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/money.dart';
import '../widgets/icons.dart';
import '../widgets/widgets.dart';
import 'add_edit_screen.dart';
import 'budgets_screen.dart';
import 'calendar_screen.dart';
import 'insights_screen.dart';
import 'recurring_screen.dart';
import 'savings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
    final balance = state.balance;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => state.refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              if (state.settings.demoAdded) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(child: _demoBanner(context)),
              ],
              SliverToBoxAdapter(child: _balanceCard(context, balance, income, expense)),
              SliverToBoxAdapter(child: _todayCard(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: _quickActions(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                  child: _monthCard(context, month, income, expense, remaining, rate, count)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(child: _miniStats(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (state.transactions.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SectionHeader(
                      strings.tr('insights'),
                      actionText: strings.tr('insights') == 'insights' ? '→' : '→',
                      onAction: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const InsightsScreen())),
                    ),
                  ),
                ),
              if (state.transactions.isNotEmpty)
                SliverToBoxAdapter(child: _insightCards(context)),
              if (state.transactions.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (state.committedMonthly > 0)
                SliverToBoxAdapter(child: _committedCard(context)),
              if (state.committedMonthly > 0) const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (state.budgets.isNotEmpty || state.goals.isNotEmpty || state.recurring.isNotEmpty)
                SliverToBoxAdapter(child: _modulesRow(context)),
              if (state.budgets.isNotEmpty || state.goals.isNotEmpty || state.recurring.isNotEmpty)
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(strings.tr('transactions'),
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      TextButton.icon(
                        onPressed: () => Scaffold.of(context).showBottomSheet((_) => const SizedBox.shrink()),
                        icon: const SizedBox.shrink(),
                        label: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _recentTransactions(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    final today = DateTime.now();
    final dateText = strings.isRtl
        ? '${weekdayName(today.weekday, strings.lang)}، ${monthName(today.month, strings.lang)} ${today.day}'
        : '${weekdayName(today.weekday, strings.lang)}, ${today.day} ${monthName(today.month, strings.lang)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.tr('app_name'),
                    style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(dateText,
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CalendarScreen())),
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: strings.tr('calendar'),
          ),
          Builder(
            builder: (ctx) => IconButton(
              onPressed: () => _browseMonth(ctx),
              icon: const Icon(Icons.calendar_view_month_rounded),
              tooltip: strings.tr('monthly_summary'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _browseMonth(BuildContext context) async {
    final state = context.read<AppState>();
    final res = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _MonthPickerSheet(initial: state.currentMonth),
    );
    if (res != null) state.setCurrentMonth(res);
  }

  Widget _demoBanner(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    final bg = AppColors.bannerBg(context);
    final border = AppColors.bannerBorder(context);
    final fg = AppColors.bannerFg(context);
    final icon = AppColors.bannerIcon(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: icon, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(strings.tr('demo_data_banner'),
                  style: t.textTheme.bodySmall?.copyWith(color: fg)),
            ),
            TextButton(
              onPressed: () => context.read<AppState>().removeDemoData(),
              child: Text(strings.tr('remove_demo'), style: TextStyle(color: fg)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(BuildContext context, int balance, int income, int expense) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    final colorScheme = t.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.balanceGradient(colorScheme),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.tr('balance'),
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(formatDA(balance),
                style: const TextStyle(
                    color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(height: 20),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                _balanceStat(strings.tr('money_in'), income, const Color(0xFF8CE99A)),
                _balanceStat(strings.tr('money_out'), -expense, const Color(0xFFFFA8A8)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _todayCard(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final today = DateTime.now();
    final inc = state.incomesOn(today);
    final exp = state.expensesOn(today);
    final net = inc - exp;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: (inc == 0 && exp == 0)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.tr('today').toUpperCase(),
                      style: t.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: t.colorScheme.primary,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Text(strings.tr('no_transactions_today'),
                      style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddEditScreen(type: TxType.expense))),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(strings.tr('add_expense')),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.tr('today').toUpperCase(),
                      style: t.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: t.colorScheme.primary,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _todayStat(context, strings.tr('money_in'), inc, AppColors.incomeOn(context))),
                      const SizedBox(width: 10),
                      Expanded(child: _todayStat(context, strings.tr('money_out'), -exp, AppColors.expenseOn(context))),
                      const SizedBox(width: 10),
                      Expanded(child: _todayStat(context, strings.tr('today_net'), net, t.colorScheme.primary)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _todayStat(BuildContext context, String label, int value, Color color) {
    final t = Theme.of(context);
    final sign = value < 0 ? '-' : value > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: t.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$sign${formatDA(value.abs())}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _balanceStat(String label, int value, Color color) {
    final prepend = value < 0 ? '-' : '+';
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('$prepend${formatDA(value.abs())}',
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.expense,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddEditScreen(type: TxType.expense))),
                icon: const Icon(Icons.south_west_rounded, size: 18),
                label: Text(strings.tr('add_expense'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.income,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddEditScreen(type: TxType.income))),
                icon: const Icon(Icons.north_east_rounded, size: 18),
                label: Text(strings.tr('add_income'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthCard(BuildContext context, DateTime month, int income, int expense, int remaining,
      double rate, int count) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    final label = '${monthName(month.month, strings.lang)} ${month.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SectionCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _monthStat(context, strings.tr('income'), income, AppColors.incomeOn(context))),
                Expanded(
                    child: _monthStat(context, strings.tr('expenses'), expense, AppColors.expenseOn(context))),
                Expanded(
                    child: _monthStat(context, strings.tr('remaining'), remaining, t.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.tr('savings_rate'),
                          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text('${rate.toStringAsFixed(1)}%',
                          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(strings.tr('transactions'),
                        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text('$count',
                        style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthStat(BuildContext context, String label, int value, Color color) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(formatDA(value), style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _miniStats(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
              child: _miniCard(context,
                  icon: Icons.today_rounded,
                  value: formatDA(state.todayExpense),
                  label: strings.tr('today_spent'),
                  color: AppColors.expenseOn(context))),
          const SizedBox(width: 10),
          Expanded(
              child: _miniCard(context,
                  icon: Icons.date_range_rounded,
                  value: formatDA(state.weekExpense),
                  label: strings.tr('week_spent'),
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(width: 10),
          Expanded(
              child: _miniCard(context,
                  icon: Icons.calendar_month_rounded,
                  value: formatDA(state.monthExpense),
                  label: strings.tr('month_spent'),
                  color: AppColors.violetOn(context))),
        ],
      ),
    );
  }

  Widget _miniCard(BuildContext context,
      {required IconData icon, required String value, required String label, required Color color}) {
    final t = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _insightCards(BuildContext context) {
    final insights = buildInsights(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final insight in insights.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _insightCard(context, insight),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const InsightsScreen())),
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
              label: Text(context.watch<AppState>().strings.tr('insights')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(BuildContext context, String text) {
    final t = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberOn(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded, color: AppColors.amberIconOn(context), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.brightness == Brightness.dark
                      ? AppColors.amberDark
                      : AppColors.amber,
                )),
          ),
        ],
      ),
    );
  }

  Widget _committedCard(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.skyOn(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.repeat_rounded, color: AppColors.skyOn(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.tr('committed_monthly'),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text('${formatDA(state.committedMonthly)} / ${strings.tr('per_month')}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.skyOn(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modulesRow(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final modules = <Widget>[
      Expanded(
          child: _moduleCard(context,
              label: strings.tr('budgets'),
              icon: Icons.track_changes_rounded,
              count: state.budgets.isEmpty ? '' : '${state.budgets.length}',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BudgetsScreen())))),
      const SizedBox(width: 10),
      Expanded(
          child: _moduleCard(context,
              label: strings.tr('savings_goals'),
              icon: Icons.savings_rounded,
              count: state.goals.isEmpty ? '' : '${state.goals.length}',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SavingsGoalsScreen())))),
      const SizedBox(width: 10),
      Expanded(
          child: _moduleCard(context,
              label: strings.tr('recurring'),
              icon: Icons.repeat_rounded,
              count: state.recurring.isEmpty ? '' : '${state.recurring.length}',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RecurringScreen())))),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: modules),
    );
  }

  Widget _moduleCard(BuildContext context,
      {required String label, required IconData icon, required String count, required VoidCallback onTap}) {
    final t = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: t.colorScheme.primary, size: 22),
                const Spacer(),
                if (count.isNotEmpty)
                  Text(count,
                      style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            Text(label, maxLines: 2, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _recentTransactions(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    if (state.transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: EmptyState(
          icon: Icons.savings_outlined,
          title: strings.tr('empty_transactions'),
          subtitle: strings.tr('empty_transactions_sub'),
          buttonLabel: strings.tr('add_first'),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddEditScreen(type: TxType.expense))),
        ),
      );
    }
    final recent = state.transactions.take(6).toList();
    return Column(
      children: [
        for (final t in recent)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _txTile(context, t),
          ),
      ],
    );
  }

  Widget _txTile(BuildContext context, AppTransaction t) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final cat = state.categoryById(t.categoryId);
    final color = t.isExpense ? AppColors.expenseOn(context) : AppColors.incomeOn(context);
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(t.note ?? t.date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text('${t.isExpense ? '- ' : '+ '}${formatDA(t.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  final DateTime initial;
  const _MonthPickerSheet({required this.initial});

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    final now = DateTime.now();
    final candidates = <DateTime>[];
    DateTime cursor = DateTime(_month.year, _month.month);
    for (var i = 0; i < 24; i++) {
      candidates.add(cursor);
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Text('${monthName(_month.month, strings.lang)} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              IconButton(
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            childAspectRatio: 2.4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < candidates.length; i++)
                _monthCell(context, candidates[i], now,
                    DateTime(now.year, now.month) == DateTime(widget.initial.year, widget.initial.month)),
            ],
          ),
          const SizedBox(height: 12),
          BigButton(
            label: strings.tr('apply'),
            onPressed: () => Navigator.pop(context, _month),
          ),
        ],
      ),
    );
  }

  Widget _monthCell(BuildContext context, DateTime m, DateTime now, bool _) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    final selected = m.year == _month.year && m.month == _month.month;
    final isCurrent = m.year == now.year && m.month == now.month;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _month = m),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? t.colorScheme.primary : t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: isCurrent && !selected ? Border.all(color: t.colorScheme.primary, width: 1) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${monthShort(m.month, strings.lang)} ${m.year}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: selected ? t.colorScheme.onPrimary : t.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}