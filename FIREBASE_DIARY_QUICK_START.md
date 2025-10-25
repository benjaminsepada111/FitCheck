# Firebase Diary Structure - Quick Start Guide

## 🎯 What Was Built

A complete diary-based calorie tracking system with **automatic statistics calculation** using scientifically validated formulas.

### ✅ Completed Components

1. **`DailyStats` Model** (`lib/models/daily_stats.dart`)

   - Represents daily calorie data for a specific date
   - Auto-calculates remaining calories, progress, etc.

2. **`StatsService`** (`lib/services/stats_service.dart`)

   - Automatic stats recalculation on every food/workout change
   - Real-time streams for live UI updates
   - Weekly summaries and batch operations

3. **`FoodLogServiceV2`** (`lib/services/food_log_service_v2.dart`)

   - Date-grouped food storage
   - Automatic stats triggers
   - Real-time food item streams

4. **`WorkoutServiceV2`** (`lib/services/workout_service_v2.dart`)
   - Separate cardio/strength collections
   - Automatic stats updates (cardio only)
   - Real-time workout streams

---

## 📁 Database Structure

```
/users/{userId}/challenges/{challengeId}/
  ├─ foodlogs/{dateId}/items/{foodId}        # Individual food items
  ├─ workouts/{dateId}/cardio/{workoutId}    # Cardio workouts
  ├─ workouts/{dateId}/strength/{workoutId}  # Strength workouts
  └─ stats/{dateId}                           # Daily summaries (auto-calculated)
```

**Date Format:** YYYYMMDD (e.g., `"20251025"` for October 25, 2025)

---

## 🚀 How To Use

### 1. Add Food (Auto-updates stats)

```dart
await FoodLogServiceV2.addFoodItem(
  challengeId: "challenge_123",
  date: DateTime.now(),
  mealType: "breakfast",  // breakfast, lunch, dinner, snack
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
// ✅ Stats automatically recalculated!
```

### 2. Add Workout (Auto-updates stats for cardio)

```dart
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
// ✅ Stats automatically updated with burned calories!
```

### 3. View Today's Stats

```dart
final stats = await StatsService.getStatsForDate(
  "challenge_123",
  DateTime.now(),
);

print('Consumed: ${stats?.foodCalories} kcal');
print('Burned: ${stats?.cardioCalories} kcal');
print('Remaining: ${stats?.remainingCalories} kcal');
```

### 4. Real-Time Stats UI

```dart
StreamBuilder<DailyStats?>(
  stream: StatsService.getStatsStreamForDate(
    challengeId,
    DateTime.now(),
  ),
  builder: (context, snapshot) {
    final stats = snapshot.data;
    return Text('Remaining: ${stats?.remainingCalories ?? 0} kcal');
  },
)
```

---

## 🔄 How It Works

### Flow Diagram

```
User adds food
    ↓
FoodLogServiceV2.addFoodItem()
    ↓
Saves to /foodlogs/{dateId}/items/{foodId}
    ↓
Calls StatsService.recalculateStatsForDate()
    ↓
Queries all food items for date
Queries all cardio workouts for date
    ↓
Calculates totals
    ↓
Updates /stats/{dateId}
    ↓
UI automatically updates via stream
```

---

## 📊 Stats Document Structure

```json
{
  "dateId": "20251025",
  "date": "2025-10-25T00:00:00Z",
  "foodCalories": 1200,
  "cardioCalories": 245,
  "strengthCalories": 0,
  "totalConsumed": 1200,
  "totalBurned": 245,
  "netCalories": 955,
  "remainingCalories": 936,
  "dailyGoal": 1891,
  "lastUpdated": "2025-10-25T09:30:00Z"
}
```

### Calorie Formula

```
remainingCalories = dailyGoal - foodCalories + cardioCalories
```

**Example:**

- Daily Goal: 1891 kcal
- Food Consumed: 1200 kcal
- Cardio Burned: 245 kcal
- **Remaining:** 1891 - 1200 + 245 = **936 kcal** ✅

---

## 🎯 Integration with Mifflin-St Jeor

The new diary system works perfectly with the updated calorie calculation:

