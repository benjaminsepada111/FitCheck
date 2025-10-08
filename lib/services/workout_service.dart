import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:capstone_project/models/workout_model.dart';

class WorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new workout
  Future<String> addWorkout(WorkoutModel workout) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(workout.userId)
          .collection('challenges')
          .doc(workout.challengeId)
          .collection('workouts')
          .add(workout.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add workout: $e');
    }
  }

  // Save workout photo locally
  Future<String> uploadWorkoutPhoto(String userId, File photoFile) async {
    try {
      // Get the app's document directory
      final directory = await getApplicationDocumentsDirectory();

      // Create a directory structure for workout photos
      final workoutPhotosDir = Directory(
        path.join(directory.path, 'workout_photos', userId)
      );

      // Create the directory if it doesn't exist
      if (!await workoutPhotosDir.exists()) {
        await workoutPhotosDir.create(recursive: true);
      }

      // Generate unique filename
      String fileName = 'workout_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destinationPath = path.join(workoutPhotosDir.path, fileName);

      // Copy the image file to the destination
      final savedFile = await photoFile.copy(destinationPath);

      return savedFile.path;
    } catch (e) {
      throw Exception('Failed to save photo locally: $e');
    }
  }

  // Get today's workouts for a specific challenge
  Stream<List<WorkoutModel>> getTodayWorkouts(String userId, String challengeId) {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    // Query from new structure: users/{userId}/challenges/{challengeId}/workouts
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('challenges')
        .doc(challengeId)
        .collection('workouts')
        .snapshots()
        .map((snapshot) {
      // Parse all workouts
      final allWorkouts = snapshot.docs.map((doc) {
        return WorkoutModel.fromJson(doc.data(), doc.id);
      }).toList();

      // Filter for today and sort in memory
      final todayWorkouts = allWorkouts.where((workout) {
        return workout.date.isAfter(startOfDay) &&
            workout.date.isBefore(endOfDay);
      }).toList();

      // Sort by date descending
      todayWorkouts.sort((a, b) => b.date.compareTo(a.date));

      return todayWorkouts;
    });
  }

  // Get all workouts (history) for a specific challenge
  Stream<List<WorkoutModel>> getWorkoutHistory(String userId, String challengeId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('challenges')
        .doc(challengeId)
        .collection('workouts')
        .snapshots()
        .map((snapshot) {
      final workouts = snapshot.docs.map((doc) {
        return WorkoutModel.fromJson(doc.data(), doc.id);
      }).toList();

      // Sort in memory instead of in query
      workouts.sort((a, b) => b.date.compareTo(a.date));

      return workouts;
    });
  }

  // Update workout
  Future<void> updateWorkout(WorkoutModel workout) async {
    try {
      await _firestore
          .collection('users')
          .doc(workout.userId)
          .collection('challenges')
          .doc(workout.challengeId)
          .collection('workouts')
          .doc(workout.id)
          .update(workout.toJson());
    } catch (e) {
      throw Exception('Failed to update workout: $e');
    }
  }

  // Delete workout
  Future<void> deleteWorkout(String userId, String challengeId, String workoutId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('challenges')
          .doc(challengeId)
          .collection('workouts')
          .doc(workoutId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete workout: $e');
    }
  }

  // Get workout statistics for a specific challenge
  Future<Map<String, dynamic>> getWorkoutStats(String userId, String challengeId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('challenges')
          .doc(challengeId)
          .collection('workouts')
          .get();

      int totalWorkouts = snapshot.docs.length;
      int totalSets = 0;

      for (var doc in snapshot.docs) {
        WorkoutModel workout = WorkoutModel.fromJson(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        totalSets += workout.sets;
      }

      return {
        'totalWorkouts': totalWorkouts,
        'totalSets': totalSets,
      };
    } catch (e) {
      throw Exception('Failed to get workout stats: $e');
    }
  }
}