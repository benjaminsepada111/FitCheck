# Quick Test Guide - Workout Page Redesign

## 🚀 How to Test the New Features

### Step 1: Build the App

```bash
flutter pub get
flutter run
```

### Step 2: Navigate to Workout Page

1. Open the app
2. Ensure you have an active challenge (create one if needed)
3. Navigate to the Workout History Page
4. Tap the floating **+ button** (bottom right)

---

## 🧪 Test Scenarios

### ✅ **Scenario 1: Add Cardio Workout**

**Steps:**

1. Modal opens with **Cardio** tab selected
2. Tap the "Search Exercise" field
3. Type: `running`
4. See filtered list appear below
5. Tap: `Running, 5 mph (12 min/mile)`
6. Verify: MET card appears showing "MET: 8.3"
7. Tap "Duration" field
8. Type: `30`
9. Tap "Camera" button (or skip if you prefer)
10. Take a photo (or skip)
11. Verify: "Save Workout" button is **enabled** (red)
12. Tap "Save Workout"
13. Verify: Modal closes
14. Verify: Green snackbar appears: "Cardio workout added successfully!"
15. Verify: Workout appears in history with orange "Cardio" badge
16. Verify: Shows "30 min" and "MET 8.3" badges

**Expected Result:** ✅ Cardio workout saved and displayed correctly

---

### ✅ **Scenario 2: Add Strength Workout**

**Steps:**

1. Tap the **+ button** again
2. Tap the **Strength** tab
3. Verify: Form switches to strength fields
4. Tap "Exercise Name" field
5. Type: `Bench Press`
6. Tap "Sets" field, type: `4`
7. Tap "Reps" field, type: `10`
8. Tap "Weight per Set" field, type: `60` (optional)
9. Tap "Gallery" button (or skip)
10. Select a photo (or skip)
11. Verify: "Save Workout" button is **enabled**
12. Tap "Save Workout"
13. Verify: Green snackbar: "Added Bench Press workout"
14. Verify: Workout appears with blue "Strength" badge
15. Verify: Shows "4 sets", "10 reps", "60.0 kg" badges

**Expected Result:** ✅ Strength workout saved and displayed correctly

---

### ✅ **Scenario 3: Toggle Between Tabs**

**Steps:**

1. Open add workout modal (Cardio selected)
2. Type in search: `swimming`
3. Select: `Swimming, freestyle, moderate`
4. Type duration: `45`
5. **Tap Strength tab**
6. Verify: Form switches to strength fields
7. Verify: Previous cardio data is cleared
8. **Tap Cardio tab again**
9. Verify: Form is reset (no exercise selected)

**Expected Result:** ✅ Switching tabs clears previous data

---

### ✅ **Scenario 4: Form Validation**

**Steps:**

1. Open add workout modal (Cardio)
2. Verify: "Save Workout" button is **disabled** (grayed out)
3. Search and select an exercise
4. Verify: Button still **disabled** (no duration)
5. Type duration: `20`
6. Verify: Button now **enabled**
7. Clear duration field
8. Verify: Button **disabled** again
9. Switch to Strength tab
10. Type exercise name: `Squats`
11. Verify: Button **disabled** (no sets/reps)
12. Type sets: `3`
13. Verify: Button still **disabled** (no reps)
14. Type reps: `12`
15. Verify: Button now **enabled**

**Expected Result:** ✅ Save button enables only when required fields are filled

---

### ✅ **Scenario 5: Exercise Search Filtering**

**Steps:**

1. Open add workout modal (Cardio)
2. Type: `run`
3. Verify: See "Running, 5 mph", "Running, 6 mph", "Running, 7 mph", etc.
4. Type: `running 5`
5. Verify: See only "Running, 5 mph"
6. Clear search (X button)
7. Verify: Dropdown closes, no exercise selected
8. Type: `swim`
9. Verify: See "Swimming, freestyle, slow", "Swimming, backstroke", etc.
10. Type: `cycle`
11. Verify: See "Cycling, stationary, light effort", etc.

**Expected Result:** ✅ Search filters correctly by name and category

---

### ✅ **Scenario 6: Image Upload**

**Steps:**

1. Open add workout modal
2. Fill required fields (cardio or strength)
3. Tap "Camera" button
4. Grant camera permission if needed
5. Take a photo
6. Verify: Photo preview appears (200px height)
7. Verify: X button in top-right corner
8. Tap X button
9. Verify: Photo removed, buttons reappear
10. Tap "Gallery" button
11. Select a photo from gallery
12. Verify: Photo preview appears
13. Tap "Save Workout"
14. Verify: Workout saved with image
15. Verify: Image appears in workout history

