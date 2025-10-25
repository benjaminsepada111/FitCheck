import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/food_models.dart';
import 'stats_service.dart';

/// Refactored Food Log Service with date-grouped structure
/// Structure: /users/{userId}/challenges/{challengeId}/foodlogs/{dateId}/items/{foodId}
class FoodLogServiceV2 {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _challengesCollection = 'challenges';
  static const String _foodLogsCollection = 'foodlogs';

  /// Helper to format date as YYYYMMDD
  static String _formatDateId(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Add a food item to a specific date
  /// Each food item is stored as a separate document for easy editing/deletion
  static Future<bool> addFoodItem({
    required String challengeId,
    required DateTime date,
    required String mealType,
    required FoodEntry foodEntry,
    required int dailyGoal,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final dateId = _formatDateId(date);

      // Create path: foodlogs/{dateId}/items/{foodId}
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(dateId)
          .set({'date': date.toIso8601String()}, SetOptions(merge: true));

      // Add food item to items subcollection
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(dateId)
          .collection('items')
          .doc(foodEntry.id)
          .set({
            ...foodEntry.toJson(),
            'mealType': mealType,
            'timestamp': DateTime.now().toIso8601String(),
          });

      // Trigger stats recalculation
      await StatsService.recalculateStatsForDate(challengeId, date, dailyGoal);

      if (kDebugMode) {
        print('Food item added: ${foodEntry.foodName} to $mealType on $dateId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error adding food item: $e');
      return false;
    }
  }

  /// Get all food items for a specific date
  static Future<Map<String, List<Map<String, dynamic>>>> getFoodItemsForDate({
    required String challengeId,
    required DateTime date,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final dateId = _formatDateId(date);

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(dateId)
          .collection('items')
          .orderBy('timestamp')
          .get();

      // Group by meal type
      final Map<String, List<Map<String, dynamic>>> groupedFoods = {
        'breakfast': [],
        'lunch': [],
        'dinner': [],
        'snack': [],
      };

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final mealType = data['mealType'] ?? 'snack';

        if (groupedFoods.containsKey(mealType)) {
          groupedFoods[mealType]!.add({'id': doc.id, ...data});
        }
      }

      return groupedFoods;
    } catch (e) {
      if (kDebugMode) print('Error getting food items: $e');
      return {};
    }
  }

  /// Get food logs for a date (backward compatible with old structure)
  static Future<List<FoodLog>> getFoodLogsForDate(
    DateTime date, {
    required String challengeId,
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
          .collection(_foodLogsCollection)
          .doc(dateId)
          .collection('items')
          .orderBy('timestamp')
          .get();

      // Group items by meal type
      final Map<String, List<FoodEntry>> mealGroups = {};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final mealType = data['mealType'] ?? 'snack';

        final entry = FoodEntry.fromJson(data);

        if (!mealGroups.containsKey(mealType)) {
          mealGroups[mealType] = [];
        }
        mealGroups[mealType]!.add(entry);
      }

      // Convert to FoodLog objects (one per meal type)
      final logs = <FoodLog>[];
      for (final entry in mealGroups.entries) {
        logs.add(
          FoodLog(
            id: '${dateId}_${entry.key}',
            date: date,
            mealType: entry.key,
            entries: entry.value,
            createdAt: date,
            updatedAt: DateTime.now(),
          ),
        );
      }

      return logs;
    } catch (e) {
      if (kDebugMode) print('Error getting food logs: $e');
      return [];
    }
  }

  /// Update a food item
  static Future<bool> updateFoodItem({
    required String challengeId,
    required DateTime date,
    required String foodId,
    required FoodEntry updatedEntry,
    required String mealType,
    required int dailyGoal,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final dateId = _formatDateId(date);

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(dateId)
          .collection('items')
          .doc(foodId)
          .update({
            ...updatedEntry.toJson(),
            'mealType': mealType,
            'timestamp': DateTime.now().toIso8601String(),
          });

      // Trigger stats recalculation
      await StatsService.recalculateStatsForDate(challengeId, date, dailyGoal);

      return true;
    } catch (e) {
      if (kDebugMode) print('Error updating food item: $e');
      return false;
    }
  }

