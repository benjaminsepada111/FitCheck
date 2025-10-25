# Calorie Calculation System Update Summary

## Overview

Updated the app's calorie calculation system to use scientifically validated multipliers based on the Mifflin-St Jeor equation, aligned with real-world standards like MyFitnessPal. The system now focuses purely on accurate daily calorie goals and diary-style tracking.

## Changes Made

### 1. Updated Calorie Calculator Service (`lib/services/calorie_calculator.dart`)

**Before:**

- Used multipliers: 1.1, 1.2, 1.3, 1.4, 1.5
- Had old lifestyle level names: sedentary, lightly_active, moderately_active, active, very_active

**After:**

- **New validated multipliers**: 1.375, 1.55, 1.725, 1.9
- **New lifestyle levels**: not_active, active, very_active, extra_active
- Based on FAO/WHO and ACSM validated activity multipliers
- Deprecated `calculateDailyWaterGoal()` and `predictWeeklyWeightChange()` functions (kept for backward compatibility)

### 2. Updated Challenge Creation Form (`lib/MainPage/create_challenge_sheet.dart`)

**New Lifestyle Level Options:**

- **Not Active** (1.375) - Mostly sitting but includes light daily movement such as walking or chores
- **Active** (1.55) - Regular movement, light work, or occasional exercise
- **Very Active** (1.725) - Physically demanding job or daily workouts
- **Extra Active** (1.9) - Intense physical activity or multiple training sessions per day

**Goal Adjustments (unchanged):**

- Lose Fat (Deficit): -500 kcal/day
- Maintain Weight: 0 kcal/day
- Gain Muscle (Surplus): +500 kcal/day

### 3. Removed Water Goal Display (`lib/MainPage/challenge_summary_page.dart`)

- Removed water intake tracking and display
- Now shows only: Daily Calorie Goal and Duration
- Cleaned up unused imports and variables

### 4. Calculation Formula

```
BMR = (10 × weight kg) + (6.25 × height cm) – (5 × age) + gender offset
  Male: +5
  Female: –161

TDEE = BMR × Lifestyle Multiplier

Final Daily Goal = max(TDEE + Goal Adjustment, Safety Minimum)
  Male minimum: 1500 kcal
  Female minimum: 1200 kcal
```

## Verification Test Results

**Test Case:**

- User: Male, 21 years, 156 cm, 50 kg
- Lifestyle: Not Active (1.375)
- Goal: Maintain (0 adjustment)

**Expected Result:** 1891 kcal/day

**Calculation:**

```
BMR = (10 × 50) + (6.25 × 156) - (5 × 21) + 5
    = 500 + 975 - 105 + 5
    = 1375 kcal

TDEE = 1375 × 1.375
     = 1890.625 kcal

Final = max(1891, 1500) = 1891 kcal/day
```

**Result:** ✓ PASS - Calculation verified correct!

## Files Modified

1. `lib/services/calorie_calculator.dart` - Updated multipliers and formulas
2. `lib/MainPage/create_challenge_sheet.dart` - Updated lifestyle level options
3. `lib/MainPage/challenge_summary_page.dart` - Removed water goals, cleaned up code

## What Stays the Same

- BMR calculation using Mifflin-St Jeor equation (already correct)
- Safety minimums (1500 kcal male, 1200 kcal female)
- Goal adjustments (-500 deficit, 0 maintain, +500 surplus)
- User data model and storage
- Food logging functionality
- Workout tracking functionality

## User Experience Impact

- **More accurate calorie goals**: Based on validated research
- **Cleaner interface**: Removed unnecessary data clutter (water goals, weight predictions)
- **Focused tracking**: Pure diary-style calorie management
- **Better alignment**: Matches real-world standards like MyFitnessPal

## Backward Compatibility

- Legacy multipliers still supported for existing user data
- Deprecated functions marked but kept functional
- Default fallback to "not_active" (1.375) if lifestyle level not found

## Next Steps for Users

1. Create a new challenge to see the new lifestyle level options
2. Select your actual lifestyle level based on daily activity (not including workouts)
3. Track food and workouts as usual
4. System will automatically calculate accurate daily calorie goals

---

_Update completed: October 25, 2025_
