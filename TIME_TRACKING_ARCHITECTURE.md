# Time Tracking System Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      YOUR FLUTTER APP                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌─────────────────┐   ┌──────────────────┐
│  Achievements │    │ Weekly Summary  │   │ Progress Tracker │
│     Page      │    │      Page       │   │     Widget       │
└───────────────┘    └─────────────────┘   └──────────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────┐
        │   AchievementTimeService (Optional)         │
        │   - Combines metrics with statistics        │
        │   - Checks achievement unlock conditions    │
        │   - Provides progress percentages           │
        └─────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────┐
        │   UserTimeTracker (Core Service)            │
        │   =====================================     │
        │   - initializeUserStartDate()               │
        │   - getDaysPassed()                         │
        │   - getWeekNumber()                         │
        │   - getMonthsPassed()                       │
        │   - getAllTimeMetrics() ← Most efficient    │
        │   - hasCompletedDays(n)                     │
        │   - getWeekDateRange(weekNum)               │
        └─────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────┐
        │         Firebase Firestore                  │
        │   users/{userId}/profile/timeTracking       │
        │   {                                         │
        │     startDate: "2025-01-15T00:00:00.000Z"  │
        │     createdAt: "2025-01-15T10:30:00.000Z"  │
        │     lastUpdated: "..."                      │
        │   }                                         │
        └─────────────────────────────────────────────┘
```

---

## Data Flow

### 1. User Registration / First Launch

```
User Signs Up
     │
     ▼
UserTimeTracker.initializeUserStartDate()
     │
     ▼
Store startDate in Firebase
users/{userId}/profile/timeTracking/startDate
     │
     ▼
Ready to track time!
```

### 2. Getting Time Metrics (Efficient Method)

```
UI Component needs metrics
     │
     ▼
UserTimeTracker.getAllTimeMetrics()
     │
     ├─► Fetch startDate from Firebase (1 read)
     │
     ├─► Get current UTC time
     │
     ├─► Calculate daysPassed
     │      (UTC midnight comparison)
     │
     ├─► Calculate weekNumber
     │      weekNumber = (daysPassed / 7) + 1
     │
     ├─► Calculate monthsPassed
     │      (Month-by-month comparison)
     │
     ├─► Calculate dayOfWeek
     │      dayOfWeek = daysPassed % 7
     │
     ▼
Return all metrics in one Map
{
  'daysPassed': 15,
  'weekNumber': 3,
  'monthsPassed': 0,
  'dayOfWeek': 1,
  'startDate': "2025-01-15T00:00:00.000Z",
  'isInitialized': true
}
```

### 3. Achievement Checking

```
Achievement Page Loads
     │
     ▼
AchievementTimeService.checkAllAchievements()
     │
     ├─► UserTimeTracker.getAllTimeMetrics()
     │   (Get days, weeks, months)
     │
     ├─► StatisticsService.getAllStatistics()
     │   (Get login days, workouts, meals)
     │
     ▼
Combine both metrics
     │
     ▼
Check each achievement condition
     │
     ├─► "Week Warrior" → loginDays >= 7?
     ├─► "First Step" → days >= 1?
     ├─► "Century Club" → days >= 100?
     │
     ▼
Return achievement statuses with progress
{
  'week_warrior': {
    unlocked: true,
    progress: 1.0,
    description: "Log activity for 7 different days (7/7)"
  },
  'century_club': {
    unlocked: false,
    progress: 0.15,
    description: "Reach day 100 of your journey (15/100)"
  }
}
```

---

## UTC-Based Date Calculation Example

### Why UTC?

**Problem:** Timezones and DST cause errors
```
User in New York (EST): 11:00 PM Jan 1
User in Tokyo (JST):    1:00 PM Jan 2

Same moment, different dates! ❌
```

**Solution:** Always use UTC midnight
```
User in New York: 2025-01-02T00:00:00.000Z
User in Tokyo:    2025-01-02T00:00:00.000Z

Same date for everyone! ✅
```

### How daysPassed Works

```
startDate: 2025-01-15T00:00:00.000Z
today:     2025-01-20T00:00:00.000Z

Step 1: Normalize to UTC midnight
startMidnight = 2025-01-15T00:00:00.000Z
todayMidnight = 2025-01-20T00:00:00.000Z

Step 2: Calculate difference
difference = todayMidnight - startMidnight
           = 5 days

Result: daysPassed = 5
```

### How weekNumber Works

```
daysPassed = 5

Week calculation:
weekNumber = (daysPassed / 7) + 1
           = (5 / 7) + 1
           = 0 + 1
           = 1

Week 1: Days 0-6
Week 2: Days 7-13
Week 3: Days 14-20
...

Result: User is in Week 1, Day 5
```

### How monthsPassed Works

```
startDate: 2025-01-15
today:     2025-03-20

Step 1: Calculate month difference
monthDiff = (2025 - 2025) * 12 + (3 - 1)
          = 0 + 2
          = 2

Step 2: Adjust for day of month
today.day (20) >= startDate.day (15) ✓
No adjustment needed

Result: monthsPassed = 2
```

---

## Performance Considerations

### ❌ Bad: Multiple Calls

```dart
// Makes 3 separate Firebase reads!
final days = await UserTimeTracker.getDaysPassed();      // Read 1
final weeks = await UserTimeTracker.getWeekNumber();     // Read 2
final months = await UserTimeTracker.getMonthsPassed();  // Read 3