  /// Delete a food item
  static Future<bool> deleteFoodItem({
    required String challengeId,
    required DateTime date,
    required String foodId,
    required int dailyGoal,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final dateId = _formatDateId(date);

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(dateId)
          .collection('items')
          .doc(foodId)
          .delete();

      // Trigger stats recalculation
      await StatsService.recalculateStatsForDate(challengeId, date, dailyGoal);

      if (kDebugMode) {
        print('Food item deleted: $foodId from $dateId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error deleting food item: $e');
      return false;
    }
  }

  /// Calculate daily calorie total for a specific date
  static Future<double> getDailyCalories(
    DateTime date, {
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0.0;

      final dateId = _formatDateId(date);

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(dateId)
          .collection('items')
          .get();

      double totalCalories = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final caloriesPer100g = (data['caloriesPer100g'] ?? 0).toDouble();
        final servingSize = (data['servingSize'] ?? 0).toDouble();
        final calories = (caloriesPer100g * servingSize) / 100;
        totalCalories += calories;
      }

      return totalCalories;
    } catch (e) {
      if (kDebugMode) print('Error calculating daily calories: $e');
      return 0.0;
    }
  }

  /// Get calorie breakdown by meal for a specific date
  static Future<Map<String, double>> getMealCalorieBreakdown(
    DateTime date, {
    required String challengeId,
  }) async {
    try {
      final foodItems = await getFoodItemsForDate(
        challengeId: challengeId,
        date: date,
      );

      final breakdown = <String, double>{};

      for (final entry in foodItems.entries) {
        double mealTotal = 0;
        for (final item in entry.value) {
          final caloriesPer100g = (item['caloriesPer100g'] ?? 0).toDouble();
          final servingSize = (item['servingSize'] ?? 0).toDouble();
          final calories = (caloriesPer100g * servingSize) / 100;
          mealTotal += calories;
        }
        breakdown[entry.key] = mealTotal;
      }

      return breakdown;
    } catch (e) {
      if (kDebugMode) print('Error getting meal breakdown: $e');
      return {};
    }
  }

  /// Listen to food items for a specific date in real-time
  static Stream<Map<String, List<Map<String, dynamic>>>>
  getFoodItemsStreamForDate({
    required String challengeId,
    required DateTime date,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value({});
    }

    final dateId = _formatDateId(date);

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection(_challengesCollection)
        .doc(challengeId)
        .collection(_foodLogsCollection)
        .doc(dateId)
        .collection('items')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) {
          // Group by meal type
          final Map<String, List<Map<String, dynamic>>> groupedFoods = {
            'breakfast': [],
            'lunch': [],
            'dinner': [],
            'snack': [],
          };

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final mealType = data['mealType'] ?? 'snack';

            if (groupedFoods.containsKey(mealType)) {
              groupedFoods[mealType]!.add({'id': doc.id, ...data});
            }
          }

          return groupedFoods;
        });
  }

  /// Get recent food entries (for recent foods feature)
  static Future<List<FoodEntry>> getRecentFoodEntries({
    int limit = 20,
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get recent dates (last 30 days)
      final now = DateTime.now();
      final recentEntries = <FoodEntry>[];
      final seenFoods = <int>{};

      // Query last 30 days
      for (int i = 0; i < 30 && recentEntries.length < limit; i++) {
        final date = now.subtract(Duration(days: i));
        final dateId = _formatDateId(date);

        final querySnapshot = await _firestore
            .collection(_usersCollection)
            .doc(user.uid)
            .collection(_challengesCollection)
            .doc(challengeId)
            .collection(_foodLogsCollection)
            .doc(dateId)
            .collection('items')
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final fdcId = data['fdcId'] as int;

          // Only add unique foods
          if (!seenFoods.contains(fdcId)) {
            seenFoods.add(fdcId);
            recentEntries.add(FoodEntry.fromJson(data));

            if (recentEntries.length >= limit) break;
          }
        }
      }

      return recentEntries;
    } catch (e) {
      if (kDebugMode) print('Error getting recent food entries: $e');
      return [];
    }
  }

  /// Generate a unique food item ID
  static String generateFoodItemId() {
    return _firestore.collection('temp').doc().id;
  }
}
