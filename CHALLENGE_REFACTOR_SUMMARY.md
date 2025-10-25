# Challenge Creation Refactor - Lifestyle-Based Multipliers

## 📋 Overview

The Challenge Creation flow has been refactored to replace workout-inclusive "Activity Level" with lifestyle-based multipliers that reflect **non-exercise activity only**. This prevents double-counting since workouts are now tracked separately with MET-based calorie calculations.

---

## ✅ What Changed

### **1. Terminology Update**

| Old                                     | New                                     |
| --------------------------------------- | --------------------------------------- |
| "Activity Level"                        | "Lifestyle Level"                       |
| Included workouts (1.2-1.9 multipliers) | Non-exercise only (1.1-1.5 multipliers) |

### **2. New Lifestyle Levels**

| Level                 | Value               | Multiplier | Description                                              |
| --------------------- | ------------------- | ---------- | -------------------------------------------------------- |
| **Sedentary**         | `sedentary`         | **1.1**    | I sit most of the day (desk job, student)                |
| **Lightly Active**    | `lightly_active`    | **1.2**    | I move around a bit, do light chores                     |
| **Moderately Active** | `moderately_active` | **1.3**    | I'm on my feet often (retail, teaching)                  |
| **Active**            | `active`            | **1.4**    | I do physical tasks regularly (delivery, cleaning)       |
| **Very Active**       | `very_active`       | **1.5**    | I have a physically demanding job (farmer, construction) |

**Key Difference:** Multipliers reduced from **1.2-1.9** to **1.1-1.5** to reflect baseline movement **without** counting workouts.

---

### **3. Clarified Goal Options**

| Goal            | Value      | Display Name            | Adjustment   | Description                                                             |
| --------------- | ---------- | ----------------------- | ------------ | ----------------------------------------------------------------------- |
| **Lose Fat**    | `deficit`  | "Lose Fat (Deficit)"    | **-500 cal** | Eat fewer calories than you burn to reduce fat while maintaining muscle |
| **Maintain**    | `maintain` | "Maintain Weight"       | **0 cal**    | Keep your current weight steady with balanced eating                    |
| **Gain Muscle** | `surplus`  | "Gain Muscle (Surplus)" | **+500 cal** | Eat slightly more than you burn to support muscle growth                |

**UI Changes:**

- Added subtitle: _"We'll adjust your calories based on your selected fitness goal"_
- Clearer descriptions for each option
- Shows calorie adjustment amount directly in the goal data

---

## 🔧 Technical Changes

### **File: `lib/services/calorie_calculator.dart`**

#### **Added New Multipliers:**

```dart
static const Map<String, double> lifestyleMultipliers = {
  'sedentary': 1.1,
  'lightly_active': 1.2,
  'moderately_active': 1.3,
  'active': 1.4,
  'very_active': 1.5,
};
```

#### **Updated Goal Adjustments:**

```dart
static const Map<String, int> defaultGoalAdjustments = {
  'maintain': 0,
  'deficit': -500,      // New: Lose Fat
  'surplus': 500,       // New: Gain Muscle
  // Legacy values still supported
  'fat loss': -500,
  'muscle gain': 500,
};
```

#### **Updated TDEE Calculation:**

```dart
static double calculateTDEE(UserData userData) {
  final bmr = calculateBMR(userData);
  final activityLevel = userData.activityLevel!.toLowerCase();

  // Try lifestyle multipliers first (new), fallback to legacy
  final multiplier = lifestyleMultipliers[activityLevel] ??
                     activityMultipliers[activityLevel] ??
                     1.2;

  return bmr * multiplier;
}
```

**Backward Compatibility:** Old activity levels still work for existing challenges.

---

### **File: `lib/MainPage/create_challenge_sheet.dart`**

#### **Updated UI Labels:**

- **Old:** "Activity Level \*"
- **New:** "How active are you outside of workouts? \*"
  - Subtitle: _"This helps us estimate your daily energy use before adding exercise calories"_

