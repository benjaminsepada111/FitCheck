# Firebase Diary Structure Implementation Plan

## Current vs New Structure

### Current Structure

```
/users/{userId}/challenges/{challengeId}/
  ├─ foodlogs/{logId} (flat structure, filtered by date)
  └─ workouts/{dateId}/items/{workoutId} (partially date-grouped)
```

### New Structure

```
/users/{userId}/challenges/{challengeId}/
  ├─ foodlogs/{dateId}/{foodId}
  ├─ workouts/{dateId}/cardio/{workoutId}
  ├─ workouts/{dateId}/strength/{workoutId}
  └─ stats/{dateId}
```

## Implementation Steps

### Phase 1: Create Models

- [x] Review existing models
- [ ] Create `DailyStats` model
- [ ] Update `Workout` model (already good)
- [ ] Update `FoodLog` model to work with new structure

### Phase 2: Create Stats Service

- [ ] Create `stats_service.dart`
- [ ] Implement automatic calculation logic
- [ ] Add listeners for food/workout changes
- [ ] Handle offline sync

### Phase 3: Refactor Services

- [ ] Refactor `food_log_service.dart` for date-grouped structure
- [ ] Refactor `workout_service.dart` to separate cardio/strength
- [ ] Add stats recalculation triggers

### Phase 4: Update UI Components

- [ ] Update food logging pages
- [ ] Update workout logging pages
- [ ] Update diary/tracker pages
- [ ] Update summary pages

### Phase 5: Testing & Migration

- [ ] Test offline sync
- [ ] Test real-time updates
- [ ] Create data migration utility (if needed)

## Date Format

Using YYYYMMDD format for dateId: `20251025`

## Stats Document Schema

```json
{
  "date": "2025-10-25T00:00:00Z",
  "foodCalories": 1200,
  "cardioCalories": 245,
  "strengthCalories": 0,
  "totalCalories": 1200,
  "burnedCalories": 245,
  "netCalories": 955,
  "remainingCalories": 936,
  "dailyGoal": 1891,
  "lastUpdated": "2025-10-25T09:00:00Z"
}
```
