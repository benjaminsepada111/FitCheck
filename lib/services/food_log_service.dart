import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/food_models.dart';

class FoodLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _challengesCollection = 'challenges';
  static const String _foodLogsCollection = 'foodlogs';

  /// Save a food log (meal)
  static Future<bool> saveFoodLog(FoodLog foodLog, {required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Log (replace with proper logging framework in production)
      debugPrint('Error: No authenticated user found');
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(foodLog.id)
          .set(foodLog.toJson());

      // Log (replace with proper logging framework in production)
      debugPrint('Food log saved: ${foodLog.mealType} for ${foodLog.date}');
      return true;
    } catch (e) {
      // Log (replace with proper logging framework in production)
      debugPrint('Error saving food log: $e');
      return false;
    }
  }

  /// Get all food logs for a specific date
  static Future<List<FoodLog>> getFoodLogsForDate(DateTime date, {required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Log (replace with proper logging framework in production)
      debugPrint('Error: No authenticated user found');
        return [];
      }

      // Create date range for the entire day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String())
          .orderBy('date')
          .get();

      return querySnapshot.docs
          .map((doc) => FoodLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      // Log (replace with proper logging framework in production)
      debugPrint('Error getting food logs for date: $e');
      return [];
    }
  }

  /// Get food logs for a date range
  static Future<List<FoodLog>> getFoodLogsForDateRange(
    DateTime startDate,
    DateTime endDate, {
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Log (replace with proper logging framework in production)
      debugPrint('Error: No authenticated user found');
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date')
          .get();

      return querySnapshot.docs
          .map((doc) => FoodLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      // Log (replace with proper logging framework in production)
      debugPrint('Error getting food logs for date range: $e');
      return [];
    }
  }

  /// Get a specific food log by ID
  static Future<FoodLog?> getFoodLog(String logId, {required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Log (replace with proper logging framework in production)
      debugPrint('Error: No authenticated user found');
        return null;
      }

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(logId)
          .get();

      if (doc.exists && doc.data() != null) {
        return FoodLog.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      // Log (replace with proper logging framework in production)
      debugPrint('Error getting food log: $e');
      return null;
    }
  }

  /// Update a food log
  static Future<bool> updateFoodLog(FoodLog foodLog, {required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Log (replace with proper logging framework in production)
      debugPrint('Error: No authenticated user found');
        return false;
      }

      final updatedLog = foodLog.copyWith(updatedAt: DateTime.now());

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(foodLog.id)
          .update(updatedLog.toJson());

      // Log (replace with proper logging framework in production)
      debugPrint('Food log updated: ${foodLog.id}');
      return true;
    } catch (e) {
      // Log (replace with proper logging framework in production)
      debugPrint('Error updating food log: $e');
      return false;
    }
  }

  /// Delete a food log
  static Future<bool> deleteFoodLog(String logId, {required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Log (replace with proper logging framework in production)
      debugPrint('Error: No authenticated user found');
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(logId)
          .delete();

      // Log (replace with proper logging framework in production)
      debugPrint('Food log deleted: $logId');
      return true;
    } catch (e) {
      // Log (replace with proper logging framework in production)
      debugPrint('Error deleting food log: $e');
      return false;
    }
  }

  /// Add a food entry to an existing meal or create a new meal
  static Future<bool> addFoodEntry(
    DateTime date,
    String mealType,
    FoodEntry foodEntry, {
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Log (replace with proper logging framework in production)
      debugPrint('Error: No authenticated user found when adding food entry');
        return false;
      }

      // Validate inputs
      if (mealType.isEmpty || foodEntry.foodName.isEmpty) {
        // Log (replace with proper logging framework in production)
      debugPrint('Error: Invalid meal type or food name');
        return false;
      }

      // Try to find existing meal for this date and meal type
      final existingLogs = await getFoodLogsForDate(date, challengeId: challengeId);
      final existingMealLogs = existingLogs.where((log) => log.mealType == mealType);
      final existingMeal = existingMealLogs.isNotEmpty ? existingMealLogs.first : null;

      if (existingMeal != null) {
        // Add to existing meal
        final updatedEntries = [...existingMeal.entries, foodEntry];
        final updatedLog = existingMeal.copyWith(
          entries: updatedEntries,
          updatedAt: DateTime.now(),
        );
        // Log (replace with proper logging framework in production)
      debugPrint('Updating existing meal log with new food entry: ${foodEntry.foodName}');
        return await updateFoodLog(updatedLog, challengeId: challengeId);
      } else {
        // Create new meal
        final newLog = FoodLog(
          id: generateFoodLogId(),
          date: date,
          mealType: mealType,
          entries: [foodEntry],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        // Log (replace with proper logging framework in production)
      debugPrint('Creating new meal log for $mealType with food entry: ${foodEntry.foodName}');
        return await saveFoodLog(newLog, challengeId: challengeId);
      }
    } catch (e) {
      // Log (replace with proper logging framework in production)
      debugPrint('Error adding food entry to $mealType: $e');
      return false;
    }
  }

  /// Calculate daily calorie total for a specific date
  static Future<double> getDailyCalories(DateTime date, {required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Log (replace with proper logging framework in production)
      debugPrint('Warning: No authenticated user when calculating daily calories');
        return 0.0;
      }

      final foodLogs = await getFoodLogsForDate(date, challengeId: challengeId);
      debugPrint('🔢 getDailyCalories - Found ${foodLogs.length} food logs for $date');

      double totalCalories = 0;

      for (final log in foodLogs) {
        try {
          debugPrint('  🍽️ ${log.mealType}: ${log.totalCalories} cal (${log.entries.length} entries)');
          totalCalories += log.totalCalories;
        } catch (e) {
          // Log (replace with proper logging framework in production)
      debugPrint('Error calculating calories for log ${log.id}: $e');
          // Continue with other logs even if one fails
        }
      }

      // Log (replace with proper logging framework in production)
      debugPrint('Total daily calories for ${date.toIso8601String().split('T')[0]}: $totalCalories');
      return totalCalories;
    } catch (e) {
      // Log (replace with proper logging framework in production)
      debugPrint('Error calculating daily calories: $e');
      return 0.0;
    }
  }

  /// Get calorie breakdown by meal for a specific date
  static Future<Map<String, double>> getMealCalorieBreakdown(DateTime date, {required String challengeId}) async {
    try {
      final foodLogs = await getFoodLogsForDate(date, challengeId: challengeId);
      final breakdown = <String, double>{};

      for (final log in foodLogs) {
        breakdown[log.mealType] = log.totalCalories;
      }

      return breakdown;
    } catch (e) {
      // Log (replace with proper logging framework in production)
      debugPrint('Error getting meal calorie breakdown: $e');
      return {};
    }
  }

  /// Listen to food logs for a specific date in real-time
  static Stream<List<FoodLog>> getFoodLogsStreamForDate(DateTime date, {required String challengeId}) {
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
        .collection(_foodLogsCollection)
        .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('date', isLessThan: endOfDay.toIso8601String())
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FoodLog.fromJson(doc.data()))
          .toList();
    });
  }

  /// Generate a unique food log ID
  static String generateFoodLogId() {
    return _firestore.collection('temp').doc().id;
  }

  /// Get the most recent food logs (for recent foods feature)
  static Future<List<FoodEntry>> getRecentFoodEntries({int limit = 20, required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Log (replace with proper logging framework in production)
      debugPrint('Error: No authenticated user found');
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      final recentEntries = <FoodEntry>[];
      for (final doc in querySnapshot.docs) {
        final foodLog = FoodLog.fromJson(doc.data());
        recentEntries.addAll(foodLog.entries);
      }

      // Remove duplicates based on fdcId and return unique foods
      final uniqueEntries = <int, FoodEntry>{};
      for (final entry in recentEntries) {
        uniqueEntries[entry.fdcId] = entry;
      }

      return uniqueEntries.values.toList();
    } catch (e) {
      // Log (replace with proper logging framework in production)
      debugPrint('Error getting recent food entries: $e');
      return [];
    }
  }
}