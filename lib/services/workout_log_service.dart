import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/workout_models.dart';

class WorkoutLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _challengesCollection = 'challenges';
  static const String _workoutLogsCollection = 'workoutlogs';

  /// Save a workout log with optional photo upload
  static Future<bool> saveWorkoutLog(
    WorkoutLog workoutLog, {
    required String challengeId,
    File? imageFile,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      WorkoutLog updatedWorkoutLog = workoutLog;

      // Save image locally if provided
      if (imageFile != null) {
        try {
          final imagePath = await _saveWorkoutImageLocally(
            imageFile,
            challengeId,
            workoutLog.id,
          );
          updatedWorkoutLog = workoutLog.copyWith(imagePath: imagePath);
          debugPrint('✅ Workout image saved locally: $imagePath');
        } catch (e) {
          debugPrint('❌ Error saving workout image: $e');
          // Continue saving workout even if image save fails
        }
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutLogsCollection)
          .doc(workoutLog.id)
          .set(updatedWorkoutLog.toJson());

      debugPrint('Workout log saved: ${workoutLog.workoutType} for ${workoutLog.date}');
      return true;
    } catch (e) {
      debugPrint('Error saving workout log: $e');
      return false;
    }
  }

  /// Save workout image to local storage
  static Future<String> _saveWorkoutImageLocally(
    File imageFile,
    String challengeId,
    String workoutLogId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    // Get the app's document directory
    final directory = await getApplicationDocumentsDirectory();

    // Create a directory structure for workout images
    final workoutImagesDir = Directory(
      path.join(directory.path, 'workout_logs', user.uid, challengeId)
    );

    // Create the directory if it doesn't exist
    if (!await workoutImagesDir.exists()) {
      await workoutImagesDir.create(recursive: true);
    }

    // Get the file extension
    final extension = path.extension(imageFile.path);

    // Create the destination file path
    final fileName = '${workoutLogId}_${DateTime.now().millisecondsSinceEpoch}$extension';
    final destinationPath = path.join(workoutImagesDir.path, fileName);

    // Copy the image file to the destination
    final savedFile = await imageFile.copy(destinationPath);

    return savedFile.path;
  }

  /// Get all workout logs for a specific date
  static Future<List<WorkoutLog>> getWorkoutLogsForDate(
    DateTime date, {
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return [];
      }

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutLogsCollection)
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String())
          .orderBy('date')
          .get();

      return querySnapshot.docs
          .map((doc) => WorkoutLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting workout logs for date: $e');
      return [];
    }
  }

  /// Get workout logs for a date range
  static Future<List<WorkoutLog>> getWorkoutLogsForDateRange(
    DateTime startDate,
    DateTime endDate, {
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutLogsCollection)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date')
          .get();

      return querySnapshot.docs
          .map((doc) => WorkoutLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting workout logs for date range: $e');
      return [];
    }
  }

  /// Get a specific workout log by ID
  static Future<WorkoutLog?> getWorkoutLog(
    String logId, {
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return null;
      }

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutLogsCollection)
          .doc(logId)
          .get();

      if (doc.exists && doc.data() != null) {
        return WorkoutLog.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting workout log: $e');
      return null;
    }
  }

  /// Update a workout log
  static Future<bool> updateWorkoutLog(
    WorkoutLog workoutLog, {
    required String challengeId,
    File? imageFile,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      WorkoutLog updatedWorkoutLog = workoutLog.copyWith(updatedAt: DateTime.now());

      // Save new image locally if provided
      if (imageFile != null) {
        try {
          final imagePath = await _saveWorkoutImageLocally(
            imageFile,
            challengeId,
            workoutLog.id,
          );
          updatedWorkoutLog = updatedWorkoutLog.copyWith(imagePath: imagePath);
        } catch (e) {
          debugPrint('Error saving workout image: $e');
        }
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutLogsCollection)
          .doc(workoutLog.id)
          .update(updatedWorkoutLog.toJson());

      debugPrint('Workout log updated: ${workoutLog.id}');
      return true;
    } catch (e) {
      debugPrint('Error updating workout log: $e');
      return false;
    }
  }

  /// Delete a workout log
  static Future<bool> deleteWorkoutLog(
    String logId, {
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      // Get the workout log first to delete associated image
      final workoutLog = await getWorkoutLog(logId, challengeId: challengeId);
      if (workoutLog?.imagePath != null) {
        try {
          final file = File(workoutLog!.imagePath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint('Deleted workout image from local storage');
          }
        } catch (e) {
          debugPrint('Error deleting workout image: $e');
        }
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutLogsCollection)
          .doc(logId)
          .delete();

      debugPrint('Workout log deleted: $logId');
      return true;
    } catch (e) {
      debugPrint('Error deleting workout log: $e');
      return false;
    }
  }

  /// Add a workout entry to an existing workout or create a new workout
  static Future<bool> addWorkoutEntry(
    DateTime date,
    String workoutType,
    WorkoutEntry workoutEntry, {
    required String challengeId,
    File? imageFile,
    String? notes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found when adding workout entry');
        return false;
      }

      // Try to find existing workout for this date and type
      final existingLogs = await getWorkoutLogsForDate(date, challengeId: challengeId);
      final existingWorkoutLogs = existingLogs.where((log) => log.workoutType == workoutType);
      final existingWorkout = existingWorkoutLogs.isNotEmpty ? existingWorkoutLogs.first : null;

      if (existingWorkout != null) {
        // Add to existing workout
        final updatedEntries = [...existingWorkout.entries, workoutEntry];
        final updatedLog = existingWorkout.copyWith(
          entries: updatedEntries,
          notes: notes ?? existingWorkout.notes,
          updatedAt: DateTime.now(),
        );
        debugPrint('Updating existing workout log with new entry: ${workoutEntry.exerciseName}');
        return await updateWorkoutLog(updatedLog, challengeId: challengeId, imageFile: imageFile);
      } else {
        // Create new workout
        final newLog = WorkoutLog(
          id: generateWorkoutLogId(),
          date: date,
          workoutType: workoutType,
          entries: [workoutEntry],
          notes: notes,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        debugPrint('Creating new workout log for $workoutType with entry: ${workoutEntry.exerciseName}');
        return await saveWorkoutLog(newLog, challengeId: challengeId, imageFile: imageFile);
      }
    } catch (e) {
      debugPrint('Error adding workout entry to $workoutType: $e');
      return false;
    }
  }

  /// Calculate daily calories burned for a specific date
  static Future<double> getDailyCaloriesBurned(
    DateTime date, {
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Warning: No authenticated user when calculating daily calories burned');
        return 0.0;
      }

      final workoutLogs = await getWorkoutLogsForDate(date, challengeId: challengeId);
      debugPrint('🔢 getDailyCaloriesBurned - Found ${workoutLogs.length} workout logs for $date');

      double totalCalories = 0;

      for (final log in workoutLogs) {
        try {
          debugPrint('  💪 ${log.workoutType}: ${log.totalCaloriesBurned} cal burned');
          totalCalories += log.totalCaloriesBurned;
        } catch (e) {
          debugPrint('Error calculating calories for workout log ${log.id}: $e');
        }
      }

      debugPrint('Total daily calories burned for ${date.toIso8601String().split('T')[0]}: $totalCalories');
      return totalCalories;
    } catch (e) {
      debugPrint('Error calculating daily calories burned: $e');
      return 0.0;
    }
  }

  /// Get total workout duration for a specific date
  static Future<int> getDailyWorkoutDuration(
    DateTime date, {
    required String challengeId,
  }) async {
    try {
      final workoutLogs = await getWorkoutLogsForDate(date, challengeId: challengeId);
      return workoutLogs.fold<int>(0, (total, log) => total + log.totalDuration);
    } catch (e) {
      debugPrint('Error calculating daily workout duration: $e');
      return 0;
    }
  }

  /// Get workout type breakdown for a specific date
  static Future<Map<String, int>> getWorkoutTypeBreakdown(
    DateTime date, {
    required String challengeId,
  }) async {
    try {
      final workoutLogs = await getWorkoutLogsForDate(date, challengeId: challengeId);
      final breakdown = <String, int>{};

      for (final log in workoutLogs) {
        breakdown[log.workoutType] = (breakdown[log.workoutType] ?? 0) + log.totalDuration;
      }

      return breakdown;
    } catch (e) {
      debugPrint('Error getting workout type breakdown: $e');
      return {};
    }
  }

  /// Listen to workout logs for a specific date in real-time
  static Stream<List<WorkoutLog>> getWorkoutLogsStreamForDate(
    DateTime date, {
    required String challengeId,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection(_challengesCollection)
        .doc(challengeId)
        .collection(_workoutLogsCollection)
        .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('date', isLessThan: endOfDay.toIso8601String())
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WorkoutLog.fromJson(doc.data()))
          .toList();
    });
  }

  /// Generate a unique workout log ID
  static String generateWorkoutLogId() {
    return _firestore.collection('temp').doc().id;
  }

  /// Get workout logs with photos for milestone compilation
  static Future<List<WorkoutLog>> getWorkoutLogsWithPhotos({
    required String challengeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return [];
      }

      Query query = _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutLogsCollection)
          .where('imageUrl', isNotEqualTo: null);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      final querySnapshot = await query.orderBy('date').get();

      return querySnapshot.docs
          .map((doc) => WorkoutLog.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting workout logs with photos: $e');
      return [];
    }
  }
}
