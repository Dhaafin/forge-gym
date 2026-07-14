import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationManager {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
      );
    } catch (e) {
      debugPrint("NotificationManager: failed to initialize: $e");
    }

    // Request notification permission on Android 13+
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint("NotificationManager: failed to request permission: $e");
    }
  }

  static Future<void> showWorkoutNotification({
    required String title,
    required DateTime startTime,
  }) async {
    final workoutStartTimeInEpoch = startTime.millisecondsSinceEpoch;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'workout_session_channel',
      'Active Workout Session',
      channelDescription: 'Displays active workout stopwatch timer.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      usesChronometer: true,
      showWhen: true,
      when: workoutStartTimeInEpoch,
      onlyAlertOnce: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: 888, // Unique notification ID for workout session
        title: title,
        body: 'Workout in progress...',
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint("NotificationManager: failed to show notification: $e");
    }
  }

  static Future<void> cancelWorkoutNotification() async {
    try {
      await _notificationsPlugin.cancel(id: 888);
    } catch (e) {
      debugPrint("NotificationManager: failed to cancel notification: $e");
    }
  }
}
