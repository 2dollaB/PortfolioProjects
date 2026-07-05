import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Foreground services are an Android concept. On iOS, background HR
/// tracking is covered by the `bluetooth-central` UIBackgroundModes entry
/// in Info.plist instead — every entry point below no-ops off Android.
bool get _isAndroid => !kIsWeb && Platform.isAndroid;

/// Initialize foreground task settings (call once at app startup)
void initForegroundTask() {
  if (!_isAndroid) return;
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
  if (!_isAndroid) return;
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
  if (!_isAndroid) return;
  await FlutterForegroundTask.updateService(
    notificationText: text,
  );
}

/// Stop the foreground service (call when workout ends)
Future<void> stopForegroundService() async {
  if (!_isAndroid) return;
  await FlutterForegroundTask.stopService();
}

// Required callback — we don't need a separate isolate task
@pragma('vm:entry-point')
void _foregroundCallback() {
  // No-op: we just need the service to keep the main isolate alive
}
