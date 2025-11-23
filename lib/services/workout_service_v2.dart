import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import 'stats_service.dart';

/// Refactored Workout Service with cardio/strength separation
/// Structure: /users/{userId}/challenges/{challengeId}/workouts/{dateId}/cardio/{workoutId}
///           /users/{userId}/challenges/{challengeId}/workouts/{dateId}/strength/{workoutId}
class WorkoutServiceV2 {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _challengesCollection = 'challenges';
  static const String _workoutsCollection = 'workouts';

  /// Helper to format date as YYYYMMDD (with normalized date)
  static String _formatDateId(DateTime date) {
    // Normalize date to ignore time component
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return '${normalizedDate.year}${normalizedDate.month.toString().padLeft(2, '0')}${normalizedDate.day.toString().padLeft(2, '0')}';
  }

  /// Add a workout (automatically determines cardio or strength)
  static Future<bool> addWorkout({
    required String challengeId,
    required Workout workout,
    required int dailyGoal,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final dateId = _formatDateId(workout.timestamp);
      final workoutType = workout.isCardio ? 'cardio' : 'strength';

      // Create date document
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateId)
          .set({
        'date': workout.timestamp.toIso8601String(),
      }, SetOptions(merge: true));

      // Add workout to appropriate subcollection
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateId)
          .collection(workoutType)
          .doc(workout.id)
          .set(workout.toMap());

      // Trigger stats recalculation (only cardio affects calorie burn)
      if (workout.isCardio) {
        await StatsService.recalculateStatsForDate(
          challengeId,
          workout.timestamp,
          dailyGoal,
        );
      }

