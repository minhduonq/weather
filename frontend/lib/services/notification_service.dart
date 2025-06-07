import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io' show Platform;

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    // Sử dụng icon mặc định của Android thay vì chuỗi rỗng
    const androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initSettings);
    await requestNotificationPermissions();
  }

  Future<void> requestNotificationPermissions() async {
    final iosImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      print('Notification permission granted: $granted');
    }

    // Request exact alarm permission for Android 12+
    final androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final exactAlarmPermissionGranted =
          await androidImplementation.requestExactAlarmsPermission();
      print('Exact alarm permission granted: $exactAlarmPermissionGranted');
    }
  }

  Future<void> scheduleDailyWeatherNotification({
    required String time,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required int id,
  }) async {
    try {
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final scheduledTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour,
        minute,
      );

      // Thử schedule với exactAllowWhileIdle trước
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'weather_channel',
            'Weather Notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print(
          'Weather notification scheduled with exact timing: $title at $scheduledTime');
    } catch (e) {
      print('Exact alarm not permitted, falling back to inexact: $e');

      // Fallback: sử dụng inexact scheduling
      try {
        final timeParts = time.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final scheduledTime = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          hour,
          minute,
        );

        await _flutterLocalNotificationsPlugin.zonedSchedule(
          0,
          title,
          body,
          tz.TZDateTime.from(scheduledTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'weather_channel',
              'Weather Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        print(
            'Weather notification scheduled with inexact timing: $title at $scheduledTime');
      } catch (fallbackError) {
        print('Failed to schedule notification: $fallbackError');
      }
    }
  }

  Future<void> scheduleNoteNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required DateTime reminderTime,
  }) async {
    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'note_channel',
            'Note Notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
      print(
          'Note notification scheduled with exact timing: $title at $scheduledTime');
    } catch (e) {
      print('Exact alarm not permitted for note, falling back to inexact: $e');

      // Fallback: sử dụng inexact scheduling
      try {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'note_channel',
              'Note Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
        print(
            'Note notification scheduled with inexact timing: $title at $scheduledTime');
      } catch (fallbackError) {
        print('Failed to schedule note notification: $fallbackError');
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    print('All notifications cancelled');
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'immediate_channel',
      'Immediate Notifications',
      importance: Importance.max,
      priority: Priority.high,
      // Sử dụng icon mặc định cho notification
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }
}
