import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/category_picker.dart';
import '../widgets/icons.dart';
import '../widgets/widgets.dart';

/// Manage categories: rename, safely delete custom ones and create new ones.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final expense = state.categoriesFor(TxType.expense);
    final income = state.categoriesFor(TxType.income);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('categories'),
            style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(strings.tr('default_category_note'),
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _sectionLabel(context, strings.tr('expense_categories')),
            _section(context, expense, TxType.expense),
            const SizedBox(height: 20),
            _sectionLabel(context, strings.tr('income_categories')),
            _section(context, income, TxType.income),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(),
          style: t.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: t.colorScheme.primary,
              letterSpacing: 0.8)),
    );
  }

  Widget _section(BuildContext context, List<AppCategory> cats, String type) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (cats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(strings.tr('no_data_chart'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          for (var i = 0; i < cats.length; i++) ...[
            if (i > 0) Divider(height: 1),
            _row(context, cats[i], state.categoryTransactionCount(cats[i].id!)),
          ],
          Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(strings.tr('add_category'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () async {
              await showCreateCategory(context, type);
            },
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppCategory c, int count) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final label = strings.categoryName(c.name);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(iconFor(c.icon), size: 19, color: t.colorScheme.primary),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(strings.tr('transactions_count').replaceAll('{n}', '$count')),
      isThreeLine: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            tooltip: strings.tr('rename'),
            onPressed: () => showRenameCategory(context, c),
          ),
          IconButton(
            icon: Icon(
              c.isDefault ? Icons.lock_outline_rounded : Icons.delete_outline_rounded,
              size: 20,
              color: c.isDefault
                  ? t.colorScheme.outline
                  : Theme.of(context).colorScheme.error,
            ),
            tooltip: c.isDefault
                ? strings.tr('default_category_note')
                : strings.tr('delete'),
            onPressed: c.isDefault ? null : () => _confirmDelete(context, c),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppCategory c) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final count = state.categoryTransactionCount(c.id!);
    final used = count > 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.tr('confirm')),
        content: Text(used
            ? strings.tr('delete_cat_used').replaceAll('{n}', '$count')
            : strings.tr('confirm_delete_cat_unused')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
                used ? strings.tr('delete_move_txns') : strings.tr('delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.removeCategory(c);
    }
  }
}