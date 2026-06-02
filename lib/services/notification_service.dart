import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin? _notifications;

  static const _settingsChannel = MethodChannel(
      'com.vkulakra.movo/settings');

  // Action IDs
  static const String actionTaskDone = 'task_done';
  static const String actionNotDone = 'not_done';

  // Notification IDs
  static const int _dailyReminderId = 1;
  static const int _taskDoneConfirmId = 2;
  static const int _weeklySummaryId = 3;

  // Pending responses for cold-start handling
  final List<NotificationResponse> _pendingResponses = [];
  void Function(NotificationResponse)? _onResponse;

  bool _initialized = false;

  NotificationService._() : _notifications = kIsWeb ? null : FlutterLocalNotificationsPlugin();

  /// Whether the current platform supports local notifications.
  /// flutter_local_notifications v18 supports Android, iOS, and macOS only.
  bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Whether the platform supports `zonedSchedule` for future-dated notifications.
  /// Android, iOS, and macOS support this.
  static bool get supportsScheduling {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Set the callback to handle notification responses (taps & action buttons).
  set onResponse(void Function(NotificationResponse)? handler) {
    _onResponse = handler;
    // Process any responses queued during cold start
    for (final response in _pendingResponses) {
      handler?.call(response);
    }
    _pendingResponses.clear();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (!isSupported) {
      _initialized = true;
      return;
    }

    // Initialize timezone data
    try {
      tz.initializeTimeZones();
      final offset = DateTime.now().timeZoneOffset;
      // Find a timezone name that matches the current offset
      final offsetSeconds = offset.inSeconds;
      final locationName = tz.timeZoneDatabase.locations.entries
          .where((e) => e.value.currentTimeZone.offset == offsetSeconds)
          .map((e) => e.key)
          .firstOrNull;
      if (locationName != null) {
        tz.setLocalLocation(tz.getLocation(locationName));
      } else {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (e) {
      debugPrint('Timezone init error: $e');
      // Set a safe default timezone
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {
        // If even UTC fails, fall back to local DateTime
      }
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
      linux: linuxSettings,
    );

    try {
      await _notifications!.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (_onResponse != null) {
      _onResponse!(response);
    } else {
      _pendingResponses.add(response);
    }
  }

  /// Request notification permissions on Android 13+.
  Future<bool> requestPermissions() async {
    if (!isSupported || _notifications == null) return false;
    try {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
    return true;
  }

  /// Build a status string about the scheduling capabilities for debugging.
  Future<String> schedulingStatus() async {
    if (!isSupported || !_initialized) return 'Not initialized';
    final buffer = StringBuffer();
    buffer.writeln('Initialized: $_initialized');
    buffer.writeln('Platform: $defaultTargetPlatform');
    buffer.writeln('Schedule mode: inexactAllowWhileIdle');
    return buffer.toString();
  }

  /// Open the system's app info page for this app, where the user can:
  /// - Disable battery optimization
  /// - Enable auto-launch (Realme/ColorOS specific)
  /// - Grant exact alarm permission
  Future<void> openAppSettings() async {
    try {
      await _settingsChannel.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('Open app settings error: $e');
    }
  }

  /// Open the battery optimization settings directly for this app.
  Future<void> openBatterySettings() async {
    try {
      await _settingsChannel.invokeMethod('openBatterySettings');
    } catch (e) {
      debugPrint('Open battery settings error: $e');
    }
  }

  /// Build the notification body text based on habit completion status.
  String _buildNotificationBody({
    required int totalHabits,
    required int completedHabits,
    required List<String> uncompletedHabitNames,
  }) {
    final remaining = totalHabits - completedHabits;

    if (totalHabits == 0) {
      // No habits yet — show a generic reminder
      return 'Time to check in with your habits!';
    } else if (remaining == 0) {
      // Celebration — all habits done!
      final messages = [
        'You crushed all $totalHabits habit${totalHabits > 1 ? 's' : ''} today! 🔥',
        'All $totalHabits done! You are unstoppable! 🚀',
        'Nailed it! Every habit checked off. 🌟',
        'Perfect day — all $totalHabits habit${totalHabits > 1 ? 's' : ''} complete! 🏆',
        '100%% today! You are a habit hero! 💪',
      ];
      return messages[completedHabits % messages.length];
    } else if (uncompletedHabitNames.isEmpty) {
      return 'You have $remaining habit${remaining > 1 ? 's' : ''} left today.';
    } else {
      final list = uncompletedHabitNames.take(3).join(', ');
      var body = 'Still to do: $list';
      if (uncompletedHabitNames.length > 3) {
        body += ' and ${uncompletedHabitNames.length - 3} more';
      }
      return body;
    }
  }

  /// Build the notification details — celebratory styling when all habits are done.
  NotificationDetails _buildNotificationDetails({
    required bool allDone,
    required List<String> uncompletedHabitNames,
  }) {
    if (allDone) {
      // Celebration — no action buttons needed
      final androidDetails = AndroidNotificationDetails(
        'habit_reminders',
        'Habit Reminders',
        channelDescription: 'Daily reminders to complete your habits',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        // Color the notification icon with Movo purple
        color: const Color.fromARGB(255, 108, 99, 255),
      );
      const iosDetails = DarwinNotificationDetails();
      return NotificationDetails(android: androidDetails, iOS: iosDetails);
    }

    // Reminder with action buttons
    final androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Daily reminders to complete your habits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: [
        AndroidNotificationAction(
          actionTaskDone,
          'Task Done',
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionNotDone,
          'Not Done',
          cancelNotification: true,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails();
    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Build the notification title — celebratory vs reminder.
  String _buildTitle(bool allDone, int totalHabits, int completedHabits) {
    if (totalHabits == 0) {
      return 'Movo Reminder';
    }
    if (allDone) {
      final titles = [
        '🎉 Amazing!',
        '🔥 Crushed It!',
        '🌟 Perfect Day!',
        '🏆 All Done!',
        '💪 Way To Go!',
      ];
      return titles[completedHabits % titles.length];
    }
    return 'Movo Reminder';
  }

  /// Show a daily reminder notification with action buttons,
  /// listing the user's uncompleted habits.
  Future<void> showReminderNotification({
    required int totalHabits,
    required int completedHabits,
    required List<String> uncompletedHabitNames,
  }) async {
    if (!isSupported || _notifications == null) return;

    final allDone = totalHabits > 0 && (totalHabits - completedHabits) == 0;
    final body = _buildNotificationBody(
      totalHabits: totalHabits,
      completedHabits: completedHabits,
      uncompletedHabitNames: uncompletedHabitNames,
    );
    final title = _buildTitle(allDone, totalHabits, completedHabits);
    final details = _buildNotificationDetails(
      allDone: allDone,
      uncompletedHabitNames: uncompletedHabitNames,
    );

    try {
      await _notifications.show(
        _dailyReminderId,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }

  /// Schedule a daily reminder notification at [hour]:[minute].
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required int totalHabits,
    required int completedHabits,
    required List<String> uncompletedHabitNames,
  }) async {
    if (!isSupported || _notifications == null || !_initialized) return;

    // Cancel any existing scheduled reminder
    await cancelScheduledReminder();

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final allDone = totalHabits > 0 && (totalHabits - completedHabits) == 0;
      final body = _buildNotificationBody(
        totalHabits: totalHabits,
        completedHabits: completedHabits,
        uncompletedHabitNames: uncompletedHabitNames,
      );
      final title = _buildTitle(allDone, totalHabits, completedHabits);
      final details = _buildNotificationDetails(
        allDone: allDone,
        uncompletedHabitNames: uncompletedHabitNames,
      );

      if (supportsScheduling) {
        await _notifications.zonedSchedule(
          _dailyReminderId,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } else {
        // On platforms without scheduling support, show immediately
        await _notifications.show(
          _dailyReminderId,
          title,
          body,
          details,
        );
      }
    } catch (e) {
      debugPrint('Schedule daily reminder error: $e');
    }
  }

  /// Build the weekly summary title/body content.
  ({String title, String body}) _buildWeeklySummaryContent(
      int daysAllDone, int totalDays) {
    final pct = totalDays > 0 ? (daysAllDone / totalDays * 100).round() : 0;

    String title;
    String body;
    if (daysAllDone == totalDays) {
      title = '🏆 Perfect Week!';
      body = 'You completed all habits every day this week! Incredible! 🔥';
    } else if (daysAllDone >= totalDays * 0.8) {
      title = '🌟 Amazing Week!';
      body =
          '$daysAllDone out of $totalDays days — all habits done! ($pct%) Keep it up! 💪';
    } else if (daysAllDone >= totalDays * 0.5) {
      title = '💪 Good Week!';
      body =
          '$daysAllDone out of $totalDays days with all habits done ($pct%). Room to improve next week! 🎯';
    } else if (daysAllDone > 0) {
      title = '📊 Weekly Summary';
      body =
          '$daysAllDone out of $totalDays days — you crushed all habits on those days. Let us make next week even better! 🚀';
    } else {
      title = '📊 Weekly Summary';
      body =
          'This week was tough — $daysAllDone out of $totalDays days with all habits done. Tomorrow is a fresh start! 🌅';
    }
    return (title: title, body: body);
  }

  /// Common channel details for weekly summary notifications.
  NotificationDetails _weeklySummaryDetails() {
    final androidDetails = AndroidNotificationDetails(
      'weekly_summary',
      'Weekly Summary',
      channelDescription: 'Weekly habit completion summary on Sundays',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: const Color.fromARGB(255, 108, 99, 255),
    );
    const iosDetails = DarwinNotificationDetails();
    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Show the weekly summary notification (can be called directly).
  Future<void> showWeeklySummaryNotification({
    required int daysAllDone,
    required int totalDays,
  }) async {
    if (!isSupported || _notifications == null) return;
    final content = _buildWeeklySummaryContent(daysAllDone, totalDays);
    try {
      await _notifications.show(
        _weeklySummaryId,
        content.title,
        content.body,
        _weeklySummaryDetails(),
      );
    } catch (e) {
      debugPrint('Show weekly summary error: $e');
    }
  }

  /// Schedule the weekly summary notification for the coming Sunday at [hour]:[minute].
  Future<void> scheduleWeeklySummary({
    required int hour,
    required int minute,
    required int daysAllDone,
    required int totalDays,
  }) async {
    if (!isSupported || _notifications == null || !_initialized) return;

    try {
      await _notifications.cancel(_weeklySummaryId);
    } catch (_) {}

    try {
      final now = tz.TZDateTime.now(tz.local);
      // Find the next Sunday
      final daysUntilSunday = (DateTime.sunday - now.weekday + 7) % 7;
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      scheduledDate = scheduledDate.add(Duration(days: daysUntilSunday));

      // If the time has already passed today (and today is Sunday), schedule for next Sunday
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      }

      final content = _buildWeeklySummaryContent(daysAllDone, totalDays);

      if (supportsScheduling) {
        await _notifications.zonedSchedule(
          _weeklySummaryId,
          content.title,
          content.body,
          scheduledDate,
          _weeklySummaryDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } else {
        // On platforms without scheduling support, show immediately
        await _notifications.show(
          _weeklySummaryId,
          content.title,
          content.body,
          _weeklySummaryDetails(),
        );
      }
    } catch (e) {
      debugPrint('Schedule weekly summary error: $e');
    }
  }

  /// Cancel the scheduled weekly summary.
  Future<void> cancelWeeklySummary() async {
    if (!isSupported || _notifications == null) return;
    try {
      await _notifications.cancel(_weeklySummaryId);
    } catch (_) {}
  }

  /// Cancel the scheduled daily reminder.
  Future<void> cancelScheduledReminder() async {
    if (!isSupported || _notifications == null) return;
    try {
      await _notifications.cancel(_dailyReminderId);
    } catch (_) {}
  }

  /// Show a confirmation notification after marking tasks as done.
  Future<void> showTaskDoneConfirmation(int count) async {
    if (!isSupported || _notifications == null) return;
    final androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Daily reminders to complete your habits',
      importance: Importance.low,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.show(
        _taskDoneConfirmId,
        '💪 Nice Work!',
        'Marked $count habit${count > 1 ? 's' : ''} as done.',
        details,
      );
    } catch (e) {
      debugPrint('Show task done confirmation error: $e');
    }
  }

  /// Send a test notification immediately to verify action buttons work.
  Future<void> sendTestNotification() async {
    if (!isSupported || _notifications == null) return;

    // Use a high-ID so it's distinct from the daily reminder
    const int testNotificationId = 999;

    const androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Daily reminders to complete your habits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: [
        AndroidNotificationAction(
          actionTaskDone,
          'Task Done',
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionNotDone,
          'Not Done',
          cancelNotification: true,
        ),
      ],
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.show(
        testNotificationId,
        '🧪 Test Notification',
        'Tap a button below to verify action buttons work. Expand this notification if buttons are hidden.',
        details,
      );
      debugPrint('Test notification sent successfully');
    } catch (e) {
      debugPrint('Send test notification error: $e');
    }
  }

  /// Schedule a test notification 1 minute from now to verify exact alarm scheduling.
  /// Uses the same exactAllowWhileIdle mode as the real daily reminder.
  Future<void> sendTestScheduledReminder() async {
    if (!isSupported || _notifications == null || !_initialized) return;

    const int testScheduleId = 1000;
    try {
      await _notifications.cancel(testScheduleId);
    } catch (_) {}

    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(const Duration(minutes: 1));

      const androidDetails = AndroidNotificationDetails(
        'habit_reminders',
        'Habit Reminders',
        channelDescription: 'Daily reminders to complete your habits',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        actions: [
          AndroidNotificationAction(
            actionTaskDone,
            'Task Done',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            actionNotDone,
            'Not Done',
            cancelNotification: true,
          ),
        ],
      );
      const details = NotificationDetails(android: androidDetails);

      if (supportsScheduling) {
        await _notifications.zonedSchedule(
          testScheduleId,
          '🧪 Scheduled Test',
          'This notification was scheduled 1 minute ago. Did it arrive? If not, please open ⚙ App Settings below to fix battery optimization.',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: null,
        );
      }
      debugPrint('Test scheduled reminder set for ${scheduledDate.hour}:${scheduledDate.minute}:${scheduledDate.second}');
    } catch (e) {
      debugPrint('Send test scheduled reminder error: $e');
    }
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    if (!isSupported || _notifications == null) return;
    try {
      await _notifications.cancelAll();
    } catch (_) {}
  }
}
