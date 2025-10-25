# Firebase Diary Structure - Complete Implementation Guide

## Overview

The app now uses a diary-based Firebase structure where each challenge acts as a calorie diary with automatic daily statistics calculation. All food and workout data is organized by date, with a dedicated stats collection that updates automatically whenever entries are added, modified, or deleted.

---

## Database Structure

### Complete Hierarchy

```
/users/{userId}/challenges/{challengeId}/
  ├─ dailyCalorieGoal: 1891
  ├─ startDate: "2025-10-01"
  ├─ endDate: "2025-12-31"
  │
  ├─ foodlogs/
  │   └─ {dateId}/                    # e.g., "20251025"
  │       ├─ date: "2025-10-25T00:00:00Z"
  │       └─ items/
  │           ├─ {foodId1}/
  │           │   ├─ fdcId: 171705
  │           │   ├─ foodName: "Apple, raw"
  │           │   ├─ caloriesPer100g: 52
  │           │   ├─ servingSize: 100
  │           │   ├─ servingUnit: "g"
  │           │   ├─ mealType: "breakfast"
  │           │   └─ timestamp: "2025-10-25T07:30:00Z"
  │           └─ {foodId2}/...
  │
  ├─ workouts/
  │   └─ {dateId}/                    # e.g., "20251025"
  │       ├─ date: "2025-10-25T00:00:00Z"
  │       ├─ cardio/
  │       │   └─ {workoutId}/
  │       │       ├─ id: "workout_123"
  │       │       ├─ exerciseName: "Running"
  │       │       ├─ workoutType: "cardio"
  │       │       ├─ met: 9.8
  │       │       ├─ durationMinutes: 30
  │       │       └─ timestamp: "2025-10-25T08:00:00Z"
  │       └─ strength/
  │           └─ {workoutId}/
  │               ├─ id: "workout_456"
  │               ├─ exerciseName: "Bench Press"
  │               ├─ workoutType: "strength"
  │               ├─ sets: 3
  │               ├─ reps: 10
  │               ├─ weight: 20
  │               └─ timestamp: "2025-10-25T09:00:00Z"
  │
  └─ stats/
      └─ {dateId}/                    # e.g., "20251025"
          ├─ dateId: "20251025"
          ├─ date: "2025-10-25T00:00:00Z"
          ├─ foodCalories: 1200
          ├─ cardioCalories: 245
          ├─ strengthCalories: 0
          ├─ totalConsumed: 1200
          ├─ totalBurned: 245
          ├─ netCalories: 955
          ├─ remainingCalories: 936
          ├─ dailyGoal: 1891
          └─ lastUpdated: "2025-10-25T09:30:00Z"
```

---

## Date Format

All date IDs use **YYYYMMDD** format:

- October 25, 2025 → `"20251025"`
- January 1, 2026 → `"20260101"`

This format:

- ✅ Sorts chronologically
- ✅ Human-readable
- ✅ Consistent across all collections
- ✅ Works with Firestore document ID queries

---

## Core Services

### 1. DailyStats Model (`lib/models/daily_stats.dart`)

**Purpose:** Represents aggregated calorie data for a single date.

**Key Properties:**

```dart
class DailyStats {
  final String dateId;           // "20251025"
  final DateTime date;            // Full date object
  final int foodCalories;         // Total consumed
  final int cardioCalories;       // Burned from cardio
  final int strengthCalories;     // Always 0
  final int dailyGoal;            // User's goal
  final DateTime lastUpdated;     // Last calculation time

  // Computed properties
  int get totalConsumed;          // foodCalories
  int get totalBurned;            // cardioCalories + strengthCalories
  int get netCalories;            // consumed - burned
  int get remainingCalories;      // goal - food + burned
  bool get isOverGoal;            // netCalories > dailyGoal
  double get progressPercentage;  // (netCalories / goal) * 100
}
```

**Helper Methods:**

```dart
// Create empty stats
DailyStats.empty(DateTime date, int dailyGoal)

// Format date to ID
DailyStats.getDateId(DateTime date) → "20251025"

// Parse date ID back to DateTime
DailyStats.parseDateId(String dateId) → DateTime
```

