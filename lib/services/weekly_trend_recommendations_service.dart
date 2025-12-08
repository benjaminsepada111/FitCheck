// services/weekly_trend_recommendations_service.dart
/// Service for generating weekly recommendations based on weight trend and goal
/// Recommendations are short, clear, and do not include weight numbers

class WeeklyTrendRecommendationsService {
  /// Generate recommendations based on goal and trend
  /// Returns a list of recommendation strings (1-2 sentences each)
  static List<String> generateRecommendations({
    required String goal, // 'lose', 'maintain', 'gain'
    required String trend, // 'up', 'down', 'same'
    bool hasInsufficientActivity = false, // If >3 days without logs
    bool hasIncompleteNetCalories = false, // If <75% of expected weekly intake logged
  }) {
    final recommendations = <String>[];
    
    // Special case: No log / Incomplete Data (>3 days)
    if (hasInsufficientActivity) {
      recommendations.add("We didn't receive enough data this week. Please log your meals and workouts consistently for accurate recommendations.");
      return recommendations;
    }
    
    // Special case: Partial net calories (<75% logged)
    if (hasIncompleteNetCalories) {
      recommendations.add("Some days this week had incomplete logging. Logging consistently helps us provide better recommendations.");
      return recommendations;
    }
    
    final goalLower = goal.toLowerCase();
    final trendLower = trend.toLowerCase();
    
    // Determine goal type
    final bool isLoseGoal = goalLower.contains('lose') || goalLower.contains('fat') || goalLower.contains('deficit');
    final bool isMaintainGoal = goalLower.contains('maintain');
    final bool isGainGoal = goalLower.contains('gain') || goalLower.contains('muscle') || goalLower.contains('surplus');
    
    // Primary recommendation based on goal + trend (exact text as specified)
    if (isLoseGoal) {
      if (trendLower == 'down') {
        recommendations.add("Great job! You're making progress. Keep up the good work and stay consistent.");
      } else if (trendLower == 'same') {
        recommendations.add("It looks like your weight stayed the same this week. Try staying focused and keep following your plan.");
      } else if (trendLower == 'up') {
        recommendations.add("Your weight went up a bit this week. Don't get discouraged—stay consistent and keep going.");
      }
    } else if (isMaintainGoal) {
      if (trendLower == 'down') {
        recommendations.add("You lost a little weight this week. Make sure to follow your usual routine to maintain your goal.");
      } else if (trendLower == 'same') {
        recommendations.add("Perfect! Your weight stayed stable this week. Keep doing what you're doing.");
      } else if (trendLower == 'up') {
        recommendations.add("You gained a little this week. Try to stay on track and keep up your current routine.");
      }
    } else if (isGainGoal) {
      if (trendLower == 'down') {
        recommendations.add("Looks like you lost some weight this week. Focus on your plan and stay consistent to reach your goal.");
      } else if (trendLower == 'same') {
        recommendations.add("You stayed on track this week! Keep going to continue progressing toward your goal.");
      } else if (trendLower == 'up') {
        recommendations.add("Great progress! You're moving in the right direction—keep it up.");
      }
    }
    
    return recommendations;
  }
  
  /// Get motivational message based on trend
  static String getMotivationalMessage(String trend, {bool hasInsufficientActivity = false, bool hasIncompleteNetCalories = false}) {
    if (hasInsufficientActivity) {
      return "Keep logging to track your progress!";
    }
    if (hasIncompleteNetCalories) {
      return "Consistent logging helps us help you better!";
    }
    
    final trendLower = trend.toLowerCase();
    switch (trendLower) {
      case 'down':
        return "You're making progress! Keep up the great work.";
      case 'same':
        return "Consistency is key. Stay focused on your daily habits.";
      case 'up':
        return "Every week is a new opportunity. You've got this!";
      default:
        return "Keep going! Small steps lead to big results.";
    }
  }
}

