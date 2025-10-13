# Time Tracking System - Quick Start Guide

## 🚀 Get Started in 3 Steps

### Step 1: Initialize Time Tracking (5 minutes)

Add this to your user registration or first app launch:

```dart
import 'package:capstone_project/services/user_time_tracker.dart';

// After user signs up or completes onboarding
await UserTimeTracker.initializeUserStartDate();
```

**Where to add:**
- `lib/SignUpPages/signuppage.dart` - After successful registration
- `lib/main_page.dart` - In initState, check if initialized

### Step 2: Display Metrics (10 minutes)

Add to any page where you want to show progress:

```dart
import 'package:capstone_project/services/user_time_tracker.dart';

// Get all metrics efficiently
final metrics = await UserTimeTracker.getAllTimeMetrics();

// Display in UI
Text('Day ${metrics['daysPassed']} of your journey!');
Text('Week ${metrics['weekNumber']}');
```

### Step 3: Check Achievements (15 minutes)

Update your achievements page:

```dart
import 'package:capstone_project/services/achievement_time_service.dart';

// Check all achievements
final achievements = await AchievementTimeService.checkAllAchievements();

// Use in UI
final weekWarrior = achievements['week_warrior'];
if (weekWarrior?.unlocked == true) {
  showUnlockedBadge();
} else {
  showProgressBar(weekWarrior?.progress ?? 0.0);
}
```

---

## 📋 Copy-Paste Code Snippets

### Initialize on App Startup

```dart
// Add to your main_page.dart or app initialization
Future<void> _initializeTimeTracking() async {
  final isInitialized = await UserTimeTracker.isInitialized();
  if (!isInitialized) {
    await UserTimeTracker.initializeUserStartDate();
    print('Time tracking initialized for user');
  }
}

@override
void initState() {
  super.initState();
  _initializeTimeTracking();
}
```

### Display Journey Progress

```dart
// Add to any StatefulWidget
import 'package:capstone_project/services/user_time_tracker.dart';

class JourneyProgressWidget extends StatefulWidget {
  @override
  _JourneyProgressWidgetState createState() => _JourneyProgressWidgetState();
}

class _JourneyProgressWidgetState extends State<JourneyProgressWidget> {
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
    if (_metrics == null) return CircularProgressIndicator();

    return Column(
      children: [
        Text('🎯 Day ${_metrics!['daysPassed']} of your journey!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text('Week ${_metrics!['weekNumber']}'),
        LinearProgressIndicator(
          value: (_metrics!['dayOfWeek'] / 7),
        ),
      ],
    );
  }
}
```

### Check Single Achievement

```dart
import 'package:capstone_project/services/user_time_tracker.dart';

// Check if user completed 7 days
final hasWeek1 = await UserTimeTracker.hasCompletedDays(7);

if (hasWeek1) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('🎉 Achievement Unlocked!'),
      content: Text('Week Warrior - Complete 7 days'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Awesome!'),
        ),
      ],
    ),
  );
}
```

### Weekly Summary Date Range

```dart
import 'package:capstone_project/services/user_time_tracker.dart';

// Get current week's date range
final weekNumber = await UserTimeTracker.getWeekNumber();
final dateRange = await UserTimeTracker.getWeekDateRange(weekNumber);

final startDate = dateRange!['startDate'];
final endDate = dateRange['endDate'];

// Now fetch your data for this date range
final weeklyWorkouts = await getWorkoutsBetween(startDate, endDate);
final weeklyMeals = await getMealsBetween(startDate, endDate);
```

---

## 🎯 Common Tasks

### Task: Show "Days Active" Badge

```dart
final days = await UserTimeTracker.getDaysPassed();

Container(
  padding: EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    '$days Days Active',
    style: TextStyle(color: Colors.white),
  ),
);
```

### Task: Weekly Progress Bar

```dart
final metrics = await UserTimeTracker.getAllTimeMetrics();
final dayOfWeek = metrics['dayOfWeek'];

Column(
  children: [
    Text('This Week: $dayOfWeek/7 days'),
    LinearProgressIndicator(value: dayOfWeek / 7),
  ],
);
```

### Task: Month Milestone Notification

