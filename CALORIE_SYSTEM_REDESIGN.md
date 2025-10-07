# Calorie Tracking System Redesign

## Overview
The calorie tracking system has been redesigned to integrate workout tracking without double-counting calories. The new architecture uses a sedentary baseline combined with dynamic workout calories to provide accurate daily calorie targets.

## Architecture Changes

### Old System (Double Counting Issue)
```
Daily Calorie Goal = BMR × Activity Multiplier ± Goal Adjustment
- Activity multipliers: sedentary (1.2), light (1.375), moderate (1.55), active (1.725)
- Problem: Assumes constant daily activity, doesn't account for logged workouts
- Result: Double counts exercise calories
```

### New System (Accurate Tracking)
```
Baseline Goal = BMR × 1.2 (sedentary) ± Goal Adjustment
Workout Calories = Sum of MET-based calculations for all workouts
Dynamic Daily Target = Baseline Goal + Workout Calories
Net Calories = Calories Consumed - Dynamic Daily Target
```

## Key Components

### 1. **Sedentary Baseline Calculation**
[calorie_calculator.dart:56-62](lib/services/calorie_calculator.dart#L56-L62)

- Uses only sedentary multiplier (1.2) for base metabolism
- Represents daily energy needs without planned exercise
- Prevents double-counting of workout calories

**Method:** `CalorieCalculator.calculateSedentaryBaseline(userData)`

### 2. **MET-Based Workout Calories**
[calorie_calculator.dart:245-317](lib/services/calorie_calculator.dart#L245-L317)

**Formula:** `Calories = MET × weight(kg) × duration(hours)`

MET (Metabolic Equivalent of Task) values represent energy cost as multiples of resting metabolic rate:
- Running (moderate): 8.0 MET
- Swimming: 8.0 MET
- Cycling: 6.5 MET
- Walking: 3.5 MET
- Weight Training: 4.5 MET
- Yoga: 3.0 MET

**Methods:**
- `CalorieCalculator.calculateCaloriesFromMET()` - Calculate calories from MET value
- `CalorieCalculator.getMETForExercise()` - Get MET value for common exercises

### 3. **Dynamic Calorie Service**
[daily_calorie_service.dart](lib/services/daily_calorie_service.dart)

Manages daily calorie targets that adjust based on logged workouts.

**Key Methods:**
- `calculateDynamicDailyTarget()` - Returns baseline + workout calories
- `getDailySummary()` - Comprehensive calorie metrics for a date
- `getNetCalorieBalance()` - Shows surplus/deficit
- `getCalorieProgress()` - Progress toward dynamic target
- `getCalorieStatus()` - Whether user is within healthy range

**Data Model:** `DailyCalorieSummary`
- `baselineGoal` - Sedentary baseline ± goal adjustment
- `caloriesConsumed` - From food logs
- `caloriesBurned` - From workout logs (MET-based)
- `dynamicTarget` - Baseline + workouts
- `netCalories` - Consumed - target
- `remainingCalories` - Target - consumed

### 4. **Updated Workout Models**
[workout_models.dart:205-266](lib/models/workout_models.dart#L205-L266)

Common exercises now use MET values instead of hardcoded calories/minute:
```dart
'Running': {'met': 8.0, 'description': 'Moderate pace'}
'Swimming': {'met': 8.0, 'description': 'Moderate effort'}
```

### 5. **Enhanced UI Display**
[daily_logs.dart:268-442](lib/MainPage/daily_logs.dart#L268-L442)

**New Features:**
- Displays baseline goal separately from dynamic target
- Shows workout calorie bonus
- Real-time net calorie balance
- Color-coded surplus (red) / deficit (green)

**UI Components:**
- Circular progress uses dynamic target
- Info bar shows:
  - Baseline Goal
  - Workout Bonus (if workouts logged)
  - Dynamic Target (baseline + workouts)
  - Net Balance (with color coding)

## Usage Examples

### Example 1: No Workouts
```
User: 25F, 65kg, goal = fat loss
BMR = 1450 cal
Baseline Goal = 1450 × 1.2 - 500 = 1240 cal
Workout Calories = 0 cal
Dynamic Target = 1240 cal
```

### Example 2: With Workout
```
User: 25F, 65kg, goal = fat loss
BMR = 1450 cal
Baseline Goal = 1450 × 1.2 - 500 = 1240 cal
Workout: Running 30 min (MET 8.0)
Workout Calories = 8.0 × 65 × 0.5 = 260 cal
Dynamic Target = 1240 + 260 = 1500 cal
```

## Migration Guide

### Deprecated Methods
The following methods are deprecated but still functional for backward compatibility:

- `calculateTDEE()` → Use `calculateSedentaryBaseline()`
- `calculateDailyCalorieGoal()` → Use `calculateBaselineCalorieGoal()`

### For New Features
Use the `DailyCalorieService` for all calorie calculations:

```dart
// Get dynamic daily target
final target = await DailyCalorieService.calculateDynamicDailyTarget(
  userData: userData,
  date: date,
  challengeId: challengeId,
);

// Get comprehensive summary
final summary = await DailyCalorieService.getDailySummary(
  userData: userData,
  date: date,
  challengeId: challengeId,
);

// Check calorie status
final status = await DailyCalorieService.getCalorieStatus(
  userData: userData,
  date: date,
  challengeId: challengeId,
);
```

## Benefits

### 1. **No Double Counting**
- Baseline uses sedentary multiplier only
- Workouts add calories separately
- Each workout is counted once

### 2. **Accurate Tracking**
- MET-based calculations account for user weight
- Scientifically validated energy expenditure
- Adjusts daily for actual activity

### 3. **Real-Time Feedback**
- Dynamic target updates as workouts logged
- Net balance shows actual surplus/deficit
- Progress bar reflects true calorie consumption

### 4. **Goal-Specific Ranges**
```dart
Fat Loss: Target ±50 cal
Muscle Gain: Target ±200 cal
Maintenance: Target ±200 cal
```

## Data Flow

```
User Profile (weight, age, gender, goal)
    ↓
CalorieCalculator.calculateSedentaryBaseline()
    ↓
Baseline Goal = BMR × 1.2 ± goal adjustment
    ↓
Workouts Logged (exercise, duration, intensity)
    ↓
CalorieCalculator.calculateCaloriesFromMET()
    ↓
Workout Calories = MET × weight × duration
    ↓
DailyCalorieService.calculateDynamicDailyTarget()
    ↓
Dynamic Target = Baseline + Workout Calories
    ↓
UI displays dynamic target and net balance
```

## Technical Notes

### Activity Level Field
- Still stored in `UserData` for potential future use
- No longer used in daily calorie calculations
- Could be repurposed for general lifestyle tracking

### Backward Compatibility
- Deprecated methods still function
- Existing challenges with fixed goals continue working
- Gradual migration to dynamic system recommended

### Performance
- Caches user data to minimize Firestore reads
- Calorie summaries calculated on-demand
- Debug logging for troubleshooting

## Future Enhancements

1. **Custom MET Values**
   - Allow users to input custom exercises with MET values
   - Store personal MET preferences

2. **Weekly Averages**
   - Track average dynamic targets
   - Compare actual vs. target over time

3. **Smart Recommendations**
   - Suggest workouts to hit calorie goals
   - Adjust baseline based on actual results

4. **Activity Level Integration**
   - Use for non-exercise activity thermogenesis (NEAT)
   - Separate from planned workouts

## Testing Checklist

- [ ] Baseline calculation with different user profiles
- [ ] MET-based calorie calculation for various exercises
- [ ] Dynamic target updates when workouts added/removed
- [ ] Net balance calculation accuracy
- [ ] UI displays correct values
- [ ] Progress bar uses dynamic target
- [ ] Calorie status ranges work correctly
- [ ] No double counting in any scenario

## References

- Mifflin-St Jeor Equation (BMR)
- Compendium of Physical Activities (MET values)
- ACSM Guidelines for Exercise Testing and Prescription