---

### 2. StatsService (`lib/services/stats_service.dart`)

**Purpose:** Manages automatic stats calculation and real-time updates.

**Key Methods:**

#### Get Stats

```dart
// Get stats for a specific date
Future<DailyStats?> getStatsForDate(String challengeId, DateTime date)

// Get stats for a date range
Future<List<DailyStats>> getStatsForDateRange(
  String challengeId,
  DateTime startDate,
  DateTime endDate,
)

// Real-time stream
Stream<DailyStats?> getStatsStreamForDate(String challengeId, DateTime date)
```

#### Recalculate Stats (Automatic)

```dart
// Recalculates stats for a date (called automatically by food/workout services)
Future<bool> recalculateStatsForDate(
  String challengeId,
  DateTime date,
  int dailyGoal,
)
```

**How It Works:**

1. Queries all food items for the date
2. Sums calories from all meals
3. Queries all cardio workouts for the date
4. Calculates burned calories using MET values
5. Creates/updates stats document with totals
6. Returns true if successful

#### Summaries

```dart
// Get weekly summary
Future<Map<String, dynamic>> getWeeklySummary(
  String challengeId,
  DateTime weekStart,
)

// Batch recalculate (for data migration)
Future<bool> batchRecalculateStats(
  String challengeId,
  List<DateTime> dates,
  int dailyGoal,
)
```

---

### 3. FoodLogServiceV2 (`lib/services/food_log_service_v2.dart`)

**Purpose:** Manages food items with date-grouped structure and automatic stats updates.

**Key Methods:**

#### Add Food

```dart
Future<bool> addFoodItem({
  required String challengeId,
  required DateTime date,
  required String mealType,      // "breakfast", "lunch", "dinner", "snack"
  required FoodEntry foodEntry,
  required int dailyGoal,
})
```

**Flow:**

1. Creates date document if doesn't exist
2. Adds food item to `items` subcollection
3. Triggers `StatsService.recalculateStatsForDate()`
4. Returns success status

#### Get Food Items

```dart
// Get all food items grouped by meal type
Future<Map<String, List<Map<String, dynamic>>>> getFoodItemsForDate({
  required String challengeId,
  required DateTime date,
})

// Returns: {"breakfast": [...], "lunch": [...], "dinner": [...], "snack": [...]}

// Backward compatible method
Future<List<FoodLog>> getFoodLogsForDate(DateTime date, {required String challengeId})

// Real-time stream
Stream<Map<String, List<Map<String, dynamic>>>> getFoodItemsStreamForDate({
  required String challengeId,
  required DateTime date,
})
```

#### Update/Delete Food

```dart
Future<bool> updateFoodItem({
  required String challengeId,
  required DateTime date,
  required String foodId,
  required FoodEntry updatedEntry,
  required String mealType,
  required int dailyGoal,
})

Future<bool> deleteFoodItem({
  required String challengeId,
  required DateTime date,
  required String foodId,
  required int dailyGoal,
})
```

Both automatically trigger stats recalculation.

#### Utilities

```dart
// Calculate daily total
Future<double> getDailyCalories(DateTime date, {required String challengeId})

// Get breakdown by meal
Future<Map<String, double>> getMealCalorieBreakdown(DateTime date, {required String challengeId})

// Get recent foods
Future<List<FoodEntry>> getRecentFoodEntries({int limit = 20, required String challengeId})
```

---

### 4. WorkoutServiceV2 (`lib/services/workout_service_v2.dart`)

**Purpose:** Manages workouts with cardio/strength separation and automatic stats updates.

**Key Methods:**

#### Add Workout

```dart
Future<bool> addWorkout({
  required String challengeId,
  required Workout workout,
  required int dailyGoal,
})
```

**Flow:**

