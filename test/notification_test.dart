import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/services/notification_copy.dart';
import 'package:money_tracker/services/notifications.dart';
import 'package:money_tracker/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationCopy', () {
    test('exposes the three daily slots', () {
      expect(NotificationCopy.slots, ['morning', 'midday', 'evening']);
    });

    test('titles are localized with English fallback', () {
      for (final lang in ['en', 'fr', 'ar']) {
        for (final slot in NotificationCopy.slots) {
          expect(NotificationCopy.title(lang, slot), isNotEmpty);
        }
      }
      expect(NotificationCopy.title('de', 'morning'),
          NotificationCopy.title('en', 'morning'));
    });

    test('bodies rotate with the weekday and wrap around', () {
      for (final lang in ['en', 'fr', 'ar']) {
        final monday = NotificationCopy.body(lang, 'morning', 1);
        final tuesday = NotificationCopy.body(lang, 'morning', 2);
        final wednesday = NotificationCopy.body(lang, 'morning', 3);
        final thursday = NotificationCopy.body(lang, 'morning', 4);
        expect(thursday, monday);
        expect({monday, tuesday, wednesday}.length, 3);
      }
      expect(NotificationCopy.body('de', 'evening', 1),
          NotificationCopy.body('en', 'evening', 1));
    });

    test('each slot has distinct copy for the same weekday', () {
      final morning = NotificationCopy.body('en', 'morning', 1);
      final midday = NotificationCopy.body('en', 'midday', 1);
      final evening = NotificationCopy.body('en', 'evening', 1);
      expect({morning, midday, evening}.length, 3);
    });
  });

  test('formatTime pads to HH:mm', () {
    expect(formatTime(8, 0), '08:00');
    expect(formatTime(11, 5), '11:05');
    expect(formatTime(18, 30), '18:30');
  });

  group('SettingsStore notifications', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to three enabled slots at 08:00 / 11:00 / 18:00', () async {
      final store = SettingsStore();
      await store.load();
      expect(store.notifEnabled, isFalse);
      expect(store.notifSlots.length, 3);
      expect(store.notifSlots[0].key, 'morning');
      expect(store.notifSlots[0].hour, 8);
      expect(store.notifSlots[1].hour, 11);
      expect(store.notifSlots[2].hour, 18);
      expect(store.notifSlots.every((s) => s.enabled), isTrue);
    });

    test('slot edits and the master switch persist across a reload', () async {
      final store = SettingsStore();
      await store.load();
      store.setNotifEnabled(true);
      store.setSlot(1, enabled: false, hour: 12, minute: 30);
      store.setSlot(2, hour: 19);
      await store.save();

      final reloaded = SettingsStore();
      await reloaded.load();
      expect(reloaded.notifEnabled, isTrue);
      expect(reloaded.notifSlots[1].enabled, isFalse);
      expect(reloaded.notifSlots[1].hour, 12);
      expect(reloaded.notifSlots[1].minute, 30);
      expect(reloaded.notifSlots[2].hour, 19);
      expect(reloaded.notifSlots[0].enabled, isTrue);
    });

    test('last payment method persists', () async {
      final store = SettingsStore();
      await store.load();
      store.setLastPayment('card');
      await store.save();

      final reloaded = SettingsStore();
      await reloaded.load();
      expect(reloaded.lastPayment, 'card');
    });
  });
}
