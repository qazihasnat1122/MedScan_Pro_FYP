import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Creates a testable instance with optional permission and schedule overrides.
  NotificationService.testable({
    Future<bool> Function()? permissionRequester,
    Future<bool> Function(
      int id,
      String title,
      String body,
      DateTime scheduledTime,
    )?
    scheduleOverride,
  }) : _permissionRequester = permissionRequester,
       _scheduleOverride = scheduleOverride;

  Future<bool> Function()? _permissionRequester;
  Future<bool> Function(
    int id,
    String title,
    String body,
    DateTime scheduledTime,
  )?
  _scheduleOverride;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  final Set<int> _scheduledNotificationIds = <int>{};

  Set<int> get scheduledNotificationIds =>
      Set<int>.unmodifiable(_scheduledNotificationIds);

  /// Generates a deterministic 31-bit notification ID for a user + medication + time slot
  /// so edits and retries replace the existing alarm instead of creating duplicate alarms.
  static int deterministicReminderId({
    required String userId,
    required String medicineName,
    required String timeSlot,
  }) {
    final key =
        '${userId.trim().toLowerCase()}|${medicineName.trim().toLowerCase()}|${timeSlot.trim().toUpperCase()}';
    var hash = 0x811c9dc5;
    for (var i = 0; i < key.length; i++) {
      hash ^= key.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    if (_permissionRequester != null || _scheduleOverride != null) {
      tz.initializeTimeZones();
      _isInitialized = true;
      return;
    }
    try {
      tz.initializeTimeZones();
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
          );
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notification clicked');
        },
      );

      final androidPlatform = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlatform != null) {
        await androidPlatform.requestNotificationsPermission();
        await androidPlatform.requestExactAlarmsPermission();
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (_permissionRequester != null) {
      return await _permissionRequester!();
    }
    await init();
    try {
      final androidPlatform = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlatform != null) {
        final res = await androidPlatform.requestNotificationsPermission();
        await androidPlatform.requestExactAlarmsPermission();
        return res ?? false;
      }
      final iosPlatform = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlatform != null) {
        final res = await iosPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return res ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
    return true;
  }

  Future<bool> showInstantAlarm({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'med_reminders_channel',
            'Medication Alarms & Reminders',
            channelDescription:
                'High priority alerts and alarms for medication doses',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
          );
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );
      await flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
      _scheduledNotificationIds.add(id);
      return true;
    } catch (e) {
      debugPrint('Error triggering instant alarm: $e');
      return false;
    }
  }

  /// Schedules a medication reminder and returns `true` ONLY when permission is granted
  /// and scheduling actually succeeds. Cancels any existing reminder with the same `id`
  /// first to prevent duplicate notifications.
  Future<bool> scheduleReminder(
    int id,
    String title,
    String body,
    DateTime scheduledTime,
  ) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      return false;
    }

    if (_scheduleOverride != null) {
      final ok = await _scheduleOverride!(id, title, body, scheduledTime);
      if (ok) {
        _scheduledNotificationIds.add(id);
      }
      return ok;
    }

    await init();
    try {
      // Cancel any existing notification with the same ID to avoid duplicates on edit/retry
      await cancelReminder(id);

      final now = DateTime.now();
      if (scheduledTime.isBefore(now.add(const Duration(seconds: 5)))) {
        return await showInstantAlarm(id: id, title: title, body: body);
      }

      final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'med_reminders_channel',
            'Medication Alarms & Reminders',
            channelDescription:
                'High priority alerts and alarms for medication doses',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
          );
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduled,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      _scheduledNotificationIds.add(id);
      return true;
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
      return false;
    }
  }

  Future<void> cancelReminder(int id) async {
    _scheduledNotificationIds.remove(id);
    if (_scheduleOverride != null) return;
    try {
      await flutterLocalNotificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('Error canceling notification: $e');
    }
  }

  Future<void> cancelAllReminders() async {
    _scheduledNotificationIds.clear();
    if (_scheduleOverride != null) return;
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }
}
