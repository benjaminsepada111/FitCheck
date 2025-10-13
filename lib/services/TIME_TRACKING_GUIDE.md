# User Time Tracking System - Integration Guide

## Overview

The `UserTimeTracker` service provides accurate per-user time tracking with UTC-based calculations for your Flutter + Firebase application. This system ensures consistent time tracking across timezones and handles cases where users skip days or are inactive.

## Features

- **Per-user start date storage** in Firebase Firestore
- **UTC-based calculations** to prevent timezone errors
- **Dynamic calculations** for:
  - Days passed since start date
  - Current week number
  - Months passed
  - Day of the week within current week
- **Accurate handling** of inactive periods
- **Real-time updates** via Firebase streams
- **Efficient batch operations** to reduce Firebase reads

---

## Quick Start

### 1. Initialize Time Tracking for a New User

Call this when a user completes registration or starts their first challenge:

```dart
import 'package:capstone_project/services/user_time_tracker.dart';

// Initialize with current date
await UserTimeTracker.initializeUserStartDate();

// Or initialize with a custom date
await UserTimeTracker.initializeUserStartDate(
  customStartDate: DateTime(2025, 1, 1),
);
```

### 2. Get Time Metrics

```dart
// Get days passed
final daysPassed = await UserTimeTracker.getDaysPassed();
print('Days since start: $daysPassed');

// Get current week number
final weekNumber = await UserTimeTracker.getWeekNumber();
print('Current week: $weekNumber');

// Get months passed
final monthsPassed = await UserTimeTracker.getMonthsPassed();
print('Months passed: $monthsPassed');

// Get all metrics at once (more efficient!)
final metrics = await UserTimeTracker.getAllTimeMetrics();
print('Days: ${metrics['daysPassed']}');
print('Week: ${metrics['weekNumber']}');
print('Months: ${metrics['monthsPassed']}');
print('Day of week: ${metrics['dayOfWeek']}');
```

---

## Integration Examples

### Example 1: Weekly Summary Page

```dart
import 'package:flutter/material.dart';
import 'package:capstone_project/services/user_time_tracker.dart';

class WeeklySummaryPage extends StatefulWidget {
  @override
  _WeeklySummaryPageState createState() => _WeeklySummaryPageState();
}

class _WeeklySummaryPageState extends State<WeeklySummaryPage> {
  int _currentWeek = 0;
  int _daysPassed = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    final metrics = await UserTimeTracker.getAllTimeMetrics();

    if (mounted) {
      setState(() {
        _currentWeek = metrics['weekNumber'];
        _daysPassed = metrics['daysPassed'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Week $_currentWeek Summary'),
      ),
      body: Column(
        children: [
          Text('You are on day $_daysPassed of your journey!'),
          Text('Current Week: $_currentWeek'),
          // Add your weekly summary widgets here
        ],
      ),
    );
  }
}
```

### Example 2: Achievement Checking

```dart
import 'package:capstone_project/services/user_time_tracker.dart';

class AchievementChecker {
  // Check if user completed 7 days
  static Future<bool> checkWeekWarriorAchievement() async {
    return await UserTimeTracker.hasCompletedDays(7);
  }

  // Check if user completed 30 days
  static Future<bool> checkMonthlyStreakAchievement() async {
    return await UserTimeTracker.hasCompletedDays(30);
  }

  // Check if user completed 4 weeks
  static Future<bool> checkFourWeekChallenge() async {
    return await UserTimeTracker.hasCompletedWeeks(4);
  }

  // Check all achievements at once
  static Future<Map<String, bool>> checkAllTimeBasedAchievements() async {
    final metrics = await UserTimeTracker.getAllTimeMetrics();
    final days = metrics['daysPassed'] as int;
    final weeks = metrics['weekNumber'] as int;

    return {
      'first_week': days >= 7,
      'two_weeks': days >= 14,
      'one_month': days >= 30,
      'three_months': days >= 90,
      'completed_4_weeks': weeks > 4,
    };
  }
}
```

### Example 3: Streak Tracking with Real-time Updates

```dart
import 'package:flutter/material.dart';
import 'package:capstone_project/services/user_time_tracker.dart';

class StreakWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserTimeTracker.getTimeTrackingStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text('Loading streak...');
        }

        // Calculate metrics whenever the stream updates
        return FutureBuilder<Map<String, dynamic>>(
          future: UserTimeTracker.getAllTimeMetrics(),
          builder: (context, metricsSnapshot) {
            if (!metricsSnapshot.hasData) {
              return CircularProgressIndicator();
            }

            final days = metricsSnapshot.data!['daysPassed'];
            final week = metricsSnapshot.data!['weekNumber'];

            return Column(
              children: [
                Text('🔥 $days Day Streak!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text('Week $week',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
```

