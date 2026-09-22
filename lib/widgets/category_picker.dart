import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'icons.dart';

/// Icons offered when creating a custom category.
const customCategoryIcons = [
  'restaurant', 'coffee', 'shopping_cart', 'directions_bus', 'home', 'bolt',
  'wifi', 'medical_services', 'checkroom', 'movie', 'school', 'devices',
  'family_restroom', 'card_giftcard', 'savings', 'more_horiz', 'payments',
  'computer', 'storefront', 'redeem', 'trending_up', 'currency_exchange', 'local_gas_station', 'phone_android',
];

class CategoryPicker extends StatelessWidget {
  final String type;
  final int? selectedId;
  final ValueChanged<int> onSelected;
  final VoidCallback? onCreateCustom;
  final List<int> recentIds;
  const CategoryPicker({
    super.key,
    required this.type,
    required this.selectedId,
    required this.onSelected,
    this.onCreateCustom,
    this.recentIds = const [],
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final cats = state.categoriesFor(type);
    final recents = recentIds
        .map(state.categoryById)
        .whereType<AppCategory>()
        .where((c) => c.type == type)
        .take(6)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recents.isNotEmpty) ...[
          Text(strings.tr('recent').toUpperCase(),
              style: t.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700, color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in recents)
                _item(context, strings.categoryName(c.name), iconFor(c.icon),
                    c.id == selectedId, () => onSelected(c.id!)),
            ],
          ),
          const SizedBox(height: 14),
          Text(strings.tr('category').toUpperCase(),
              style: t.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700, color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cats)
              _item(context, strings.categoryName(c.name), iconFor(c.icon), c.id == selectedId, () => onSelected(c.id!)),
            if (onCreateCustom != null)
              _item(context, '+', Icons.add_rounded, false, onCreateCustom!, dimmed: true),
          ],
        ),
      ],
    );
  }

  Widget _item(BuildContext context, String label, IconData icon, bool selected, VoidCallback onTap, {bool dimmed = false}) {
    final t = Theme.of(context);
    final fg = selected ? t.colorScheme.onPrimary : (dimmed ? t.colorScheme.outline : t.colorScheme.onSurface);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? t.colorScheme.primary : t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Opens the custom-category creation dialog and returns true if created.
Future<bool> showCreateCategory(BuildContext context, String type) => showCategoryForm(context, type);

/// Opens the rename-category dialog and returns true if renamed.
Future<bool> showRenameCategory(BuildContext context, AppCategory category) =>
    showCategoryForm(context, category.type, editing: category);

/// Shared create / rename dialog for categories.
Future<bool> showCategoryForm(BuildContext context, String type, {AppCategory? editing}) async {
  final state = context.read<AppState>();
  final strings = state.strings;
  final nameController = TextEditingController(
      text: editing == null ? '' : strings.categoryName(editing.name));
  var selectedIcon = editing?.icon ?? 'more_horiz';
  final created = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Future<void> submit() async {
          final trimmed = nameController.text.trim();
          if (trimmed.isEmpty) return;
          Navigator.pop(ctx, true);
          if (editing == null) {
            await state.addCustomCategory(trimmed, selectedIcon, type);
          } else {
            await state.renameCategory(editing, trimmed);
          }
        }

        return AlertDialog(
          title: Text(editing == null ? strings.tr('add_category') : strings.tr('rename_category')),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: strings.tr('category_name'),
                      hintText: strings.tr('custom'),
                    ),
                  ),
                  if (editing == null) ...[
                    const SizedBox(height: 16),
                    Text(strings.tr('choose_icon'),
                        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final icon in customCategoryIcons)
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => selectedIcon = icon),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: selectedIcon == icon
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(iconFor(icon),
                                  size: 20,
                                  color: selectedIcon == icon
                                      ? Theme.of(ctx).colorScheme.onPrimary
                                      : Theme.of(ctx).colorScheme.onSurface),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.tr('cancel'))),
            FilledButton(
              onPressed: submit,
              child: Text(editing == null ? strings.tr('create') : strings.tr('saveexp')),
            ),
          ],
        );
      },
    ),
  );
  return created ?? false;
}

class PaymentChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const PaymentChips({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in PaymentMethods.all)
          ChoiceChip(
            label: Text(strings.tr(m)),
            selected: selected == m,
            onSelected: (_) => onChanged(m),
          ),
      ],
    );
  }
}