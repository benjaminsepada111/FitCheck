// services/challenge_completion_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class ChallengeCompletionService {
  static const String _completionShownPrefix = 'completion_shown_';

  /// Check if completion popup has been shown for a challenge
  static Future<bool> hasShownCompletionPopup(String challengeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_completionShownPrefix$challengeId') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark completion popup as shown for a challenge
  static Future<void> markCompletionPopupShown(String challengeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_completionShownPrefix$challengeId', true);
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