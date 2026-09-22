import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/money.dart';
import '../widgets/widgets.dart';
import 'add_edit_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  String? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = dateKey(now);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);

    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday % 7; // Sunday-first grid

    return Scaffold(
      appBar: AppBar(title: Text(strings.tr('calendar'))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            MonthSelector(
              month: _month,
              label: '${monthName(_month.month, strings.lang)} ${_month.year}',
              onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            ),
            const SizedBox(height: 12),
            SectionCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Text(
                            weekdayShort((i + 6) % 7 + 1, strings.lang),
                            textAlign: TextAlign.center,
                            style: t.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800, color: t.colorScheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 0.9,
                    children: [
                      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
                      for (var d = 1; d <= daysInMonth; d++)
                        _dayCell(context, DateTime(_month.year, _month.month, d)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_selected != null) _selectedDetail(context),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, DateTime day) {
    final state = context.watch<AppState>();
    final t = Theme.of(context);
    final key = dateKey(day);
    final exp = state.expensesOn(day);
    final inc = state.incomesOn(day);
    final isToday = key == dateKey(DateTime.now());
    final selected = _selected == key;
    final hasTx = exp > 0 || inc > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selected = key),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? t.colorScheme.primary : null,
          borderRadius: BorderRadius.circular(10),
          border: isToday && !selected ? Border.all(color: t.colorScheme.primary, width: 1.2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected
                      ? t.colorScheme.onPrimary
                      : isToday
                          ? t.colorScheme.primary
                          : t.colorScheme.onSurface,
                )),
            const SizedBox(height: 2),
            if (hasTx)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (exp > 0) Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: AppColors.expenseOn(context), shape: BoxShape.circle)),
                  const SizedBox(width: 2),
                  if (inc > 0) Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: AppColors.incomeOn(context), shape: BoxShape.circle)),
                ],
              )
            else
              const SizedBox(height: 7),
          ],
        ),
      ),
    );
  }

  Widget _selectedDetail(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final day = parseDateKey(_selected!);
    final inc = state.incomesOn(day);
    final exp = state.expensesOn(day);
    final dayTx = state.transactions
        .where((x) => x.date == _selected)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${day.day} ${monthName(day.month, strings.lang)} ${day.year}',
                style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
builder: (_) => AddEditScreen(type: TxType.expense),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              tooltip: strings.tr('add_expense'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SectionCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: _netStat(strings.tr('income'), '+${formatDA(inc)}', AppColors.incomeOn(context)),
              ),
              Expanded(
                child: _netStat(strings.tr('expenses'), '-${formatDA(exp)}', AppColors.expenseOn(context)),
              ),
              Expanded(
                child: _netStat(strings.tr('daily_net'),
                    '${inc - exp >= 0 ? '+' : '-'}${formatDA((inc - exp).abs())}',
                    t.colorScheme.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (dayTx.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(strings.tr('no_data_chart'),
                  style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ),
          )
        else
          for (final tx in dayTx)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _txRow(context, tx),
            ),
      ],
    );
  }

  Widget _netStat(String label, String value, Color color) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      ],
    );
  }

  Widget _txRow(BuildContext context, AppTransaction tx) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cat = state.categoryById(tx.categoryId);
    final color = tx.isExpense ? AppColors.expenseOn(context) : AppColors.incomeOn(context);
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(tx.date,
              style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          Expanded(
            child: Text(
              [cat == null ? strings.tr('other') : strings.categoryName(cat.name),
               if (tx.note != null && tx.note!.isNotEmpty) tx.note].join(' · '),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text('${tx.isExpense ? '- ' : '+ '}${formatDA(tx.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}