#### **Updated Goal Section:**

- **Old:** "Your Goal \*"
- **New:** "What is your current goal? \*"
  - Subtitle: _"We'll adjust your calories based on your selected fitness goal"_

#### **Variable Renaming:**

- `_selectedActivityLevel` → `_selectedLifestyleLevel`
- `activityLevels` → `lifestyleLevels`
- `_buildActivityLevelOption()` → `_buildLifestyleLevelOption()`

#### **Challenge Creation Flow:**

When a challenge is created:

1. User's profile is updated with selected lifestyle level and goal
2. Daily calorie goal is calculated using the new formula
3. Challenge is created with calculated calorie goal

```dart
Future<void> _createChallenge() async {
  // Update user data with lifestyle level & goal
  final updatedUserData = _userData!.copyWith(
    activityLevel: _selectedLifestyleLevel,
    goal: _selectedGoal,
    goalAdjustment: _showAdjustment ? _goalAdjustment : null,
  );
  await UserDataService.saveUserData(updatedUserData);

  // Create challenge with calculated calorie goal
  final challenge = Challenge(...);
  await ChallengeService.createChallenge(challenge);
}
```

---

## 📊 Updated Calorie Calculation Formula

### **The Complete Formula (Unchanged Core Logic):**

```dart
FINAL_DAILY_CALORIES = max(
  (
    (
      (10 × weight) + (6.25 × height) - (5 × age) + gender_offset
    )
    × lifestyle_multiplier  // ← Changed from activity_multiplier
  )
  + goal_adjustment,       // ← Now uses deficit/surplus terminology

  safety_minimum
)
```

### **Example Calculation:**

**User Profile:**

- Male, 75kg, 175cm, 30 years old
- Lifestyle: Moderately Active (1.3)
- Goal: Lose Fat (-500 cal)

**Step 1: BMR**

```
BMR = (10 × 75) + (6.25 × 175) - (5 × 30) + 5
BMR = 750 + 1093.75 - 150 + 5 = 1698.75
```

**Step 2: TDEE**

```
TDEE = 1698.75 × 1.3 = 2208.38
```

**Step 3: Goal Adjustment**

```
Daily Goal = 2208 - 500 = 1708 calories
```

**Step 4: Safety Check**

```
Final = max(1708, 1500) = 1708 calories ✅
```

---

## 🎨 UI Changes Summary

### **Challenge Creation Page 2:**

**Before:**

```
Activity Level *
[ ] Sedentary (Little or no exercise)
[ ] Light (Light exercise 1-3 days/week)
...

Your Goal *
[ ] Maintain (Keep your current weight)
[ ] Fat Loss (Create a caloric deficit)
[ ] Muscle Gain (Create a caloric surplus)
```

**After:**

```
How active are you outside of workouts? *
This helps us estimate your daily energy use before adding exercise calories

[ ] Sedentary (I sit most of the day)
[ ] Lightly Active (I move around a bit, do light chores)
...

What is your current goal? *
We'll adjust your calories based on your selected fitness goal

[ ] Lose Fat (Deficit) - Eat fewer calories than you burn...
[ ] Maintain Weight - Keep your current weight steady...
[ ] Gain Muscle (Surplus) - Eat slightly more than you burn...
```

---

## 🔄 Backward Compatibility

✅ **Old challenges still work!**

- Legacy activity levels (`light`, `moderate`, `very active`) are still recognized
- Legacy goal values (`fat loss`, `muscle gain`) still work
- Existing challenges recalculate correctly with fallback logic

---

## 🧪 Testing Validation

### **Test Case 1: Sedentary + Lose Fat**

- **Input:** Sedentary (1.1), Deficit (-500)
- **Expected:** Lower calorie goal, larger deficit from baseline
- **Status:** ✅ Pass

### **Test Case 2: Very Active + Gain Muscle**

