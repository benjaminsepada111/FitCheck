# FitCheck Achievement System Integration Guide

## Overview

This guide explains how to integrate the achievement tracking system throughout your FitCheck app. The system automatically unlocks achievements when users meet conditions.

## Architecture

### Files
- `lib/services/user_achievement_service.dart` - Main achievement service
- `lib/achievements_page.dart` - UI for displaying achievements
- `lib/services/achievement_time_service.dart` - Alternative time-based tracking (optional)

### Firestore Structure
```
users/
  {uid}/
    stats/
      user_stats (document)
        - total_calories_burned: int
        - consecutive_login_days: int
        - photo_upload_days: int
        - meal_logging_days: int
        - total_workouts: int
        - challenges_completed: int
        - login_dates: array
        - photo_upload_dates: array
        - meal_logging_dates: array
    achievements/
      {achievement_id} (document)
        - unlocked: bool
        - progress: double (0.0 to 1.0)
        - unlocked_at: timestamp
```

## Integration Points

### 1. App Launch / User Login

**File**: `lib/main.dart` or your authentication handler

```dart
import 'package:capstone_project/services/user_achievement_service.dart';

// When user successfully logs in or app launches with authenticated user
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeAchievements();
  }

  Future<void> _initializeAchievements() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Track daily login
      await UserAchievementService.trackDailyLogin();

      // Check for newly unlocked achievements
      final newlyUnlocked = await UserAchievementService.checkAndUnlockAchievements();

      // Optional: Show achievement unlock notifications
      if (newlyUnlocked.isNotEmpty) {
        _showAchievementNotifications(newlyUnlocked);
      }
    }
  }

  void _showAchievementNotifications(List<String> achievementIds) {
    for (final id in achievementIds) {
      final achievement = UserAchievementService.getAchievementWithMetadata(id);
      // Show snackbar, dialog, or notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Achievement Unlocked: ${achievement['title']}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
```

### 2. Workout Completion

**File**: Your workout tracking/completion page

```dart
import 'package:capstone_project/services/user_achievement_service.dart';

// When user completes a workout
Future<void> _completeWorkout(int caloriesBurned) async {
  try {
    // Track workout with calories burned
    await UserAchievementService.trackWorkoutCompletion(caloriesBurned);

    // This automatically:
    // - Increments total_workouts by 1
    // - Adds caloriesBurned to total_calories_burned
    // - Checks and unlocks relevant achievements

    print('Workout tracked successfully!');
  } catch (e) {
    print('Error tracking workout: $e');
  }
}

// Example usage:
_completeWorkout(350); // User burned 350 calories
```

### 3. Photo Upload

**File**: Your progress photo upload page

```dart
import 'package:capstone_project/services/user_achievement_service.dart';

// When user successfully uploads a progress photo
Future<void> _uploadProgressPhoto(File imageFile) async {
  try {
    // Upload photo to Firebase Storage
    final photoUrl = await _uploadToStorage(imageFile);

    // Track photo upload for achievement
    await UserAchievementService.trackPhotoUpload();

    // This tracks unique days of photo uploads
    print('Photo uploaded and tracked!');
  } catch (e) {
    print('Error uploading photo: $e');
  }
}
```

### 4. Meal Logging

**File**: Your meal logging page

```dart
import 'package:capstone_project/services/user_achievement_service.dart';

// When user logs a meal
Future<void> _logMeal(Map<String, dynamic> mealData) async {
  try {
    // Save meal to Firestore
    await FirebaseFirestore.instance
        .collection('meals')
        .add(mealData);

    // Track meal logging for achievement
    await UserAchievementService.trackMealLogging();

    // This tracks unique days of meal logging
    print('Meal logged and tracked!');
  } catch (e) {
    print('Error logging meal: $e');
  }
}
```

### 5. Challenge Completion

**File**: Your challenge tracking page

```dart
import 'package:capstone_project/services/user_achievement_service.dart';

// When user completes a challenge
Future<void> _completeChallenge(String challengeId) async {
  try {
    // Update challenge status
    await FirebaseFirestore.instance
        .collection('challenges')
        .doc(challengeId)
        .update({'completed': true});

    // Track challenge completion for achievement
    await UserAchievementService.trackChallengeCompletion();

    // This increments challenges_completed by 1
    print('Challenge completed and tracked!');
  } catch (e) {
    print('Error completing challenge: $e');
  }
}
```

### 6. Manual Calorie Tracking (Alternative)

**File**: Any page where you track calories separately from workouts

```dart
import 'package:capstone_project/services/user_achievement_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// If tracking calories separately
Future<void> _addCaloriesBurned(int calories) async {
  try {
    await UserAchievementService.incrementStat('total_calories_burned', calories);
    print('Calories tracked!');
  } catch (e) {
    print('Error tracking calories: $e');
  }
}
```

## Display Achievements in UI

### Navigate to Achievements Page

```dart
import 'package:capstone_project/achievements_page.dart';

// Add button to navigate to achievements
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AchievementsPage()),
    );
  },
  child: const Text('View Achievements'),
)
```

### Show Achievement Count Badge

