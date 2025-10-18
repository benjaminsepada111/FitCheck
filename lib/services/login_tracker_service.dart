import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
}
