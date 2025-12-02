// services/challenge_completion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChallengeCompletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _usersCollection = 'users';
  static const String _challengesCollection = 'challenges';

  /// Check if completion popup has been shown for a challenge
  /// This is stored in Firestore so it persists across app reinstalls
  static Future<bool> hasShownCompletionPopup(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final challengeDoc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .get();

      if (!challengeDoc.exists) return false;

      final data = challengeDoc.data();
      // Check if completionPopupShown field exists and is true
      return data?['completionPopupShown'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Mark completion popup as shown for a challenge
  /// This is stored in Firestore so it persists across app reinstalls
  static Future<void> markCompletionPopupShown(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .update({
        'completionPopupShown': true,
        'completionPopupShownAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently handle error
    }
  }

  /// Check if challenge just completed (end date was yesterday or earlier, and today is after)
  static bool isChallengeJustCompleted(DateTime endDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final challengeEndDay = DateTime(endDate.year, endDate.month, endDate.day);

    // Challenge is "just completed" if today is the day after (or later than) end date
    return today.isAfter(challengeEndDay);
  }
}