      if (kDebugMode) {
        print('$workoutType workout added: ${workout.exerciseName} on $dateId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error adding workout: $e');
      return false;
    }
  }

  /// Get all workouts for a specific date
  static Future<List<Workout>> getWorkoutsForDate({
    required String challengeId,
    required DateTime date,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final dateId = _formatDateId(date);
      final allWorkouts = <Workout>[];

      // Get cardio workouts
      final cardioSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateId)
          .collection('cardio')
          .orderBy('timestamp', descending: true)
          .get();

      allWorkouts.addAll(
        cardioSnapshot.docs.map((doc) => Workout.fromMap(doc.data())),
      );

      // Get strength workouts
      final strengthSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateId)
          .collection('strength')
          .orderBy('timestamp', descending: true)
          .get();

      allWorkouts.addAll(
        strengthSnapshot.docs.map((doc) => Workout.fromMap(doc.data())),
      );

      // Sort all by timestamp
      allWorkouts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allWorkouts;
    } catch (e) {
      if (kDebugMode) print('Error getting workouts for date: $e');
      return [];
    }
  }

  /// Get cardio workouts for a specific date
  static Future<List<Workout>> getCardioWorkoutsForDate({
    required String challengeId,
    required DateTime date,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final dateId = _formatDateId(date);

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateId)
          .collection('cardio')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Workout.fromMap(doc.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error getting cardio workouts: $e');
      return [];
    }
  }

  /// Get strength workouts for a specific date
  static Future<List<Workout>> getStrengthWorkoutsForDate({
    required String challengeId,
    required DateTime date,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final dateId = _formatDateId(date);

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateId)
          .collection('strength')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Workout.fromMap(doc.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error getting strength workouts: $e');
      return [];
    }
  }

  /// Get all workouts for a challenge (across all dates)
  static Future<List<Workout>> getChallengeWorkouts(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final allWorkouts = <Workout>[];

      // Get all date documents
      final datesSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .get();

      // For each date, get workouts from both cardio and strength
      for (var dateDoc in datesSnapshot.docs) {
        // Get cardio workouts
        final cardioSnapshot = await dateDoc.reference
            .collection('cardio')
            .orderBy('timestamp', descending: true)
            .get();

        allWorkouts.addAll(
          cardioSnapshot.docs.map((doc) => Workout.fromMap(doc.data())),
        );

        // Get strength workouts
        final strengthSnapshot = await dateDoc.reference
            .collection('strength')
            .orderBy('timestamp', descending: true)
            .get();

        allWorkouts.addAll(
          strengthSnapshot.docs.map((doc) => Workout.fromMap(doc.data())),
        );
      }

      // Sort all workouts by timestamp
      allWorkouts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allWorkouts;
    } catch (e) {
      if (kDebugMode) print('Error getting challenge workouts: $e');
      return [];
    }
  }

  /// Update a workout
  static Future<bool> updateWorkout({
    required String challengeId,
    required Workout workout,
    required int dailyGoal,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final dateId = _formatDateId(workout.timestamp);
      final workoutType = workout.isCardio ? 'cardio' : 'strength';

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateId)
          .collection(workoutType)
          .doc(workout.id)
          .update(workout.toMap());

      // Trigger stats recalculation (only cardio affects calorie burn)
      if (workout.isCardio) {
        await StatsService.recalculateStatsForDate(
          challengeId,
          workout.timestamp,
          dailyGoal,
        );
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error updating workout: $e');
      return false;
    }
  }

  /// Delete a workout
  static Future<bool> deleteWorkout({
    required String challengeId,
    required String workoutId,
    required DateTime workoutDate,
    required bool isCardio,
    required int dailyGoal,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final dateId = _formatDateId(workoutDate);
      final workoutType = isCardio ? 'cardio' : 'strength';

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateId)
          .collection(workoutType)
          .doc(workoutId)
          .delete();

      // Trigger stats recalculation (only cardio affects calorie burn)
      if (isCardio) {
        await StatsService.recalculateStatsForDate(
          challengeId,
          workoutDate,
          dailyGoal,
        );
      }

      if (kDebugMode) {
        print('$workoutType workout deleted: $workoutId from $dateId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error deleting workout: $e');
      return false;
    }
  }

  /// Listen to workouts for a specific date in real-time
  static Stream<List<Workout>> getWorkoutsStreamForDate({
    required String challengeId,
    required DateTime date,
  }) async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    final dateId = _formatDateId(date);

    // Combine streams from both cardio and strength
    final cardioStream = _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection(_challengesCollection)
        .doc(challengeId)
        .collection(_workoutsCollection)
        .doc(dateId)
        .collection('cardio')
        .orderBy('timestamp', descending: true)
        .snapshots();

    final strengthStream = _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection(_challengesCollection)
        .doc(challengeId)
        .collection(_workoutsCollection)
        .doc(dateId)
        .collection('strength')
        .orderBy('timestamp', descending: true)
        .snapshots();

    await for (final cardioSnapshot in cardioStream) {
      final strengthSnapshot = await strengthStream.first;

      final allWorkouts = <Workout>[];

      allWorkouts.addAll(
        cardioSnapshot.docs.map((doc) => Workout.fromMap(doc.data())),
      );

      allWorkouts.addAll(
        strengthSnapshot.docs.map((doc) => Workout.fromMap(doc.data())),
      );

      // Sort by timestamp
      allWorkouts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      yield allWorkouts;
    }
  }

  /// Calculate total calories burned from cardio for a specific date
  static Future<int> getCardioCaloriesForDate({
    required String challengeId,
    required DateTime date,
    double userWeight = 70, // Default weight in kg
  }) async {
    try {
      final cardioWorkouts = await getCardioWorkoutsForDate(
        challengeId: challengeId,
        date: date,
      );

      int totalCalories = 0;

      for (final workout in cardioWorkouts) {
        if (workout.met != null && workout.durationMinutes != null) {
          // Calories = MET × weight(kg) × duration(hours)
          final calories =
              workout.met! * userWeight * (workout.durationMinutes! / 60);
          totalCalories += calories.round();
        }
      }

      return totalCalories;
    } catch (e) {
      if (kDebugMode) print('Error calculating cardio calories: $e');
      return 0;
    }
  }

  /// Generate a unique workout ID
  static String generateWorkoutId() {
    return _firestore.collection('temp').doc().id;
  }

  /// Helper to get workout document name (for backward compatibility)
  static String createWorkoutDocName(String exerciseName, DateTime timestamp) {
    final sanitized = exerciseName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    final timeStamp = timestamp.millisecondsSinceEpoch.toString();
    return '${sanitized}_$timeStamp';
  }
}