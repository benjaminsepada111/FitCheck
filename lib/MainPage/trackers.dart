import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/services/workout_service.dart';
import 'package:capstone_project/achievements_page.dart';
import '../app_text_styles.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'dart:async';

class Trackers extends StatefulWidget {
  final Challenge? currentChallenge;
  final Function(int calories) onCaloriesChanged;

  const Trackers({
    super.key,
    this.currentChallenge,
    required this.onCaloriesChanged,
  });

  @override
  State<Trackers> createState() => TrackersState();
}

class TrackersState extends State<Trackers> with SingleTickerProviderStateMixin {
  int _currentCalories = 0;
  int _calorieGoal = 2000;
  int _caloriesBurned = 0;
  int _newBadgesEarned = 0;
  bool _isLoading = true;

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // Stream subscriptions for real-time updates
  StreamSubscription? _foodLogSubscription;
  StreamSubscription? _workoutSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadTodaysData();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _foodLogSubscription?.cancel();
    _workoutSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(Trackers oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when widget updates (e.g., challenge changes)
    if (oldWidget.currentChallenge != widget.currentChallenge) {
      _loadTodaysData();
    }
  }

  Future<void> _loadTodaysData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final today = DateTime.now();

      // Get calorie goal (same logic as FoodLogger)
      int goal = 2000;
      if (widget.currentChallenge?.dailyCalorieGoal != null) {
        goal = widget.currentChallenge!.dailyCalorieGoal;
      } else {
        final calculatedGoal = await UserDataService.getDailyCalorieGoal();
        if (calculatedGoal != 2000) {
          goal = calculatedGoal;
        }
      }

      // Get calories consumed from FoodLogService
      final totalCalories = widget.currentChallenge != null
          ? (await FoodLogService.getDailyCalories(
              today,
              challengeId: widget.currentChallenge!.id,
            )).round()
          : 0;

      // Get calories burned from WorkoutService
      int caloriesBurned = 0;
      if (widget.currentChallenge != null) {
        final workouts = await WorkoutService.getWorkoutsForDate(
          widget.currentChallenge!.id,
          today,
        );

        // Get user weight for calorie calculation
        final userData = await UserDataService.loadUserData();
        final userWeight = userData?.weight?.toDouble() ?? 70.0; // Default 70kg

        for (var workout in workouts) {
          caloriesBurned += workout.calculateCaloriesBurned(userWeight);
        }
      }

      if (mounted) {
        setState(() {
          _calorieGoal = goal;
          _currentCalories = totalCalories;
          _caloriesBurned = caloriesBurned;
          _isLoading = false;
        });

        // Trigger animation
        _animationController.forward(from: 0);

        // Notify parent components
        widget.onCaloriesChanged(_currentCalories);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _calorieGoal = widget.currentChallenge?.dailyCalorieGoal ?? 2000;
          _currentCalories = 0;
          _caloriesBurned = 0;
          _isLoading = false;
        });

        widget.onCaloriesChanged(0);
      }
    }
  }

  // Setup real-time listeners for food logs and workouts
  void _setupRealtimeListeners() {
    if (widget.currentChallenge == null) return;

    // Note: FoodLogService has getFoodLogsStreamForDate but WorkoutService
    // doesn't have a date-specific stream. For now, we'll rely on manual refresh
    // via the refreshData() method called from parent widgets.
  }

  // Public method to refresh data (can be called from parent)
  void refreshData() {
    _loadTodaysData();
  }

  // Calculate net calories (goal - consumed + burned)
  int _calculateNetCalories() {
    return _calorieGoal - _currentCalories + _caloriesBurned;
  }

  double _calculateProgress(int current, int goal) {
    if (goal <= 0) return 0.0;
    return (current / goal).clamp(0.0, 1.0);
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.9) {
      return AppColors.secondary;
    } else if (progress >= 0.7) {
      return AppColors.secondary.shade600;
    } else if (progress >= 0.4) {
      return AppColors.secondary.shade500;
    } else {
      return AppColors.secondary.shade400;
    }
  }

  // Build Calories Consumed Card (with white gradient and floating shadow)
  Widget _buildCaloriesConsumedCard() {
    final progress = _calculateProgress(_currentCalories, _calorieGoal);
    final progressColor = _getProgressColor(progress);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              progressColor.withValues(alpha: 0.05),
              progressColor.withValues(alpha: 0.12),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background icon with opacity
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                Icons.restaurant,
                size: 70,
                color: progressColor.withValues(alpha: 0.06),
              ),
            ),
            // Content
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Consumed",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "$_currentCalories",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                        height: 1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "kcal",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build Net Calories Card (with white gradient and floating shadow)
  Widget _buildNetCaloriesCard() {
    final netCalories = _calculateNetCalories();
    final isPositive = netCalories >= 0;
    final displayColor = isPositive ? Colors.green.shade600 : Colors.red.shade600;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              displayColor.withValues(alpha: 0.05),
              displayColor.withValues(alpha: 0.12),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background icon with opacity
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                isPositive ? Icons.trending_down : Icons.trending_up,
                size: 70,
                color: displayColor.withValues(alpha: 0.06),
              ),
            ),
            // Content
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive ? "Remaining" : "Over Limit",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      netCalories.abs().toString(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: displayColor,
                        height: 1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "kcal",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build Calories Burned Card (with white gradient and floating shadow)
  Widget _buildCaloriesBurnedCard() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.orange.shade300.withValues(alpha: 0.05),
              Colors.orange.shade300.withValues(alpha: 0.12),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background fire icon with opacity
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                Icons.local_fire_department,
                size: 70,
                color: Colors.orange.shade500.withValues(alpha: 0.06),
              ),
            ),
            // Content
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Burned",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "$_caloriesBurned",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade800,
                        height: 1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "kcal",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build Achievement Rectangle (Full Width)
  Widget _buildAchievementRectangle() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AchievementsPage(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.amber.shade100.withValues(alpha: 0.15),
              Colors.amber.shade100.withValues(alpha: 0.25),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Badge icon with gradient
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber.shade400,
                    Colors.amber.shade600,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.shade400.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Statistics and Badges",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _newBadgesEarned > 0
                        ? "You have $_newBadgesEarned new badge${_newBadgesEarned > 1 ? 's' : ''}"
                        : "View your progress and milestones",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow or badge counter
            if (_newBadgesEarned > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.shade600,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.shade300.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  "$_newBadgesEarned",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                color: Colors.amber.shade700,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Calorie Overview", style: AppTextStyles.heading2),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(child: FitCheckLoader()),
          ),
        ],
      );
    }

    // No challenge state
    if (widget.currentChallenge == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Calorie Overview",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timeline_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  "No Active Challenge",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create a challenge to start tracking your progress",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Active challenge state - New Calorie Overview Design
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title with daily goal
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "Calorie Overview",
                style: AppTextStyles.heading2.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "• $_calorieGoal kcal goal",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Three square cards: Consumed | Net | Burned
        Row(
          children: [
            _buildCaloriesConsumedCard(),
            const SizedBox(width: 10),
            _buildNetCaloriesCard(),
            const SizedBox(width: 10),
            _buildCaloriesBurnedCard(),
          ],
        ),

        // Achievement Rectangle (Full Width)
        _buildAchievementRectangle(),
      ],
    );
  }
}
