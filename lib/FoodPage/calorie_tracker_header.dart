import 'package:flutter/material.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/workout_service.dart';
import 'package:capstone_project/services/user_data_service.dart';

class CalorieTrackerHeader extends StatefulWidget {
  final Challenge? currentChallenge;

  const CalorieTrackerHeader({super.key, required this.currentChallenge});

  @override
  State<CalorieTrackerHeader> createState() => CalorieTrackerHeaderState();
}

class CalorieTrackerHeaderState extends State<CalorieTrackerHeader> {
  double _caloriesConsumed = 0;
  int _caloriesBurned = 0;

  @override
  void initState() {
    super.initState();
    loadCalorieData();
  }

  // Public method to refresh calorie data
  Future<void> loadCalorieData() async {
    if (widget.currentChallenge == null) {
      return;
    }

    try {
      final today = DateTime.now();

      // Get calories consumed
      final calories = await FoodLogService.getDailyCalories(
        today,
        challengeId: widget.currentChallenge!.id,
      );

      // Get calories burned from workouts
      int caloriesBurned = 0;
      final workouts = await WorkoutService.getWorkoutsForDate(
        widget.currentChallenge!.id,
        today,
      );

      // Get user weight for calorie calculation
      final userData = await UserDataService.loadUserData();
      final userWeight = userData?.weight?.toDouble() ?? 70.0;

      for (var workout in workouts) {
        caloriesBurned += workout.calculateCaloriesBurned(userWeight);
      }

      if (mounted) {
        setState(() {
          _caloriesConsumed = calories;
          _caloriesBurned = caloriesBurned;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentChallenge == null) {
      return const SizedBox.shrink();
    }

    final calorieGoal = widget.currentChallenge!.dailyCalorieGoal;
    // Net calories = consumed - burned (same as home page)
    final netCalories = (_caloriesConsumed - _caloriesBurned)
        .clamp(0, double.infinity)
        .toInt();

    final progress = calorieGoal > 0
        ? (netCalories / calorieGoal).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF06111D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A2332), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net Calories',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        netCalories.toString(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ $calorieGoal cal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade400.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: Colors.red.shade400,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF1A2332),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
