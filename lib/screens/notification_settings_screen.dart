import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notifications.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _slotIcons = [
    Icons.wb_sunny_rounded,
    Icons.bolt_rounded,
    Icons.nights_stay_rounded,
  ];

  Future<void> _apply({bool confirm = false}) async {
    final state = context.read<AppState>();
    setState(() {});
    try {
      await NotificationService.instance.apply(
        enabled: state.settings.notifEnabled,
        slots: state.settings.notifSlots,
        lang: state.strings.lang,
      );
      if (confirm && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.strings.tr('daily_reminders'))),
        );
      }
    } catch (_) {
      // Reminders simply stay disabled if scheduling fails (e.g. no permission).
    }
  }

  Future<bool> _requestPermission() async {
    try {
      return await NotificationService.instance.requestPermission();
    } catch (_) {
      return false;
    }
  }

  void _showPermissionDialog(BuildContext context) {
    final strings = context.read<AppState>().strings;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.tr('notifications')),
        content: Text(strings.tr('permission_needed')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.tr('ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMaster(bool v) async {
    final state = context.read<AppState>();
    if (v) {
      final granted = await _requestPermission();
      if (!granted && mounted) _showPermissionDialog(context);
    }
    state.settings.setNotifEnabled(v);
    await _apply(confirm: v);
  }

  Future<void> _toggleSlot(int index, bool v) async {
    final state = context.read<AppState>();
    if (v && !state.settings.notifEnabled) {
      final granted = await _requestPermission();
      if (!granted && mounted) _showPermissionDialog(context);
      state.settings.setNotifEnabled(true);
    }
    state.settings.setSlot(index, enabled: v);
    await _apply();
  }

  Future<void> _pickTime(int index) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final slot = state.settings.notifSlots[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: slot.hour, minute: slot.minute),
      helpText: strings.tr('time'),
    );
    if (picked != null) {
      state.settings.setSlot(index, hour: picked.hour, minute: picked.minute);
      await _apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final t = Theme.of(context);
    final settings = state.settings;
    final slotKeys = ['slot_morning', 'slot_midday', 'slot_evening'];

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('daily_reminders'),
            style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(strings.tr('notif_intro'),
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            SectionCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Icon(Icons.notifications_active_rounded,
                    color: settings.notifEnabled
                        ? t.colorScheme.primary
                        : t.colorScheme.onSurfaceVariant),
                title: Text(strings.tr('daily_reminders'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                value: settings.notifEnabled,
                onChanged: _toggleMaster,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < settings.notifSlots.length; i++) ...[
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Icon(_slotIcons[i], color: t.colorScheme.primary),
                      title: Text(strings.tr(slotKeys[i])),
                      subtitle: Text(settings.notifSlots[i].enabled
                          ? formatTime(settings.notifSlots[i].hour, settings.notifSlots[i].minute)
                          : strings.tr('on_off')),
                      value: settings.notifSlots[i].enabled,
                      onChanged: (v) => _toggleSlot(i, v),
                    ),
                    if (settings.notifSlots[i].enabled)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        leading: const Icon(Icons.schedule_rounded),
                        title: Text(strings.tr('time')),
                        trailing: Text(
                          formatTime(settings.notifSlots[i].hour, settings.notifSlots[i].minute),
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _pickTime(i),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}