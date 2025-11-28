import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/recommendation.dart';
import '../models/challenge.dart';
import '../models/food_models.dart';
import '../models/workout.dart';
import '../models/milestone.dart';
import 'food_log_service.dart';
import 'workout_service_v2.dart';
import 'milestone_service.dart';

class WeeklyRecommendationsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate personalized recommendations based on past week performance
  static Future<List<Recommendation>> generateRecommendations({
    required Challenge challenge,
  }) async {
    try {
      // Step 1: Analyze past 7 days of data
      final performance = await _analyzePastWeek(challenge);

      // Step 2: Generate scored recommendations
      final recommendations = _generateRecommendations(performance, challenge);

      // Step 3: Sort by priority and return top 3
      recommendations.sort((a, b) => b.priority.compareTo(a.priority));

      return recommendations.take(3).toList();
    } catch (e) {
      if (kDebugMode) print('Error generating recommendations: $e');
      return _getFallbackRecommendations();
    }
  }

  /// Analyze past 7 days of user performance
  static Future<WeeklyPerformanceData> _analyzePastWeek(Challenge challenge) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(const Duration(days: 7));

    double totalCalories = 0;
    double totalDeviation = 0;
    int workoutCount = 0;
    int cardioCount = 0;
    int strengthCount = 0;
    int daysWithMeals = 0;
    int photoCount = 0;
    int daysInWeek = 0;

    // Analyze each day in the past week
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));

      // Skip future dates
      if (date.isAfter(now)) continue;

      // Skip dates before challenge started
      if (date.isBefore(challenge.startDate)) continue;

      daysInWeek++;

      // Get food logs for this date
      final foodLogs = await FoodLogService.getFoodLogsForDate(
        date,
        challengeId: challenge.id,
      );

      double dayCalories = 0;
      bool hasMeals = false;

      for (var log in foodLogs) {
        if (log.entries.isNotEmpty) {
          hasMeals = true;
          dayCalories += log.totalCalories;
        }
      }

      if (hasMeals) daysWithMeals++;
      totalCalories += dayCalories;

      // Calculate deviation from goal
      final deviation = dayCalories - challenge.dailyCalorieGoal.toDouble();
      totalDeviation += deviation;

      // Get workouts for this date
      final workouts = await WorkoutServiceV2.getWorkoutsForDate(
        challengeId: challenge.id,
        date: date,
      );

      workoutCount += workouts.length;

      for (var workout in workouts) {
        if (workout.isCardio) {
          cardioCount++;
        } else {
          strengthCount++;
        }
      }

      // Get progress photos for this date
      final allMilestones = await MilestoneService.getAllMilestones(
        challengeId: challenge.id,
      );

      final dayPhotos = allMilestones.where((m) => _isSameDate(m.date, date));
      photoCount += dayPhotos.length;
    }

    // Calculate averages
    final avgCalories = daysInWeek > 0 ? totalCalories / daysInWeek : 0.0;
    final avgDeviation = daysInWeek > 0 ? totalDeviation / daysInWeek : 0.0;
    final mealLoggingRate = daysInWeek > 0 ? daysWithMeals / daysInWeek : 0.0;

    return WeeklyPerformanceData(
      avgCaloriesConsumed: avgCalories,
      avgCalorieDeviation: avgDeviation,
      workoutCount: workoutCount,
      cardioCount: cardioCount,
      strengthCount: strengthCount,
      mealLoggingRate: mealLoggingRate,
      photoCount: photoCount,
      totalActiveDays: daysWithMeals,
      daysInWeek: daysInWeek,
    );
  }

  /// Generate recommendations based on performance analysis
  static List<Recommendation> _generateRecommendations(
      WeeklyPerformanceData performance,
      Challenge challenge,
      ) {
    final recommendations = <Recommendation>[];

    // 1. CALORIE MANAGEMENT (High Priority)
    if (performance.avgCalorieDeviation > 300) {
      // Significantly over goal
      recommendations.add(Recommendation(
        id: 'calories_over',
        title: 'Focus on portion control',
        description:
        'You averaged ${performance.avgCalorieDeviation.round()} calories over your goal. This week: Use smaller plates, fill half with vegetables, measure calorie-dense foods like rice and oils, eat slowly to recognize fullness cues, and swap high-calorie snacks for fruits or nuts.',
        icon: Icons.restaurant_outlined,
        type: RecommendationType.calories,
        priority: 9,
      ));
    } else if (performance.avgCalorieDeviation < -300) {
      // Significantly under goal
      recommendations.add(Recommendation(
        id: 'calories_under',
        title: 'Increase nutrient-dense calories',
        description:
        'You were ${(-performance.avgCalorieDeviation).round()} calories under your goal. This week: Add healthy fats like avocados, nuts, and olive oil. Include lean proteins at each meal. Try calorie-dense smoothies with banana, oats, and nut butter. Eating enough fuels your workouts and recovery.',
        icon: Icons.add_circle_outline,
        type: RecommendationType.calories,
        priority: 8,
      ));
    } else if (performance.avgCalorieDeviation.abs() <= 100 && performance.avgCaloriesConsumed > 0) {
      // Right on target!
      recommendations.add(Recommendation(
        id: 'calories_perfect',
        title: 'Maintain your excellent balance',
        description:
        'You stayed within ${performance.avgCalorieDeviation.abs().round()} calories of your goal—impressive! This week: Continue your current eating patterns, stay mindful of hunger and fullness, and consider meal prepping on Sundays to maintain this consistency.',
        icon: Icons.star_outline,
        type: RecommendationType.calories,
        priority: 5,
      ));
    }

    // 2. WORKOUT FREQUENCY (High Priority)
    if (performance.workoutCount == 0) {
      recommendations.add(Recommendation(
        id: 'workouts_none',
        title: 'Start small with daily movement',
        description:
        'No workouts logged this week. This week\'s goal: Start with 3 days of 15-minute walks. Focus on consistency over intensity. Schedule your walks at the same time daily (morning or after dinner works best). Even light movement boosts mood and burns calories.',
        icon: Icons.directions_walk,
        type: RecommendationType.workouts,
        priority: 9,
      ));
    } else if (performance.workoutCount < 3) {
      recommendations.add(Recommendation(
        id: 'workouts_low',
        title: 'Build workout consistency',
        description:
        'You logged ${performance.workoutCount} workout${performance.workoutCount == 1 ? '' : 's'}. This week: Aim for 3-4 sessions. Try: Monday (30min cardio), Wednesday (strength), Friday (cardio), Saturday (active recovery like yoga). Schedule them in your calendar and set reminders.',
        icon: Icons.fitness_center,
        type: RecommendationType.workouts,
        priority: 8,
      ));
    } else if (performance.workoutCount >= 5) {
      recommendations.add(Recommendation(
        id: 'workouts_excellent',
        title: 'Optimize your training schedule',
        description:
        '${performance.workoutCount} workouts—fantastic dedication! This week: Ensure you\'re including 1-2 rest or active recovery days. Mix intensities: alternate hard workout days with lighter sessions. Consider tracking progressive overload (increasing weights or reps) to keep improving.',
        icon: Icons.emoji_events,
        type: RecommendationType.workouts,
        priority: 4,
      ));
    }

    // 3. WORKOUT VARIETY (Medium Priority)
    if (performance.workoutCount >= 3) {
      if (performance.cardioCount == 0) {
        recommendations.add(Recommendation(
          id: 'add_cardio',
          title: 'Incorporate heart-healthy cardio',
          description:
          'You\'re doing great with strength training! This week: Add 2 cardio sessions. Try: brisk walking (30min), cycling (20min), or swimming (25min). Cardio burns calories, improves heart health, and complements your strength routine. Start at moderate intensity.',
          icon: Icons.directions_run,
          type: RecommendationType.workouts,
          priority: 6,
        ));
      } else if (performance.strengthCount == 0) {
        recommendations.add(Recommendation(
          id: 'add_strength',
          title: 'Add strength training for results',
          description:
          'Great cardio work! This week: Add 2 strength sessions. Start with bodyweight exercises: squats (3×12), push-ups (3×10), lunges (3×10 each leg), planks (3×30sec). Strength training builds muscle, boosts metabolism, and helps maintain weight loss long-term.',
          icon: Icons.fitness_center,
          type: RecommendationType.workouts,
          priority: 6,
        ));
      }
    }

    // 4. MEAL LOGGING CONSISTENCY (Medium Priority)
    if (performance.mealLoggingRate < 0.5) {
      // Less than 50% of days
      recommendations.add(Recommendation(
        id: 'meals_low',
        title: 'Build a daily logging habit',
        description:
        'You logged meals on only ${(performance.mealLoggingRate * 100).round()}% of days. This week: Log immediately after eating (don\'t wait). Pre-log breakfast the night before. Set 3 daily reminders (after each main meal). Research shows daily logging doubles weight loss success.',
        icon: Icons.edit_calendar,
        type: RecommendationType.meals,
        priority: 7,
      ));
    } else if (performance.mealLoggingRate < 0.85) {
      recommendations.add(Recommendation(
        id: 'meals_medium',
        title: 'Reach 100% logging consistency',
        description:
        'You\'re tracking ${(performance.mealLoggingRate * 100).round()}% of days—close to perfect! This week: Identify which meals you skip logging (usually snacks or weekends?). Take quick food photos before eating as reminders. Complete tracking gives you the full picture of your nutrition.',
        icon: Icons.restaurant_menu,
        type: RecommendationType.meals,
        priority: 6,
      ));
    } else if (performance.mealLoggingRate >= 0.85) {
      recommendations.add(Recommendation(
        id: 'meals_excellent',
        title: 'Use your data for insights',
        description:
        'You logged meals on ${(performance.mealLoggingRate * 100).round()}% of days—excellent! This week: Review your logs to identify patterns. Notice: Which meals keep you full longest? When do cravings hit? Which foods fit your goals best? Use these insights to optimize your meal planning.',
        icon: Icons.verified,
        type: RecommendationType.meals,
        priority: 4,
      ));
    }

    // 5. PROGRESS PHOTOS (ALWAYS INCLUDED - High Priority if none)
    // CRITICAL: Always add at least ONE photo recommendation
    if (performance.photoCount == 0) {
      recommendations.add(Recommendation(
        id: 'photos_none',
        title: 'Start documenting your journey',
        description:
        'No milestone photos this week. This week: Take your first progress photo in good lighting, same spot, same time of day (mornings work best). Wear fitted clothes. Take front, side, and back angles. You won\'t see daily changes, but weekly photos reveal amazing progress over time!',
        icon: Icons.photo_camera,
        type: RecommendationType.photos,
        priority: 8, // HIGH PRIORITY - Changed from 7 to 8 to ensure it appears
      ));
    } else if (performance.photoCount == 1) {
      recommendations.add(Recommendation(
        id: 'photos_one',
        title: 'Increase photo consistency',
        description:
        'You uploaded 1 photo—great start! This week: Take 2-3 photos at different times (start, middle, end of week). Use the same lighting and location for accurate comparison. Include a full body shot and close-ups of target areas. Consistency helps you track real changes.',
        icon: Icons.add_a_photo,
        type: RecommendationType.photos,
        priority: 6,
      ));
    } else if (performance.photoCount < 3 && performance.daysInWeek >= 7) {
      recommendations.add(Recommendation(
        id: 'photos_low',
        title: 'Build your visual progress diary',
        description:
        'You uploaded ${performance.photoCount} photos. This week: Aim for 3 milestone photos—Monday (start), Thursday (mid-week), Sunday (end). Add brief notes about how you feel, energy levels, or clothing fit. These details make your journey story complete.',
        icon: Icons.collections_outlined,
        type: RecommendationType.photos,
        priority: 5,
      ));
    } else if (performance.photoCount >= 3) {
      recommendations.add(Recommendation(
        id: 'photos_excellent',
        title: 'Compare and celebrate progress',
        description:
        'Excellent—${performance.photoCount} progress photos! This week: Compare your recent photos with earlier ones. Notice subtle changes in posture, muscle definition, or how clothes fit. Screenshot your favorite comparison. Celebrate non-scale victories! Share progress with a trusted friend for extra motivation.',
        icon: Icons.collections,
        type: RecommendationType.photos,
        priority: 4,
      ));
    }

    // 6. HYDRATION & RECOVERY (Always Important)
    recommendations.add(Recommendation(
      id: 'hydration',
      title: 'Optimize hydration for performance',
      description:
      'This week: Drink 8-10 glasses of water daily (2-3 liters). Start your day with 2 glasses upon waking. Keep a water bottle visible. Drink a glass before each meal (helps with fullness too). Proper hydration improves workout performance, reduces fatigue, and aids recovery.',
      icon: Icons.water_drop_outlined,
      type: RecommendationType.water,
      priority: 3,
    ));

    recommendations.add(Recommendation(
      id: 'sleep',
      title: 'Prioritize recovery with quality sleep',
      description:
      'This week: Aim for 7-9 hours nightly. Create a routine: no screens 1 hour before bed, keep your room cool and dark, go to bed at the same time. Quality sleep reduces cravings, improves workout recovery, and helps your body burn fat more efficiently.',
      icon: Icons.nightlight_outlined,
      type: RecommendationType.sleep,
      priority: 3,
    ));

    recommendations.add(Recommendation(
      id: 'consistency',
      title: 'Stay consistent with your habits',
      description:
      'This week: Focus on showing up daily, even when motivation is low. Track one small win each day (logged meals, completed workout, drank enough water). Small, consistent actions compound into major results. You\'re building a sustainable, healthy lifestyle—not just losing weight.',
      icon: Icons.trending_up,
      type: RecommendationType.consistency,
      priority: 2,
    ));

    return recommendations;
  }

  /// Fallback recommendations if analysis fails
  static List<Recommendation> _getFallbackRecommendations() {
    return [
      Recommendation(
        id: 'fallback_photos',
        title: 'Start your progress photo journey',
        description:
        'This week: Take your first milestone photo today! Find good lighting, wear fitted clothes, and capture front/side/back angles. Progress photos are powerful motivators—you\'ll love looking back at where you started. Take at least 2 photos this week.',
        icon: Icons.photo_camera,
        type: RecommendationType.photos,
        priority: 6, // High priority in fallback
      ),
      Recommendation(
        id: 'fallback_consistency',
        title: 'Focus on daily consistency',
        description:
        'This week: Commit to logging all meals, completing 3 workouts, and taking at least one progress photo. Set daily reminders for each. Small consistent actions create lasting results. You\'ve got this!',
        icon: Icons.check_circle_outline,
        type: RecommendationType.consistency,
        priority: 5,
      ),
      Recommendation(
        id: 'fallback_workouts',
        title: 'Establish a workout routine',
        description:
        'This week: Schedule 3-4 workouts. Mix cardio (walking, cycling) with strength training (bodyweight exercises). Start with 20-30 minute sessions. Exercise boosts metabolism, improves mood, and accelerates your progress toward your goals.',
        icon: Icons.fitness_center,
        type: RecommendationType.workouts,
        priority: 5,
      ),
    ];
  }

  /// Helper to check if two dates are the same day
  static bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}