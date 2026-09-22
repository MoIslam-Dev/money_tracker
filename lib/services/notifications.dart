import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../state/settings_store.dart';
import 'notification_copy.dart';

/// Schedules the daily reminder notifications completely offline on the device.
///
/// Reminders are re-scheduled automatically after a device reboot by the
/// plugin's boot receiver. Changing a slot cancels everything and reschedules,
/// which avoids duplicates.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'daily_reminders';
  static const _channelName = 'Daily reminders';
  static const _channelDesc = 'Reminders to log your transactions';
  static const _baseIds = {'morning': 101, 'midday': 102, 'evening': 103};

  /// Initializes the plugin and local timezone. Never requests permissions.
  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      if (info.identifier.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(info.identifier));
      }
    } catch (_) {
      // keep the default location (UTC is acceptable as a fallback)
    }
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (!_ready) await init();
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await impl?.requestNotificationsPermission() ?? true;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
        ),
      );

  /// Drops all pending reminders, then schedules one weekly notification per
  /// enabled slot and weekday so the copy rotates through the variants.
  Future<void> apply({
    required bool enabled,
    required List<NotifSlot> slots,
    required String lang,
  }) async {
    if (!_ready) await init();
    await _plugin.cancelAll();
    if (!enabled) return;
    for (final slot in slots) {
      if (!slot.enabled) continue;
      final baseId = _baseIds[slot.key] ?? 100;
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
        final scheduled = _nextInstance(slot.hour, slot.minute, weekday);
        await _plugin.zonedSchedule(
          baseId * 10 + weekday,
          NotificationCopy.title(lang, slot.key),
          NotificationCopy.body(lang, slot.key, weekday),
          scheduled,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) await init();
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstance(int hour, int minute, int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (d.weekday != weekday || d.isBefore(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }
}

/// Formats a slot time as `HH:mm`.
String formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';