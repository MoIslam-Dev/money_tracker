import 'dart:io';
// ignore_for_file: use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/settings_store.dart';
import '../utils/backup.dart';
import '../models/currency.dart';
import '../utils/excel_export.dart';
import 'categories_screen.dart';
import 'notification_settings_screen.dart';

enum _CurrencyChoice { keep, convert }

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.tr('settings'),
          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _sectionLabel(context, strings.tr('currency')),
            _tile(
              context,
              icon: Icons.payments_rounded,
              title: strings.tr('currency'),
              trailing: Text(state.currencyLabel),
              onTap: () => _pickCurrency(context),
            ),
            _sectionLabel(context, strings.tr('language')),
            _langRow(context),
            _sectionLabel(context, strings.tr('theme')),
            _themeRow(context),
            _sectionLabel(context, strings.tr('statistics')),
            _habitsWeeksRow(context),
            _sectionLabel(context, strings.tr('security')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.lock_rounded),
              title: Text(strings.tr('app_lock')),
              subtitle: Text(strings.tr('on_off')),
              value: state.settings.lockEnabled,
              onChanged: (v) async {
                if (v && !state.settings.hasPin) {
                  final ok = await _setPin(context);
                  if (!ok) return;
                }
                await state.setLockEnabled(v);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pin_rounded),
              title: Text(
                strings.tr(state.settings.hasPin ? 'change_pin' : 'set_pin'),
              ),
              onTap: () => _setPin(context),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.fingerprint_rounded),
              title: Text(strings.tr('biometrics')),
              subtitle: Text(strings.tr('use_biometrics')),
              value: state.settings.useBiometrics,
              onChanged: (v) async {
                if (v && !await _biometricsAvailable()) {
                  _toast(context, strings.tr('biometrics_unavailable'));
                  return;
                }
                await state.setUseBiometrics(v);
              },
            ),
            _sectionLabel(context, strings.tr('categories')),
            _tile(
              context,
              icon: Icons.category_rounded,
              title: strings.tr('categories'),
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  ),
            ),
            _sectionLabel(context, strings.tr('notifications')),
            _tile(
              context,
              icon: Icons.notifications_rounded,
              title: strings.tr('daily_reminders'),
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
            ),
            _sectionLabel(context, strings.tr('data')),
            _tile(
              context,
              icon: Icons.table_view_rounded,
              title: strings.tr('export_excel'),
              onTap: () => _exportExcel(context),
            ),
            _tile(
              context,
              icon: Icons.upload_file_rounded,
              title: strings.tr('export_csv'),
              onTap: () => _export(context, csv: true),
            ),
            _tile(
              context,
              icon: Icons.file_download_rounded,
              title: strings.tr('export_json'),
              onTap: () => _export(context, csv: false),
            ),
            _tile(
              context,
              icon: Icons.backup_rounded,
              title: strings.tr('backup_create'),
              onTap: () async {
                final path = await exportJson(context.read<AppState>());
                _toast(context, '${strings.tr('backup_created')}\n$path');
              },
            ),
            _tile(
              context,
              icon: Icons.settings_backup_restore_rounded,
              title: strings.tr('restore'),
              onTap: () => _restore(context),
            ),
            _tile(
              context,
              icon: Icons.delete_forever_rounded,
              title: strings.tr('delete_all'),
              color: Theme.of(context).colorScheme.error,
              onTap: () => _deleteAll(context),
            ),
            _tile(
              context,
              icon: Icons.auto_awesome_rounded,
              title: strings.tr(
                state.settings.demoAdded ? 'remove_demo' : 'load_demo',
              ),
              onTap: () async {
                final st = context.read<AppState>();
                if (st.settings.demoAdded) {
                  await st.removeDemoData();
                } else {
                  await st.addDemoData();
                }
                _toast(context, strings.tr('transaction_saved'));
              },
            ),
            _sectionLabel(context, strings.tr('about')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_rounded),
              title: Text(
                '${strings.tr('app_name')} — ${strings.tr('version')} 1.1.0',
              ),
              subtitle: Text(strings.tr('made_by')),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: t.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: t.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    Color? color,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _langRow(BuildContext context) {
    final state = context.watch<AppState>();
    final options = {'fr': 'Français', 'en': 'English', 'ar': 'العربية'};
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: state.settings.lang == e.key,
            onSelected: (_) => state.setLang(e.key),
          ),
      ],
    );
  }

  Widget _habitsWeeksRow(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.tr('habits_window'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in [4, 8, 12])
                ChoiceChip(
                  label: Text(
                    strings.tr('weeks').replaceAll('{n}', '$w'),
                  ),
                  selected: state.settings.spendingHabitsWeeks == w,
                  onSelected: (_) => state.setSpendingHabitsWeeks(w),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCurrency(BuildContext context) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final all = [...state.currencies];
    if (!all.any((c) => c.code == state.currency)) {
      all.add(state.activeCurrency);
    }
    final sel = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    strings.tr('currency'),
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                for (final c in all)
                  ListTile(
                    leading: Text(
                      c.symbol,
                      style: const TextStyle(fontSize: 20),
                    ),
                    title: Text(
                      "${c.code} · ${c.localizedName(state.settings.lang)}",
                    ),
                    subtitle: Text(_currencyLocalized(c, state.settings.lang)),
                    trailing:
                        state.currency == c.code
                            ? const Icon(
                              Icons.check_rounded,
                              color: Colors.green,
                            )
                            : null,
                    onTap: () => Navigator.pop(ctx, c.code),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: Text(strings.tr('add_custom_currency')),
                  onTap: () async {
                    final code = await _addCustomCurrency(ctx);
                    if (code != null && ctx.mounted) Navigator.pop(ctx, code);
                  },
                ),
              ],
            ),
          ),
    );
    if (sel != null) {
      await _applyCurrencyChange(context, sel);
    }
  }

  Future<String?> _addCustomCurrency(BuildContext context) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final codeCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final nameFrCtrl = TextEditingController();
    final nameArCtrl = TextEditingController();
    var symbolBefore = false;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(strings.tr('add_custom_currency')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    labelText: strings.tr('currency_code'),
                  ),
                  textAlignVertical: TextAlignVertical.center,
                  textCapitalization: TextCapitalization.characters,
                ),
                TextField(
                  controller: symbolCtrl,
                  decoration: InputDecoration(
                    labelText: strings.tr('currency_symbol'),
                  ),
                ),
                TextField(
                  controller: nameEnCtrl,
                  decoration: InputDecoration(
                    labelText: strings.tr('currency_name'),
                  ),
                  textDirection: TextDirection.ltr,
                ),
                TextField(
                  controller: nameFrCtrl,
                  decoration: InputDecoration(
                    labelText: strings.tr('category_name_fr'),
                  ),
                  textDirection: TextDirection.ltr,
                ),
                TextField(
                  controller: nameArCtrl,
                  decoration: InputDecoration(
                    labelText: strings.tr('category_name_ar'),
                  ),
                  textDirection: TextDirection.rtl,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.tr('symbol_before_amount')),
                  value: symbolBefore,
                  onChanged: (v) => symbolBefore = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.tr('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final code = codeCtrl.text.trim().toUpperCase();
                if (!RegExp(r'^[A-Za-z0-9]{2,12}$').hasMatch(code)) {
                  _toast(ctx, strings.tr('currency_code'));
                  return;
                }
                if (state.currencies.any((c) => c.code == code)) {
                  _toast(ctx, strings.tr('currency_code'));
                  return;
                }
                final c = customCurrency(
                  code,
                  symbol: symbolCtrl.text.trim(),
                  symbolBefore: symbolBefore,
                  nameEn: nameEnCtrl.text.trim(),
                  nameFr: nameFrCtrl.text.trim(),
                  nameAr: nameArCtrl.text.trim(),
                );
                await state.addCustomCurrency(c);
                if (ctx.mounted) Navigator.pop(ctx, code);
              },
              child: Text(strings.tr('currency_saved')),
            ),
          ],
        );
      },
    );
    codeCtrl.dispose();
    symbolCtrl.dispose();
    nameEnCtrl.dispose();
    nameFrCtrl.dispose();
    nameArCtrl.dispose();
    return result;
  }

  Future<void> _applyCurrencyChange(BuildContext context, String code) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    if (code == state.currency) return;
    final oldCount =
        state.transactions.where((t) => t.currency == state.currency).length;
    if (oldCount == 0) {
      await state.setCurrency(code);
      _toast(context, strings.tr('currency_saved'));
      return;
    }
    final choice = await showDialog<_CurrencyChoice>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(strings.tr('currency_history')),
            content: Text(strings.tr('currency_keep_desc')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(strings.tr('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _CurrencyChoice.keep),
                child: Text(strings.tr('currency_keep')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, _CurrencyChoice.convert),
                child: Text(strings.tr('currency_convert')),
              ),
            ],
          ),
    );
    if (choice == null) return;
    if (choice == _CurrencyChoice.keep) {
      await state.setCurrency(code);
      _toast(context, strings.tr('currency_saved'));
      return;
    }
    final rate = await _askConversionRate(context, state.currency, code);
    if (rate == null) return;
    final ok = await state.setCurrency(
      code,
      mode: CurrencyChangeMode.convert,
      rate: rate,
    );
    if (ok) {
      _toast(context, strings.tr('currency_saved'));
    } else {
      _toast(context, strings.tr('currency_convert_error'));
    }
  }

  Future<double?> _askConversionRate(
    BuildContext context,
    String from,
    String to,
  ) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final ctrl = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(strings.tr('conversion_rate')),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: state.currencyLabelFor(from),
                suffixText: '→ ${state.currencyLabelFor(to)}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(strings.tr('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final parsed = double.tryParse(
                    ctrl.text.trim().replaceAll(',', '.'),
                  );
                  if (parsed != null && parsed > 0) {
                    Navigator.pop(ctx, parsed);
                  } else {
                    _toast(ctx, strings.tr('currency_convert_error'));
                  }
                },
                child: Text(strings.tr('currency_convert')),
              ),
            ],
          ),
    );
    ctrl.dispose();
    return result;
  }

  String _currencyLocalized(AppCurrency c, String lang) {
    if (lang == 'fr') return c.nameFr;
    if (lang == 'ar') return c.nameAr;
    return c.nameEn;
  }

  Widget _themeRow(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final options = {
      'light': strings.tr('light'),
      // 'system' deliberately removed: the app now follows the device by
      // default until the user picks light or dark explicitly.
      'dark': strings.tr('dark'),
    };
    return SegmentedButton<String>(
      segments: [
        for (final e in options.entries)
          ButtonSegment(value: e.key, label: Text(e.value)),
      ],
      selected: {state.settings.theme},
      onSelectionChanged: (s) => state.setTheme(s.first),
    );
  }

  Future<bool> _setPin(BuildContext context) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    var error = '';
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setState) => AlertDialog(
                  title: Text(strings.tr('set_pin')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: c1,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        decoration: InputDecoration(
                          labelText: strings.tr('enter_pin'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: c2,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        onChanged: (_) => setState(() => error = ''),
                        decoration: InputDecoration(
                          labelText: strings.tr('enter_pin'),
                        ),
                      ),
                      if (error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(strings.tr('cancel')),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (c1.text.length != 4) {
                          setState(() => error = strings.tr('wrong_pin'));
                        } else if (c1.text != c2.text) {
                          setState(() => error = strings.tr('wrong_pin'));
                        } else {
                          state.settings.setPin(sha256Hex(c1.text));
                          Navigator.pop(ctx, true);
                        }
                      },
                      child: Text(strings.tr('saveexp')),
                    ),
                  ],
                ),
          ),
    );
    return ok ?? false;
  }

  Future<bool> _biometricsAvailable() async {
    final auth = LocalAuthentication();
    return auth.isDeviceSupported();
  }

  Future<void> _export(BuildContext context, {required bool csv}) async {
    final state = context.read<AppState>();
    try {
      final path = csv ? await exportCsv(state) : await exportJson(state);
      _toast(context, '${state.strings.tr('exported_to')} $path');
    } catch (e) {
      _toast(context, 'Error: $e');
    }
  }

  Future<void> _exportExcel(BuildContext context) async {
    final state = context.read<AppState>();
    try {
      final path = await exportExcel(state);
      _toast(context, '${state.strings.tr('exported_to')} $path');
    } catch (e) {
      _toast(context, 'Error: $e');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final raw = await file.readAsString();
      final backup = BackupFile.parse(raw);
      await state.repo.replaceAll(
        categories: backup.categories(),
        transactions: backup.transactions(),
        budgets: backup.budgets(),
        goals: backup.goals(),
        recurring: backup.recurring(),
      );
      state.settings.setDemoAdded(false);
      await state.refresh();
      _toast(context, strings.tr('restore_done'));
    } catch (e) {
      _toast(context, '${strings.tr('restore_error')}: $e');
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final ctrl = TextEditingController();
    await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(strings.tr('delete_all')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.tr('delete_all_confirm')),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    helperText: strings.tr('type_confirm'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(strings.tr('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () async {
                  if (ctrl.text.trim().toUpperCase() != 'DELETE') return;
                  await state.deleteAll();
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: Text(strings.tr('delete_all')),
              ),
            ],
          ),
    );
  }
}