Total: 3 Firebase reads ❌
```

### ✅ Good: Batch Call

```dart
// Makes only 1 Firebase read!
final metrics = await UserTimeTracker.getAllTimeMetrics();
final days = metrics['daysPassed'];
final weeks = metrics['weekNumber'];
final months = metrics['monthsPassed'];

Total: 1 Firebase read ✅
```

### Firebase Read Optimization

```
Traditional approach:
┌─────────┐    ┌─────────┐    ┌─────────┐
│ Read 1  │ →  │ Read 2  │ →  │ Read 3  │
└─────────┘    └─────────┘    └─────────┘
   200ms          200ms          200ms
              Total: 600ms

Optimized approach:
┌──────────────────────┐
│   Single Read        │
│  (getAllTimeMetrics) │
└──────────────────────┘
       200ms
    Total: 200ms

3x faster! ✅
```

---

## Integration Points

### 1. User Registration Flow

```dart
SignUpPage
    │
    ▼
Firebase Auth
    │
    ▼
UserDataService.saveUserData()
    │
    ▼
UserTimeTracker.initializeUserStartDate() ← Add this!
    │
    ▼
Navigate to MainPage
```

### 2. Achievements Page

```dart
AchievementsPage
    │
    ▼
initState()
    │
    ▼
_loadAllData()
    │
    ├─► StatisticsService.getAllStatistics()
    ├─► UserTimeTracker.getAllTimeMetrics()      ← Add this!
    └─► AchievementTimeService.checkAllAchievements() ← Add this!
    │
    ▼
Display with progress bars
```

### 3. Weekly Summary Page

```dart
WeeklySummaryPage
    │
    ▼
UserTimeTracker.getWeekNumber()
    │
    ▼
UserTimeTracker.getWeekDateRange(weekNumber)
    │
    ▼
Fetch food logs / workouts for date range
    │
    ▼
Display weekly summary
```

### 4. Progress Widget (Any Page)

```dart
ProgressWidget
    │
    ▼
StreamBuilder(
  stream: UserTimeTracker.getTimeTrackingStream()
)
    │
    ▼
Auto-updates when startDate changes
```

---

## Error Handling Flow

```
User calls getDaysPassed()
    │
    ▼
Check: Is user authenticated?
    │
    ├─ NO → Return 0, log error
    │
    └─ YES
       │
       ▼
Check: Does startDate exist?
    │
    ├─ NO → Return 0, log warning
    │       (User needs to initialize)
    │
    └─ YES
       │
       ▼
Try to calculate
    │
    ├─ Error → Return 0, log error
    │
    └─ Success → Return result ✓
```

---

## Real-time Updates

### Scenario: User resets their start date

```
User resets journey
    │
    ▼
UserTimeTracker.resetStartDate(newDate)
    │
    ▼
Firebase updates timeTracking doc
    │
    ▼
Stream listeners get notification
    │
    ▼
UI components using getTimeTrackingStream()
automatically rebuild with new data
    │
    ▼
User sees updated metrics instantly
```

---

## Testing Scenarios

### Test Case 1: New User
```
Initial state: No startDate
Action: Initialize time tracking
Expected: daysPassed = 0, weekNumber = 1
```

### Test Case 2: 30 Days Later
```
Initial state: startDate = 30 days ago
Action: Get metrics
Expected: daysPassed = 30, weekNumber = 5, monthsPassed = 1
```

### Test Case 3: User Skips 2 Weeks
```
Initial state: startDate = 20 days ago
Last login: 6 days ago
Action: User opens app today
Expected: Still shows daysPassed = 20 ✓
(Not affected by login gaps)
```

### Test Case 4: Timezone Change
```
Initial state: User in NYC (EST)
Action: User travels to Tokyo (JST)
Expected: Same daysPassed value ✓
(UTC calculations prevent timezone issues)
```

---

## Achievement Unlock Logic

```
Achievement: "Week Warrior"
Condition: loginDays >= 7

Day 1: User logs food → loginDays = 1 ❌
Day 2: User logs food → loginDays = 2 ❌
Day 3: User logs food → loginDays = 3 ❌
...
Day 7: User logs food → loginDays = 7 ✓ UNLOCKED!

┌────────────────────────────────┐
│   🎉 Achievement Unlocked!     │
│      Week Warrior              │
│   "Complete 7 days of          │
│    tracking"                   │
└────────────────────────────────┘
```

---

## Summary

**Three-Layer Architecture:**

1. **UI Layer** (Your Pages)
   - Achievements, Summaries, Progress widgets
   - Displays metrics to user

2. **Service Layer**
   - `UserTimeTracker`: Core time calculations
   - `AchievementTimeService`: Achievement logic
   - `StatisticsService`: User activity stats

3. **Data Layer**
   - Firebase Firestore
   - Per-user time tracking documents
   - Real-time updates via streams

**Key Benefits:**
- ✅ Scalable for any number of users
- ✅ Accurate across timezones
- ✅ Works after periods of inactivity
- ✅ Efficient Firebase usage
- ✅ Easy to integrate
- ✅ Well-tested and documented
