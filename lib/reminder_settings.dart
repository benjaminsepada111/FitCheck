import 'package:flutter/material.dart';
import 'package:capstone_project/services/notification_service.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> with SingleTickerProviderStateMixin {
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
  bool _notificationsEnabled = true; // Master toggle
  bool _isSaving = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Load saved notification settings from SharedPreferences
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load master toggle state
      _notificationsEnabled = prefs.getBool('global_notifications_enabled') ?? true;

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

  /// Toggle master notifications ON/OFF
  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('global_notifications_enabled', value);

    setState(() {
      _notificationsEnabled = value;
    });

    if (!value) {
      // Cancel all notifications when disabled
      await NotificationService().cancelAllMealReminders();
      await NotificationService().cancelMilestoneReminder();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.notifications_off_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notifications disabled. All reminders have been turned off.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      // Restore notifications when enabled (reschedule based on saved settings)
      await _rescheduleAllReminders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notifications enabled! Your reminders are now active.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Reschedule all enabled reminders
  Future<void> _rescheduleAllReminders() async {
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
    if (_milestoneEnabled) {
      await NotificationService().scheduleMilestoneReminderAt(
        _milestoneTime.hour,
        _milestoneTime.minute,
      );
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save master toggle
      await prefs.setBool('global_notifications_enabled', _notificationsEnabled);

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

  /// Apply all notification settings with enhanced UX
  Future<void> _applyAllSettings() async {
    if (!_notificationsEnabled) {
      _showNotificationDisabledDialog();
      return;
    }

    // Animate button press
    await _animationController.forward();
    await _animationController.reverse();

    setState(() {
      _isSaving = true;
    });

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

      // Add delay for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('Error applying settings: $e');
      setState(() {
        _isSaving = false;
      });

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

  /// Show success dialog with animation
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated checkmark
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 24),
              Text(
                'Settings Applied!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Your notification preferences have been saved successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You\'ll receive reminders at your scheduled times daily.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show notification disabled dialog
  void _showNotificationDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.shade400,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_off_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Notifications Disabled',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Please enable notifications using the toggle above to customize your reminder settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Got It',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggle meal reminder and update immediately
  Future<void> _toggleMealReminder(String mealType, bool enabled) async {
    if (!_notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.notifications_off_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable notifications first to set reminders',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
    if (!_notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.notifications_off_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable notifications first to set times',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
    if (!_notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.notifications_off_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable notifications first to set reminders',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
    if (!_notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.notifications_off_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable notifications first to set times',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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

  /// Build master toggle card
  Widget _buildMasterToggle() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _notificationsEnabled
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.grey.shade400, Colors.grey.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_notificationsEnabled ? Colors.green.shade300 : Colors.grey.shade300)
                .withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _notificationsEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _notificationsEnabled
                      ? 'All reminders are active'
                      : 'All reminders are turned off',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.1,
            child: Switch(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              activeColor: Colors.white,
              activeTrackColor: Colors.white.withOpacity(0.4),
              inactiveThumbColor: Colors.white.withOpacity(0.8),
              inactiveTrackColor: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reminder Settings',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Master Toggle Card
                _buildMasterToggle(),

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
                          'Your reminders will fire daily at the times you set, even when the app is closed.',
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

                const SizedBox(height: 100),
              ],
            ),
          ),

          // Apply Button (Fixed at bottom)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 0.95).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isSaving || !_notificationsEnabled) ? null : _applyAllSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _notificationsEnabled
                          ? AppColors.secondary
                          : Colors.grey.shade400,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '⟳ Applying Settings...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                        : Text(
                      _notificationsEnabled
                          ? '✓ Apply All Settings'
                          : 'Enable Notifications First',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build meal reminder card widget
  Widget _buildMealReminderCard({
    required String emoji,
    required String title,
    required bool isEnabled,
    required TimeOfDay time,
    required String mealType,
  }) {
    final isInteractive = _notificationsEnabled;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInteractive && isEnabled
              ? AppColors.secondary.withOpacity(0.3)
              : Colors.grey.shade200,
          width: 2,
        ),
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
                    color: isInteractive ? Colors.grey[100] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: 24,
                      color: isInteractive ? Colors.black : Colors.grey,
                    ),
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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isInteractive ? Colors.black87 : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEnabled && isInteractive
                            ? _getNextReminderText(time)
                            : 'Tap to enable reminder',
                        style: TextStyle(
                          fontSize: 14,
                          color: isInteractive ? Colors.grey[600] : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle switch
                Switch(
                  value: isEnabled && isInteractive,
                  onChanged: isInteractive
                      ? (value) => _toggleMealReminder(mealType, value)
                      : null,
                  activeColor: AppColors.secondary,
                ),
              ],
            ),
          ),
          // Time picker section (only visible when enabled)
          if (isEnabled && isInteractive) ...[
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
    final isInteractive = _notificationsEnabled;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInteractive && _milestoneEnabled
              ? AppColors.secondary.withOpacity(0.3)
              : Colors.grey.shade200,
          width: 2,
        ),
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
                    color: isInteractive ? Colors.grey[100] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '📸',
                    style: TextStyle(
                      fontSize: 24,
                      color: isInteractive ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Milestone Photos',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isInteractive ? Colors.black87 : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _milestoneEnabled && isInteractive
                            ? _getNextReminderText(_milestoneTime)
                            : 'Tap to enable reminders',
                        style: TextStyle(
                          fontSize: 14,
                          color: isInteractive ? Colors.grey[600] : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle switch
                Switch(
                  value: _milestoneEnabled && isInteractive,
                  onChanged: isInteractive ? _toggleMilestoneReminder : null,
                  activeColor: AppColors.secondary,
                ),
              ],
            ),
          ),
          // Time picker section (only visible when enabled)
          if (_milestoneEnabled && isInteractive) ...[
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