```dart
final months = await UserTimeTracker.getMonthsPassed();

if (months == 1) {
  // Show special notification
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('🎉 One Month Milestone!'),
      content: Text('You\'ve been on your journey for a full month!'),
    ),
  );
}
```

### Task: Streak Counter

```dart
final days = await UserTimeTracker.getDaysPassed();

Row(
  children: [
    Text('🔥', style: TextStyle(fontSize: 24)),
    SizedBox(width: 8),
    Text(
      '$days Day Streak',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  ],
);
```

---

## 📱 Integration Checklist

Use this checklist to integrate the system:

### Phase 1: Basic Setup
- [ ] Initialize time tracking on user registration
- [ ] Add initialization check on app startup
- [ ] Test with new user account

### Phase 2: Display Metrics
- [ ] Add journey progress to main page
- [ ] Show week number in weekly summary
- [ ] Display days passed in profile page

### Phase 3: Achievements
- [ ] Import `AchievementTimeService`
- [ ] Update achievement checking logic
- [ ] Add progress bars for locked achievements
- [ ] Test achievement unlocking

### Phase 4: Polish
- [ ] Add real-time updates with streams
- [ ] Show celebration animations on unlock
- [ ] Add pull-to-refresh on achievements page
- [ ] Test with different dates (30 days ago, etc.)

---

## 🔍 Troubleshooting

### Problem: Getting 0 for all metrics

**Solution:**
```dart
// Check if initialized
final isInitialized = await UserTimeTracker.isInitialized();
if (!isInitialized) {
  await UserTimeTracker.initializeUserStartDate();
}
```

### Problem: Metrics not updating

**Solution:**
```dart
// Use real-time stream instead
StreamBuilder<Map<String, dynamic>?>(
  stream: UserTimeTracker.getTimeTrackingStream(),
  builder: (context, snapshot) {
    // Rebuilds automatically when data changes
  },
);
```

### Problem: Wrong day count

**Cause:** Timezone or initialization issue

**Solution:**
```dart
// Check start date
final startDate = await UserTimeTracker.getUserStartDate();
print('Start date: $startDate');

// Should be in UTC format
// Example: 2025-01-15T00:00:00.000Z
```

---

## 📖 Files Reference

- **Core Service:** `lib/services/user_time_tracker.dart`
- **Achievements:** `lib/services/achievement_time_service.dart`
- **Full Guide:** `lib/services/TIME_TRACKING_GUIDE.md`
- **Example Page:** `lib/examples/achievements_page_with_time_tracking.dart`
- **Architecture:** `TIME_TRACKING_ARCHITECTURE.md`

---

## 🎨 UI Examples Available

Check `lib/examples/achievements_page_with_time_tracking.dart` for:

1. **Journey Progress Card** - Gradient card with metrics
2. **Week Progress Bar** - Visual week completion
3. **Achievement Cards** - With progress bars
4. **Statistics Grid** - Clean metric display
5. **Pull-to-Refresh** - Manual refresh support

You can copy any of these widgets directly!

---

## ⚡ Performance Tips

1. **Use `getAllTimeMetrics()`** instead of individual calls
2. **Cache metrics locally** if displaying in multiple places
3. **Use streams** for real-time updates, not polling
4. **Initialize once** per user, not on every app launch

---

## 🎯 Next Steps

1. **Start Simple**: Add initialization to registration flow
2. **Test Locally**: Create a test user and verify metrics
3. **Add UI**: Display days passed on main page
4. **Expand**: Add achievements and weekly summaries
5. **Polish**: Add animations and celebrations

---

## 💡 Pro Tips

- Initialize time tracking **after** user completes onboarding
- Use `getAllTimeMetrics()` to reduce Firebase reads
- Show progress bars for locked achievements (motivating!)
- Celebrate milestones: 7 days, 30 days, 100 days
- Use streams for pages that stay open long-term

---

## 🆘 Need Help?

1. Check `TIME_TRACKING_GUIDE.md` for detailed examples
2. Review `achievements_page_with_time_tracking.dart` for UI code
3. Read inline documentation in `user_time_tracker.dart`
4. Look at `TIME_TRACKING_ARCHITECTURE.md` for system overview

---

**You're ready to go! Start with Step 1 above and build from there.** 🚀