```dart
import 'package:capstone_project/services/user_achievement_service.dart';

class AchievementBadge extends StatefulWidget {
  @override
  State<AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<AchievementBadge> {
  int _unlockedCount = 0;
  int _totalCount = 6;

  @override
  void initState() {
    super.initState();
    _loadAchievementCount();
  }

  Future<void> _loadAchievementCount() async {
    final counts = await UserAchievementService.getAchievementCount();
    setState(() {
      _unlockedCount = counts['unlocked'] ?? 0;
      _totalCount = counts['total'] ?? 6;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$_unlockedCount/$_totalCount',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
```

## Achievement Definitions

| Achievement | Condition | Threshold | Description |
|------------|-----------|-----------|-------------|
| Challenge Conqueror | `challenges_completed` | 1 | Complete your first challenge |
| Burning Resolve | `total_calories_burned` | 5000 | Burn 5000 calories total |
| Steadfast | `consecutive_login_days` | 7 | Log in for 7 consecutive days |
| Perseverance | `photo_upload_days` | 7 | Upload progress photos for 7 days |
| Discipline | `meal_logging_days` | 30 | Log meals for 30 days |
| Workout Warrior | `total_workouts` | 50 | Complete 50 workouts |

## Testing

### Manual Testing

1. **Test Login Tracking**:
   ```dart
   await UserAchievementService.trackDailyLogin();
   final stats = await UserAchievementService.getUserStats();
   print('Login days: ${stats['consecutive_login_days']}');
   ```

2. **Test Workout Tracking**:
   ```dart
   await UserAchievementService.trackWorkoutCompletion(100);
   final stats = await UserAchievementService.getUserStats();
   print('Total workouts: ${stats['total_workouts']}');
   print('Total calories: ${stats['total_calories_burned']}');
   ```

3. **Check Achievements**:
   ```dart
   final achievements = await UserAchievementService.getAllAchievementsWithDetails();
   for (final achievement in achievements) {
     print('${achievement['title']}: ${achievement['unlocked'] ? 'UNLOCKED' : 'Locked'} (${(achievement['progress'] * 100).toStringAsFixed(0)}%)');
   }
   ```

### Simulate Achievement Unlocks (Development Only)

```dart
// WARNING: Only use for testing!
Future<void> _simulateAchievements() async {
  // Unlock Challenge Conqueror
  await UserAchievementService.trackChallengeCompletion();

  // Unlock Burning Resolve (5000 calories)
  await UserAchievementService.incrementStat('total_calories_burned', 5000);

  // Unlock Workout Warrior (50 workouts)
  for (int i = 0; i < 50; i++) {
    await UserAchievementService.trackWorkoutCompletion(100);
  }

  print('Simulated achievements unlocked!');
}
```

## Best Practices

1. **Always wrap in try-catch**: Achievement tracking shouldn't crash your app
   ```dart
   try {
     await UserAchievementService.trackDailyLogin();
   } catch (e) {
     debugPrint('Achievement tracking failed: $e');
     // Continue with normal app flow
   }
   ```

2. **Track at the right time**: Call tracking methods AFTER successful operations
   ```dart
   // Good: Track after successful upload
   await uploadPhoto();
   await UserAchievementService.trackPhotoUpload();

   // Bad: Track before operation completes
   await UserAchievementService.trackPhotoUpload(); // Too early!
   await uploadPhoto();
   ```

3. **Show feedback**: Let users know when they unlock achievements
   ```dart
   final newlyUnlocked = await UserAchievementService.checkAndUnlockAchievements();
   if (newlyUnlocked.isNotEmpty) {
     _showCelebration(newlyUnlocked);
   }
   ```

4. **Refresh UI**: Update achievement displays when returning from other pages
   ```dart
   @override
   void didChangeDependencies() {
     super.didChangeDependencies();
     _loadAchievements(); // Refresh when navigating back
   }
   ```

## Firestore Security Rules

Add these rules to protect user achievement data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User stats
    match /users/{userId}/stats/{statId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // User achievements
    match /users/{userId}/achievements/{achievementId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Troubleshooting

### Achievements not unlocking?

1. Check user is authenticated: `FirebaseAuth.instance.currentUser != null`
2. Verify stats are updating: `await UserAchievementService.getUserStats()`
3. Check Firestore console for data
4. Enable debug logs: Look for `debugPrint` messages

### Stats not incrementing?

1. Ensure you're calling the tracking methods after successful operations
2. Check network connectivity
3. Verify Firestore security rules allow writes
4. Check for exceptions in console

### Progress not showing correctly?

1. Refresh the achievements page
2. Check that you're using the correct stat key names
3. Verify thresholds in achievement definitions

## Additional Features

### Get Recently Unlocked Achievements

```dart
final recent = await UserAchievementService.getRecentlyUnlockedAchievements();
// Shows achievements unlocked in last 7 days
```

### Get Specific Achievement with Progress

```dart
final achievements = await UserAchievementService.getAllAchievementsWithDetails();
final burningResolve = achievements.firstWhere(
  (a) => a['id'] == 'burning_resolve',
);
print('Burning Resolve: ${burningResolve['currentValue']}/${burningResolve['threshold']} calories');
```

## Next Steps

1. Add achievement tracking calls to your existing features (workouts, meals, photos, challenges)
2. Test each achievement type manually
3. Add celebration animations/sounds when achievements unlock
4. Consider push notifications for achievement unlocks
5. Add achievement sharing to social media

## Support

For issues or questions, check:
- [user_achievement_service.dart](lib/services/user_achievement_service.dart) - Service implementation
- [achievements_page.dart](lib/achievements_page.dart) - UI reference
- Firestore console for data verification
