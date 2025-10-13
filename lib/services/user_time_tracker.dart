// services/user_time_tracker.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// A service for tracking per-user time-based metrics using UTC timestamps
///
/// This service provides accurate calculations for:
/// - Days passed since user's start date
/// - Current week number since start date
/// - Months passed since start date
///
/// All calculations are UTC-based to prevent timezone errors and work
/// correctly even when users skip days or change timezones.
class UserTimeTracker {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _timeTrackingDoc = 'timeTracking';

  /// Initialize time tracking for a user by storing their start date
  ///
  /// This should be called when:
  /// - User completes registration
  /// - User starts their first challenge
  /// - User begins using the app for the first time
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> initializeUserStartDate({DateTime? customStartDate}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      // Check if start date already exists
      final existingData = await _getTimeTrackingData();
      if (existingData != null && existingData['startDate'] != null) {
        debugPrint('Start date already exists for user: ${existingData['startDate']}');
        return true; // Already initialized
      }

      // Use custom date or current UTC time
      final startDate = customStartDate ?? DateTime.now().toUtc();

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc(_timeTrackingDoc)
          .set({
        'startDate': startDate.toIso8601String(),
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
      });

      debugPrint('User start date initialized: ${startDate.toIso8601String()}');
      return true;
    } catch (e) {
      debugPrint('Error initializing user start date: $e');
      return false;
    }
  }

  /// Get the user's start date from Firebase
  /// Returns null if not set or on error
  static Future<DateTime?> getUserStartDate() async {
    try {
      final data = await _getTimeTrackingData();
      if (data != null && data['startDate'] != null) {
        return DateTime.parse(data['startDate']).toUtc();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user start date: $e');
      return null;
    }
  }

  /// Calculate the number of days passed since the user's start date
  ///
  /// Uses UTC midnight-to-midnight comparison to ensure accuracy
  /// across timezones and daylight saving time changes.
  ///
  /// Returns 0 if start date is not set or on error
  static Future<int> getDaysPassed() async {
    try {
      final startDate = await getUserStartDate();
      if (startDate == null) {
        debugPrint('Warning: Start date not set. Call initializeUserStartDate first.');
        return 0;
      }

      final now = DateTime.now().toUtc();

      // Normalize both dates to UTC midnight for accurate day counting
      final startMidnight = DateTime.utc(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final nowMidnight = DateTime.utc(
        now.year,
        now.month,
        now.day,
      );

      // Calculate difference in days
      final difference = nowMidnight.difference(startMidnight).inDays;

      debugPrint('Days passed: $difference (from ${startMidnight.toIso8601String()} to ${nowMidnight.toIso8601String()})');
      return difference;
    } catch (e) {
      debugPrint('Error calculating days passed: $e');
      return 0;
    }
  }

  /// Calculate the current week number since the user's start date
  ///
  /// Week 1 = Days 0-6, Week 2 = Days 7-13, etc.
  ///
  /// Returns 0 if start date is not set or on error
  static Future<int> getWeekNumber() async {
    try {
      final daysPassed = await getDaysPassed();

      // Week number is (daysPassed / 7) + 1
      // Day 0-6 = Week 1, Day 7-13 = Week 2, etc.
      final weekNumber = (daysPassed ~/ 7) + 1;

      debugPrint('Current week number: $weekNumber (day $daysPassed)');
      return weekNumber;
    } catch (e) {
      debugPrint('Error calculating week number: $e');
      return 0;
    }
  }

  /// Calculate the number of complete months passed since the user's start date
  ///
  /// Uses month-by-month comparison to handle varying month lengths correctly.
  ///
  /// Returns 0 if start date is not set or on error
  static Future<int> getMonthsPassed() async {
    try {
      final startDate = await getUserStartDate();
      if (startDate == null) {
        debugPrint('Warning: Start date not set. Call initializeUserStartDate first.');
        return 0;
      }

      final now = DateTime.now().toUtc();

      // Calculate month difference
      int monthDiff = (now.year - startDate.year) * 12 + (now.month - startDate.month);

      // Adjust if current day is before start day in the month
      if (now.day < startDate.day) {
        monthDiff--;
      }

      // Ensure non-negative result
      final monthsPassed = monthDiff < 0 ? 0 : monthDiff;

      debugPrint('Months passed: $monthsPassed');
      return monthsPassed;
    } catch (e) {
      debugPrint('Error calculating months passed: $e');
      return 0;
    }
  }

  /// Get the day of the week within the current week (0-6)
  ///
  /// Returns which day of the current week the user is on:
  /// 0 = first day of the week, 6 = last day of the week
  static Future<int> getDayOfWeek() async {
    try {
      final daysPassed = await getDaysPassed();
      final dayOfWeek = daysPassed % 7;

      debugPrint('Day of current week: $dayOfWeek');
      return dayOfWeek;
    } catch (e) {
      debugPrint('Error calculating day of week: $e');
      return 0;
    }
  }

  /// Get all time tracking metrics at once for efficiency
  ///
  /// Returns a map containing:
  /// - daysPassed: Number of days since start date
  /// - weekNumber: Current week number
  /// - monthsPassed: Number of complete months passed
  /// - dayOfWeek: Day within current week (0-6)
  /// - startDate: User's start date (ISO8601 string)
  static Future<Map<String, dynamic>> getAllTimeMetrics() async {
    try {
      final startDate = await getUserStartDate();

      if (startDate == null) {
        debugPrint('Warning: Start date not set. Returning default metrics.');
        return {
          'daysPassed': 0,
          'weekNumber': 0,
          'monthsPassed': 0,
          'dayOfWeek': 0,
          'startDate': null,
          'isInitialized': false,
        };
      }

      // Calculate all metrics
      final daysPassed = await getDaysPassed();
      final weekNumber = await getWeekNumber();
      final monthsPassed = await getMonthsPassed();
      final dayOfWeek = await getDayOfWeek();

      return {
        'daysPassed': daysPassed,
        'weekNumber': weekNumber,
        'monthsPassed': monthsPassed,
        'dayOfWeek': dayOfWeek,
        'startDate': startDate.toIso8601String(),
        'isInitialized': true,
      };
    } catch (e) {
      debugPrint('Error getting all time metrics: $e');
      return {
        'daysPassed': 0,
        'weekNumber': 0,
        'monthsPassed': 0,
        'dayOfWeek': 0,
        'startDate': null,
        'isInitialized': false,
      };
    }
  }

  /// Check if the user has completed a specific number of weeks
  ///
  /// Useful for achievements like "Complete 4 weeks"
  static Future<bool> hasCompletedWeeks(int targetWeeks) async {
    final weekNumber = await getWeekNumber();
    return weekNumber > targetWeeks; // Greater than because we're in the NEXT week
  }

  /// Check if the user has completed a specific number of days
  ///
  /// Useful for achievements and streak tracking
  static Future<bool> hasCompletedDays(int targetDays) async {
    final daysPassed = await getDaysPassed();
    return daysPassed >= targetDays;
  }

  /// Get the date range for a specific week number
  ///
  /// Returns a map with 'startDate' and 'endDate' for the given week
  static Future<Map<String, DateTime>?> getWeekDateRange(int weekNumber) async {
    try {
      final startDate = await getUserStartDate();
      if (startDate == null) return null;

      // Week 1 starts at day 0, Week 2 at day 7, etc.
      final weekStartDay = (weekNumber - 1) * 7;
      final weekEndDay = weekStartDay + 6;

      final weekStartDate = DateTime.utc(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: weekStartDay));

      final weekEndDate = DateTime.utc(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: weekEndDay));

      return {
        'startDate': weekStartDate,
        'endDate': weekEndDate,
      };
    } catch (e) {
      debugPrint('Error getting week date range: $e');
      return null;
    }
  }

  /// Reset the user's start date (use with caution)
  ///
  /// This will recalculate all time-based metrics from the new start date.
  /// Should only be used in specific cases like restarting a challenge.
  static Future<bool> resetStartDate(DateTime newStartDate) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc(_timeTrackingDoc)
          .set({
        'startDate': newStartDate.toUtc().toIso8601String(),
        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
        'resetAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));

      debugPrint('User start date reset to: ${newStartDate.toIso8601String()}');
      return true;
    } catch (e) {
      debugPrint('Error resetting start date: $e');
      return false;
    }
  }

  /// Check if time tracking has been initialized for the current user
  static Future<bool> isInitialized() async {
    final startDate = await getUserStartDate();
    return startDate != null;
  }

  /// Private helper to get time tracking data from Firebase
  static Future<Map<String, dynamic>?> _getTimeTrackingData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc(_timeTrackingDoc)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error getting time tracking data: $e');
      return null;
    }
  }

  /// Listen to time tracking changes in real-time
  ///
  /// Useful for UI that needs to update when start date changes
  static Stream<Map<String, dynamic>?> getTimeTrackingStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection('profile')
        .doc(_timeTrackingDoc)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }
}