1. Determines workout type (cardio or strength)
2. Creates date document if doesn't exist
3. Adds workout to appropriate subcollection (`cardio/` or `strength/`)
4. If cardio, triggers stats recalculation
5. If strength, no stats update (strength doesn't burn measurable calories)

#### Get Workouts

```dart
// Get all workouts for a date (both cardio and strength)
Future<List<Workout>> getWorkoutsForDate({
  required String challengeId,
  required DateTime date,
})

// Get only cardio workouts
Future<List<Workout>> getCardioWorkoutsForDate({
  required String challengeId,
  required DateTime date,
})

// Get only strength workouts
Future<List<Workout>> getStrengthWorkoutsForDate({
  required String challengeId,
  required DateTime date,
})

// Get all workouts for entire challenge
Future<List<Workout>> getChallengeWorkouts(String challengeId)

// Real-time stream
Stream<List<Workout>> getWorkoutsStreamForDate({
  required String challengeId,
  required DateTime date,
})
```

#### Update/Delete Workout

```dart
Future<bool> updateWorkout({
  required String challengeId,
  required Workout workout,
  required int dailyGoal,
})

Future<bool> deleteWorkout({
  required String challengeId,
  required String workoutId,
  required DateTime workoutDate,
  required bool isCardio,
  required int dailyGoal,
})
```

Both automatically trigger stats recalculation if cardio.

#### Calculate Calories

```dart
Future<int> getCardioCaloriesForDate({
  required String challengeId,
  required DateTime date,
  double userWeight = 70,  // kg
})
```

Uses formula: `Calories = MET × weight(kg) × duration(hours)`

---

## Usage Examples

### Example 1: Add Food and View Stats

```dart
// 1. Add a food item
await FoodLogServiceV2.addFoodItem(
  challengeId: "challenge_123",
  date: DateTime(2025, 10, 25),
  mealType: "breakfast",
  foodEntry: FoodEntry(
    id: FoodLogServiceV2.generateFoodItemId(),
    fdcId: 171705,
    foodName: "Apple, raw",
    servingSize: 100,
    servingUnit: "g",
    caloriesPer100g: 52,
  ),
  dailyGoal: 1891,
);

// 2. Stats are automatically calculated
// 3. Fetch updated stats
final stats = await StatsService.getStatsForDate(
  "challenge_123",
  DateTime(2025, 10, 25),
);

print('Food: ${stats?.foodCalories} kcal');
print('Remaining: ${stats?.remainingCalories} kcal');
```

### Example 2: Add Cardio Workout

```dart
// Add cardio workout
await WorkoutServiceV2.addWorkout(
  challengeId: "challenge_123",
  workout: Workout(
    id: WorkoutServiceV2.generateWorkoutId(),
    userId: currentUser.uid,
    exerciseName: "Running",
    workoutType: "cardio",
    met: 9.8,
    durationMinutes: 30,
    timestamp: DateTime.now(),
  ),
  dailyGoal: 1891,
);

// Stats automatically update with burned calories
```

### Example 3: Real-Time Stats Monitoring

```dart
// Listen to stats changes in real-time
StreamBuilder<DailyStats?>(
  stream: StatsService.getStatsStreamForDate(
    challengeId,
    DateTime.now(),
  ),
  builder: (context, snapshot) {
    final stats = snapshot.data;
    if (stats == null) return Text('No data yet');

    return Column(
      children: [
        Text('Daily Goal: ${stats.dailyGoal} kcal'),
        Text('Consumed: ${stats.foodCalories} kcal'),
        Text('Burned: ${stats.totalBurned} kcal'),
        Text('Remaining: ${stats.remainingCalories} kcal'),
        LinearProgressIndicator(
          value: stats.progressPercentage / 100,
        ),
      ],
    );
  },
)
```

### Example 4: Get Weekly Summary

```dart
final weekStart = DateTime.now().subtract(Duration(days: 7));
final summary = await StatsService.getWeeklySummary(
  "challenge_123",
  weekStart,
);

print('Total food this week: ${summary['totalFoodCalories']} kcal');
print('Total burned: ${summary['totalBurnedCalories']} kcal');
print('Average daily: ${summary['averageDailyCalories']} kcal');
print('Days logged: ${summary['daysLogged']}');
```

---

## Benefits of This Structure

### 1. Performance Optimized

- ✅ Each food/workout is a separate document (easy to edit/delete)
- ✅ Date-grouped organization reduces query complexity
- ✅ Stats are pre-calculated (no expensive aggregations)
- ✅ Firestore is optimized for many small documents

### 2. Real-Time Updates

- ✅ Any add/update/delete instantly reflects in stats
- ✅ UI can use streams for automatic updates
- ✅ No manual refresh needed

### 3. Accurate Calculations

- ✅ Stats recalculated on every data change
- ✅ Consistent across all devices
- ✅ No stale data

### 4. Scalable

- ✅ Easy to add weekly/monthly summaries
- ✅ Can aggregate stats documents for analytics
- ✅ Handles large datasets efficiently

### 5. Extensible

- ✅ Easy to add new meal types
- ✅ Can add more workout types
- ✅ Stats schema can be expanded

---

## Migration Strategy

### For Existing Data

If you have existing challenges with the old structure, you can migrate using:

```dart
Future<void> migrateChallenge(String challengeId) async {
  // 1. Get challenge details
  final challenge = await ChallengeService.getChallenge(challengeId);
  if (challenge == null) return;

  // 2. Get all dates in challenge
  final dates = <DateTime>[];
  for (var date = challenge.startDate;
       date.isBefore(challenge.endDate.add(Duration(days: 1)));
       date = date.add(Duration(days: 1))) {
    dates.add(date);
  }

  // 3. Batch recalculate stats
  await StatsService.batchRecalculateStats(
    challengeId,
    dates,
    challenge.dailyCalorieGoal,
  );

  print('Migration complete for $challengeId');
}
```

### Gradual Rollout

The V2 services are backward compatible:

1. Keep old services running
2. Start using V2 services for new data
3. Migrate old challenges as needed
4. Eventually remove old services

---

## Testing Checklist

- [ ] Add food item → verify stats update
- [ ] Delete food item → verify stats recalculate
- [ ] Add cardio workout → verify calories burned update
- [ ] Add strength workout → verify no stats change
- [ ] Test real-time streams
- [ ] Test offline sync
- [ ] Test date boundaries (midnight transitions)
- [ ] Test multiple users
- [ ] Test large datasets (100+ entries per day)

---

## Firestore Security Rules

Add these rules to `firestore.rules`:

```javascript
// Stats collection - read by owner, write only by cloud functions
match /users/{userId}/challenges/{challengeId}/stats/{dateId} {
  allow read: if request.auth.uid == userId;
  // Write access should ideally be restricted to cloud functions
  // For now, allow write for client-side calculation
  allow write: if request.auth.uid == userId;
}

// Food logs - read/write by owner
match /users/{userId}/challenges/{challengeId}/foodlogs/{dateId}/items/{itemId} {
  allow read, write: if request.auth.uid == userId;
}

// Workouts - read/write by owner
match /users/{userId}/challenges/{challengeId}/workouts/{dateId}/{type}/{workoutId} {
  allow read, write: if request.auth.uid == userId;
}
```

---

## Future Enhancements

1. **Cloud Functions** - Move stats calculation to server-side for better reliability
2. **Batch Operations** - Support bulk add/delete operations
3. **Analytics** - Weekly/monthly aggregation documents
4. **Caching** - Local cache for faster load times
5. **Export** - Export diary data to CSV/PDF
6. **Sharing** - Share daily summaries with friends
7. **Reminders** - Notifications if not logged by certain time

---

## Summary

The new diary-based structure provides:

- ✅ **Organized** - Everything grouped by date
- ✅ **Automatic** - Stats update on every change
- ✅ **Accurate** - Real-time calorie tracking
- ✅ **Efficient** - Optimized for Firestore
- ✅ **Simple** - Clean API, easy to use
- ✅ **Scalable** - Handles growth gracefully

**Date format:** YYYYMMDD (e.g., "20251025")  
**Stats update:** Automatic on food/cardio changes  
**Strength workouts:** Stored but don't affect calorie burn

Use the V2 services for all new development!