**Expected Result:** ✅ Image upload and preview work correctly

---

### ✅ **Scenario 7: Error Handling**

**Steps:**

1. Open add workout modal (Cardio)
2. Search and select exercise
3. Type duration: `1000`
4. Tap "Save Workout"
5. Verify: Red snackbar: "Duration seems too long..."
6. Change duration to: `abc`
7. Tap "Save Workout"
8. Verify: Button is disabled (non-numeric input)
9. Switch to Strength tab
10. Type exercise name: `A` (1 character)
11. Type sets: `3`, reps: `10`
12. Tap "Save Workout"
13. Verify: Red snackbar: "Exercise name must be at least 2 characters"
14. Type exercise name: `Ab` (2 characters)
15. Type sets: `200`
16. Tap "Save Workout"
17. Verify: Red snackbar: "Number of sets seems too high..."

**Expected Result:** ✅ Validation errors show appropriate messages

---

## 🎨 Visual Consistency Checks

### ✅ **Compare with Food Log Modal**

**Open Food Log (Food Page):**

1. Tap a recommended food
2. Notice modal appearance

**Open Workout Modal (Workout Page):**

1. Tap + button
2. Compare:

| Element                | Should Match                 |
| ---------------------- | ---------------------------- |
| Modal corner radius    | ✅ Same (24px)               |
| Input field corners    | ✅ Same (12px)               |
| Input field background | ✅ Same (light gray)         |
| Focus border color     | ✅ Same (red)                |
| Focus border width     | ✅ Same (2px)                |
| Button style           | ✅ Same (red bg, white text) |
| Button padding         | ✅ Same (16px vertical)      |
| Icon backgrounds       | ✅ Same (colored circles)    |
| Typography             | ✅ Same (Sen font)           |
| Spacing                | ✅ Same (16-24px)            |

---

## 🐛 Known Issues to Watch For

### ⚠️ **Potential Issues:**

1. **JSON Loading Failure**

   - **Symptom:** No exercises appear in search
   - **Cause:** Asset not loaded properly
   - **Fix:** Run `flutter pub get` and rebuild

2. **Image Upload on iOS**

   - **Symptom:** Camera/gallery buttons don't work
   - **Cause:** Missing permissions in Info.plist
   - **Fix:** Add camera/photo library permissions

3. **Keyboard Overlapping**

   - **Symptom:** Keyboard covers input fields
   - **Cause:** `isScrollControlled: true` needed
   - **Fix:** Already implemented in modal

4. **Old Workouts Not Loading**
   - **Symptom:** Existing strength workouts show errors
   - **Cause:** Old workouts don't have `workoutType` field
   - **Fix:** Default to 'strength' in `Workout.fromMap()` (already done)

---

## 📱 Device-Specific Testing

### **Android:**

- ✅ Test on Android 10+
- ✅ Test soft keyboard behavior
- ✅ Test back button (should close modal)
- ✅ Test camera permission flow

### **iOS:**

- ✅ Test on iOS 13+
- ✅ Test keyboard dismissal (tap outside)
- ✅ Test camera permission flow
- ✅ Test gallery permission flow

---

## 📊 Success Criteria

✅ All 7 test scenarios pass  
✅ Visual consistency with Food Log confirmed  
✅ No linter errors  
✅ No runtime errors  
✅ Images upload successfully  
✅ Workouts save to Firestore  
✅ Workouts appear in history  
✅ Delete works correctly  
✅ Form validation prevents invalid data  
✅ Toggle switches smoothly  
✅ Search filters correctly  
✅ MET values display correctly

---

## 🎯 Next Steps (After Testing)

1. **If everything works:** ✅ Ready for calorie calculation integration
2. **If issues found:** 🐛 Check console logs and report errors
3. **If design tweaks needed:** 🎨 Update colors/spacing as desired

---

## 💡 Quick Debugging Tips

### **Issue: Exercises not loading**

```dart
// Check console for:
print('Loaded ${_allCardioExercises.length} exercises');
```

### **Issue: Save button not enabling**

```dart
// Check validation:
print('Form valid: ${_isFormValid()}');
print('Selected exercise: $_selectedCardioExercise');
print('Duration: ${_durationController.text}');
```

### **Issue: Image not uploading**

```dart
// Check storage service:
print('Uploading image: ${_selectedImage?.path}');
print('Challenge ID: ${widget.currentChallenge.id}');
```

---

## 🎉 Enjoy Your New Workout Page!

The redesigned Workout Page is now ready for testing. Follow the scenarios above to verify everything works as expected. If you encounter any issues or have suggestions for improvements, feel free to iterate on the design!

**Happy Testing! 💪**
