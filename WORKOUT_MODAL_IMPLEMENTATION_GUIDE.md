# Workout Modal V2 - Quick Implementation Guide

## ✅ What's Ready to Use

All code is complete and linted. You can start using the new workout modal immediately.

## 📦 New Files

1. **`lib/services/workout_cache_service.dart`** - Caching service
2. **`lib/WorkoutPage/add_workout_sheet_v2.dart`** - New modal
3. **`WORKOUT_MODAL_REDESIGN_SUMMARY.md`** - Complete documentation

## 🚀 Quick Start (3 Steps)

### Step 1: Import the New Modal

```dart
import 'package:capstone_project/WorkoutPage/add_workout_sheet_v2.dart';
```

### Step 2: Show the Modal

```dart
void _showAddWorkoutModal() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddWorkoutSheetV2(
      challengeId: widget.currentChallenge.id,
      onWorkoutAdded: (name, calories, {durationMinutes, met, imageUrl}) {
        _handleWorkoutAdded(name, calories, durationMinutes, met, imageUrl);
      },
    ),
  );
}
```

### Step 3: Handle the Workout Data

```dart
Future<void> _handleWorkoutAdded(
  String workoutName,
  int calories,
  int? durationMinutes,
  double? met,
  String? imageUrl,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final workout = Workout(
    id: WorkoutService.generateWorkoutId(),
    userId: user.uid,
    exerciseName: workoutName,
    workoutType: 'cardio',
    durationMinutes: durationMinutes,
    met: met,
    caloriesBurned: calories, // NEW: use this for display
    imageUrl: imageUrl,
    timestamp: DateTime.now(),
  );

  final success = await WorkoutService.createWorkout(
    workout,
    widget.currentChallenge.id,
  );

  if (success) {
    setState(() {
      // Refresh your data
    });
  }
}
```

## 🎯 Key Differences from Old Modal

| Feature        | Old Modal                 | New Modal (V2)               |
| -------------- | ------------------------- | ---------------------------- |
| **Calories**   | Shows MET values          | Shows actual calories burned |
| **Search**     | Limited to 25 results     | Shows all matching results   |
| **Caching**    | No caching                | Firebase + session caching   |
| **Design**     | Custom design             | Matches food modal exactly   |
| **Button**     | Conditionally disabled    | Always active (shows errors) |
| **Weight**     | Uses fixed 70kg           | Uses user's actual weight    |
| **Entry Mode** | Cardio vs Strength toggle | Search vs Manual toggle      |

## 📝 Example: Replace in Challenge Page

**OLD CODE:**

```dart
FloatingActionButton(
  onPressed: () {
    showModalBottomSheet(
      context: context,
      builder: (context) => AddWorkoutSheet(
        currentChallenge: widget.currentChallenge,
        onWorkoutAdded: () {
          _refreshWorkouts();
        },
      ),
    );
  },
  child: Icon(Icons.add),
)
```

**NEW CODE:**

```dart
FloatingActionButton(
  onPressed: () {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddWorkoutSheetV2(
        challengeId: widget.currentChallenge.id,
        onWorkoutAdded: (name, calories, {durationMinutes, met, imageUrl}) async {
          final workout = Workout(
            id: WorkoutService.generateWorkoutId(),
            userId: FirebaseAuth.instance.currentUser!.uid,
            exerciseName: name,
            workoutType: 'cardio',
            durationMinutes: durationMinutes,
            met: met,
            caloriesBurned: calories,
            imageUrl: imageUrl,
            timestamp: DateTime.now(),
          );

          await WorkoutService.createWorkout(
            workout,
            widget.currentChallenge.id,
          );

          _refreshWorkouts();
        },
      ),
    );
  },
  child: Icon(Icons.add),
)
```

## ✨ Features You Get For Free

### 1. Firebase Caching

Searches are automatically cached. Users' repeat searches load instantly.

### 2. Smart Search

- Multi-keyword matching (e.g., "mountain bike" finds all mountain biking activities)
- Case-insensitive
- Searches names and categories

### 3. Popular Workouts

When search is empty, shows 5 popular workouts:

- Running
- Walking
- Bicycling
- Swimming
- Yoga

### 4. Personalized Calories

Automatically uses the user's weight from their profile:

```dart
// Calculation done automatically:
calories = MET × user_weight × (duration / 60)
```

### 5. Image Upload

Works exactly like food log image upload:

- Camera or gallery
- Auto-upload to Firebase Storage
- Organized by challenge
- Non-blocking (continues without image if upload fails)

## 🔧 Customization Options

### Change Modal Height

```dart
// Default is 85% of screen
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => Container(
    height: MediaQuery.of(context).size.height * 0.9, // Custom height
    child: AddWorkoutSheetV2(...),
  ),
)
```

### Disable Image Upload

```dart
AddWorkoutSheetV2(
  challengeId: null, // No challenge = no image upload
  onWorkoutAdded: (...) { },
)
```

### Custom Callback Logic

```dart
onWorkoutAdded: (name, calories, {durationMinutes, met, imageUrl}) {
  // Your custom logic here
  print('Workout: $name');
  print('Calories: $calories');
  print('Duration: $durationMinutes min');
  print('MET: $met');
  print('Image: $imageUrl');

  // Save, display, analyze, etc.
}
```

## 🐛 Troubleshooting

### "No workouts found"

- **Cause:** Compendium file not loaded
- **Fix:** Ensure `assets/data/compendium_2024_activities.json` is in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/data/compendium_2024_activities.json
```

### Calories seem wrong

- **Cause:** User weight not set
- **Fix:** User needs to complete profile with weight. Defaults to 70kg.

### Cache not working

- **Cause:** Firebase not initialized
- **Fix:** Ensure Firebase is initialized in `main.dart`

### Images not uploading

- **Cause:** No challenge ID provided
- **Fix:** Pass valid `challengeId` to modal

## 📊 Performance Tips

### Preload Compendium (Optional)

Load exercises early for faster first search:

```dart
@override
void initState() {
  super.initState();
  // Preload in background
  WorkoutCacheService.searchWorkouts('running').then((_) {
    print('Compendium preloaded');
  });
}
```

### Clear Cache (If Needed)

```dart
// Clear session cache (in-memory)
WorkoutCacheService.clearSessionCache();

// Clear Firebase cache (persistent)
await WorkoutCacheService.clearUserCache();
```

## ✅ Testing Checklist

Before going live, test these scenarios:

- [ ] Search for common workouts (running, yoga, swimming)
- [ ] Search with multiple keywords ("mountain bike")
- [ ] Select a workout and enter duration
- [ ] Verify calor calories calculated correctly
- [ ] Try manual entry mode
- [ ] Upload an image (camera and gallery)
- [ ] Save workout without image
- [ ] Try with no internet (should use cache)
- [ ] Repeat search (should be instant from cache)
- [ ] Check UI matches food modal
- [ ] Try invalid inputs (see error messages)

## 📞 Support

For issues or questions:

1. Check `WORKOUT_MODAL_REDESIGN_SUMMARY.md` for detailed docs
2. Read inline code comments in:
   - `lib/services/workout_cache_service.dart`
   - `lib/WorkoutPage/add_workout_sheet_v2.dart`
3. Compare with food modal implementation (`lib/FoodPage/add_food_sheet.dart`)

## 🎉 That's It!

You're ready to use the new workout modal. It's consistent with your food logging, shows real calories, and provides a better user experience.

Happy coding! 💪
