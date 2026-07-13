import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
}

class ForegroundTaskHandler extends TaskHandler {
  SendPort? _sendPort;
  int _elapsedSeconds = 0;
  DateTime? _startTime;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    _startTime = timestamp;
    
    // Attempt to parse start time from data if provided
    final data = await FlutterForegroundTask.getData<String>(key: 'start_time');
    if (data != null) {
      _startTime = DateTime.tryParse(data) ?? timestamp;
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    if (_startTime != null) {
      _elapsedSeconds = timestamp.difference(_startTime!).inSeconds;
    } else {
      _elapsedSeconds++;
    }

    final duration = Duration(seconds: _elapsedSeconds);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    // Update notification content
    FlutterForegroundTask.updateService(
      notificationTitle: 'Forge — Session Active',
      notificationText: 'Duration: $minutes:$seconds',
    );

    // Send data back to UI (optional)
    sendPort?.send(_elapsedSeconds);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // Clean up resources when the task is destroyed
  }

  @override
  void onReceiveData(Object data) {
    // Handle data sent from the UI to the background task
    if (data is String) {
      // You can process custom commands here
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button press.
    // In our spec, the notification just opens the app, which is the default behavior if no action is specified, 
    // or if we defined a button, we can handle it here.
  }
}

class ForegroundServiceManager {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'forge_workout_session',
        channelName: 'Workout Session Tracking',
        channelDescription: 'Keeps your workout session active in the background.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 1000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> startService(String title, DateTime startTime) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Forge — Session Active',
        notificationText: 'Starting...',
        callback: startCallback,
      );
    }
    await FlutterForegroundTask.saveData(key: 'start_time', value: startTime.toIso8601String());
  }

  static Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
  }
}
