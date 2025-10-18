import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/workout.dart';

class WorkoutService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _challengesCollection = 'challenges';
  static const String _workoutsCollection = 'workouts';

  /// Helper to format date as MMDDYYYY
  static String _formatDateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$month$day$year';
  }

  /// Helper to create a unique workout document name from exercise name
  static String _createWorkoutDocName(String exerciseName, DateTime timestamp) {
    // Sanitize the exercise name (remove special characters, replace spaces with underscores)
    final sanitized = exerciseName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    // Add timestamp to make it unique
    final timeStamp = timestamp.millisecondsSinceEpoch.toString();
    return '${sanitized}_$timeStamp';
  }

  /// Create a new workout entry under a specific challenge
  static Future<bool> createWorkout(Workout workout, String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      final dateKey = _formatDateKey(workout.timestamp);
      final workoutDocName = _createWorkoutDocName(workout.exerciseName, workout.timestamp);

      // Structure: workouts/{date}/items/{workoutName}
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateKey)
          .set({'date': workout.timestamp.toIso8601String()}, SetOptions(merge: true));

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateKey)
          .collection('items')
          .doc(workoutDocName)
          .set(workout.toMap());

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all workouts for a specific challenge
  static Future<List<Workout>> getChallengeWorkouts(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      List<Workout> allWorkouts = [];

      // Get all date documents
      final datesSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .get();


      // For each date, get workouts from its subcollection
      for (var dateDoc in datesSnapshot.docs) {
        final dateKey = dateDoc.id;

        final workoutsSnapshot = await dateDoc.reference
            .collection('items')
            .orderBy('timestamp', descending: true)
            .get();


        final dateWorkouts = workoutsSnapshot.docs
            .map((doc) => Workout.fromMap(doc.data()))
            .toList();

        allWorkouts.addAll(dateWorkouts);
      }

      // Sort all workouts by timestamp
      allWorkouts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allWorkouts;
    } catch (e) {
      return [];
    }
  }

  /// Get workouts for a specific date in a specific challenge
  static Future<List<Workout>> getWorkoutsForDate(String challengeId, DateTime date) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final dateKey = _formatDateKey(date);

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateKey)
          .collection('items')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Workout.fromMap(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Update a workout in a specific challenge
  static Future<bool> updateWorkout(Workout workout, String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      final dateKey = _formatDateKey(workout.timestamp);
      final workoutDocName = _createWorkoutDocName(workout.exerciseName, workout.timestamp);

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateKey)
          .collection('items')
          .doc(workoutDocName)
          .update(workout.toMap());

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a workout from a specific challenge
  static Future<bool> deleteWorkout(String workoutDocName, String challengeId, DateTime workoutDate) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      final dateKey = _formatDateKey(workoutDate);

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateKey)
          .collection('items')
          .doc(workoutDocName)
          .delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Listen to workouts in real-time for a specific challenge
  static Stream<List<Workout>> getWorkoutsStream(String challengeId) async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    try {
      // Get all date documents
      final datesSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .get();

      List<Workout> allWorkouts = [];

      // For each date, get workouts from its subcollection
      for (var dateDoc in datesSnapshot.docs) {
        final workoutsSnapshot = await dateDoc.reference
            .collection('items')
            .orderBy('timestamp', descending: true)
            .get();

        final dateWorkouts = workoutsSnapshot.docs
            .map((doc) => Workout.fromMap(doc.data()))
            .toList();

        allWorkouts.addAll(dateWorkouts);
      }

      // Sort all workouts by timestamp
      allWorkouts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      yield allWorkouts;
    } catch (e) {
      yield [];
    }
  }

  /// Generate a unique workout ID
  static String generateWorkoutId() {
    return _firestore.collection('temp').doc().id;
  }
}
