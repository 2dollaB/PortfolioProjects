import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 6.4 — Local notification service
/// Handles:
///   - Daily workout reminder (user-set time)
///   - Streak milestone alerts (3, 7, 14, 30 days)
///   - Post-workout recovery reminders
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelIdReminder = 'beatsync_reminder';
  static const _channelIdStreak   = 'beatsync_streak';
  static const _channelIdRecovery = 'beatsync_recovery';
  static const _prefReminderEnabled = 'notif_reminder_enabled';
  static const _prefReminderHour    = 'notif_reminder_hour';
  static const _prefReminderMin     = 'notif_reminder_min';

  static const _idDailyReminder = 1;
  static const _idStreak        = 2;
  static const _idRecovery      = 3;

  // ══════════════════════════════════════════════
  // Init
  // ══════════════════════════════════════════════

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
    debugPrint('[Notifications] Initialized');
  }

  static Future<bool> requestPermission() async {
    try {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // Saved preferences
  // ══════════════════════════════════════════════

  static Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefReminderEnabled) ?? false;
  }

  static Future<TimeOfDay> reminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_prefReminderHour) ?? 7,
      minute: prefs.getInt(_prefReminderMin) ?? 0,
    );
  }

  static Future<void> saveReminderTime(TimeOfDay t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefReminderHour, t.hour);
    await prefs.setInt(_prefReminderMin, t.minute);
  }

  // ══════════════════════════════════════════════
  // Daily reminder
  // ══════════════════════════════════════════════

  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await cancelDailyReminder();
    await saveReminderTime(time);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefReminderEnabled, true);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _idDailyReminder,
      '💓 Time to train!',
      'Your heart is ready. Start a workout and crush your streak.',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdReminder,
          'Daily Reminder',
          channelDescription: 'Daily workout reminder',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('[Notifications] Daily reminder set at ${time.hour}:${time.minute}');
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_idDailyReminder);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefReminderEnabled, false);
  }

  // ══════════════════════════════════════════════
  // Streak milestone
  // ══════════════════════════════════════════════

  static Future<void> showStreakMilestone(int streak) async {
    final milestones = {
      3:  ('🏅 3-Day Streak!',  "You're building a habit. Keep it up!"),
      7:  ('🔥 One Week Streak!', "A full week of consistency. You're on fire!"),
      14: ('⚡ 2-Week Streak!',  'Half a month of training. Incredible discipline!'),
      30: ('🏆 30-Day Streak!', 'One month of daily effort. You are a champion.'),
    };

    if (milestones.containsKey(streak)) {
      final (title, body) = milestones[streak]!;
      await _plugin.show(
        _idStreak,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelIdStreak,
            'Streak Milestones',
            channelDescription: 'Workout streak achievements',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      debugPrint('[Notifications] Streak milestone shown: $streak days');
    }
  }

  // ══════════════════════════════════════════════
  // Post-workout recovery reminder
  // ══════════════════════════════════════════════

  static Future<void> scheduleRecoveryReminder({int hoursAfter = 12}) async {
    await _plugin.cancel(_idRecovery);

    final scheduled = tz.TZDateTime.now(tz.local)
        .add(Duration(hours: hoursAfter));

    await _plugin.zonedSchedule(
      _idRecovery,
      '🧘 Recovery Check-in',
      "How's your body feeling? Log another session when you're ready.",
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdRecovery,
          'Recovery Reminders',
          channelDescription: 'Post-workout recovery nudge',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('[Notifications] Recovery reminder in ${hoursAfter}h');
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
