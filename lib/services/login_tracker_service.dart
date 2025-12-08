import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to track daily app logins (user opens app, even without activity)
class LoginTrackerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _loginTrackingDoc = 'loginTracking';

  /// Record that user opened the app today
  /// Call this when user opens the app (e.g., in main_page initState)
  static Future<void> recordDailyLogin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return;
      }

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Store in a subcollection to easily count unique days
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc(_loginTrackingDoc)
          .collection('days')
          .doc(dateKey)
          .set({
        'date': dateKey,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
    }
  }

  /// Get total number of unique login days
  static Future<int> getTotalLoginDays() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc(_loginTrackingDoc)
          .collection('days')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Check if user logged in today
  static Future<bool> hasLoggedInToday() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc(_loginTrackingDoc)
          .collection('days')
          .doc(dateKey)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get login streak (consecutive days)
  static Future<int> getCurrentStreak() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc(_loginTrackingDoc)
          .collection('days')
          .orderBy('date', descending: true)
          .limit(365) // Check last year
          .get();

      if (snapshot.docs.isEmpty) return 0;

      int streak = 0;
      DateTime currentDate = DateTime.now();

      for (var doc in snapshot.docs) {
        final dateKey = doc.id;
        final expectedDateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

        if (dateKey == expectedDateKey) {
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      return 0;
    }
  }

  /// Get days since last login
  /// Returns the number of days since the user's last login (app open)
  /// Returns null if user has never logged in
  static Future<int?> getDaysSinceLastLogin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc(_loginTrackingDoc)
          .collection('days')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // User has never logged in
        return null;
      }

      // Get the most recent login date
      final lastLoginDateKey = snapshot.docs.first.id;
      // Parse date key format: YYYY-MM-DD
      final parts = lastLoginDateKey.split('-');
      if (parts.length != 3) return null;

      final lastLoginDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastLogin = DateTime(lastLoginDate.year, lastLoginDate.month, lastLoginDate.day);

      final daysSince = today.difference(lastLogin).inDays;
      return daysSince;
    } catch (e) {
      return null;
    }
  }

  /// Check if user hasn't logged in for more than N days
  /// Returns true if user hasn't logged in for more than the specified days
  static Future<bool> hasNotLoggedInForDays(int days) async {
    final daysSince = await getDaysSinceLastLogin();
    if (daysSince == null) {
      // User has never logged in, consider it as not logged in for more than N days
      return true;
    }
    return daysSince > days;
  }

  /// Check if user logged in at least once during a date range
  /// Returns true if user logged in at least once between startDate and endDate (inclusive)
  static Future<bool> hasLoggedInDuringDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Normalize dates to start of day for comparison
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      // Get all login dates
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc(_loginTrackingDoc)
          .collection('days')
          .get();

      if (snapshot.docs.isEmpty) return false;

      // Check if any login date falls within the range
      for (var doc in snapshot.docs) {
        final dateKey = doc.id;
        // Parse date key format: YYYY-MM-DD
        final parts = dateKey.split('-');
        if (parts.length != 3) continue;

        try {
          final loginDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          final normalizedLoginDate = DateTime(loginDate.year, loginDate.month, loginDate.day);

          // Check if login date is within range (inclusive)
          if (normalizedLoginDate.isAtSameMomentAs(start) ||
              normalizedLoginDate.isAtSameMomentAs(end) ||
              (normalizedLoginDate.isAfter(start) && normalizedLoginDate.isBefore(end))) {
            return true;
          }
        } catch (e) {
          // Skip invalid date formats
          continue;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if user has logged in within the last N days from a specific date
  /// Returns true if user logged in at least once within the last N days from referenceDate
  /// "Within last N days" means: today, yesterday, ..., (N-1) days ago
  /// So for N=3: today, yesterday, 2 days ago (but NOT 3 days ago)
  static Future<bool> hasLoggedInWithinLastNDays({
    required DateTime referenceDate,
    required int days,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final reference = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
      // Cutoff is (days) days ago - logins AFTER this date count, but not on this date
      // For "within last 3 days": cutoff = 3 days ago, so we want logins AFTER 3 days ago
      final cutoffDate = reference.subtract(Duration(days: days));

      // Get all login dates
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc(_loginTrackingDoc)
          .collection('days')
          .get();

      if (snapshot.docs.isEmpty) return false;

      // Check if any login date is within the last N days
      for (var doc in snapshot.docs) {
        final dateKey = doc.id;
        // Parse date key format: YYYY-MM-DD
        final parts = dateKey.split('-');
        if (parts.length != 3) continue;

        try {
          final loginDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          final normalizedLoginDate = DateTime(loginDate.year, loginDate.month, loginDate.day);

          // Check if login date is STRICTLY after cutoff date
          // This means: if cutoff is 3 days ago, we want logins from 2 days ago, yesterday, or today
          // But NOT from exactly 3 days ago (because "> 3 days" means more than 3)
          if (normalizedLoginDate.isAfter(cutoffDate)) {
            return true;
          }
        } catch (e) {
          // Skip invalid date formats
          continue;
        }
      }

      return false;
    } catch (e) {
      // On error, assume no login (fail-safe: skip adjustment if we can't verify)
      return false;
    }
  }
}
