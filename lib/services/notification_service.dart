import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_project/services/notification_storage_service.dart';

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

  /// Get notification ID for meal type
  int _getMealReminderId(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return breakfastReminderId;
      case 'Lunch':
        return lunchReminderId;
      case 'Snack':
        return snackReminderId;
      case 'Dinner':
        return dinnerReminderId;
      default:
        return breakfastReminderId;
    }
  }

  /// Get meal emoji
  String _getMealEmoji(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return '🍳';
      case 'Lunch':
        return '🍱';
      case 'Snack':
        return '🍎';
      case 'Dinner':
        return '🍽️';
      default:
        return '🔔';
    }
  }

  /// Get meal asset path
  String _getMealAssetPath(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 'assets/images/breakfast.jpg';
      case 'lunch':
        return 'assets/images/lunch.jpg';
      case 'snack':
        return 'assets/images/snack.jpg';
      case 'dinner':
        return 'assets/images/dinner.jpg';
      default:
        return 'assets/images/snack.jpg';
    }
  }

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

      // iOS-specific settings with action categories
      final DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            'meal_reminder_category',
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                'log_now',
                'Log Now',
              ),
            ],
          ),
        ],
      );

      // Combined initialization settings
      final InitializationSettings initSettings = InitializationSettings(
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

      // Request exact alarm permission (Android 12+)
      final exactAlarmGranted = await requestExactAlarmPermission();
      if (!exactAlarmGranted) {
        debugPrint('⚠️ Cannot schedule exact alarms without permission');
      }

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');

      // 🆕 Load and apply saved notification settings (or use defaults)
      await _loadAndApplySavedSettings();
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
    }
  }

  /// 🆕 Load saved settings and apply them, or use defaults
  Future<void> _loadAndApplySavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if user has ever customized settings
      final hasCustomSettings = prefs.containsKey('breakfast_enabled');

      if (hasCustomSettings) {
        debugPrint('📱 Loading custom notification settings...');

        // Load and schedule each meal based on saved preferences
        await _scheduleFromSavedPreferences('Breakfast', prefs);
        await _scheduleFromSavedPreferences('Lunch', prefs);
        await _scheduleFromSavedPreferences('Snack', prefs);
        await _scheduleFromSavedPreferences('Dinner', prefs);

        // Load milestone settings
        final milestoneEnabled = prefs.getBool('milestone_enabled') ?? false;
        if (milestoneEnabled) {
          final hour = prefs.getInt('milestone_hour') ?? 20;
          final minute = prefs.getInt('milestone_minute') ?? 0;
          await scheduleMilestoneReminderAt(hour, minute);
        }

        debugPrint('✅ Custom notification settings applied');
      } else {
        debugPrint('📱 No custom settings found, using defaults...');
        // Use default scheduling (original behavior)
        await scheduleDailyMealReminders();
      }
    } catch (e) {
      debugPrint('❌ Error loading saved settings, using defaults: $e');
      // Fallback to default scheduling if there's an error
      await scheduleDailyMealReminders();
    }
  }

  /// 🆕 Helper to schedule a meal from saved preferences
  Future<void> _scheduleFromSavedPreferences(
      String mealType,
      SharedPreferences prefs,
      ) async {
    final mealLower = mealType.toLowerCase();
    final isEnabled = prefs.getBool('${mealLower}_enabled') ?? true;

    if (isEnabled) {
      final hour = prefs.getInt('${mealLower}_hour') ??
          _getDefaultHour(mealType);
      final minute = prefs.getInt('${mealLower}_minute') ?? 0;
      await scheduleMealReminder(mealType, hour, minute);
    } else {
      await cancelMealReminderByType(mealType);
    }
  }

  /// Get default hour for meal type
  int _getDefaultHour(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return 8;
      case 'Lunch':
        return 12;
      case 'Snack':
        return 16;
      case 'Dinner':
        return 19;
      default:
        return 12;
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

  /// Copy asset image to temporary directory and return file path
  Future<String?> _getAssetImagePath(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = assetPath.split('/').last;
      final File tempFile = File('${tempDir.path}/$fileName');

      await tempFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );

      debugPrint('✅ Asset copied to: ${tempFile.path}');
      return tempFile.path;
    } catch (e) {
      debugPrint('❌ Error copying asset image: $e');
      return null;
    }
  }

  /// Handle notification tap events
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');

    // Handle action button clicks
    if (response.actionId == 'log_now') {
      debugPrint('🔘 Log Now button tapped');
      // You can add navigation logic here or use a callback
    }
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

  /// 🆕 Schedule a single meal reminder at custom time
  Future<void> scheduleMealReminder(
      String mealType,
      int hour,
      int minute,
      ) async {
    if (!_isInitialized) {
      debugPrint('⚠️ NotificationService not initialized');
      return;
    }

    try {
      final int notificationId = _getMealReminderId(mealType);
      final String emoji = _getMealEmoji(mealType);
      final String assetPath = _getMealAssetPath(mealType);

      // Get image path
      final String? imagePath = await _getAssetImagePath(assetPath);

      // Create action button
      const AndroidNotificationAction logNowAction = AndroidNotificationAction(
        'log_now',
        'Log Now',
        showsUserInterface: true,
      );

      // Configure notification with image
      final AndroidNotificationDetails androidDetails =
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
        largeIcon:
        imagePath != null ? FilePathAndroidBitmap(imagePath) : null,
        styleInformation: imagePath != null
            ? BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath),
          contentTitle: '$emoji Time for $mealType!',
          summaryText: "Don't forget to log your $mealType in FitCheck!",
          hideExpandedLargeIcon: false,
        )
            : null,
        actions: const <AndroidNotificationAction>[logNowAction],
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        attachments: imagePath != null
            ? <DarwinNotificationAttachment>[
          DarwinNotificationAttachment(imagePath)
        ]
            : null,
        categoryIdentifier: 'meal_reminder_category',
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule the notification
      final now = tz.TZDateTime.now(tz.local);
      var scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
        0,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        notificationId,
        '$emoji Time for $mealType!',
        "Don't forget to log your $mealType in FitCheck!",
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'meal_reminder_${mealType.toLowerCase()}',
      );

      debugPrint(
          '✅ Scheduled $mealType reminder at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('❌ Error scheduling $mealType reminder: $e');
    }
  }

  /// 🆕 Cancel a specific meal reminder by type
  Future<void> cancelMealReminderByType(String mealType) async {
    try {
      final int notificationId = _getMealReminderId(mealType);
      await _notifications.cancel(notificationId);
      debugPrint('✅ Cancelled $mealType reminder');
    } catch (e) {
      debugPrint('❌ Error cancelling $mealType reminder: $e');
    }
  }

  /// 🆕 Cancel all meal reminders
  Future<void> cancelAllMealReminders() async {
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

  /// 🆕 Schedule milestone reminder at custom time
  Future<void> scheduleMilestoneReminderAt(int hour, int minute) async {
    if (!_isInitialized) {
      debugPrint('⚠️ NotificationService not initialized');
      return;
    }

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
        0,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
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
        eveningReminderId,
        '📸 Milestone Reminder',
        "Don't forget to add your milestone photo today!",
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'milestone_reminder',
      );

      debugPrint(
          '✅ Scheduled milestone reminder at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('❌ Error scheduling milestone reminder: $e');
    }
  }

  /// Schedule daily meal reminders at default times (ORIGINAL METHOD - PRESERVED)
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
          'asset': 'assets/images/breakfast.jpg',
        },
        {
          'id': lunchReminderId,
          'hour': 12,
          'minute': 0,
          'meal': 'Lunch',
          'emoji': '🍱',
          'asset': 'assets/images/lunch.jpg',
        },
        {
          'id': snackReminderId,
          'hour': 16,
          'minute': 0,
          'meal': 'Snack',
          'emoji': '🍎',
          'asset': 'assets/images/snack.jpg',
        },
        {
          'id': dinnerReminderId,
          'hour': 19,
          'minute': 0,
          'meal': 'Dinner',
          'emoji': '🍽️',
          'asset': 'assets/images/dinner.jpg',
        },
      ];

      for (final reminder in mealReminders) {
        // Get image path for this meal
        final String? imagePath =
        await _getAssetImagePath(reminder['asset'] as String);

        // Create action button
        const AndroidNotificationAction logNowAction =
        AndroidNotificationAction(
          'log_now',
          'Log Now',
          showsUserInterface: true,
        );

        // Configure notification with image
        final AndroidNotificationDetails androidDetails =
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
          largeIcon:
          imagePath != null ? FilePathAndroidBitmap(imagePath) : null,
          styleInformation: imagePath != null
              ? BigPictureStyleInformation(
            FilePathAndroidBitmap(imagePath),
            contentTitle:
            '${reminder['emoji']} Time for ${reminder['meal']}!',
            summaryText:
            "Don't forget to log your ${reminder['meal']} in FitCheck!",
            hideExpandedLargeIcon: false,
          )
              : null,
          actions: const <AndroidNotificationAction>[logNowAction],
        );

        final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          attachments: imagePath != null
              ? <DarwinNotificationAttachment>[
            DarwinNotificationAttachment(imagePath)
          ]
              : null,
          categoryIdentifier: 'meal_reminder_category',
        );

        final NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

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
          '$emoji Time for $mealName!',
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
            '✅ Scheduled $mealName reminder with image at ${reminder['hour']}:${(reminder['minute'] as int).toString().padLeft(2, '0')}');
      }

      debugPrint('✅ All daily meal reminders with images scheduled successfully');
    } catch (e) {
      debugPrint('❌ Error scheduling meal reminders: $e');
    }
  }

  /// Reschedule meal reminders (ORIGINAL METHOD - PRESERVED)
  Future<void> rescheduleOnReboot() async {
    debugPrint('🔄 Rescheduling meal reminders after reboot...');
    await _loadAndApplySavedSettings();
  }

  /// Cancel all meal reminders (ORIGINAL METHOD - PRESERVED)
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

  /// Schedule daily milestone reminders (ORIGINAL METHOD - PRESERVED)
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

  // ALL ORIGINAL METHODS BELOW ARE PRESERVED ✅

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

  /// 🆕 UPDATED: Save notification to Firestore
  Future<void> showMilestoneSavedNotification() async {
    await showInstantNotification(
      title: '✅ Milestone Saved!',
      body: 'Great job! Your progress has been recorded.',
      payload: 'milestone_saved',
    );

    // Save to Firestore
    await NotificationStorageService.saveNotification(
      type: NotificationStorageService.typeMilestonePhoto,
      title: 'Milestone Photo Added',
      description: 'Great progress! Your milestone photo has been saved.',
      iconName: 'camera_alt',
      iconColor: 0xFFE91E63,
    );
  }

  /// 🆕 UPDATED: Save notification to Firestore
  Future<void> showMealLoggedNotification(String mealType) async {
    await showInstantNotification(
      title: '✅ $mealType Logged!',
      body: 'Great job tracking your nutrition!',
      payload: 'meal_logged_${mealType.toLowerCase()}',
    );

    // Save to Firestore
    await NotificationStorageService.saveNotification(
      type: NotificationStorageService.typeMealLogged,
      title: 'Meal Logged Successfully',
      description: 'You have logged your $mealType. Keep up the great work!',
      iconName: 'restaurant',
      iconColor: 0xFFFF9800,
      metadata: {'mealType': mealType},
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