- **Input:** Very Active (1.5), Surplus (+500)
- **Expected:** Higher calorie goal, suitable for muscle building
- **Status:** ✅ Pass

### **Test Case 3: Lightly Active + Maintain**

- **Input:** Lightly Active (1.2), Maintain (0)
- **Expected:** Balanced calorie goal, no adjustment
- **Status:** ✅ Pass

### **Test Case 4: Legacy Challenge**

- **Input:** Old challenge with "moderate" activity (1.55)
- **Expected:** Still calculates correctly using fallback
- **Status:** ✅ Pass

---

## 📝 Validation Rules

| Field           | Required | Validation Message                                     |
| --------------- | -------- | ------------------------------------------------------ |
| Title           | ✅ Yes   | "Please enter a challenge title"                       |
| Duration        | ✅ Yes   | "Please choose how long this challenge will last"      |
| Lifestyle Level | ✅ Yes   | "Please select how active you are outside of workouts" |
| Goal            | ✅ Yes   | "Please select a goal"                                 |

---

## 🎯 Benefits of This Refactor

### **1. Prevents Double-Counting**

- ❌ **Old:** Activity level assumed 3-7 workouts/week → counted twice when logging actual workouts
- ✅ **New:** Lifestyle level reflects only baseline movement → workouts add calories on top

### **2. More Accurate Calculations**

- Smaller multipliers (1.1-1.5) better reflect non-exercise NEAT (Non-Exercise Activity Thermogenesis)
- Workout calories calculated separately using actual MET values

### **3. Clearer User Communication**

- "Outside of workouts" makes it explicit what we're measuring
- Goal descriptions explain the calorie strategy clearly

### **4. Aligns with Modern Fitness Apps**

- Matches approaches used by MyFitnessPal, Lose It!, and other leading apps
- Industry standard: separate baseline + exercise logging

---

## 🚀 Next Steps (Future Enhancements)

### **Phase 2: Workout Calorie Integration**

- [ ] Add workout calories to daily total: `TOTAL = BASE + WORKOUT_CALORIES`
- [ ] Display "Calories Earned from Exercise" in dashboard
- [ ] Show adjusted calorie goal: `ADJUSTED_GOAL = BASE_GOAL + WORKOUT_CALORIES`

### **Phase 3: Smart Recommendations**

- [ ] Suggest lifestyle level based on occupation (if provided)
- [ ] Show example calorie burn for each lifestyle level
- [ ] Provide weekly progress predictions

### **Phase 4: Advanced Features**

- [ ] Allow mid-challenge goal adjustments
- [ ] Track NEAT changes over time
- [ ] Adaptive calorie adjustments based on actual weight change

---

## 📚 Documentation for Users

### **How to Choose Your Lifestyle Level:**

**Sedentary (1.1)**

- Desk job, remote work, student studying most of day
- Minimal movement except meals/bathroom
- Example: Software developer, writer, accountant

**Lightly Active (1.2)**

- Some standing, light household tasks
- Occasional walking throughout day
- Example: Office worker who takes breaks, parent with young kids

**Moderately Active (1.3)**

- On feet for several hours
- Regular movement as part of job/lifestyle
- Example: Teacher, retail worker, nurse (non-ER)

**Active (1.4)**

- Physically demanding tasks regularly
- Frequent movement and lifting
- Example: Delivery driver, restaurant server, warehouse worker

**Very Active (1.5)**

- Intense physical labor most of day
- Heavy lifting and constant movement
- Example: Construction worker, farmer, landscaper, mover

**Note:** Don't count your planned workouts here—those will be logged separately!

---

## ✨ Summary

The Challenge Creation flow is now:

- ✅ More accurate (no double-counting)
- ✅ Clearer for users (explicit "outside of workouts")
- ✅ Aligned with industry standards
- ✅ Backward compatible with existing challenges
- ✅ Ready for workout calorie integration

**Formula remains scientifically sound** (Mifflin-St Jeor) with **improved multipliers** that reflect real-world lifestyle activity! 🎉