### Example 4: Initialize on User Registration

```dart
import 'package:capstone_project/services/user_time_tracker.dart';
import 'package:capstone_project/services/auth_service.dart';

class RegistrationService {
  static Future<bool> completeUserRegistration({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      // 1. Create Firebase Auth user
      final authResult = await AuthService.registerUser(email, password);

      if (!authResult) {
        return false;
      }

      // 2. Save user profile data
      await UserDataService.saveUserData(UserData.fromJson(userData));

      // 3. Initialize time tracking (IMPORTANT!)
      await UserTimeTracker.initializeUserStartDate();

      print('User registration complete with time tracking initialized');
      return true;
    } catch (e) {
      print('Error during registration: $e');
      return false;
    }
  }
}
```

### Example 5: Weekly Challenge Date Ranges

```dart
import 'package:capstone_project/services/user_time_tracker.dart';

class WeeklyChallengeService {
  // Get data for a specific week
  static Future<Map<String, dynamic>?> getWeeklyData(int weekNumber) async {
    final dateRange = await UserTimeTracker.getWeekDateRange(weekNumber);

    if (dateRange == null) {
      return null;
    }

    final startDate = dateRange['startDate']!;
    final endDate = dateRange['endDate']!;

    // Now fetch data for this date range from Firebase
    // For example, get food logs, workouts, etc. for this week

    return {
      'weekNumber': weekNumber,
      'startDate': startDate,
      'endDate': endDate,
      'totalDays': 7,
      // Add your fetched data here
    };
  }

  // Get current week's data
  static Future<Map<String, dynamic>?> getCurrentWeekData() async {
    final weekNumber = await UserTimeTracker.getWeekNumber();
    return await getWeeklyData(weekNumber);
  }
}
```

### Example 6: Progress Tracking Widget

```dart
import 'package:flutter/material.dart';
import 'package:capstone_project/services/user_time_tracker.dart';

class ProgressTracker extends StatefulWidget {
  @override
  _ProgressTrackerState createState() => _ProgressTrackerState();
}

class _ProgressTrackerState extends State<ProgressTracker> {
  Map<String, dynamic>? _metrics;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    final metrics = await UserTimeTracker.getAllTimeMetrics();
    setState(() => _metrics = metrics);
  }

  @override
  Widget build(BuildContext context) {
    if (_metrics == null) {
      return CircularProgressIndicator();
    }

    final days = _metrics!['daysPassed'];
    final week = _metrics!['weekNumber'];
    final months = _metrics!['monthsPassed'];
    final dayOfWeek = _metrics!['dayOfWeek'];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Progress',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildProgressRow('Total Days', days.toString()),
            _buildProgressRow('Current Week', week.toString()),
            _buildProgressRow('Months Active', months.toString()),
            _buildProgressRow('Week Progress', '$dayOfWeek/7 days'),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: dayOfWeek / 7,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
```

---

## Best Practices

### 1. **Initialize Once Per User**

```dart
// Check if already initialized before initializing
final isInitialized = await UserTimeTracker.isInitialized();

if (!isInitialized) {
  await UserTimeTracker.initializeUserStartDate();
}
```

### 2. **Use Batch Operations**

Instead of multiple individual calls, use `getAllTimeMetrics()`:

```dart
// ❌ Bad - Multiple Firebase reads
final days = await UserTimeTracker.getDaysPassed();
final weeks = await UserTimeTracker.getWeekNumber();
final months = await UserTimeTracker.getMonthsPassed();

// ✅ Good - Single Firebase read
final metrics = await UserTimeTracker.getAllTimeMetrics();
final days = metrics['daysPassed'];
final weeks = metrics['weekNumber'];
final months = metrics['monthsPassed'];
```

### 3. **Handle Uninitialized State**

```dart
final metrics = await UserTimeTracker.getAllTimeMetrics();

if (!metrics['isInitialized']) {
  // Show onboarding or initialize time tracking
  await UserTimeTracker.initializeUserStartDate();
}
```

### 4. **Use Streams for Real-time Updates**

For UI that needs to update automatically:

```dart
StreamBuilder<Map<String, dynamic>?>(
  stream: UserTimeTracker.getTimeTrackingStream(),
  builder: (context, snapshot) {
    // UI updates automatically when start date changes
  },
);
```

