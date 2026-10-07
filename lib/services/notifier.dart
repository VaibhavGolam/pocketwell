import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local due-date reminders. Everything happens on the phone, no server.
///
/// Reminders are scheduled as absolute moments in time (UTC), so there is no
/// need to look up the phone's time zone. 9:00 in the user's local time is
/// converted to an exact instant before it is handed to the plugin.
class Notifier {
  Notifier._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _askedPermission = false;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifier init failed: $e');
    }
  }

  /// Asks for permission once per app session, the first time a reminder is
  /// actually needed. We never ask on launch.
  static Future<void> _ensurePermission() async {
    if (_askedPermission) return;
    _askedPermission = true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: false, sound: true);
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  static Future<void> scheduleDue({
    required int personId,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(personId);
      if (when.isBefore(DateTime.now())) return;
      await _ensurePermission();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'dues',
          'Due reminders',
          channelDescription:
              'Reminders for money you will get or need to pay',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.zonedSchedule(
        personId,
        title,
        body,
        tz.TZDateTime.from(when, tz.UTC),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Could not schedule reminder: $e');
    }
  }

  static Future<void> cancelPerson(int personId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(personId);
    } catch (e) {
      debugPrint('Could not cancel reminder: $e');
    }
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Could not cancel reminders: $e');
    }
  }
}
