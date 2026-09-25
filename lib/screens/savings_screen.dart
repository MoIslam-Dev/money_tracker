import 'package:flutter/material.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/money.dart';
import '../widgets/widgets.dart';

class SavingsGoalsScreen extends StatelessWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.tr('savings_goals'))),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => state.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              if (state.goals.isEmpty)
                EmptyState(
                  icon: Icons.savings_outlined,
                  title: strings.tr('savings_goals'),
                  subtitle: strings.tr('empty_transactions_sub'),
                )
              else
                for (final g in state.goals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _goalCard(context, g),
                  ),
              const SizedBox(height: 12),
              BigButton(
                label: strings.tr('add_savings'),
                icon: Icons.savings_rounded,
                onPressed: () => _openEditor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalCard(BuildContext context, SavingsGoal g) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final pct = g.progressPercent;
    final reached = g.currentAmount >= g.targetAmount;
    final color = reached ? AppColors.incomeOn(context) : t.colorScheme.primary;

    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  reached ? Icons.emoji_events_rounded : Icons.savings_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (g.targetDate != null)
                      Text(
                        '${strings.tr('target_date')}: ${dateKey(parseDateKey(g.targetDate!))}',
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
                            ? _openEditor(context, g)
                            : _delete(context, g),
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
          if (g.note != null && g.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              g.note!,
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${state.moneyFor(g.currentAmount, g.currency)}  /  ${state.moneyFor(g.targetAmount, g.currency)}',
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (reached)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    strings.tr('goal_reached'),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (!reached) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addMoney(context, g),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(strings.tr('add_money')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addMoney(BuildContext context, SavingsGoal g) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final ctrl = TextEditingController();
    await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(strings.tr('add_money')),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '${state.currencyDefinition(g.currency).symbol} ',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(strings.tr('cancel')),
              ),
              FilledButton(
                onPressed: () async {
                  final amt = parseAmount(ctrl.text);
                  if (amt == null) return;
                  await state.addToGoal(g, amt);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: Text(strings.tr('saveexp')),
              ),
            ],
          ),
    );
  }

  Future<void> _openEditor(BuildContext context, [SavingsGoal? editing]) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final targetCtrl = TextEditingController(
      text: editing == null ? '' : '${editing.targetAmount}',
    );
    final currentCtrl = TextEditingController(
      text: editing == null ? '' : '${editing.currentAmount}',
    );
    final noteCtrl = TextEditingController(text: editing?.note ?? '');
    DateTime? targetDate =
        editing?.targetDate == null ? null : parseDateKey(editing!.targetDate!);

    await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                title: Text(
                  editing == null
                      ? strings.tr('add_savings')
                      : strings.tr('edit_savings'),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: strings.tr('goal_name'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: targetCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: strings.tr('target_amount'),
                          prefixText:
                              '${state.currencyDefinition(editing?.currency ?? state.currency).symbol} ',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: currentCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: strings.tr('current_amount'),
                          prefixText:
                              '${state.currencyDefinition(editing?.currency ?? state.currency).symbol} ',
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            initialDate:
                                targetDate ??
                                DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            locale: Locale(state.strings.lang),
                          );
                          if (p != null) setState(() => targetDate = p);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: strings.tr('target_date'),
                            suffixIcon: const Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                            ),
                          ),
                          child: Text(
                            targetDate == null ? '-' : dateKey(targetDate!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteCtrl,
                        decoration: InputDecoration(
                          labelText: strings.tr('note'),
                        ),
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
                      final target = parseAmount(targetCtrl.text);
                      if (target == null || nameCtrl.text.trim().isEmpty) {
                        return;
                      }
                      await state.saveGoal(
                        id: editing?.id,
                        name: nameCtrl.text.trim(),
                        target: target,
                        current:
                            parseAmount(currentCtrl.text) ??
                            (editing?.currentAmount ?? 0),
                        currency: editing?.currency,
                        targetDate: targetDate,
                        note:
                            noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
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

  Future<void> _delete(BuildContext context, SavingsGoal g) async {
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
      await context.read<AppState>().deleteGoal(g);
    }
  }
}