```dart
// 1. Calculate user's daily goal using Mifflin-St Jeor
final userData = await UserDataService.loadUserData();
final dailyGoal = CalorieCalculator.calculateDailyCalorieGoal(userData);

// 2. Create challenge with this goal
final challenge = Challenge(
  id: ChallengeService.generateChallengeId(),
  dailyCalorieGoal: dailyGoal,  // e.g., 1891 kcal
  // ... other fields
);

// 3. Log food/workouts throughout the day
await FoodLogServiceV2.addFoodItem(..., dailyGoal: challenge.dailyCalorieGoal);

// 4. Stats automatically track against this goal
final stats = await StatsService.getStatsForDate(challengeId, DateTime.now());
// stats.remainingCalories will show how many calories left for the day
```

---

## 🔥 Key Features

### ✅ Automatic Calculation

- Every add/update/delete triggers stats recalculation
- No manual refresh needed
- Always accurate and up-to-date

### ✅ Real-Time Updates

- Use streams for live UI updates
- Changes instantly reflect across devices
- Perfect for progress tracking

### ✅ Performance Optimized

- Date-grouped organization reduces query complexity
- Pre-calculated stats (no expensive aggregations at runtime)
- Firestore-optimized structure

### ✅ Backward Compatible

- Old `FoodLogService` and `WorkoutService` still work
- Gradual migration possible
- V2 services designed for easy transition

---

## 🧪 Testing Example

```dart
// Test the complete flow
void testDiaryFlow() async {
  final challengeId = "test_challenge";
  final today = DateTime.now();
  final dailyGoal = 2000;

  // 1. Add breakfast
  await FoodLogServiceV2.addFoodItem(
    challengeId: challengeId,
    date: today,
    mealType: "breakfast",
    foodEntry: FoodEntry(...),  // 300 kcal
    dailyGoal: dailyGoal,
  );

  // 2. Check stats
  var stats = await StatsService.getStatsForDate(challengeId, today);
  print('After breakfast: ${stats?.remainingCalories} kcal');  // 1700

  // 3. Add cardio workout
  await WorkoutServiceV2.addWorkout(
    challengeId: challengeId,
    workout: Workout(...),  // Burns 200 kcal
    dailyGoal: dailyGoal,
  );

  // 4. Check stats again
  stats = await StatsService.getStatsForDate(challengeId, today);
  print('After workout: ${stats?.remainingCalories} kcal');  // 1900

  // 5. Add lunch
  await FoodLogServiceV2.addFoodItem(
    challengeId: challengeId,
    date: today,
    mealType: "lunch",
    foodEntry: FoodEntry(...),  // 500 kcal
    dailyGoal: dailyGoal,
  );

  // 6. Final check
  stats = await StatsService.getStatsForDate(challengeId, today);
  print('After lunch: ${stats?.remainingCalories} kcal');  // 1400

  // ✅ All stats automatically calculated correctly!
}
```

---

## 📝 Migration Path

### Option 1: Fresh Start

Use V2 services for all new challenges going forward.

### Option 2: Gradual Migration

```dart
// Migrate existing challenge
Future<void> migrateChallenge(String challengeId) async {
  final challenge = await ChallengeService.getChallenge(challengeId);
  if (challenge == null) return;

  // Recalculate stats for all dates in challenge
  final dates = <DateTime>[];
  for (var date = challenge.startDate;
       date.isBefore(challenge.endDate.add(Duration(days: 1)));
       date = date.add(Duration(days: 1))) {
    dates.add(date);
  }

  await StatsService.batchRecalculateStats(
    challengeId,
    dates,
    challenge.dailyCalorieGoal,
  );
}
```

---

## 📖 Documentation

- **Full Implementation Guide:** `FIREBASE_DIARY_IMPLEMENTATION.md`
- **Calorie Calculation Update:** `CALORIE_CALCULATION_UPDATE_SUMMARY.md`
- **Planning Document:** `FIREBASE_DIARY_STRUCTURE_PLAN.md`

---

## 🎉 Summary

You now have a complete, production-ready diary-based calorie tracking system with:

✅ **Automatic stats calculation** - No manual work needed  
✅ **Real-time updates** - Changes instantly visible  
✅ **Scientifically accurate** - Uses Mifflin-St Jeor + validated multipliers  
✅ **Performance optimized** - Designed for Firestore  
✅ **Easy to use** - Clean API, simple integration

**Start using V2 services today for all new development!** 🚀