---

## Firebase Structure

The service stores data in this structure:

```
users/
  └── {userId}/
      └── profile/
          └── timeTracking/
              ├── startDate: "2025-01-15T00:00:00.000Z"
              ├── createdAt: "2025-01-15T10:30:00.000Z"
              └── lastUpdated: "2025-01-15T10:30:00.000Z"
```

---

## Common Use Cases

### Achievement System

```dart
final hasCompletedWeek = await UserTimeTracker.hasCompletedDays(7);
if (hasCompletedWeek) {
  unlockAchievement('week_warrior');
}
```

### Weekly Summaries

```dart
final currentWeek = await UserTimeTracker.getWeekNumber();
final weekRange = await UserTimeTracker.getWeekDateRange(currentWeek);
// Fetch and display data for this week's date range
```

### Progress Tracking

```dart
final metrics = await UserTimeTracker.getAllTimeMetrics();
final progressPercent = (metrics['dayOfWeek'] / 7) * 100;
// Show week progress bar
```

### Streak Maintenance

```dart
final daysPassed = await UserTimeTracker.getDaysPassed();
// Check if user logged activity today to maintain streak
```

---

## Testing

You can test the system with custom dates:

```dart
// Initialize with a date 30 days ago for testing
final testStartDate = DateTime.now().subtract(Duration(days: 30));
await UserTimeTracker.initializeUserStartDate(
  customStartDate: testStartDate,
);

// Now check metrics
final metrics = await UserTimeTracker.getAllTimeMetrics();
// Should show ~30 days passed, week 5, etc.
```

---

## Resetting Start Date (Use with Caution)

Only use this when a user explicitly restarts their journey:

```dart
final newStartDate = DateTime.now();
await UserTimeTracker.resetStartDate(newStartDate);
```

---

## Migration for Existing Users

If you already have users without a start date:

```dart
class MigrationService {
  static Future<void> migrateExistingUsers() async {
    final isInitialized = await UserTimeTracker.isInitialized();

    if (!isInitialized) {
      // Option 1: Use current date
      await UserTimeTracker.initializeUserStartDate();

      // Option 2: Use user's registration date if available
      final userData = await UserDataService.loadUserData();
      if (userData?.birthDate != null) {
        // Or use any other meaningful date
        await UserTimeTracker.initializeUserStartDate(
          customStartDate: userData!.birthDate!,
        );
      }
    }
  }
}
```

---

## Troubleshooting

### Issue: Getting 0 for all metrics

**Solution**: User's start date hasn't been initialized. Call:
```dart
await UserTimeTracker.initializeUserStartDate();
```

### Issue: Incorrect day count

**Cause**: Timezone issues or not using UTC.

**Solution**: The service automatically uses UTC. Verify your system time is correct.

### Issue: Week number seems off

**Remember**: Week 1 = Days 0-6, Week 2 = Days 7-13, etc. Day 0 is the start date.

---

## Performance Considerations

1. **Cache metrics locally** when possible (they only change once per day)
2. **Use `getAllTimeMetrics()`** instead of individual calls
3. **Use streams** for real-time updates instead of polling
4. Firebase reads are optimized - only reads once per call

---

## API Reference

| Method | Returns | Description |
|--------|---------|-------------|
| `initializeUserStartDate()` | `Future<bool>` | Initialize user's start date |
| `getUserStartDate()` | `Future<DateTime?>` | Get user's start date |
| `getDaysPassed()` | `Future<int>` | Days since start date |
| `getWeekNumber()` | `Future<int>` | Current week number (1-based) |
| `getMonthsPassed()` | `Future<int>` | Complete months passed |
| `getDayOfWeek()` | `Future<int>` | Day of current week (0-6) |
| `getAllTimeMetrics()` | `Future<Map>` | All metrics in one call |
| `hasCompletedDays(int)` | `Future<bool>` | Check if N days completed |
| `hasCompletedWeeks(int)` | `Future<bool>` | Check if N weeks completed |
| `getWeekDateRange(int)` | `Future<Map?>` | Date range for week N |
| `isInitialized()` | `Future<bool>` | Check if time tracking set up |
| `resetStartDate(DateTime)` | `Future<bool>` | Reset user's start date |
| `getTimeTrackingStream()` | `Stream<Map?>` | Real-time updates |

---

## Need Help?

Check the inline documentation in `user_time_tracker.dart` for detailed parameter descriptions and return values.
