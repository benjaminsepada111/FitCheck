import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  // Singleton pattern - ensures only one instance exists
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // The notification plugin instance
  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // Track initialization status
  bool _isInitialized = false;

  // Notification IDs for different reminders
  static const int breakfastReminderId = 2001;
  static const int lunchReminderId = 2002;
  static const int snackReminderId = 2003;
  static const int dinnerReminderId = 2004;

  // Legacy IDs (keeping for backwards compatibility)
  static const int afternoonReminderId = 1001;
  static const int eveningReminderId = 1002;

  /// Initialize the notification service
  /// Call this once in main.dart
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone database for scheduling
      tz.initializeTimeZones();

      // Set local timezone (Asia/Manila for Philippines)
      final String timeZoneName = await _getLocalTimeZone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      // Android-specific settings
      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS-specific settings
      const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the plugin
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions for Android 13+ and iOS
      await _requestPermissions();

      // 🆕 Request exact alarm permission (Android 12+)
      final exactAlarmGranted = await requestExactAlarmPermission();
      if (!exactAlarmGranted) {
        debugPrint('⚠️ Cannot schedule exact alarms without permission');
      }

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');

      // Automatically schedule meal reminders on initialization
      await scheduleDailyMealReminders();
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
    }
  }

  /// Get local timezone (defaults to Asia/Manila for Philippines)
  Future<String> _getLocalTimeZone() async {
    try {
      return 'Asia/Manila';
    } catch (e) {
      return 'UTC';
    }
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    bool? granted;

    // Android 13+ permission request
    if (defaultTargetPlatform == TargetPlatform.android) {
      granted = await _notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // iOS permission request
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      granted = await _notifications
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    return granted ?? false;
  }

  /// Request exact alarm permission (Android 12+)
  Future<bool> requestExactAlarmPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        // Check if permission is already granted
        final status = await Permission.scheduleExactAlarm.status;

        if (status.isGranted) {
          debugPrint('✅ Exact alarm permission already granted');
          return true;
        }

        // Request permission
        final result = await Permission.scheduleExactAlarm.request();

        if (result.isGranted) {
          debugPrint('✅ Exact alarm permission granted');
          return true;
        } else if (result.isDenied) {
          debugPrint('⚠️ Exact alarm permission denied');
          return false;
        } else if (result.isPermanentlyDenied) {
          debugPrint('⚠️ Exact alarm permission permanently denied');
          return false;
        }
      } catch (e) {
        debugPrint('❌ Error requesting exact alarm permission: $e');
        return false;
      }
    }

    return true; // iOS doesn't need this
  }

  /// Handle notification tap events
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Show an instant notification (appears immediately)
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      debugPrint('⚠️ NotificationService not initialized');
      return;
    }

    try {
      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'instant_channel',
        'Instant Notifications',
        channelDescription: 'Notifications that appear immediately',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecond,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugPrint('✅ Notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  /// Schedule daily meal reminders at specific times
  Future<void> scheduleDailyMealReminders() async {
    if (!_isInitialized) {
      debugPrint('⚠️ NotificationService not initialized');
      return;
    }

    try {
      await cancelMealReminders();

      final now = tz.TZDateTime.now(tz.local);

      final mealReminders = [
        {
          'id': breakfastReminderId,
          'hour': 8,
          'minute': 0,
          'meal': 'Breakfast',
          'emoji': '🍳',
        },
        {
          'id': lunchReminderId,
          'hour': 12,
          'minute': 0,
          'meal': 'Lunch',
          'emoji': '🍱',
        },
        {
          'id': snackReminderId,
          'hour': 16,
          'minute': 0,
          'meal': 'Snack',
          'emoji': '🍎',
        },
        {
          'id': dinnerReminderId,
          'hour': 19,
          'minute': 0,
          'meal': 'Dinner',
          'emoji': '🍽️',
        },
      ];

      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'meal_reminder_channel',
        'Meal Reminders',
        channelDescription: 'Daily reminders to log your meals',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      for (final reminder in mealReminders) {
        var scheduledTime = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          reminder['hour'] as int,
          reminder['minute'] as int,
          0,
        );

        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }

        final mealName = reminder['meal'] as String;
        final emoji = reminder['emoji'] as String;

        await _notifications.zonedSchedule(
          reminder['id'] as int,
          '$emoji Meal Reminder',
          "Don't forget to log your $mealName in FitCheck!",
          scheduledTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'meal_reminder_${mealName.toLowerCase()}',
        );

        debugPrint(
            '✅ Scheduled $mealName reminder at ${reminder['hour']}:${(reminder['minute'] as int).toString().padLeft(2, '0')}');
      }

      debugPrint('✅ All daily meal reminders scheduled successfully');
    } catch (e) {
      debugPrint('❌ Error scheduling meal reminders: $e');
    }
  }

  /// Reschedule meal reminders
  Future<void> rescheduleOnReboot() async {
    debugPrint('🔄 Rescheduling meal reminders after reboot...');
    await scheduleDailyMealReminders();
  }

  /// Cancel all meal reminders
  Future<void> cancelMealReminders() async {
    try {
      await _notifications.cancel(breakfastReminderId);
      await _notifications.cancel(lunchReminderId);
      await _notifications.cancel(snackReminderId);
      await _notifications.cancel(dinnerReminderId);
      debugPrint('✅ All meal reminders cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling meal reminders: $e');
    }
  }

  /// Legacy: Schedule daily milestone reminders
  Future<void> scheduleDailyMilestoneReminders() async {
    if (!_isInitialized) {
      debugPrint('⚠️ NotificationService not initialized');
      return;
    }

    try {
      await cancelMilestoneReminder();

      final now = tz.TZDateTime.now(tz.local);

      var afternoonTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        14,
        0,
        0,
      );

      if (afternoonTime.isBefore(now)) {
        afternoonTime = afternoonTime.add(const Duration(days: 1));
      }

      var eveningTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        20,
        0,
        0,
      );

      if (eveningTime.isBefore(now)) {
        eveningTime = eveningTime.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'milestone_reminder_channel',
        'Milestone Reminders',
        channelDescription: 'Daily reminders to add milestone photos',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        afternoonReminderId,
        '📸 Milestone Reminder',
        "Don't forget to add your milestone photo today!",
        afternoonTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'milestone_reminder_afternoon',
      );

      await _notifications.zonedSchedule(
        eveningReminderId,
        '📸 Milestone Reminder',
        "You haven't added your milestone photo yet. Add it now!",
        eveningTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'milestone_reminder_evening',
      );

      debugPrint('✅ Daily milestone reminders scheduled: 2:00 PM and 8:00 PM');
    } catch (e) {
      debugPrint('❌ Error scheduling milestone reminders: $e');
    }
  }

  Future<void> showReminderNotification() async {
    await showInstantNotification(
      title: '📸 Milestone Reminder',
      body: "Don't forget to add your milestone photo today!",
      payload: 'milestone_reminder',
    );
  }

  Future<void> cancelMilestoneReminder() async {
    try {
      await _notifications.cancel(afternoonReminderId);
      await _notifications.cancel(eveningReminderId);
      debugPrint('✅ All milestone reminders cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling milestone reminders: $e');
    }
  }

  Future<void> showLogoutNotification() async {
    await showInstantNotification(
      title: 'You have logged out successfully',
      body: 'See you again soon, FitChecker!',
      payload: 'logout',
    );
  }

  Future<void> showMilestoneSavedNotification() async {
    await showInstantNotification(
      title: '✅ Milestone Saved!',
      body: 'Great job! Your progress has been recorded.',
      payload: 'milestone_saved',
    );
  }

  Future<void> showMealLoggedNotification(String mealType) async {
    await showInstantNotification(
      title: '✅ $mealType Logged!',
      body: 'Great job tracking your nutrition!',
      payload: 'meal_logged_${mealType.toLowerCase()}',
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('✅ All notifications cancelled');
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  Future<bool> areNotificationsEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  Future<void> debugPrintPendingNotifications() async {
    final pending = await getPendingNotifications();
    debugPrint('📋 Pending notifications: ${pending.length}');
    for (final notification in pending) {
      debugPrint('  - ID: ${notification.id}, Title: ${notification.title}');
    }
  }
}