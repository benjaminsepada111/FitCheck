import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_models.dart';

class FoodLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _foodLogsCollection = 'foodlogs';

  /// Save a food log (meal)
  static Future<bool> saveFoodLog(FoodLog foodLog) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_foodLogsCollection)
          .doc(foodLog.id)
          .set(foodLog.toJson());

      print('Food log saved: ${foodLog.mealType} for ${foodLog.date}');
      return true;
    } catch (e) {
      print('Error saving food log: $e');
      return false;
    }
  }

  /// Get all food logs for a specific date
  static Future<List<FoodLog>> getFoodLogsForDate(DateTime date) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return [];
      }

      // Create date range for the entire day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_foodLogsCollection)
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String())
          .orderBy('date')
          .get();

      return querySnapshot.docs
          .map((doc) => FoodLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting food logs for date: $e');
      return [];
    }
  }

  /// Get food logs for a date range
  static Future<List<FoodLog>> getFoodLogsForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_foodLogsCollection)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date')
          .get();

      return querySnapshot.docs
          .map((doc) => FoodLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting food logs for date range: $e');
      return [];
    }
  }

  /// Get a specific food log by ID
  static Future<FoodLog?> getFoodLog(String logId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return null;
      }

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_foodLogsCollection)
          .doc(logId)
          .get();

      if (doc.exists && doc.data() != null) {
        return FoodLog.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting food log: $e');
      return null;
    }
  }

  /// Update a food log
  static Future<bool> updateFoodLog(FoodLog foodLog) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return false;
      }

      final updatedLog = foodLog.copyWith(updatedAt: DateTime.now());

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_foodLogsCollection)
          .doc(foodLog.id)
          .update(updatedLog.toJson());

      print('Food log updated: ${foodLog.id}');
      return true;
    } catch (e) {
      print('Error updating food log: $e');
      return false;
    }
  }

  /// Delete a food log
  static Future<bool> deleteFoodLog(String logId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_foodLogsCollection)
          .doc(logId)
          .delete();

      print('Food log deleted: $logId');
      return true;
    } catch (e) {
      print('Error deleting food log: $e');
      return false;
    }
  }

  /// Add a food entry to an existing meal or create a new meal
  static Future<bool> addFoodEntry(
    DateTime date,
    String mealType,
    FoodEntry foodEntry,
  ) async {
    try {
      // Try to find existing meal for this date and meal type
      final existingLogs = await getFoodLogsForDate(date);
      final existingMeal = existingLogs
          .where((log) => log.mealType == mealType)
          .firstOrNull;

      if (existingMeal != null) {
        // Add to existing meal
        final updatedEntries = [...existingMeal.entries, foodEntry];
        final updatedLog = existingMeal.copyWith(
          entries: updatedEntries,
          updatedAt: DateTime.now(),
        );
        return await updateFoodLog(updatedLog);
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
        return await saveFoodLog(newLog);
      }
    } catch (e) {
      print('Error adding food entry: $e');
      return false;
    }
  }

  /// Calculate daily totals for a specific date
  static Future<Map<String, double>> getDailyTotals(DateTime date) async {
    try {
      final foodLogs = await getFoodLogsForDate(date);

      double totalCalories = 0;
      double totalProtein = 0;
      double totalFat = 0;
      double totalCarbs = 0;

      for (final log in foodLogs) {
        totalCalories += log.totalCalories;
        totalProtein += log.totalProtein;
        totalFat += log.totalFat;
        totalCarbs += log.totalCarbs;
      }

      return {
        'calories': totalCalories,
        'protein': totalProtein,
        'fat': totalFat,
        'carbs': totalCarbs,
      };
    } catch (e) {
      print('Error calculating daily totals: $e');
      return {
        'calories': 0.0,
        'protein': 0.0,
        'fat': 0.0,
        'carbs': 0.0,
      };
    }
  }

  /// Get meal breakdown for a specific date
  static Future<Map<String, Map<String, double>>> getMealBreakdown(DateTime date) async {
    try {
      final foodLogs = await getFoodLogsForDate(date);

      final breakdown = <String, Map<String, double>>{};

      for (final log in foodLogs) {
        breakdown[log.mealType] = {
          'calories': log.totalCalories,
          'protein': log.totalProtein,
          'fat': log.totalFat,
          'carbs': log.totalCarbs,
        };
      }

      return breakdown;
    } catch (e) {
      print('Error getting meal breakdown: $e');
      return {};
    }
  }

  /// Listen to food logs for a specific date in real-time
  static Stream<List<FoodLog>> getFoodLogsStreamForDate(DateTime date) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
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
  static Future<List<FoodEntry>> getRecentFoodEntries({int limit = 20}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
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
      print('Error getting recent food entries: $e');
      return [];
    }
  }
}