import 'package:flutter/material.dart';
import 'package:capstone_project/services/notification_service.dart';
import 'package:capstone_project/services/notification_storage_service.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/app_text_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Meal reminder states
  bool _breakfastEnabled = true;
  TimeOfDay _breakfastTime = const TimeOfDay(hour: 8, minute: 0);

  bool _lunchEnabled = true;
  TimeOfDay _lunchTime = const TimeOfDay(hour: 12, minute: 0);

  bool _snackEnabled = true;
  TimeOfDay _snackTime = const TimeOfDay(hour: 16, minute: 0);

  bool _dinnerEnabled = true;
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 19, minute: 0);

  // Milestone reminder state
  bool _milestoneEnabled = false;
  TimeOfDay _milestoneTime = const TimeOfDay(hour: 20, minute: 0);

  bool _isLoading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load saved notification settings from SharedPreferences
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if notifications are enabled
      _notificationsEnabled =
      await NotificationService().areNotificationsEnabled();

      // Load breakfast settings
      _breakfastEnabled = prefs.getBool('breakfast_enabled') ?? true;
      final breakfastHour = prefs.getInt('breakfast_hour') ?? 8;
      final breakfastMinute = prefs.getInt('breakfast_minute') ?? 0;
      _breakfastTime = TimeOfDay(hour: breakfastHour, minute: breakfastMinute);

      // Load lunch settings
      _lunchEnabled = prefs.getBool('lunch_enabled') ?? true;
      final lunchHour = prefs.getInt('lunch_hour') ?? 12;
      final lunchMinute = prefs.getInt('lunch_minute') ?? 0;
      _lunchTime = TimeOfDay(hour: lunchHour, minute: lunchMinute);

      // Load snack settings
      _snackEnabled = prefs.getBool('snack_enabled') ?? true;
      final snackHour = prefs.getInt('snack_hour') ?? 16;
      final snackMinute = prefs.getInt('snack_minute') ?? 0;
      _snackTime = TimeOfDay(hour: snackHour, minute: snackMinute);

      // Load dinner settings
      _dinnerEnabled = prefs.getBool('dinner_enabled') ?? true;
      final dinnerHour = prefs.getInt('dinner_hour') ?? 19;
      final dinnerMinute = prefs.getInt('dinner_minute') ?? 0;
      _dinnerTime = TimeOfDay(hour: dinnerHour, minute: dinnerMinute);

      // Load milestone settings
      _milestoneEnabled = prefs.getBool('milestone_enabled') ?? false;
      final milestoneHour = prefs.getInt('milestone_hour') ?? 20;
      final milestoneMinute = prefs.getInt('milestone_minute') ?? 0;
      _milestoneTime = TimeOfDay(hour: milestoneHour, minute: milestoneMinute);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save breakfast
      await prefs.setBool('breakfast_enabled', _breakfastEnabled);
      await prefs.setInt('breakfast_hour', _breakfastTime.hour);
      await prefs.setInt('breakfast_minute', _breakfastTime.minute);

      // Save lunch
      await prefs.setBool('lunch_enabled', _lunchEnabled);
      await prefs.setInt('lunch_hour', _lunchTime.hour);
      await prefs.setInt('lunch_minute', _lunchTime.minute);

      // Save snack
      await prefs.setBool('snack_enabled', _snackEnabled);
      await prefs.setInt('snack_hour', _snackTime.hour);
      await prefs.setInt('snack_minute', _snackTime.minute);

      // Save dinner
      await prefs.setBool('dinner_enabled', _dinnerEnabled);
      await prefs.setInt('dinner_hour', _dinnerTime.hour);
      await prefs.setInt('dinner_minute', _dinnerTime.minute);

      // Save milestone
      await prefs.setBool('milestone_enabled', _milestoneEnabled);
      await prefs.setInt('milestone_hour', _milestoneTime.hour);
      await prefs.setInt('milestone_minute', _milestoneTime.minute);

      debugPrint('✅ Notification settings saved');
    } catch (e) {
      debugPrint('❌ Error saving settings: $e');
    }
  }

  /// Apply all notification settings
  Future<void> _applyAllSettings() async {
    try {
      // Cancel all existing meal reminders
      await NotificationService().cancelAllMealReminders();

      // Schedule enabled meal reminders
      if (_breakfastEnabled) {
        await NotificationService().scheduleMealReminder(
          'Breakfast',
          _breakfastTime.hour,
          _breakfastTime.minute,
        );
      }

      if (_lunchEnabled) {
        await NotificationService().scheduleMealReminder(
          'Lunch',
          _lunchTime.hour,
          _lunchTime.minute,
        );
      }

      if (_snackEnabled) {
        await NotificationService().scheduleMealReminder(
          'Snack',
          _snackTime.hour,
          _snackTime.minute,
        );
      }

      if (_dinnerEnabled) {
        await NotificationService().scheduleMealReminder(
          'Dinner',
          _dinnerTime.hour,
          _dinnerTime.minute,
        );
      }

      // Handle milestone reminder
      await NotificationService().cancelMilestoneReminder();
      if (_milestoneEnabled) {
        await NotificationService().scheduleMilestoneReminderAt(
          _milestoneTime.hour,
          _milestoneTime.minute,
        );
      }

      // Save settings
      await _saveSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Notification settings saved!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error applying settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save settings'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// Toggle meal reminder and update immediately
  Future<void> _toggleMealReminder(String mealType, bool enabled) async {
    setState(() {
      switch (mealType) {
        case 'Breakfast':
          _breakfastEnabled = enabled;
          break;
        case 'Lunch':
          _lunchEnabled = enabled;
          break;
        case 'Snack':
          _snackEnabled = enabled;
          break;
        case 'Dinner':
          _dinnerEnabled = enabled;
          break;
      }
    });

    if (enabled) {
      // Schedule the reminder
      TimeOfDay time;
      switch (mealType) {
        case 'Breakfast':
          time = _breakfastTime;
          break;
        case 'Lunch':
          time = _lunchTime;
          break;
        case 'Snack':
          time = _snackTime;
          break;
        case 'Dinner':
          time = _dinnerTime;
          break;
        default:
          return;
      }
      await NotificationService()
          .scheduleMealReminder(mealType, time.hour, time.minute);
    } else {
      // Cancel the reminder
      await NotificationService().cancelMealReminderByType(mealType);
    }

    await _saveSettings();
  }

  /// Pick time for meal reminder
  Future<void> _pickMealTime(String mealType) async {
    TimeOfDay currentTime;
    switch (mealType) {
      case 'Breakfast':
        currentTime = _breakfastTime;
        break;
      case 'Lunch':
        currentTime = _lunchTime;
        break;
      case 'Snack':
        currentTime = _snackTime;
        break;
      case 'Dinner':
        currentTime = _dinnerTime;
        break;
      default:
        return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.secondary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        switch (mealType) {
          case 'Breakfast':
            _breakfastTime = picked;
            break;
          case 'Lunch':
            _lunchTime = picked;
            break;
          case 'Snack':
            _snackTime = picked;
            break;
          case 'Dinner':
            _dinnerTime = picked;
            break;
        }
      });

      // Reschedule if enabled
      bool isEnabled;
      switch (mealType) {
        case 'Breakfast':
          isEnabled = _breakfastEnabled;
          break;
        case 'Lunch':
          isEnabled = _lunchEnabled;
          break;
        case 'Snack':
          isEnabled = _snackEnabled;
          break;
        case 'Dinner':
          isEnabled = _dinnerEnabled;
          break;
        default:
          return;
      }

      if (isEnabled) {
        await NotificationService()
            .scheduleMealReminder(mealType, picked.hour, picked.minute);
      }

      await _saveSettings();
    }
  }

  /// Toggle milestone reminder
  Future<void> _toggleMilestoneReminder(bool enabled) async {
    setState(() {
      _milestoneEnabled = enabled;
    });

    await NotificationService().cancelMilestoneReminder();

    if (enabled) {
      await NotificationService().scheduleMilestoneReminderAt(
        _milestoneTime.hour,
        _milestoneTime.minute,
      );
    }

    await _saveSettings();
  }

  /// Pick time for milestone reminder
  Future<void> _pickMilestoneTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _milestoneTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.secondary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _milestoneTime = picked;
      });

      // Reschedule if enabled
      if (_milestoneEnabled) {
        await NotificationService().cancelMilestoneReminder();
        await NotificationService().scheduleMilestoneReminderAt(
          picked.hour,
          picked.minute,
        );
      }

      await _saveSettings();
    }
  }

  /// Format time for display
  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dateTime =
    DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Get next reminder datetime string
  String _getNextReminderText(TimeOfDay time) {
    return 'Next reminder at ${_formatTime(time)}';
  }

  /// Request notification permissions
  Future<void> _requestNotificationPermission() async {
    final result = await NotificationService().requestExactAlarmPermission();
    if (result) {
      final isEnabled = await NotificationService().areNotificationsEnabled();
      setState(() {
        _notificationsEnabled = isEnabled;
      });

      if (isEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Notifications enabled successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// Delete notification with confirmation
  Future<void> _deleteNotification(NotificationItem notification) async {
    await NotificationStorageService.deleteNotification(notification.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification deleted'),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  /// Clear all notifications
  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NotificationStorageService.deleteAllNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All notifications cleared'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Clear all button - only show on Notifications tab
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.black87),
              onPressed: _clearAllNotifications,
              tooltip: 'Clear all notifications',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.secondary,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              indicatorColor: AppColors.secondary,
              indicatorWeight: 3,
              onTap: (index) => setState(() {}), // Rebuild to show/hide clear button
              tabs: const [
                Tab(text: 'Notifications'),
                Tab(text: 'Reminders'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          // Notifications Tab
          _buildNotificationsTab(),
          // Reminders Tab
          _buildRemindersTab(),
        ],
      ),
    );
  }

  /// Build Notifications Tab with real-time data
  Widget _buildNotificationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: NotificationStorageService.getNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading notifications',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final notifications = snapshot.data!.docs
            .map((doc) => NotificationItem.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: notifications.length + 1, // +1 for header
          itemBuilder: (context, index) {
            if (index == 0) {
              // Header
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Latest',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              );
            }

            final notification = notifications[index - 1];
            return _buildNotificationItemDismissible(notification);
          },
        );
      },
    );
  }

  /// Build empty state for notifications
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Notifications Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your notifications will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build dismissible notification item
  Widget _buildNotificationItemDismissible(NotificationItem notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (direction) {
        _deleteNotification(notification);
      },
      child: _buildNotificationItem(
        icon: _getIconData(notification.icon),
        iconColor: Color(notification.iconColor),
        title: notification.title,
        description: notification.description,
        time: notification.getTimeAgo(),
        isRead: notification.isRead,
        onTap: () async {
          if (!notification.isRead) {
            await NotificationStorageService.markAsRead(notification.id);
          }
        },
      ),
    );
  }

  /// Get IconData from string name
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'flag':
        return Icons.flag;
      default:
        return Icons.notifications;
    }
  }

  /// Build Reminders Tab
  Widget _buildRemindersTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Enable/Disable Notifications Button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _notificationsEnabled
                  ? null
                  : _requestNotificationPermission,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _notificationsEnabled
                            ? AppColors.secondary.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _notificationsEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off_outlined,
                        color: _notificationsEnabled
                            ? AppColors.secondary
                            : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _notificationsEnabled
                                ? 'Notifications Enabled'
                                : 'Notifications Disabled',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _notificationsEnabled
                                ? 'You\'ll receive meal and milestone reminders'
                                : 'Tap to enable notifications in settings',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_notificationsEnabled)
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'MEAL REMINDERS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Breakfast Reminder
        _buildMealReminderCard(
          emoji: '🍳',
          title: 'Breakfast Reminder',
          isEnabled: _breakfastEnabled,
          time: _breakfastTime,
          mealType: 'Breakfast',
        ),

        // Lunch Reminder
        _buildMealReminderCard(
          emoji: '🍱',
          title: 'Lunch Reminder',
          isEnabled: _lunchEnabled,
          time: _lunchTime,
          mealType: 'Lunch',
        ),

        // Snack Reminder
        _buildMealReminderCard(
          emoji: '🍎',
          title: 'Snack Reminder',
          isEnabled: _snackEnabled,
          time: _snackTime,
          mealType: 'Snack',
        ),

        // Dinner Reminder
        _buildMealReminderCard(
          emoji: '🍽️',
          title: 'Dinner Reminder',
          isEnabled: _dinnerEnabled,
          time: _dinnerTime,
          mealType: 'Dinner',
        ),

        const SizedBox(height: 16),

        // Milestone Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'MILESTONE REMINDERS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Milestone Reminder Card
        _buildMilestoneCard(),

        const SizedBox(height: 24),

        // Save All Settings Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _notificationsEnabled ? _applyAllSettings : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Apply All Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Info Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[700],
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your reminders will fire daily at the times you set, even when the app is closed. Make sure to allow notifications in your device settings.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[900],
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  /// Build Notification Item
  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String time,
    bool isRead = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.blue[50]?.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build meal reminder card widget (MyFitnessPal style)
  Widget _buildMealReminderCard({
    required String emoji,
    required String title,
    required bool isEnabled,
    required TimeOfDay time,
    required String mealType,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main toggle section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Emoji icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEnabled
                            ? _getNextReminderText(time)
                            : 'Tap to enable reminder',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle switch
                Switch(
                  value: isEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) => _toggleMealReminder(mealType, value)
                      : null,
                  activeColor: AppColors.secondary,
                ),
              ],
            ),
          ),
          // Time picker section (only visible when enabled)
          if (isEnabled) ...[
            Divider(height: 1, color: Colors.grey[200]),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pickMealTime(mealType),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: AppColors.secondary,
                        size: 22,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Reminder Time',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(time),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build milestone reminder card
  Widget _buildMilestoneCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main toggle section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Camera icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '📸',
                    style: TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Milestone Photos',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _milestoneEnabled
                            ? _getNextReminderText(_milestoneTime)
                            : 'Tap to enable reminders',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle switch
                Switch(
                  value: _milestoneEnabled,
                  onChanged:
                  _notificationsEnabled ? _toggleMilestoneReminder : null,
                  activeColor: AppColors.secondary,
                ),
              ],
            ),
          ),
          // Time picker section (only visible when enabled)
          if (_milestoneEnabled) ...[
            Divider(height: 1, color: Colors.grey[200]),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickMilestoneTime,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: AppColors.secondary,
                        size: 22,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Reminder Time',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(_milestoneTime),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}