import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_stats.dart';

/// Service for managing daily statistics
/// Automatically recalculates stats when food or workouts are added/updated/deleted
class StatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _challengesCollection = 'challenges';
  static const String _statsCollection = 'stats';
  static const String _foodLogsCollection = 'foodlogs';
  static const String _workoutsCollection = 'workouts';

  /// Helper to format date as YYYYMMDD
  static String _formatDateId(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Get stats for a specific date
  static Future<DailyStats?> getStatsForDate(
    String challengeId,
    DateTime date,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final dateId = _formatDateId(date);

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_statsCollection)
          .doc(dateId)
          .get();

      if (doc.exists && doc.data() != null) {
        return DailyStats.fromJson(doc.data()!);
      }

      // Return empty stats if document doesn't exist
      return null;
    } catch (e) {
      if (kDebugMode) print('Error getting stats: $e');
      return null;
    }
  }

  /// Get stats for a date range
  static Future<List<DailyStats>> getStatsForDateRange(
    String challengeId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final startDateId = _formatDateId(startDate);
      final endDateId = _formatDateId(endDate);

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_statsCollection)
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateId)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDateId)
          .orderBy(FieldPath.documentId)
          .get();

      return querySnapshot.docs
          .map((doc) => DailyStats.fromJson(doc.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error getting stats range: $e');
      return [];
    }
  }

  /// Recalculate and update stats for a specific date
  /// This should be called whenever food or workouts are added/updated/deleted
  static Future<bool> recalculateStatsForDate(
    String challengeId,
    DateTime date,
    int dailyGoal,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final dateId = _formatDateId(date);

      // Calculate food calories
      final foodCalories = await _calculateFoodCalories(
        user.uid,
        challengeId,
        dateId,
      );

      // Calculate cardio calories
      final cardioCalories = await _calculateCardioCalories(
        user.uid,
        challengeId,
        dateId,
      );

      // Create stats object
      final stats = DailyStats(
        dateId: dateId,
        date: DateTime(date.year, date.month, date.day),
        foodCalories: foodCalories,
        cardioCalories: cardioCalories,
        strengthCalories: 0, // Strength doesn't burn measurable calories
        dailyGoal: dailyGoal,
        lastUpdated: DateTime.now(),
      );

      // Save to Firebase
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_statsCollection)
          .doc(dateId)
          .set(stats.toJson(), SetOptions(merge: true));

      if (kDebugMode) {
        print('Stats recalculated for $dateId: $stats');
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error recalculating stats: $e');
      return false;
    }
  }

  /// Calculate total food calories for a date
  static Future<int> _calculateFoodCalories(
    String userId,
    String challengeId,
    String dateId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_foodLogsCollection)
          .doc(dateId)
          .collection('items')
          .get();

      int totalCalories = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // Handle both old structure (entries array) and new structure (individual items)
        if (data.containsKey('entries')) {
          // Old structure: sum calories from entries
          final entries = data['entries'] as List<dynamic>?;
          if (entries != null) {
            for (final entry in entries) {
              final caloriesPer100g = (entry['caloriesPer100g'] ?? 0)
                  .toDouble();
              final servingSize = (entry['servingSize'] ?? 0).toDouble();
              final calories = (caloriesPer100g * servingSize) / 100;
              totalCalories += calories.round().toInt();
            }
          }
        } else {
          // New structure: each document is a food item
          final caloriesPer100g = (data['caloriesPer100g'] ?? 0).toDouble();
          final servingSize = (data['servingSize'] ?? 0).toDouble();
          final calories = (caloriesPer100g * servingSize) / 100;
          totalCalories += calories.round().toInt();
        }
      }

      return totalCalories;
    } catch (e) {
      if (kDebugMode) print('Error calculating food calories: $e');
      return 0;
    }
  }

  /// Calculate total cardio calories for a date
  static Future<int> _calculateCardioCalories(
    String userId,
    String challengeId,
    String dateId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_workoutsCollection)
          .doc(dateId)
          .collection('cardio')
          .get();

      int totalCalories = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // Check if this is a cardio workout with estimated calories
        if (data['workoutType'] == 'cardio') {
          // Calculate calories from MET value and duration
          final met = (data['met'] ?? 0).toDouble();
          final duration = (data['durationMinutes'] ?? 0).toDouble();

          // For now, use a simple estimation
          // TODO: Get user's weight for more accurate calculation
          // Calories = MET × weight(kg) × duration(hours)
          // Using average weight of 70kg for estimation
          final calories = met * 70 * (duration / 60);
          totalCalories += calories.round().toInt();
        }
      }

      return totalCalories;
    } catch (e) {
      if (kDebugMode) print('Error calculating cardio calories: $e');
      return 0;
    }
  }

  /// Listen to stats for a specific date in real-time
  static Stream<DailyStats?> getStatsStreamForDate(
    String challengeId,
    DateTime date,
  ) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    final dateId = _formatDateId(date);

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection(_challengesCollection)
        .doc(challengeId)
        .collection(_statsCollection)
        .doc(dateId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return DailyStats.fromJson(snapshot.data()!);
          }
          return null;
        });
  }

  /// Delete stats for a specific date
  static Future<bool> deleteStatsForDate(
    String challengeId,
    DateTime date,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final dateId = _formatDateId(date);

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_statsCollection)
          .doc(dateId)
          .delete();

      return true;
    } catch (e) {
      if (kDebugMode) print('Error deleting stats: $e');
      return false;
    }
  }

  /// Get weekly summary (7 days of stats)
  static Future<Map<String, dynamic>> getWeeklySummary(
    String challengeId,
    DateTime weekStart,
  ) async {
    try {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final statsList = await getStatsForDateRange(
        challengeId,
        weekStart,
        weekEnd,
      );

      int totalFood = 0;
      int totalBurned = 0;
      int avgDaily = 0;
      int daysLogged = statsList.length;

      for (final stats in statsList) {
        totalFood += stats.foodCalories;
        totalBurned += stats.totalBurned;
      }

      if (daysLogged > 0) {
        avgDaily = (totalFood / daysLogged).round();
      }

      return {
        'totalFoodCalories': totalFood,
        'totalBurnedCalories': totalBurned,
        'averageDailyCalories': avgDaily,
        'daysLogged': daysLogged,
        'weekStart': weekStart.toIso8601String(),
        'weekEnd': weekEnd.toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) print('Error getting weekly summary: $e');
      return {};
    }
  }

  /// Batch recalculate stats for multiple dates
  /// Useful for backfilling or correcting data
  static Future<bool> batchRecalculateStats(
    String challengeId,
    List<DateTime> dates,
    int dailyGoal,
  ) async {
    try {
      for (final date in dates) {
        await recalculateStatsForDate(challengeId, date, dailyGoal);
        // Small delay to avoid overwhelming Firebase
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error batch recalculating stats: $e');
      return false;
    }
  }
}
