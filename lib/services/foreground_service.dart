import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Initialize foreground task settings (call once at app startup)
void initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'beatsync_workout',
      channelName: 'BeatSync Workout',
      channelDescription: 'Keeps heart rate tracking active during workout',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

/// Start the foreground service (call when workout starts)
Future<void> startForegroundService() async {
  await FlutterForegroundTask.requestNotificationPermission();

  await FlutterForegroundTask.startService(
    notificationTitle: 'BeatSync — Workout Active',
    notificationText: 'Heart rate tracking in progress',
    notificationIcon: null,
    callback: _foregroundCallback,
  );
}

/// Update the notification text (e.g., with current BPM)
Future<void> updateForegroundNotification(String text) async {
  await FlutterForegroundTask.updateService(
    notificationText: text,
  );
}

/// Stop the foreground service (call when workout ends)
Future<void> stopForegroundService() async {
  await FlutterForegroundTask.stopService();
}

// Required callback — we don't need a separate isolate task
@pragma('vm:entry-point')
void _foregroundCallback() {
  // No-op: we just need the service to keep the main isolate alive
}
