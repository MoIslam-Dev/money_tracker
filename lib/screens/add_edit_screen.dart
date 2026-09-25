import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../utils/money.dart';
import '../widgets/category_picker.dart';
import '../widgets/widgets.dart';

/// Full transaction entry/edit form.
class AddEditScreen extends StatefulWidget {
  final String type;
  final AppTransaction? editing;
  const AddEditScreen({super.key, this.type = TxType.expense, this.editing});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  late String _type;
  late TextEditingController _amountCtrl;
  final _amountFocus = FocusNode();
  int? _categoryId;
  late String _payment;
  late DateTime _date;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final state = context.read<AppState>();
    _type = widget.type;
    _amountCtrl = TextEditingController(text: e == null ? '' : '${e.amount}');
    _categoryId = e?.categoryId;
    _payment =
        e?.paymentMethod.isNotEmpty == true
            ? e!.paymentMethod
            : (state.settings.lastPayment.isNotEmpty
                ? state.settings.lastPayment
                : 'cash');
    _date = e == null ? DateTime.now() : parseDateKey(e.date);
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final state = context.read<AppState>();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: Locale(state.strings.lang),
      helpText: state.strings.tr('date'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final amount = parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _showErr('${strings.tr('amount')} > 0');
      return;
    }
    final cid = _categoryId ?? state.categoriesFor(_type).firstOrNull?.id;
    if (cid == null) {
      _showErr('${strings.tr('category')} ✱');
      return;
    }
    final navigator = Navigator.of(context);
    final currency = widget.editing?.currency ?? state.currency;
    if (widget.editing == null) {
      await state.addTransaction(
        type: _type,
        amount: amount,
        categoryId: cid,
        paymentMethod: _payment,
        date: _date,
        note: _noteCtrl.text,
        currency: currency,
      );
    } else {
      await state.updateTransaction(
        widget.editing!,
        type: _type,
        amount: amount,
        categoryId: cid,
        paymentMethod: _payment,
        date: _date,
        note: _noteCtrl.text,
        currency: currency,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('transaction_saved'))));
      navigator.pop();
    }
  }

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final editing = widget.editing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing
              ? strings.tr('edit_transaction')
              : strings.tr('new_transaction'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(child: _typeButton(context, TxType.expense)),
                    Expanded(child: _typeButton(context, TxType.income)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                strings.tr('amount'),
                style: t.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              AmountField(
                controller: _amountCtrl,
                focusNode: _amountFocus,
                hint: '0',
                currency: widget.editing?.currency,
                onChanged: (_) {},
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    strings.tr('category'),
                    style: t.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final created = await showCreateCategory(context, _type);
                      if (created && mounted) {
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(strings.tr('add_category')),
                  ),
                ],
              ),
              CategoryPicker(
                type: _type,
                selectedId: _categoryId,
                recentIds: state.recentCategoryIds(_type),
                onSelected: (id) => setState(() => _categoryId = id),
              ),
              const SizedBox(height: 24),
              Text(
                strings.tr('payment_method'),
                style: t.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              PaymentChips(
                selected: _payment,
                onChanged: (m) => setState(() => _payment = m),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(_friendlyDate(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                strings.tr('note'),
                style: t.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(hintText: strings.tr('note_hint')),
              ),
              const SizedBox(height: 28),
              BigButton(
                label: strings.tr('save'),
                icon: Icons.check_rounded,
                color:
                    _type == TxType.expense
                        ? AppColors.expense
                        : AppColors.income,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyDate(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final d = _date;
    final today = DateTime.now();
    String day;
    if (dateKey(d) == dateKey(today)) {
      day =
          strings.lang == 'ar'
              ? 'اليوم'
              : strings.lang == 'fr'
              ? "Aujourd'hui"
              : 'Today';
    } else if (dateKey(d) == dateKey(today.subtract(const Duration(days: 1)))) {
      day =
          strings.lang == 'ar'
              ? 'أمس'
              : strings.lang == 'fr'
              ? 'Hier'
              : 'Yesterday';
    } else {
      day = '${d.day} ${monthName(d.month, strings.lang)} ${d.year}';
    }
    return day;
  }

  Widget _typeButton(BuildContext context, String type) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    final selected = _type == type;
    final isExp = type == TxType.expense;
    final color = isExp ? AppColors.expense : AppColors.income;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _type = type;
          final hasInNew =
              _categoryId != null &&
              context.read<AppState>().categoryById(_categoryId)?.type == type;
          if (!hasInNew) _categoryId = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : (isExp
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded),
              size: 18,
              color: selected ? Colors.white : t.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              strings.tr(isExp ? 'expense' : 'income'),
              style: TextStyle(
                color: selected ? Colors.white : t.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fast "add" bottom sheet: amount + category + save (a few seconds).
Future<void> showQuickAdd(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  String _type = TxType.expense;
  final _amountCtrl = TextEditingController(text: '');
  final _amountFocus = FocusNode();
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final amount = parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _err('${strings.tr('amount')} > 0');
      return;
    }
    final cid = _categoryId ?? state.categoriesFor(_type).firstOrNull?.id;
    if (cid == null) {
      _err('${strings.tr('category')} ✱');
      return;
    }
    setState(() => _saving = true);
    await state.addTransaction(
      type: _type,
      amount: amount,
      categoryId: cid,
      paymentMethod: state.settings.lastPayment,
      date: DateTime.now(),
      note: null,
    );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('transaction_saved'))));
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: t.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _qt(context, TxType.expense)),
                        Expanded(child: _qt(context, TxType.income)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditScreen(type: _type),
                      ),
                    );
                  },
                  tooltip: strings.tr('new_transaction'),
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AmountField(
              controller: _amountCtrl,
              focusNode: _amountFocus,
              hint: '0',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  strings.tr('category'),
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final created = await showCreateCategory(context, _type);
                    if (created && mounted) setState(() {});
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(strings.tr('add_category')),
                ),
              ],
            ),
            CategoryPicker(
              type: _type,
              selectedId: _categoryId,
              recentIds: state.recentCategoryIds(_type),
              onSelected: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: 20),
            BigButton(
              label: strings.tr('save'),
              icon: Icons.check_rounded,
              color:
                  _type == TxType.expense
                      ? AppColors.expense
                      : AppColors.income,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _qt(BuildContext context, String type) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final selected = _type == type;
    final isExp = type == TxType.expense;
    final color = isExp ? AppColors.expense : AppColors.income;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _type = type;
          final ok =
              _categoryId != null &&
              state.categoryById(_categoryId)?.type == type;
          if (!ok) _categoryId = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          strings.tr(isExp ? 'expense' : 'income'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
